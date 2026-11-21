-----------------------------------
-- Zealot (WHM) — Staff Communion and single-target divine magic.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/globals/spells/damage_spell')

local m = Module:new('soulspire_whm_zealot')
local spec = xi.soulspire.spec
local actions = require('modules/custom/lua/soulspire_soul_actions')
local KEY = 'zealot'
local DIVINE_SEAL = 74
local ATTACK_LISTENER = 'OX_ZEALOT_COMMUNION'
local STAFF_LOCK = 'OX_ZEALOT_COMMUNION_UNTIL'
local SEAL_WINDOW = 'OX_ZEALOT_SEAL_UNTIL'
local SEAL_RECAST = 'OX_ZEALOT_SEAL_RECAST'
local SEAL_DURATION = 20
local SEAL_COOLDOWN = 90
local SEAL_NAME = 'Consecration'
local SEAL_DESCRIPTION = 'Empower your next damaging Zealot spell by 20%. Lasts up to 20s. 90s recast.'

local ZEALOT_KIT_SPELLS =
{
    [28] = { script = 'banish',     name = 'Dawnfire',      unlockLvl = 10, castMs = 2000, recastSec = 6,  mpPercent = 8,  mult = 1.5,
             description = 'Strike one enemy with light. Costs 8% max MP. 6s recast.' },
    [29] = { script = 'banish_ii',  name = 'Sunbrand',      unlockLvl = 30, castMs = 2500, recastSec = 8,  mpPercent = 12, mult = 1.6,
             description = 'Burn one enemy with concentrated light. Costs 12% max MP. 8s recast.' },
    [30] = { script = 'banish_iii', name = 'Pillar of Day', unlockLvl = 50, castMs = 3000, recastSec = 12, mpPercent = 16, mult = 1.5,
             description = 'Smite one enemy with a pillar of light. Costs 16% max MP. 12s recast.' },
    [21] = { script = 'holy',       name = 'Last Light',    unlockLvl = 50, castMs = 3500, recastSec = 14, mpPercent = 20, mult = 1.8,
             description = 'Commit to a heavy light strike against one enemy. Costs 20% max MP, 22% at Lv.70 with increased power. 14s recast.' },
}

xi.soulspire.whmZealotSpecs = { ZEALOT_KIT_SPELLS = ZEALOT_KIT_SPELLS }

local function isZealot(player)
    return player and player:isPC() and player:getMainJob() == xi.job.WHM and
        player:getMainLvl() >= 10 and spec.is(player, xi.job.WHM, KEY)
end

local function hasStaff(player)
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.STAFF
end

local function scale(level, first, second, third, fourth)
    if level >= 70 then return fourth end
    if level >= 50 then return third end
    if level >= 30 then return second end
    return first
end

local function remaining(player, key)
    return math.max(0, player:getLocalVar(key) - xi.soulspire.nowSec())
end

local function clear(player)
    player:setLocalVar('OX_ZEALOT_ACTIVE', 0)
    player:setLocalVar(STAFF_LOCK, 0)
    player:setLocalVar(SEAL_WINDOW, 0)
    player:removeListener(ATTACK_LISTENER)
    player:sendSoulSpellList()
end

local function refreshSpells(player)
    player:setLocalVar('OX_ZEALOT_ACTIVE', 1)
    player:sendSoulSpellList()
end

local function onAttack(player, target)
    if not isZealot(player) or not hasStaff(player) or not target or not target:isMob() or
        remaining(player, STAFF_LOCK) > 0
    then
        return
    end

    local rate = scale(player:getMainLvl(), 35, 40, 40, 45)
    local restored = player:addMP(math.max(2, math.floor(player:getMaxMP() * rate / 1000)))
    if restored > 0 then
        player:setLocalVar(STAFF_LOCK, xi.soulspire.nowSec() + 3)
    end
end

local function attach(player)
    refreshSpells(player)
    player:removeListener(ATTACK_LISTENER)
    player:addListener('SOUL_STAFF_HIT', ATTACK_LISTENER, onAttack)
end

