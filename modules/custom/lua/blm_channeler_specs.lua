-- Channeler (BLM) — trade an action window for one ally's faster, cheaper spell.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_blm_channeler')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.BLM] then
    require('modules/custom/lua/blm_specs')
end

local actions = require('modules/custom/lua/soulspire_soul_actions')
local LINK = 273
local LINK_RECAST = 24
local LINK_DURATION = 8
local LINK_NAME = 'Conduit Link'
local LINK_HELP = 'Channel for up to 8s to speed and discount one eligible party spell. Self-link discounts MP only. 24s recast.'
local OWNER = 'OX_CHN_OWNER'
local RECIPIENT = 'OX_CHN_RECIPIENT'
local UNTIL = 'OX_CHN_LINK_UNTIL'
local RESERVED = 'OX_CHN_RESERVED'
local CAST_SAVE = 'OX_CHN_CAST_SAVE'
local MP_SAVE = 'OX_CHN_MP_SAVE'
local MP_RELAY = 'OX_CHN_MP_RELAY'
local RANGE = 'OX_CHN_RANGE'
local RECAST_UNTIL = 'OX_CHN_RECAST_UNTIL'

local CHANNELER_KIT_SPELLS =
{
    [164] =
    {
        name = 'Conduit Bolt', script = 'thunder', unlockLvl = 10, castMs = 2000, recastSec = 4, mpCost = 9,
        description = 'Discharge a low-cost single-target arc. Costs 9 MP. 4s recast.',
    },
    [247] =
    {
        name = 'Aether Tap', script = 'aspir', unlockLvl = 30, castMs = 3000, recastSec = 60, mpCost = 10,
        description = 'Siphon MP from one enemy that has MP. Costs 10 MP. 60s recast.',
    },
}
xi.soulspire.blmChannelerSpecs = { CHANNELER_KIT_SPELLS = CHANNELER_KIT_SPELLS }

local function isChanneler(player)
    return player and player:isPC() and player:getMainJob() == xi.job.BLM and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.BLM, 'channeler')
end

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function getPlayer(id, self)
    if id == 0 then return nil end
    return id == self:getID() and self or GetPlayerByID(id)
end

local function clearLink(owner)
    local target = getPlayer(owner:getLocalVar(RECIPIENT), owner)
    if target and target:getLocalVar(OWNER) == owner:getID() then
        target:setLocalVar(OWNER, 0)
        target:setLocalVar(UNTIL, 0)
        target:setLocalVar(RESERVED, 0)
    end
    owner:setLocalVar(RECIPIENT, 0)
end

local function isPartyPC(player, target)
    if not target or not target:isPC() or not target:isAlive() or target:getZoneID() ~= player:getZoneID() then
        return false
    end
    if player:getID() == target:getID() then return true end
    for _, member in ipairs(player:getParty()) do
        if member:getID() == target:getID() then return true end
    end
    return false
end

local function linkRange(player)
    return player:getMainLvl() >= 50 and 20 or 15
end

local function savings(player, target)
    local level = player:getMainLvl()
    local selfLink = player:getID() == target:getID()
    local cast = selfLink and 0 or scale(level, 20, 25, 25, 30)
    local mp = scale(level, 15, 15, 25, 25)
    return cast, mp, not selfLink and level >= 30 and 5 or 0
end

local function cost(player, target)
    return player:getID() == target:getID() and 0 or math.max(1, math.ceil(player:getMaxMP() * 0.08))
end

local function canLink(player, target)
    if not isPartyPC(player, target) or player:checkDistance(target) > linkRange(player) or
        (player:getID() ~= target:getID() and isChanneler(target)) or player:getMP() < cost(player, target)
    then
        return false
    end
    local currentOwner = getPlayer(target:getLocalVar(OWNER), player)
    if currentOwner and isChanneler(currentOwner) and isPartyPC(currentOwner, target) and
        currentOwner:getLocalVar(RECIPIENT) == target:getID() and
        (target:getLocalVar(RESERVED) > now() or currentOwner:checkDistance(target) <= target:getLocalVar(RANGE)) and
        (target:getLocalVar(UNTIL) > now() or target:getLocalVar(RESERVED) > now())
    then
        if target:getLocalVar(RESERVED) > now() then return false end
        local cast, mp = savings(player, target)
        if target:getLocalVar(CAST_SAVE) + target:getLocalVar(MP_SAVE) >= cast + mp then return false end
    end
    return true
