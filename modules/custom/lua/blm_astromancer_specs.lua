-- Astromancer (BLM) — elemental probes and deliberate Ancient Magic.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/globals/spells/damage_spell')

local m = Module:new('soulspire_blm_astromancer')
local spec = xi.soulspire.spec
-- The wiki exporter may discover this additive module before the base BLM module.
if spec.jobs and not spec.jobs[xi.job.BLM] then
    require('modules/custom/lua/blm_specs')
end

local actions = require('modules/custom/lua/soulspire_soul_actions')
local unpack = table.unpack or unpack
local RECOVERY = 'OX_AST_RECOVERY'
local SATURATION = 'OX_AST_SATURATION'
local ENCOUNTER_HP = 'OX_AST_ENCOUNTER_HP'
local ALIGNMENT = 'OX_AST_ALIGNMENT'
local RESERVE_RECAST = 'OX_AST_RESERVE_RECAST'
local INVOCATION = 160
local SURVEY = 235
local GATHER_AETHER = 75

local probes =
{
    { 144, 'fire',     'Cinder',       'Fire',    xi.element.FIRE,    xi.mod.FIRE_RES_RANK,    6 },
    { 149, 'blizzard', 'Rime',         'Ice',     xi.element.ICE,     xi.mod.ICE_RES_RANK,     8 },
    { 154, 'aero',     'Gale',         'Wind',    xi.element.WIND,    xi.mod.WIND_RES_RANK,    6 },
    { 159, 'stone',    'Bedrock',      'Earth',   xi.element.EARTH,   xi.mod.EARTH_RES_RANK,   4 },
    { 164, 'thunder',  'Static Spark', 'Thunder', xi.element.THUNDER, xi.mod.THUNDER_RES_RANK, 9 },
    { 169, 'water',    'Tsunami',      'Water',   xi.element.WATER,   xi.mod.WATER_RES_RANK,   5 },
}

local ancients =
{
    { 204, 'flare',   'Solar Collapse', 'Fire' },
    { 206, 'freeze',  'Rimefall',       'Ice' },
    { 208, 'tornado', 'Skybreak',       'Wind' },
    { 210, 'quake',   'Worldsplitter',  'Earth' },
    { 212, 'burst',   'Thunderstar',    'Thunder' },
    { 214, 'flood',   'Tidal Cataclysm', 'Water' },
}

local ASTROMANCER_KIT_SPELLS =
{
    [INVOCATION] =
    {
        script = 'stone_ii', name = 'Ancient Invocation', unlockLvl = 10, castMs = 4500, recastSec = 18,
        ancient = true,
        description = 'Invoke Ancient Magic in your last damaging probe element, or earth by default. Costs 16% max MP. 18s shared recovery.',
    },
    [SURVEY] =
    {
        script = 'burn', name = 'Elemental Survey', unlockLvl = 30, castMs = 1000, recastSec = 30,
        description = 'Read the weakest elemental resistances of one enemy. Costs 2% max MP. 30s recast.',
    },
    [261] =
    {
        script = 'warp', name = 'Starway', unlockLvl = 30, castMs = 4000, recastSec = 10, mpCost = 100,
        description = 'Return to your home point. Costs 100 MP. 10s recast.',
    },
}

for _, probe in ipairs(probes) do
    local id, script, name, elementName, element, _, mp = unpack(probe)
    ASTROMANCER_KIT_SPELLS[id] =
    {
        script = script, name = name, unlockLvl = 10, castMs = 1500, recastSec = 3, mpCost = mp,
        probe = element,
        description = string.format('%s probe. Damage aligns Ancient Invocation to this element. %d MP. 3s recast.', elementName, mp),
    }
end

for _, ancient in ipairs(ancients) do
    local id, script, name, elementName = unpack(ancient)
    ASTROMANCER_KIT_SPELLS[id] =
    {
        script = script, name = name, unlockLvl = 50, castMs = 7000, recastSec = 18, ancient = true,
        description = string.format('%s Ancient Magic against one enemy. Costs 22%% max MP. 18s shared recovery. Can trigger Astral Saturation.', elementName),
    }
end

local api = { ASTROMANCER_KIT_SPELLS = ASTROMANCER_KIT_SPELLS }
xi.soulspire.blmAstromancerSpecs = api

local function isAstromancer(player)
    return player and player:isPC() and player:getMainJob() == xi.job.BLM and
        player:getMainLvl() >= 10 and spec.is(player, xi.job.BLM, 'astromancer')
end

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function remaining(entity, key)
    return math.max(0, entity:getLocalVar(key) - now())
end

local function alignment(player)
    local element = player:getLocalVar(ALIGNMENT)
    return element ~= 0 and element or xi.element.EARTH
end

local function apply(player)
    player:setLocalVar('OX_AST_ACTIVE', 1)
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar('OX_AST_ACTIVE', 0)
    player:setLocalVar(ALIGNMENT, 0)
    player:setLocalVar('OX_AST_LAST_TARGET', 0)
    player:sendSoulSpellList()
end

