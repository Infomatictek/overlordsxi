require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')
require('scripts/globals/pets')

local m = Module:new('soulspire_bst_beastspeaker')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.BST] then require('modules/custom/lua/bst_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')

local READ, EXPOSE, FIGHT, HEEL, LEAVE, CHOOSE, CALL = 53, 54, 69, 70, 71, 73, 85
local ACTIVE, PENDING, VULNERABLE = 'OX_BSP_ACTIVE', 'OX_BSP_PENDING', 'OX_BSP_EXPOSED'
local DAMAGE_TYPES =
{
    { xi.damageType.BLUNT, xi.mod.IMPACT_SDT, 'Blunt' },
    { xi.damageType.SLASHING, xi.mod.SLASH_SDT, 'Slashing' },
    { xi.damageType.PIERCING, xi.mod.PIERCE_SDT, 'Piercing' },
}
local reads, exposures = {}, {}
local BSP = {}
xi.soulspire.beastspeaker = BSP

local function now()
    return xi.soulspire.nowSec()
end

local function scale(level, low, middle, high, cap)
    if level >= 70 then return cap end
    if level >= 50 then return high end
    if level >= 30 then return middle end
    return low
end

local function active(player)
    return player and player:isPC() and player:isAlive() and player:getMainJob() == xi.job.BST and
        player:getMainLvl() >= 10 and player:getLocalVar(ACTIVE) == 1 and spec.is(player, xi.job.BST, 'beastspeaker')
end

local function sharesBattle(a, b)
    return a:getZoneID() == b:getZoneID() and a:getBattleID() == b:getBattleID()
end

local function enemy(player, target)
    return target and target:isMob() and target:isAlive() and not target:getMaster() and sharesBattle(player, target)
end

local function companion(player)
    local pet = player:getPet()
    if pet and pet:isAlive() and player:hasJugPet() and pet:getPetID() == xi.petId.FLOWERPOT_BILL then return pet end
end

local function generation(target)
    return target:getLocalVar('OX_ARC_SPAWN')
end

local function recordFor(player, target)
    local record = reads[player:getID()]
    if record and record.expires > now() and (not target or
        (target:getID() == record.target and generation(target) == record.spawn)) then return record end
end

local function clearRead(player)
    local id = player:getID()
    local record = reads[id]
    local quarry = record and GetMobByID(record.target) or nil
    if quarry and generation(quarry) == record.spawn then quarry:removeListener('OX_BSP_OBSERVE_' .. id) end
    reads[id] = nil
    player:setLocalVar(PENDING, 0)
end

local function findFamily(target)
    local id = target:getFamily()
    for name, family in pairs(xi.mobFamily or {}) do
        if family == id and id > 0 then return name:gsub('_', ' ') end
    end
    return 'Unknown'
end

local function read(player, target)
    clearRead(player)
    local family = findFamily(target)
    local index = 1
    if family ~= 'Unknown' then
        for candidate = 2, #DAMAGE_TYPES do
            if target:getMod(DAMAGE_TYPES[candidate][2]) > target:getMod(DAMAGE_TYPES[index][2]) then index = candidate end
        end
    end
    local id = player:getID()
    local record = { target = target:getID(), spawn = generation(target), family = family, kind = index, expires = now() + 60 }
    reads[id] = record
    if player:getMainLvl() >= 30 then
        target:addListener('SOUL_ARCHIVIST_ACTION_COMPLETED', 'OX_BSP_OBSERVE_' .. id, function(actor, _, _, name)
            if reads[id] == record and record.expires > now() and generation(actor) == record.spawn then
                record.observed = tostring(name):gsub('_', ' ')
            end
        end)
    end
    player:timer(60000, function(owner)
        if reads[id] == record then clearRead(owner) end
    end)
end

local function canOrder(player, target)
    local pet = companion(player)
    local petTarget = pet and pet:getTarget()
    return enemy(player, target) and petTarget and recordFor(player, target) and sharesBattle(pet, target) and
        petTarget:getID() == target:getID() and player:checkDistance(target) <= 15
end

