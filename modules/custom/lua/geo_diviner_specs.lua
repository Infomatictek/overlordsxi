require('modules/module_utils')
require('modules/custom/lua/soulspire_job_specs')
require('scripts/globals/player')

local m = Module:new('soulspire_geo_diviner')
local spec = xi.soulspire.spec
if spec.jobs and not spec.jobs[xi.job.GEO] then require('modules/custom/lua/geo_specs') end
local actions = require('modules/custom/lua/soulspire_soul_actions')

local ACTIVE, APPLIED, DEATH = 'OX_DIV_ACTIVE', 'OX_DIV_APPLIED', 'OX_DIV_CLEAR'
local RECALL, SHIFT = 345, 347
local SOURCE_INTERVAL, LEASE_INTERVAL = 250, 500
local sources, covering, leases = {}, {}, {}
local D = {}
xi.soulspire.diviner = D

local function now()
    return xi.soulspire.nowSec()
end

local function scale(level, a, b, c, d)
    if level >= 70 then return d end
    if level >= 50 then return c end
    if level >= 30 then return b end
    return a
end

local function active(player)
    return player and player:isPC() and player:isAlive() and player:getMainJob() == xi.job.GEO and
        player:getMainLvl() >= 10 and player:getLocalVar(ACTIVE) == 1 and spec.is(player, xi.job.GEO, 'diviner')
end

local function sameBattle(a, b)
    return a:getZoneID() == b:getZoneID() and a:getBattleID() == b:getBattleID() and
        a:getCombatInstanceRunId() == b:getCombatInstanceRunId()
end

local function lengthSquared(anchor, endpoint)
    local dx, dz = endpoint.x - anchor.x, endpoint.z - anchor.z
    return dx * dx + dz * dz
end

function D.isInside(anchor, endpoint, point, width)
    local len = lengthSquared(anchor, endpoint)
    if len < 9 or len > 225 or math.abs(endpoint.y - anchor.y) > 3 then return false end
    local dx, dy, dz = endpoint.x - anchor.x, endpoint.y - anchor.y, endpoint.z - anchor.z
    local t = ((point.x - anchor.x) * dx + (point.z - anchor.z) * dz) / len
    t = math.max(0, math.min(1, t))
    local x, y, z = point.x - (anchor.x + dx * t), point.y - (anchor.y + dy * t), point.z - (anchor.z + dz * t)
    return x * x + z * z <= width * width and math.abs(y) <= 3
end

local function applyBonus(player, bonus)
    local before = player:getLocalVar(APPLIED)
    if before ~= bonus then
        player:addMod(xi.mod.ACC, bonus - before)
        player:addMod(xi.mod.MACC, bonus - before)
        player:setLocalVar(APPLIED, bonus)
    end
end

local function refreshRecipient(member, id)
    local best = 0
    local rows = covering[id]
    if rows then
        for sourceID, row in pairs(rows) do
            if member:isAlive() and member:getZoneID() == row.record.zone and member:getBattleID() == row.record.battle and
                member:getCombatInstanceRunId() == row.record.instance and sources[sourceID] == row.record and
                row.record.expires > now() and row.sampled + 1 >= now() then
                best = math.max(best, row.record.bonus)
            else
                rows[sourceID] = nil
            end
        end
        if next(rows) == nil then covering[id] = nil end
    end
    applyBonus(member, best)
end

local function scheduleLease(member, id)
    if leases[id] then return end
    local token = {}
    leases[id] = token
    local function poll(recipient)
        if leases[id] ~= token then return end
        refreshRecipient(recipient, id)
        if covering[id] then
            recipient:timer(LEASE_INTERVAL, poll)
        else
            leases[id] = nil
        end
    end
    member:timer(LEASE_INTERVAL, poll)
end

