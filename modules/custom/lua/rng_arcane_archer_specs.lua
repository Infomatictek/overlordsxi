-- Arcane Archer (RNG) - mark a target for one coordinated elemental follow-up.
require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_rng_arcane_archer')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.RNG] then require('modules/custom/lua/rng_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')
local ACTIVE, ELEMENT, ARROW_CD = 'OX_ACA_ACTIVE', 'OX_ACA_ELEMENT', 'OX_ACA_ARROW_CD'
local MARK_TARGET = 'OX_ACA_TARGET'
local MARK_OWNER, MARK_END = 'OX_ACA_MARK_OWNER', 'OX_ACA_MARK_END'
local MARK_ELEMENT, MARK_PCT = 'OX_ACA_MARK_ELEMENT', 'OX_ACA_MARK_PCT'
local MARK_SEQ, MARK_BUSY = 'OX_ACA_MARK_SEQ', 'OX_ACA_MARK_BUSY'
local LISTENER = 'OX_ACA_ARROW_LAND'
local elements = { 'Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water' }
local arrowHelp = 'Fire one attuned arrow to mark an enemy within 20 yalms. The next matching party spell or skillchain deals more damage. 16s recast.'
local nextHelp = 'Select the next element for Attunement Arrow. 1s recast.'
local prevHelp = 'Select the previous element for Attunement Arrow. 1s recast.'

local function now()
    return math.floor(xi.soulspire.nowSec())
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function isArcher(player)
    return player and player:isPC() and player:getMainJob() == xi.job.RNG and player:getMainLvl() >= 10 and
        spec.is(player, xi.job.RNG, 'arcanearcher')
end

local function selected(player)
    return math.max(1, player:getLocalVar(ELEMENT))
end

local function markOwner(target)
    if not target or not target:isMob() or not target:isAlive() or target:getLocalVar(MARK_END) <= now() then return nil end
    local owner = GetPlayerByID(target:getLocalVar(MARK_OWNER))
    if isArcher(owner) and owner:getZoneID() == target:getZoneID() and owner:getLocalVar(MARK_TARGET) == target:getID() then
        return owner
    end
    target:setLocalVar(MARK_END, 0)
    return nil
end

local function placeMark(player, target, element)
    if not isArcher(player) or not elements[element] or not target or not target:isMob() or not target:isAlive() then return end
    local level = player:getMainLvl()
    player:setLocalVar(MARK_TARGET, target:getID())
    target:setLocalVar(MARK_OWNER, player:getID())
    target:setLocalVar(MARK_ELEMENT, element)
    target:setLocalVar(MARK_PCT, scale(level, 12, 15, 18, 20))
    target:setLocalVar(MARK_END, now() + scale(level, 10, 12, 12, 14))
    target:setLocalVar(MARK_SEQ, target:getLocalVar(MARK_SEQ) % 4294967295 + 1)
    target:setLocalVar(MARK_BUSY, 0)
end

local function sameParty(owner, actor)
    for _, member in ipairs(owner:getParty()) do
        if member:getID() == actor:getID() then return true end
    end
    return false
end

local function isSolo(owner)
    for _, member in ipairs(owner:getParty()) do
        if member:isPC() and member:getID() ~= owner:getID() and member:getZoneID() == owner:getZoneID() then return false end
    end
    return true
end

local function reserve(actor, target, element, damage, source, eligibleDamage)
    if damage <= 0 or not elements[element] or not target or not target:isMob() or
        target:getLocalVar(MARK_ELEMENT) ~= element or target:getLocalVar(MARK_BUSY) ~= 0
    then
        return damage, nil
    end
    local owner = markOwner(target)
    if not owner or not actor then return damage, nil end

    local contributor = actor:isPC() and actor or (actor:isPet() and actor:getMaster() or nil)
    if not contributor or not contributor:isPC() then return damage, nil end
    local self = contributor:getID() == owner:getID()
    local pct = target:getLocalVar(MARK_PCT)
    if self then
        if source ~= 'bow' or not actor:isPC() or not isSolo(owner) then return damage, nil end
        pct = math.floor(pct / 2)
    elseif (source ~= 'spell' and source ~= 'chain') or not sameParty(owner, contributor) then
        return damage, nil
    end

    local base = eligibleDamage or damage
    if base <= 0 then return damage, nil end
    local sequence = target:getLocalVar(MARK_SEQ)
    target:setLocalVar(MARK_BUSY, sequence)
    return damage + math.floor(base * pct / 100), sequence