function BSP.onTrackerHit(pet, target, owner)
    if not active(owner) or not canOrder(owner, target) then return end
    local record = recordFor(owner, target)
    if not record.order or record.order.expires <= now() or record.order.pet ~= pet:getID() or
        companion(owner):getID() ~= pet:getID() then return end
    local index = record.order.kind
    record.order = nil
    owner:setLocalVar(PENDING, 0)
    local level = owner:getMainLvl()
    local pct = record.family == 'Unknown' and scale(level, 4, 4, 4, 6) or scale(level, 8, 10, 10, 12)
    local id = target:getID()
    local existing = exposures[id]
    if existing and existing.spawn == generation(target) and existing.expires > now() and existing.pct > pct then return end
    local entry =
    {
        owner = owner:getID(), spawn = generation(target), kind = index, pct = pct,
        expires = now() + (level >= 50 and 10 or 8), claims = {},
    }
    exposures[id] = entry
    target:setLocalVar(VULNERABLE, entry.expires)
    target:timer((entry.expires - now()) * 1000, function(quarry)
        if exposures[id] ~= entry then return end
        exposures[id] = nil
        if generation(quarry) == entry.spawn then quarry:setLocalVar(VULNERABLE, 0) end
    end)
end

local function eligibleExposure(actor, target, damageType)
    if not actor:isPC() then return end
    local entry = exposures[target:getID()]
    if not entry or entry.expires <= now() or entry.spawn ~= generation(target) or
        (entry.claims[actor:getID()] or 0) >= 2 then return end
    local typ = DAMAGE_TYPES[entry.kind][1]
    if damageType ~= typ and not (typ == xi.damageType.BLUNT and damageType == xi.damageType.HAND_TO_HAND) then return end
    local owner = GetPlayerByID(entry.owner)
    if not active(owner) or not sharesBattle(owner, actor) or not sharesBattle(actor, target) then return end
    if actor:getID() == entry.owner then return entry end
    for _, member in ipairs(owner:getParty()) do
        if member:getID() == actor:getID() then return entry end
    end
end

function BSP.bonus(actor, target, damageType)
    local entry = eligibleExposure(actor, target, damageType)
    return entry and entry.pct or 0
end

function BSP.claim(actor, target, damageType)
    local entry = eligibleExposure(actor, target, damageType)
    if not entry then return false end
    local id = actor:getID()
    entry.claims[id] = (entry.claims[id] or 0) + 1
    return true
end

local function checkWhen(name, predicate)
    m:addOverride('xi.actions.abilities.' .. name .. '.onAbilityCheck', function(player, target, ability)
        if not active(player) then return super(player, target, ability) end
        if not predicate(player, target) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
        ability:setMsg(xi.msg.basic.NONE)
        return 0, 0
    end)
end

local function useWhen(name, resolve)
    m:addOverride('xi.actions.abilities.' .. name .. '.onUseAbility', function(player, target, ability, action)
        if not active(player) then return super(player, target, ability, action) end
        resolve(player, target)
        return 0
    end)
end

checkWhen('gauge', function(player, target) return enemy(player, target) and player:checkDistance(target) <= 15 end)
useWhen('gauge', read)
checkWhen('tame', canOrder)
useWhen('tame', function(player, target)
    if not canOrder(player, target) then return end
    local record = recordFor(player, target)
    local pending = { kind = record.kind, expires = now() + 6, pet = companion(player):getID() }
    record.order = pending
    player:setLocalVar(PENDING, pending.expires)
    player:timer(6000, function(owner)
        if recordFor(owner) == record and record.order == pending then
            record.order = nil
            owner:setLocalVar(PENDING, 0)
        end
    end)
end)