local function removeRecipient(sourceID, memberID)
    local rows = covering[memberID]
    if not rows then return end
    rows[sourceID] = nil
    local member = GetPlayerByID(memberID)
    if member then
        refreshRecipient(member, memberID)
    elseif next(rows) == nil then
        covering[memberID], leases[memberID] = nil, nil
    end
end

local function recall(id)
    local record = sources[id]
    if not record then return end
    sources[id] = nil
    for memberID in pairs(record.members) do removeRecipient(id, memberID) end
end

local function sample(player, record)
    local id = player:getID()
    local nextMembers = {}
    local endpoint = player:getPos()
    local function collect(member)
        if not member:isPC() or not member:isAlive() or not sameBattle(player, member) or
            not D.isInside(record.anchor, endpoint, member:getPos(), record.width) then return end
        local memberID = member:getID()
        nextMembers[memberID] = true
        local rows = covering[memberID] or {}
        rows[id] = { record = record, sampled = now() }
        covering[memberID] = rows
        refreshRecipient(member, memberID)
        scheduleLease(member, memberID)
    end
    collect(player)
    for _, member in ipairs(player:getParty()) do
        if member:getID() ~= id then collect(member) end
    end
    for memberID in pairs(record.members) do
        if not nextMembers[memberID] then removeRecipient(id, memberID) end
    end
    record.members = nextMembers
end

local function pulse(player, record)
    local id = player:getID()
    if sources[id] ~= record then return end
    if not active(player) or player:getZoneID() ~= record.zone or player:getBattleID() ~= record.battle or
        player:getCombatInstanceRunId() ~= record.instance or record.expires <= now() then
        recall(id)
        return
    end
    sample(player, record)
    player:timer(SOURCE_INTERVAL, function(owner) pulse(owner, record) end)
end

local function lay(player)
    local id, level = player:getID(), player:getMainLvl()
    recall(id)
    local record =
    {
        anchor = player:getPos(), zone = player:getZoneID(), battle = player:getBattleID(),
        instance = player:getCombatInstanceRunId(),
        expires = now() + (level >= 70 and 40 or 30), width = level >= 50 and 2.5 or 2,
        bonus = scale(level, 12, 20, 28, 35), members = {},
    }
    sources[id] = record
    pulse(player, record)
end

local function shift(player)
    local record = sources[player:getID()]
    if not record or record.expires <= now() or player:getMainLvl() < 30 then return end
    record.anchor = player:getPos()
    sample(player, record)
end

local root = 'xi.actions.spells.geomancy.indi-precision'
m:addOverride(root .. '.onMagicCastingCheck', function(player, target, spell)
    if not active(player) then return super(player, target, spell) end
    return player:getID() == target:getID() and 0 or xi.msg.basic.MAGIC_UNABLE_TO_CAST
end)
m:addOverride(root .. '.onSpellCast', function(player, target, spell, action)
    if not active(player) then return super(player, target, spell, action) end
    if player:getID() ~= target:getID() then return 0 end
    lay(player)
    spell:setMsg(xi.msg.basic.NONE)
    return 0
end)

for _, entry in ipairs({ { 'full_circle', 10, function(owner) recall(owner:getID()) end }, { 'ecliptic_attrition', 30, shift } }) do
    local path = 'xi.actions.abilities.' .. entry[1]
    local function eligible(player)
        local record = sources[player:getID()]
        return player:getMainLvl() >= entry[2] and record and record.expires > now()
    end
    m:addOverride(path .. '.onAbilityCheck', function(player, target, ability)
        if not active(player) then return super(player, target, ability) end
        if not eligible(player) then return xi.msg.basic.UNABLE_TO_USE_JA, 0 end
        ability:setMsg(xi.msg.basic.NONE)
        return 0, 0
    end)
    m:addOverride(path .. '.onUseAbility', function(player, target, ability, action)
        if not active(player) then return super(player, target, ability, action) end
        if eligible(player) then entry[3](player) end
        return 0
    end)
end