local spells = {}
for id, entry in pairs(ZEALOT_KIT_SPELLS) do
    local path = 'xi.actions.spells.white.' .. entry.script
    spells[id] =
    {
        name = entry.name,
        description = entry.description,
        castTime = entry.castMs / 1000,
        recastTime = entry.recastSec,
    }

    m:addOverride(path .. '.onMagicCastingCheck', function(caster, target, spell)
        if not isZealot(caster) then
            return super(caster, target, spell)
        end

        if not hasStaff(caster) or not target:isMob() or caster:getMainLvl() < entry.unlockLvl then
            return xi.msg.basic.CANNOT_CAST_SPELL
        end

        spell:setCastTime(entry.castMs)
        return 0
    end)
end

m:addOverride('xi.actions.abilities.divine_seal.onAbilityCheck', function(player, target, ability)
    if not isZealot(player) then
        return super(player, target, ability)
    end

    if not hasStaff(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end

    ability:setRecast(SEAL_COOLDOWN)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.divine_seal.onUseAbility', function(player, target, ability)
    if not isZealot(player) then
        return super(player, target, ability)
    end

    local now = xi.soulspire.nowSec()
    player:setLocalVar(SEAL_WINDOW, now + SEAL_DURATION)
    player:setLocalVar(SEAL_RECAST, now + SEAL_COOLDOWN)
    return 0
end)

-- The native damage pipeline owns resists, mitigation, damage caps and enmity.
-- The scalar applies before mitigation. Consume the seal only after positive damage.
xi.soulspire.whmZealotSpecs.damageMultiplier = function(caster, spell)
    if not isZealot(caster) then return 1 end
    local entry = ZEALOT_KIT_SPELLS[spell:getID()]
    if not entry then return 1 end
    local multiplier = spell:getID() == 21 and caster:getMainLvl() >= 70 and 2 or entry.mult
    return multiplier * (remaining(caster, SEAL_WINDOW) > 0 and 1.20 or 1)
end

xi.soulspire.whmZealotSpecs.onNukeDamage = function(caster, spell, damage)
    if damage > 0 and isZealot(caster) and ZEALOT_KIT_SPELLS[spell:getID()] then
        caster:setLocalVar(SEAL_WINDOW, 0)
    end
end

actions.register(KEY,
{
    spell = spells,
    ability = { [DIVINE_SEAL] = { name = SEAL_NAME, description = SEAL_DESCRIPTION, recastTime = SEAL_COOLDOWN } },
})

spec.registerCrystal(xi.job.WHM,
{
    id = 2,
    key = 'zealot',
    name = 'Zealot',
    abr = 'ZEL',
    role = 'Damage',
    icon = 'zealot',
    reqLevel = 10,
    description = 'Fight in melee to refill MP with Staff Communion. Spend it on powerful light magic against a single enemy.',
    highlights =
    {
        'Staff Communion restores MP on a damaging staff attack round, at most once every 3 seconds.',
        'At Lv.10, use Dawnfire and Consecration. Sunbrand unlocks at Lv.30, then Pillar of Day and Last Light at Lv.50. Last Light intensifies at Lv.70.',
        'Consecration amplifies the next damaging spell within 20 seconds, so hold it for an opening.',
    },
    extraAbilities = function(_, level)
        return level >= 10 and { DIVINE_SEAL } or {}
    end,
    mods = function(_, level)
        return
        {
            { xi.mod.STAFF, scale(level, 12, 22, 34, 46) },
            { xi.mod.ACC,   scale(level, 10, 18, 28, 40) },
            { xi.mod.MND,   scale(level,  6, 12, 18, 25) },
            { xi.mod.MATT,  scale(level,  8, 14, 22, 30) },
            { xi.mod.MACC,  scale(level,  8, 14, 22, 30) },
        }
    end,
    onApply = attach,
    onRemove = clear,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isZealot(player) then
            refreshSpells(player)
        end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider(KEY, function(player)
        return
        {
            staff = hasStaff(player) and 1 or 0,
            communion_cd = math.ceil(remaining(player, STAFF_LOCK)),
            seal_rem = math.ceil(remaining(player, SEAL_WINDOW)),
            seal_cd = math.ceil(remaining(player, SEAL_RECAST)),
        }
    end)
end

return m
