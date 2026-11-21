-- Scourge (DRK) - maintain one tactical curse on the enemy.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/globals/spells/damage_spell')
require('scripts/combat/basic/magic_hit_rate')

local m = Module:new('soulspire_drk_scourge')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.DRK] then require('modules/custom/lua/drk_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local WITHERING, ASH, FAMINE = 1, 2, 3
local CURSE, WARD = 'OX_SCR_CURSE', 'OX_SCR_WARD'
local CURSE_CD, WARD_CD, RITE_CD = 'OX_SCR_CURSE_CD', 'OX_SCR_WARD_CD', 'OX_SCR_RITE_CD'
local riteHelp = 'Recover MP while your current enemy bears one of your curses or immunity wards. 24s recast.'
local SCOURGE_KIT_SPELLS =
{
    [266] =
    {
        script = 'absorb-str', name = 'Withering', unlockLvl = 10, castMs = 1000, recastSec = 12, mpCost = 10,
        description = 'Curse one enemy to dampen its physical TP moves for 24 seconds. Shares a 12s recast with other curses.',
    },
    [230] =
    {
        script = 'bio', name = 'Ash', unlockLvl = 10, castMs = 1000, recastSec = 12, mpCost = 10,
        description = 'Curse one enemy to dampen its damaging spells for 24 seconds. Shares a 12s recast with other curses.',
    },
    [271] =
    {
        script = 'absorb-mnd', name = 'Famine', unlockLvl = 30, castMs = 1000, recastSec = 12, mpCost = 10,
        description = 'Curse one enemy to reduce its own combat healing for 24 seconds. Shares a 12s recast with other curses.',
    },
}
xi.soulspire.drkScourgeSpecs = { SCOURGE_KIT_SPELLS = SCOURGE_KIT_SPELLS }

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function isScourge(player)
    return player and player:isPC() and player:getMainJob() == xi.job.DRK and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.DRK, 'scourge')
end

local function isEnemy(target)
    return target and target:isMob() and target:isAlive()
end

local function remaining(entity, key)
    return math.max(0, entity:getLocalVar(key) - now())
end

local function effectOwner(target, prefix)
    if not isEnemy(target) or remaining(target, prefix .. '_END') == 0 then return nil end
    local owner = GetPlayerByID(target:getLocalVar(prefix .. '_OWNER'))
    if isScourge(owner) and owner:getZoneID() == target:getZoneID() then return owner end
    target:setLocalVar(prefix .. '_END', 0)
    return nil
end

local function inParty(owner, actor)
    if not actor:isPC() then actor = actor:getMaster() end
    if not actor then return false end
    if owner:getID() == actor:getID() then return true end
    for _, member in ipairs(owner:getParty()) do
        if member:getID() == actor:getID() then return true end
    end
    return false
end

local function setEffect(target, prefix, player, kind, pct, seconds)
    target:setLocalVar(prefix .. '_OWNER', player:getID())
    target:setLocalVar(prefix .. '_KIND', kind)
    target:setLocalVar(prefix .. '_PCT', pct)
    target:setLocalVar(prefix .. '_END', now() + seconds)
end

local function reduce(target, kind, amount, victim)
    if amount <= 0 then return amount end
    if target:getLocalVar(CURSE .. '_KIND') == kind and effectOwner(target, CURSE) then
        return amount - math.floor(amount * target:getLocalVar(CURSE .. '_PCT') / 100)
    end
    if target:getLocalVar(WARD .. '_KIND') == kind then
        local owner = effectOwner(target, WARD)
        if owner and (not victim or inParty(owner, victim)) then
            target:setLocalVar(WARD .. '_END', 0)
            return amount - math.floor(amount * target:getLocalVar(WARD .. '_PCT') / 100)
        end
    end
    return amount
end

local priorDamage = xi.soulspire.onPreTakeDamage
xi.soulspire.onPreTakeDamage = function(defender, amount, attacker, attackType, damageType)
    if priorDamage then amount = priorDamage(defender, amount, attacker, attackType, damageType) end
    if type(amount) ~= 'number' or amount <= 0 or not isEnemy(attacker) then return amount end
    local category = attacker:getLocalVar('OX_SCR_ACTION')
    if category == 1 and (attackType == xi.attackType.PHYSICAL or attackType == xi.attackType.RANGED) then
        return reduce(attacker, WITHERING, amount, defender)
    elseif category == 2 and attackType == xi.attackType.MAGICAL then
        return reduce(attacker, ASH, amount, defender)
    end
    return amount
end

xi.soulspire.scourge =
{
    reduceSelfHeal = function(actor, target, amount)
        if isEnemy(actor) and actor:getID() == target:getID() and actor:getLocalVar('OX_SCR_ACTION') > 0 then
            return reduce(actor, FAMINE, amount)
        end
        return amount
    end,
}

local function notify(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3)
end