checkWhen('stay', function(player)
    local record = recordFor(player)
    local quarry = record and GetMobByID(record.target) or nil
    return player:getMainLvl() >= 50 and enemy(player, quarry) and recordFor(player, quarry)
end)
useWhen('stay', function(player)
    local record = recordFor(player)
    if record then record.kind = (record.kind % #DAMAGE_TYPES) + 1 end
end)

checkWhen('call_beast', function(player) return not player:getPet() end)
useWhen('call_beast', function(player)
    if player:getPet() then return end
    xi.pet.spawnPet(player, xi.petId.FLOWERPOT_BILL)
    local pet = companion(player)
    if pet then pet:setLocalVar('OX_BSP_SUMMONED', 1) end
end)

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    player:sendSoulSpellList()
end

local function remove(player)
    clearRead(player)
    player:setLocalVar(ACTIVE, 0)
    local id = player:getID()
    for targetID, entry in pairs(exposures) do
        if entry.owner == id then
            local target = GetMobByID(targetID)
            if target and generation(target) == entry.spawn then target:setLocalVar(VULNERABLE, 0) end
            exposures[targetID] = nil
        end
    end
    local pet = companion(player)
    if pet and pet:getLocalVar('OX_BSP_SUMMONED') == 1 then player:despawnPet() end
    player:sendSoulSpellList()
end

actions.register('beastspeaker',
{
    ability =
    {
        [READ] = { name = 'Read Quarry', description = 'Identify the enemy family and its weakest physical damage type within 15 yalms.', recastTime = 10 },
        [EXPOSE] = { name = 'Expose Quarry', description = 'Order your tracker to expose the chosen weakness on its next landed melee hit within six seconds.', recastTime = 25 },
        [FIGHT] = { name = 'Track Quarry', description = 'Send your tracker after the selected enemy.', recastTime = 5 },
        [HEEL] = { name = 'Recall Tracker', description = 'Call your tracker back to your side.', recastTime = 5 },
        [LEAVE] = { name = 'Release Tracker', description = 'Dismiss your active tracker.', recastTime = 5 },
        [CHOOSE] = { name = 'Choose Weakness', description = 'Cycle the recorded weakness through blunt, slashing, and piercing for your next exposure.', recastTime = 1 },
        [CALL] = { name = 'Call Tracker', description = 'Summon your mandragora tracker without spending a jug.', recastTime = 300 },
    },
})

spec.registerCrystal(xi.job.BST,
{
    id = 3, key = 'beastspeaker', name = 'Beastspeaker', abr = 'BSP', role = 'Support', icon = 'beastspeaker', reqLevel = 10,
    description = 'Identify your quarry’s physical weakness and ask your tracker to open it up for your party’s regular attacks.',
    highlights =
    {
        'Lv.10: Call Tracker, Track Quarry, Read Quarry, and Expose Quarry enable targeted party support from the first fight.',
        'Expose Quarry boosts two matching physical hits per party member at most, with a maximum of one claim per attack round.',
        'Known family bonus scales to 8/10/10/12%. Unknown family yields 4/4/4/6%. Exposure lasts 8 seconds, or 10 from Lv.50.',
        'Lv.30: Observe the quarry’s latest completed hostile action after a read. Lv.50: Choose Weakness overrides the next exposure type.',
    },
    extraAbilities = function(_, level)
        if level < 10 then return {} end
        local kit = { READ, EXPOSE, FIGHT, HEEL, LEAVE, CALL }
        if level >= 50 then kit[#kit + 1] = CHOOSE end
        return kit
    end,
    mods = function(_, level)
        return { { xi.mod.AXE, scale(level, 10, 18, 28, 38) }, { xi.mod.ACC, scale(level, 10, 18, 28, 38) } }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        if player:getMainJob() ~= xi.job.BST or not spec.is(player, xi.job.BST, 'beastspeaker') then return end
        if event == 'onGameIn' then clearRead(player) end
        if player:getMainLvl() >= 10 then
            apply(player)
            player:recalculateAbilitiesTable()
        elseif player:getLocalVar(ACTIVE) == 1 then
            remove(player)
            player:recalculateAbilitiesTable()
        end
    end)
end

if xi.soulspire.hud then
    xi.soulspire.hud.registerProvider('beastspeaker', function(player)
        local rec = recordFor(player)
        local entry = rec and exposures[rec.target]
        local live = entry and entry.owner == player:getID() and entry.spawn == rec.spawn and entry.expires > now()
        return
        {
            pet = companion(player) and 1 or 0,
            family = rec and rec.family or '',
            weakness = rec and DAMAGE_TYPES[live and entry.kind or rec.kind][3] or '',
            learned = rec and (rec.observed or '') or '',
            pending = rec and rec.order and math.max(0, rec.order.expires - now()) or 0,
            exposed = live and entry.expires - now() or 0,
            bonus = live and entry.pct or 0,
        }
    end)
end

return m
