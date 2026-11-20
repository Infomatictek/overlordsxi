-- Valkyrie (WHM) — rescue a party caster after a hostile cast interruption.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_whm_valkyrie')
local spec = xi.soulspire.spec
local actions = require('modules/custom/lua/soulspire_soul_actions')
local WINGMATE = 273
local ESCORT = 275
local WINGMATE_RECAST = 5
local ESCORT_RECAST = 25
local WINDOW = 6
local WINGMATE_ID = 'OX_VLK_WINGMATE'
local INTERRUPT_UNTIL = 'OX_VLK_INTERRUPT_UNTIL'
local INTERRUPT_SPELL = 'OX_VLK_INTERRUPT_SPELL'
local RETRY_UNTIL = 'OX_VLK_RETRY_UNTIL'
local RETRY_SPELL = 'OX_VLK_RETRY_SPELL'
local RETRY_REFUND = 'OX_VLK_RETRY_REFUND'
local RETRY_OWNER = 'OX_VLK_RETRY_OWNER'
local ESCORT_RECAST_UNTIL = 'OX_VLK_ESCORT_RECAST'

local VALKYRIE_KIT_SPELLS =
{
    [28] =
    {
        name = 'Vigil Lance', script = 'banish',
        unlockLvl = 10, castMs = 2500, recastSec = 15, mpCost = 15,
        description = 'Strike one enemy with a lance of light. Costs 15 MP. 15s recast.',
    },
}

xi.soulspire.whmValkyrieSpecs = { VALKYRIE_KIT_SPELLS = VALKYRIE_KIT_SPELLS }

local function isValkyrie(player)
    return player and player:isPC() and player:getMainJob() == xi.job.WHM and
        player:getMainLvl() >= 10 and spec.is(player, xi.job.WHM, 'valkyrie')
end

local function hasPolearm(player)
    return player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.POLEARM
end

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function remaining(player, key)
    return math.max(0, player:getLocalVar(key) - now())
end

local function isPartyPC(player, target)
    if not target or not target:isPC() or not target:isAlive() or
        target:getZoneID() ~= player:getZoneID()
    then
        return false
    end

    if target:getID() == player:getID() then return true end
    for _, member in ipairs(player:getParty()) do
        if member:getID() == target:getID() then return true end
    end
    return false
end

local function inRange(player, target, range)
    return hasPolearm(player) and isPartyPC(player, target) and player:checkDistance(target) <= range
end

local function escortRange(player)
    return player:getMainLvl() >= 50 and 20 or 15
end

local function canEscort(player, target)
    return inRange(player, target, escortRange(player)) and
        target:getID() == player:getLocalVar(WINGMATE_ID) and
        remaining(target, INTERRUPT_UNTIL) > 0 and remaining(target, RETRY_UNTIL) == 0
end

local function refundPercent(player, target)
    local level = player:getMainLvl()
    local percent = level >= 70 and 25 or (level >= 30 and 15 or 0)
    if player:getID() == target:getID() then
        return level >= 50 and math.floor(percent / 2) or 0
    end
    return percent
end

local function clearRetry(target)
    target:setLocalVar(RETRY_UNTIL, 0)
    target:setLocalVar(RETRY_OWNER, 0)
end

local function clearWingmate(player)
    local id = player:getLocalVar(WINGMATE_ID)
    if id ~= 0 then
        local target = id == player:getID() and player or GetPlayerByID(id)
        if target and target:getLocalVar(RETRY_OWNER) == player:getID() then
            clearRetry(target)
        end
    end
    player:setLocalVar(WINGMATE_ID, 0)
end

local function attach(player)
    player:setLocalVar('OX_VLK_ACTIVE', 1)
    player:sendSoulSpellList()
end

local function detach(player)
    player:setLocalVar('OX_VLK_ACTIVE', 0)
    clearWingmate(player)
    player:sendSoulSpellList()

    local weapon = player:getEquippedItem(xi.slot.MAIN)
    if weapon and not player:canEquipItem(weapon:getID()) then
        player:unequipItem(xi.slot.MAIN)
    end
end