local function reportSurvey(player, target)
    local bestRank
    local weakest = {}
    for _, probe in ipairs(probes) do
        local rank = target:getMod(probe[6])
        if not bestRank or rank < bestRank then
            bestRank = rank
            weakest = {}
        end
        if rank == bestRank then weakest[#weakest + 1] = probe[4] end
    end
    player:printToPlayer('Elemental Survey: lowest resistance — ' .. table.concat(weakest, ', ') .. '.', xi.msg.channel.SYSTEM_3, '')
end

local spellActions = {}
for id, entry in pairs(ASTROMANCER_KIT_SPELLS) do
    local spellPath = 'xi.actions.spells.black.' .. entry.script
    spellActions[id] =
    {
        name = entry.name, description = entry.description, castTime = entry.castMs / 1000,
        recastTime = entry.recastSec, mpCost = entry.mpCost,
    }
    m:addOverride(spellPath .. '.onMagicCastingCheck', function(caster, target, spell)
        if not isAstromancer(caster) then return super(caster, target, spell) end
        if caster:getMainLvl() < entry.unlockLvl or (id ~= 261 and not target:isMob()) then
            return xi.msg.basic.CANNOT_CAST_SPELL
        end
        if id == 261 then
            return super(caster, target, spell)
        end
        spell:setCastTime(entry.castMs)
        if id == INVOCATION then
            spell:setElement(alignment(caster))
        end
        return 0
    end)

    if entry.ancient or id == SURVEY then
        m:addOverride(spellPath .. '.onSpellCast', function(caster, target, spell)
            if not isAstromancer(caster) then return super(caster, target, spell) end
            if id == SURVEY then
                reportSurvey(caster, target)
                spell:setMsg(0)
                return 0
            end
            caster:setLocalVar(RECOVERY, now() + 18)
            return super(caster, target, spell)
        end)
    end
end

local reserveDescription = 'Recover 10% of your maximum MP. 90s recast.'
m:addOverride('xi.actions.abilities.elemental_seal.onAbilityCheck', function(player, target, ability)
    if not isAstromancer(player) then return super(player, target, ability) end
    if player:getMP() >= player:getMaxMP() then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRecast(90)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.elemental_seal.onUseAbility', function(player, target, ability, action)
    if not isAstromancer(player) then return super(player, target, ability, action) end
    player:addMP(math.max(1, math.floor(player:getMaxMP() * 0.10)))
    player:setLocalVar(RESERVE_RECAST, now() + 90)
    return 0
end)

api.adjustDamage = function(caster, target, spell, damage)
    if damage <= 0 or not isAstromancer(caster) or not target:isMob() then return damage end
    local entry = ASTROMANCER_KIT_SPELLS[spell:getID()]
    if not entry or not entry.ancient then return damage end

    local level = caster:getMainLvl()
    local factor = spell:getID() == INVOCATION and 3 or (level >= 70 and 2.5 or 2)
    local bonus = math.floor(damage * (factor - 1))
    if level >= 70 and target:isNM() then
        local hp = target:getLocalVar(ENCOUNTER_HP)
        if hp == 0 then
            hp = target:getMaxHP()
            target:setLocalVar(ENCOUNTER_HP, hp)
        end
        bonus = math.min(bonus, math.floor(hp * 0.03))
    end
    if remaining(target, SATURATION) > 0 then
        bonus = math.floor(bonus * 0.10)
    end
    return damage + bonus
end

api.basePower = function(caster, spellId, power)
    if spellId == INVOCATION and isAstromancer(caster) then
        return 12 + math.floor(caster:getMainLvl() * 0.8)
    end
    return power
end

api.onNukeDamage = function(caster, target, spell, damage)
    if damage <= 0 or not isAstromancer(caster) or not target:isMob() then return end
    local entry = ASTROMANCER_KIT_SPELLS[spell:getID()]
    if not entry then return end
    caster:setLocalVar('OX_AST_LAST_TARGET', target:getID())
    caster:setLocalVar('OX_AST_LAST_ZONE', target:getZoneID())
    if entry.probe then
        caster:setLocalVar(ALIGNMENT, entry.probe)
    elseif entry.ancient and remaining(target, SATURATION) == 0 then
        target:setLocalVar(SATURATION, now() + 20)
    end
end

actions.register('astromancer',
{
    spell = spellActions,
    ability = { [GATHER_AETHER] = { name = 'Gather Aether', description = reserveDescription, recastTime = 90 } },
})

spec.registerCrystal(xi.job.BLM,
{
    id = 1,
    key = 'astromancer',
    name = 'Astromancer',
    abr = 'AST',
    role = 'Damage',
    icon = 'astromancer',
    reqLevel = 10,
    description = 'Read an enemy with elemental probes and commit to one decisive, single-target Ancient Magic cast.',
    highlights =
    {
        'Lv.10: Elemental probes set Ancient Invocation alignment. Gather Aether restores MP.',
        'Lv.30: Read the target with Elemental Survey. Lv.50: Choose from six powerful Ancient Magic spells. Lv.70: Their power increases.',
        'Ancient resolves into 18s shared recovery. Astral Saturation reduces the unique damage bonus of allied follow-up Ancients for 20s.',
    },
    extraAbilities = function(_, level)
        return level >= 10 and { GATHER_AETHER } or {}
    end,
    mods = function(_, level)
        local tier = level >= 70 and 4 or (level >= 50 and 3 or (level >= 30 and 2 or 1))
        return
        {
            { xi.mod.INT,  ({ 8, 15, 22, 30 })[tier] },
            { xi.mod.MATT, ({ 10, 18, 28, 38 })[tier] },
            { xi.mod.MACC, ({ 8, 15, 24, 34 })[tier] },
            { xi.mod.MPP,  ({ 6, 10, 14, 18 })[tier] },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isAstromancer(player) then apply(player) end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('astromancer', function(player)
        local target = player:getTarget()
        if (not target or not target:isMob()) and player:getLocalVar('OX_AST_LAST_TARGET') > 0 and
            player:getLocalVar('OX_AST_LAST_ZONE') == player:getZoneID()
        then
            target = GetEntityByID(player:getLocalVar('OX_AST_LAST_TARGET'), player:getInstance(), true)
        end
        return
        {
            element = alignment(player),
            recovery_cd = remaining(player, RECOVERY),
            sat_rem = target and target:isMob() and target:isAlive() and remaining(target, SATURATION) or 0,
            aether_cd = remaining(player, RESERVE_RECAST),
        }
    end)
end

return m