end

m:addOverride('xi.actions.abilities.manawell.onAbilityCheck', function(player, target, ability)
    if not isChanneler(player) then return super(player, target, ability) end
    if not canLink(player, target) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
    ability:setRecast(LINK_RECAST)
    ability:setRange(linkRange(player))
    ability:setCE(0)
    ability:setVE(0)
    return 0, 0
end)

m:addOverride('xi.actions.abilities.manawell.onUseAbility', function(player, target, ability, action)
    if not isChanneler(player) then return super(player, target, ability, action) end
    clearLink(player)
    local oldOwner = getPlayer(target:getLocalVar(OWNER), player)
    if oldOwner and oldOwner:getLocalVar(RECIPIENT) == target:getID() then clearLink(oldOwner) end

    local cast, mp, relay = savings(player, target)
    player:addMP(-cost(player, target))
    player:setLocalVar(RECIPIENT, target:getID())
    player:setLocalVar(RECAST_UNTIL, now() + LINK_RECAST)
    target:setLocalVar(OWNER, player:getID())
    target:setLocalVar(UNTIL, now() + LINK_DURATION)
    target:setLocalVar(RESERVED, 0)
    target:setLocalVar(CAST_SAVE, cast)
    target:setLocalVar(MP_SAVE, mp)
    target:setLocalVar(MP_RELAY, relay)
    target:setLocalVar(RANGE, linkRange(player))
    return 0
end)

m:addOverride('xi.actions.spells.black.thunder.onMagicCastingCheck', function(caster, target, spell)
    if not isChanneler(caster) then return super(caster, target, spell) end
    if not target:isMob() then return xi.msg.basic.CANNOT_CAST_SPELL end
    spell:setCastTime(CHANNELER_KIT_SPELLS[164].castMs)
    return 0
end)

local function apply(player)
    player:setLocalVar('OX_CHN_ACTIVE', 1)
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar('OX_CHN_ACTIVE', 0)
    clearLink(player)
    player:sendSoulSpellList()
end

actions.register('channeler',
{
    spell = CHANNELER_KIT_SPELLS,
    ability = { [LINK] = { name = LINK_NAME, description = LINK_HELP, recastTime = LINK_RECAST } },
})

spec.registerCrystal(xi.job.BLM,
{
    id = 2, key = 'channeler', name = 'Channeler', abr = 'CHN', role = 'Support',
    icon = 'channeler', reqLevel = 10,
    description = 'Give one ally a faster, cheaper cast by committing your own casting window.',
    highlights =
    {
        'Lv.10: Use Conduit Link on one party caster, or self-link for a solo MP discount.',
        'Lv.30: A successful allied cast relays 5% of its actual MP expenditure to you. Aether Tap drains enemy MP.',
        'Later levels increase Link range and savings. Ancient Magic, instant casts and another Channeler cannot receive the allied link.',
    },
    extraAbilities = function(_, level) return level >= 10 and { LINK } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.MPP,  scale(level, 8, 12, 16, 20) },
            { xi.mod.MACC, scale(level, 8, 14, 22, 30) },
            { xi.mod.HPP,  scale(level, 4, 6, 8, 10) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isChanneler(player) then
            if event == 'onGameIn' then clearLink(player) end
            apply(player)
        end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('channeler', function(player)
        local target = getPlayer(player:getLocalVar(RECIPIENT), player)
        local linked = target and target:getLocalVar(OWNER) == player:getID()
        return
        {
            link_rem = linked and math.max(0, target:getLocalVar(UNTIL) - now()) or 0,
            casting = linked and target:getLocalVar(RESERVED) > now() and 1 or 0,
            link_cd = math.max(0, player:getLocalVar(RECAST_UNTIL) - now()),
        }
    end)
end

return m
