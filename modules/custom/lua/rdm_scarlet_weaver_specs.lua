-- Scarlet Weaver (RDM) — choose between focused spell pressure and sword offense.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/globals/spells/damage_spell')

local m = Module:new('soulspire_rdm_scarlet_weaver')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.RDM] then
    require('modules/custom/lua/rdm_specs')
end

local actions = require('modules/custom/lua/soulspire_soul_actions')
local YIN, YANG = 1, 2
local SPELLWEAVE, BLADEWEAVE = 247, 274
local ASPECT = 'OX_SCW_ASPECT'
local COOLDOWN = 'OX_SCW_SWITCH_UNTIL'
local RECOVERY = 'OX_SCW_RECOVERY_UNTIL'
local POTENCY = 'OX_SCW_POTENCY'
local sharedRecast = 12
local yinText = 'Enter Yin to strengthen your Scarlet Weaver spells. In combat, both forms share a 12s recast and a 2s recovery.'
local yangText = 'Enter Yang to strengthen regular main-hand sword hits. In combat, both forms share a 12s recast and a 2s recovery.'

local SCARLETWEAVER_KIT_SPELLS =
{
    [144] = { script = 'fire',     name = 'Searing Needle', unlockLvl = 10, castMs = 1500, recastSec = 3, description = 'Single-target flame stitch. Yin increases its damage. 3s recast.' },
    [149] = { script = 'blizzard', name = 'Rime Stitch',    unlockLvl = 10, castMs = 1500, recastSec = 3, description = 'Single-target frost stitch. Yin increases its damage. 3s recast.' },
    [154] = { script = 'aero',     name = 'Gale Needle',    unlockLvl = 10, castMs = 1500, recastSec = 3, description = 'Single-target wind stitch. Yin increases its damage. 3s recast.' },
    [159] = { script = 'stone',    name = 'Copper Stitch',  unlockLvl = 10, castMs = 1500, recastSec = 3, description = 'Single-target earth stitch. Yin increases its damage. 3s recast.' },
    [164] = { script = 'thunder',  name = 'Storm Needle',   unlockLvl = 10, castMs = 1500, recastSec = 3, description = 'Single-target lightning stitch. Yin increases its damage. 3s recast.' },
    [169] = { script = 'water',    name = 'Tide Stitch',    unlockLvl = 10, castMs = 1500, recastSec = 3, description = 'Single-target tidal stitch. Yin increases its damage. 3s recast.' },
    [145] = { script = 'fire_ii',  name = 'Scarlet Spindle',unlockLvl = 30, castMs = 2000, recastSec = 6, description = 'Stronger single-target flame weave. Yin increases its damage. 6s recast.' },
    [165] = { script = 'thunder_ii', name = 'Violet Shuttle',unlockLvl = 50, castMs = 2400, recastSec = 7, description = 'Stronger single-target lightning weave. Yin increases its damage. 7s recast.' },
    [156] = { script = 'aero_iii', name = 'Tempest Loom',   unlockLvl = 70, castMs = 3000, recastSec = 12, description = 'Commit to a strong single-target wind weave. Yin increases its damage. 12s recast.' },
}
local api = { SCARLETWEAVER_KIT_SPELLS = SCARLETWEAVER_KIT_SPELLS }
xi.soulspire.rdmScarletWeaverSpecs = api

local function isWeaver(player)
    return player and player:isPC() and player:getMainJob() == xi.job.RDM and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.RDM, 'scarletweaver')
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function remaining(player, variable)
    return math.max(0, player:getLocalVar(variable) - now())
end

local function inCombat(player)
    return player:isEngaged() or player:hasEnmity()
end

local function apply(player)
    player:setLocalVar('OX_SCW_ACTIVE', 1)
    player:setLocalVar(POTENCY, scale(player:getMainLvl(), 15, 18, 22, 25))
    if player:getLocalVar(ASPECT) == 0 then player:setLocalVar(ASPECT, YANG) end
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar('OX_SCW_ACTIVE', 0)
    player:setLocalVar(ASPECT, 0)
    player:setLocalVar(POTENCY, 0)
    player:sendSoulSpellList()