m:addOverride('xi.actions.abilities.manawell.onAbilityCheck', function(player, target, ability)
    if not isValkyrie(player) then return super(player, target, ability) end
    if not inRange(player, target, 15) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRange(15)
    ability:setRecast(WINGMATE_RECAST)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.manawell.onUseAbility', function(player, target, ability, action)
    if not isValkyrie(player) then return super(player, target, ability, action) end
    if player:getLocalVar(WINGMATE_ID) ~= target:getID() then clearWingmate(player) end
    player:setLocalVar(WINGMATE_ID, target:getID())
    return 0
end)

m:addOverride('xi.actions.abilities.spontaneity.onAbilityCheck', function(player, target, ability)
    if not isValkyrie(player) then return super(player, target, ability) end
    if not canEscort(player, target) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRange(escortRange(player))
    ability:setRecast(ESCORT_RECAST)
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.spontaneity.onUseAbility', function(player, target, ability, action)
    if not isValkyrie(player) then return super(player, target, ability, action) end
    target:setLocalVar(RETRY_SPELL, target:getLocalVar(INTERRUPT_SPELL))
    target:setLocalVar(INTERRUPT_UNTIL, 0)
    target:setLocalVar(RETRY_REFUND, refundPercent(player, target))
    target:setLocalVar(RETRY_OWNER, player:getID())
    target:setLocalVar(RETRY_UNTIL, now() + WINDOW)
    player:setLocalVar(ESCORT_RECAST_UNTIL, now() + ESCORT_RECAST)
    return 0
end)

m:addOverride('xi.actions.spells.white.banish.onMagicCastingCheck', function(caster, target, spell)
    if not isValkyrie(caster) then return super(caster, target, spell) end
    if not hasPolearm(caster) or not target:isMob() then return xi.msg.basic.CANNOT_CAST_SPELL end
    spell:setCastTime(VALKYRIE_KIT_SPELLS[28].castMs)
    return 0
end)

actions.register('valkyrie',
{
    spell = { [28] = VALKYRIE_KIT_SPELLS[28] },
    ability =
    {
        [WINGMATE] = { name = 'Wingmate', description = 'Designate yourself or one nearby party member for escort. 5s recast.', recastTime = WINGMATE_RECAST },
        [ESCORT] =
        {
            name = "Valkyrie's Escort",
            description = 'After enemy damage interrupts your Wingmate, protect one retry of the same spell within 6s. MP refund scales with level. 25s recast.',
            recastTime = ESCORT_RECAST,
        },
    },
})

spec.registerCrystal(xi.job.WHM,
{
    id = 3,
    key = 'valkyrie',
    name = 'Valkyrie',
    abr = 'VLK',
    role = 'Support',
    icon = 'valkyrie',
    reqLevel = 10,
    description = 'A polearm support Soul that rescues one ally after enemy damage interrupts a spell.',
    highlights =
    {
        'Wingmate designates one party caster within 15y. Select yourself to practice with Vigil Lance.',
        "Valkyrie's Escort secures one retry of the exact spell after a hostile interruption. Starts within 6s.",
        'Lv.30 unlocks an ally MP refund, Lv.50 extends Escort range and introduces a reduced self refund, and Lv.70 increases the refund.',
    },
    extraAbilities = function(_, level)
        return level >= 10 and { WINGMATE, ESCORT } or {}
    end,
    mods = function(_, level)
        local step = level >= 70 and 3 or (level >= 50 and 2 or (level >= 30 and 1 or 0))
        return
        {
            { xi.mod.POLEARM, 10 + (step * 9) },
            { xi.mod.HPP, 6 + (step * 4) },
            { xi.mod.MEVA, 8 + (step * 7) },
        }
    end,
    onApply = attach,
    onRemove = detach,
})

m:addOverride('xi.player.onGameIn', function(player, ...)
    super(player, ...)
    if isValkyrie(player) then
        clearWingmate(player)
        attach(player)
    end
end)

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('valkyrie', function(player)
        local id = player:getLocalVar(WINGMATE_ID)
        local target = id ~= 0 and (id == player:getID() and player or GetPlayerByID(id)) or nil
        local valid = isPartyPC(player, target)
        return
        {
            polearm = hasPolearm(player) and 1 or 0,
            wingmate = valid and 1 or 0,
            interrupt_rem = valid and remaining(target, INTERRUPT_UNTIL) or 0,
            retry_rem = valid and target:getLocalVar(RETRY_OWNER) == player:getID() and remaining(target, RETRY_UNTIL) or 0,
            escort_cd = remaining(player, ESCORT_RECAST_UNTIL),
        }
    end)
end

return m