local spellKit =
{
    [159] = { script = 'stone', name = 'Ley Spark', description = 'Strike a single enemy with earth magic while you hold your line.', unlockLvl = 10, castMs = 500, recastSec = 5, mpCost = 4 },
    [783] = { script = 'indi-precision', name = 'Lay Meridian', description = 'Anchor a stationary point. Move 3–15 yalms away to form an accuracy corridor for your party.', unlockLvl = 10, castMs = 750, recastSec = 18, mpCost = 0 },
}
xi.soulspire.geoDivinerSpecs = { DIVINER_KIT_SPELLS = spellKit }
actions.register('diviner',
{
    spell = spellKit,
    ability =
    {
        [RECALL] = { name = 'Recall Meridian', description = 'Remove your corridor and end its bonuses immediately.', recastTime = 0 },
        [SHIFT] = { name = 'Meridian Shift', description = 'Move the anchor to your current position and keep the original expiry.', recastTime = 20 },
    },
})

local function apply(player)
    player:setLocalVar(ACTIVE, 1)
    player:removeListener(DEATH)
    player:addListener('DEATH', DEATH, function(owner) recall(owner:getID()) end)
    player:sendSoulSpellList()
end

local function remove(player)
    recall(player:getID())
    player:removeListener(DEATH)
    player:setLocalVar(ACTIVE, 0)
    player:sendSoulSpellList()
end

spec.registerCrystal(xi.job.GEO,
{
    id = 1, key = 'diviner', name = 'Diviner', abr = 'DIV', role = 'Support', icon = 'diviner', reqLevel = 10,
    description = 'Use your position and a fixed anchor to create a lane of physical and magical accuracy for your party.',
    highlights =
    {
        'Lv.10: Lay Meridian and step 3–15 yalms from your anchor to form a corridor granting +12 ACC and MACC.',
        'The corridor is two yalms from the segment center and within three vertical yalms of its interpolated height.',
        'Lv.30: Meridian Shift moves the anchor without extending duration. Scale to +20/+28/+35 ACC and MACC.',
        'Lv.50: Radius becomes 2.5 yalms. Lv.70: Lifetime increases from 30 to 40 seconds. Only the strongest covering corridor applies.',
    },
    extraAbilities = function(_, level)
        if level >= 30 then return { RECALL, SHIFT } end
        return level >= 10 and { RECALL } or {}
    end,
    mods = function(_, level)
        return { { xi.mod.GEOMANCY_SKILL, scale(level, 10, 18, 28, 38) }, { xi.mod.HPP, scale(level, 4, 6, 8, 10) } }
    end,
    onApply = apply,
    onRemove = remove,
})

for _, event in ipairs({ 'onGameIn', 'onPlayerLevelUp', 'onPlayerLevelDown' }) do
    m:addOverride('xi.player.' .. event, function(player, ...)
        super(player, ...)
        local id = player:getID()
        if event == 'onGameIn' then
            recall(id)
            covering[id], leases[id] = nil, nil
            applyBonus(player, 0)
        end
        if player:getMainJob() ~= xi.job.GEO or not spec.is(player, xi.job.GEO, 'diviner') then return end
        if event ~= 'onGameIn' and sources[id] then recall(id) end
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
    xi.soulspire.hud.registerProvider('diviner', function(player)
        local rec = sources[player:getID()]
        if not rec or rec.expires <= now() then return { duration = 0 } end
        local pos = player:getPos()
        local count = 0
        for _ in pairs(rec.members) do count = count + 1 end
        local len = math.sqrt(lengthSquared(rec.anchor, pos))
        return
        {
            duration = rec.expires - now(), length = math.floor(len * 10 + 0.5),
            floor = math.abs(rec.anchor.y - pos.y) <= 3 and 1 or 0,
            live = D.isInside(rec.anchor, pos, pos, rec.width) and 1 or 0,
            count = count, bonus = rec.bonus, max_duration = player:getMainLvl() >= 70 and 40 or 30,
        }
    end)
end

return m