end

for _, form in ipairs({ { 'composure', YIN }, { 'saboteur', YANG } }) do
    local path = 'xi.actions.abilities.' .. form[1]
    local aspect = form[2]
    m:addOverride(path .. '.onAbilityCheck', function(player, target, ability)
        if not isWeaver(player) then return super(player, target, ability) end
        if player:getLocalVar(ASPECT) == aspect or (inCombat(player) and remaining(player, COOLDOWN) > 0) then
            return xi.msg.basic.UNABLE_TO_USE_JA, 0
        end
        -- Both forms share the Soul timer, including across their different native recast groups.
        ability:setRecast(0)
        ability:setCE(0)
        ability:setVE(0)
        return 0, 0
    end)
    m:addOverride(path .. '.onUseAbility', function(player, target, ability, action)
        if not isWeaver(player) then return super(player, target, ability, action) end
        if inCombat(player) then
            player:setLocalVar(COOLDOWN, now() + sharedRecast)
            player:setLocalVar(RECOVERY, now() + 2)
        else
            player:setLocalVar(RECOVERY, 0)
        end
        player:setLocalVar(ASPECT, aspect)
        return 0
    end)
end

for _, entry in pairs(SCARLETWEAVER_KIT_SPELLS) do
    m:addOverride('xi.actions.spells.black.' .. entry.script .. '.onMagicCastingCheck', function(caster, target, spell)
        if not isWeaver(caster) then return super(caster, target, spell) end
        if caster:getMainLvl() < entry.unlockLvl or not target:isMob() then return xi.msg.basic.CANNOT_CAST_SPELL end
        spell:setCastTime(entry.castMs)
        return 0
    end)
end

api.adjustDamage = function(caster, spell, damage)
    if damage > 0 and isWeaver(caster) and SCARLETWEAVER_KIT_SPELLS[spell:getID()] and
        caster:getLocalVar(ASPECT) == YIN and remaining(caster, RECOVERY) == 0
    then
        return math.floor(damage * (100 + caster:getLocalVar(POTENCY)) / 100)
    end
    return damage
end

actions.register('scarletweaver',
{
    spell = SCARLETWEAVER_KIT_SPELLS,
    ability =
    {
        [SPELLWEAVE] = { name = 'Spellweave', description = yinText, recastTime = sharedRecast },
        [BLADEWEAVE] = { name = 'Bladeweave', description = yangText, recastTime = sharedRecast },
    },
})

spec.registerCrystal(xi.job.RDM,
{
    id = 3, key = 'scarletweaver', name = 'Scarlet Weaver', abr = 'SCW', role = 'Damage',
    icon = 'scarletweaver', reqLevel = 10,
    description = 'Commit to one offensive form. Yin focuses elemental spell damage. Yang focuses ordinary Sword swings.',
    highlights =
    {
        'Lv.10: Spellweave enters Yin and Bladeweave enters Yang. Start in Yang on activation.',
        'Combat form changes share a 12s recast and a 2s offensive recovery. Change freely outside combat.',
        'Lv.30/50/70 unlock stronger spells and raise the active form bonus from 15% to 18/22/25%.',
    },
    extraAbilities = function(_, level) return level >= 10 and { SPELLWEAVE, BLADEWEAVE } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.SWORD, scale(level, 10, 18, 28, 40) },
            { xi.mod.ACC, scale(level, 10, 18, 28, 38) },
            { xi.mod.DEX, scale(level, 6, 10, 15, 20) },
            { xi.mod.INT, scale(level, 6, 12, 18, 25) },
            { xi.mod.MATT, scale(level, 8, 14, 22, 30) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isWeaver(player) then apply(player) end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('scarletweaver', function(player)
        return
        {
            form = player:getLocalVar(ASPECT), switch_cd = remaining(player, COOLDOWN),
            recovery_rem = remaining(player, RECOVERY), bonus = player:getLocalVar(POTENCY),
        }
    end)
end

return m