end

local function finish(target, claim, hpLost)
    if claim ~= target:getLocalVar(MARK_BUSY) or claim ~= target:getLocalVar(MARK_SEQ) then return end
    target:setLocalVar(MARK_BUSY, 0)
    if hpLost > 0 then target:setLocalVar(MARK_END, 0) end
end

xi.soulspire.arcaneArcher = { reserve = reserve, finish = finish }

for _, selector in ipairs({ { 'sharpshot', 1 }, { 'camouflage', -1 } }) do
    local path = 'xi.actions.abilities.' .. selector[1]
    local direction = selector[2]
    m:addOverride(path .. '.onAbilityCheck', function(player, target, ability)
        if not isArcher(player) then return super(player, target, ability) end
        ability:setRecast(1)
        ability:setCE(0)
        ability:setVE(0)
        return 0, 0
    end)
    m:addOverride(path .. '.onUseAbility', function(player, target, ability, action)
        if not isArcher(player) then return super(player, target, ability, action) end
        local index = (selected(player) - 1 + direction) % #elements + 1
        player:setLocalVar(ELEMENT, index)
        if action then action:messageID(player:getID(), xi.msg.basic.NONE) end
        player:printToPlayer('Attunement: ' .. elements[index] .. '.', xi.msg.channel.SYSTEM_3)
        return 0
    end)
end

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    player:setLocalVar(ELEMENT, selected(player))
    player:removeListener(LISTENER)
    player:addListener('SOUL_ATTUNEMENT_ARROW_LAND', LISTENER, placeMark)
    player:sendSoulSpellList()
end

local function remove(player)
    player:setLocalVar(ACTIVE, 0)
    player:setLocalVar(ELEMENT, 0)
    player:setLocalVar(MARK_TARGET, 0)
    player:removeListener(LISTENER)
    player:sendSoulSpellList()
end

actions.register('arcanearcher',
{
    ability =
    {
        [57] = { name = 'Attunement Arrow', description = arrowHelp, recastTime = 16 },
        [59] = { name = 'Next Attunement', description = nextHelp, recastTime = 1 },
        [58] = { name = 'Previous Attunement', description = prevHelp, recastTime = 1 },
    },
})

spec.registerCrystal(xi.job.RNG,
{
    id = 3, key = 'arcanearcher', name = 'Arcane Archer', abr = 'ACA', role = 'Support', icon = 'arcanearcher', reqLevel = 10,
    description = 'Select one of six elements and land an arrow to amplify one coordinated allied follow-up.',
    highlights =
    {
        'Attunement Arrow works from Lv.10. A landed bow shot marks one enemy for 10/12/12/14 seconds at Lv.10/30/50/70+.',
        'The first matching party spell or skillchain gains 12/15/18/20% damage at Lv.10/30/50/70+.',
        'A solo Arcane Archer can claim its own mark with an elemental bow weapon skill at half the bonus.',
        'One live mark per archer and per enemy. Misses spend one arrow and start the recast without replacing a mark.',
    },
    extraAbilities = function(_, level) return level >= 10 and { 57, 59, 58 } or {} end,
    mods = function(_, level)
        return
        {
            { xi.mod.ARCHERY, scale(level, 12, 20, 30, 42) },
            { xi.mod.RACC, scale(level, 10, 18, 28, 38) },
            { xi.mod.MACC, scale(level, 8, 14, 22, 30) },
        }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if isArcher(player) then
            if event == 'onGameIn' then player:setLocalVar(MARK_TARGET, 0) end
            apply(player)
        end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('arcanearcher', function(player)
        local target = player:getTarget()
        local owner = markOwner(target)
        return
        {
            element = selected(player),
            mark_element = owner and target:getLocalVar(MARK_ELEMENT) or 0,
            mark_rem = owner and math.max(0, target:getLocalVar(MARK_END) - now()) or 0,
            arrow_cd = math.max(0, player:getLocalVar(ARROW_CD) - now()),
        }
    end)
end

return m