local function castCurse(player, target, kind, definition, spell)
    player:setLocalVar(CURSE_CD, now() + 12)
    for id, other in pairs(SCOURGE_KIT_SPELLS) do
        if id ~= spell:getID() and other.unlockLvl <= player:getMainLvl() then
            player:addRecast(xi.recast.MAGIC, id, 12)
        end
    end

    local level = player:getMainLvl()
    local potency = kind == FAMINE and scale(level, 0, 20, 25, 30) or scale(level, 8, 8, 12, 15)
    local dark = xi.element.DARK
    local magic = xi.spells.damage
    local fullyImmune = magic.calculateNullification(target, dark, false, true, false, false) == 0 or
        magic.calculateAbsorption(target, dark, false, true, false, false) < 0
    if fullyImmune then
        spell:setMsg(xi.msg.basic.MAGIC_RESIST)
        local existingCurse = target:getLocalVar(CURSE .. '_KIND') == kind and effectOwner(target, CURSE)
        if not existingCurse and not effectOwner(target, WARD) and remaining(player, WARD_CD) == 0 then
            player:setLocalVar(WARD_CD, now() + 24)
            setEffect(target, WARD, player, kind, math.floor(potency / 2), 8)
            notify(player, 'Your immunity ward is ready for the next matching action.')
        end
        return 0
    end

    local params = { magicalElement = dark, actorStat = xi.mod.INT, skillType = xi.skill.DARK_MAGIC, spellGroup = xi.magic.spellGroup.BLACK }
    local resist = xi.combat.magicHitRate.calculateResistRate(player, target, params)
    if resist < 0.5 then
        spell:setMsg(xi.msg.basic.MAGIC_RESIST)
        return 0
    end

    if target:getLocalVar(WARD .. '_KIND') == kind then target:setLocalVar(WARD .. '_END', 0) end
    setEffect(target, CURSE, player, kind, potency, resist >= 1 and 24 or 12)
    spell:setMsg(xi.msg.basic.NONE)
    notify(player, definition.name .. ' afflicts ' .. target:getName() .. '.')
    return 0
end

for _, row in ipairs({ {266, WITHERING}, {230, ASH}, {271, FAMINE} }) do
    local definition = SCOURGE_KIT_SPELLS[row[1]]
    local kind = row[2]
    local path = 'xi.actions.spells.black.' .. definition.script
    m:addOverride(path .. '.onMagicCastingCheck', function(player, target, spell)
        if not isScourge(player) then return super(player, target, spell) end
        if not isEnemy(target) or player:getMainLvl() < definition.unlockLvl or remaining(player, CURSE_CD) > 0 then
            return xi.msg.basic.MAGIC_UNABLE_TO_CAST
        end
        return 0
    end)
    m:addOverride(path .. '.onSpellCast', function(player, target, spell, action)
        if not isScourge(player) then return super(player, target, spell, action) end
        return castCurse(player, target, kind, definition, spell)
    end)
end

local function ownsTargetEffect(player)
    local target = player:getTarget()
    for _, prefix in ipairs({ CURSE, WARD }) do
        local owner = effectOwner(target, prefix)
        if owner and owner:getID() == player:getID() then return true end
    end
    return false
end

m:addOverride('xi.actions.abilities.arcane_circle.onAbilityCheck', function(player, target, ability)
    if not isScourge(player) then return super(player, target, ability) end
    if player:getMP() >= player:getMaxMP() or not ownsTargetEffect(player) then
        return xi.msg.basic.UNABLE_TO_USE_JA, 0
    end
    ability:setRecast(24)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.arcane_circle.onUseAbility', function(player, target, ability, action)
    if not isScourge(player) then return super(player, target, ability, action) end
    player:setLocalVar(RITE_CD, now() + 24)
    local amount = math.min(player:getMaxMP() - player:getMP(), scale(player:getMainLvl(), 14, 18, 22, 28))
    player:addMP(amount)
    if action then action:messageID(player:getID(), xi.msg.basic.JA_RECOVERS_MP) end
    return amount
end)

local function apply(player)
    player:setLocalVar('OX_SCR_ACTIVE', 1)
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar('OX_SCR_ACTIVE', 0)
    player:sendSoulSpellList()
end

actions.register('scourge',
{
    spell = SCOURGE_KIT_SPELLS,
    ability = { [50] = { name = 'Rite of Malice', description = riteHelp, recastTime = 24 } },
})

spec.registerCrystal(xi.job.DRK,
{
    id = 3, key = 'scourge', name = 'Scourge', abr = 'SCR', role = 'Support', icon = 'scourge', reqLevel = 10,
    description = 'Choose one curse to dampen a dangerous enemy action, with a short ward against explicit dark immunity.',
    highlights =
    {
        'Withering and Ash are available at Lv.10. They reduce physical TP or spell damage by 8/8/12/15% at Lv.10/30/50/70+.',
        'Famine unlocks at Lv.30 and reduces standard enemy self-heals by 20/25/30%.',
        'Curses share a 12-second recast and last up to 24 seconds. A resisted curse leaves any current curse active.',
        'Dark immunity can grant an eight-second party ward at half potency for one matching hit or heal.',
    },
    extraAbilities = function(_, level) return level >= 10 and { 50 } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.MACC, scale(level, 10, 18, 28, 38) },
            { xi.mod.MPP, scale(level, 6, 10, 14, 18) },
            { xi.mod.HPP, scale(level, 4, 6, 8, 10) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isScourge(player) then apply(player) end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('scourge', function(player)
        local target = player:getTarget()
        local curse = effectOwner(target, CURSE)
        local ward = effectOwner(target, WARD)
        return
        {
            curse_kind = curse and target:getLocalVar(CURSE .. '_KIND') or 0,
            curse_rem = curse and remaining(target, CURSE .. '_END') or 0,
            ward_kind = ward and target:getLocalVar(WARD .. '_KIND') or 0,
            ward_rem = ward and remaining(target, WARD .. '_END') or 0,
            curse_cd = remaining(player, CURSE_CD), rite_cd = remaining(player, RITE_CD),
        }
    end)
end

return m
