-----------------------------------
-- OverlordsXI SCH 3: Archivist (Sequence E — Targeted Defense/Support)
-- Records completed hostile action IDs and files targeted Countermeasure pages.
-- Additive to sch_specs.lua / overlords_job_specs.lua (preserves Medic & Sage).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_sch_archivist')
local spec = xi.overlords.spec
local SCH = xi.job.SCH
local KEY = 'archivist'

local VAR_RECORD_CD = 'OX_ARC_RECORD_CD'
local VAR_FILE_CD   = 'OX_ARC_FILE_CD'

local recordsByArchivist = {}  -- archivistId -> list of 1..2 records { enemyId, spawnGen, actionId, category, untilSec }
local pendingSampleByChar = {} -- archivistId -> { enemyId, spawnGen, untilSec }
local pagesByVictim = {}       -- victimId -> list of active pages { ownerId, enemyId, spawnGen, actionId, pct, untilSec }

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isArchivist(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == SCH and player:getMainLvl() >= 10 and
        spec.is(player, SCH, KEY)
end

local function clearState(player)
    if not player or not player.getID then return end
    local id = player:getID()
    recordsByArchivist[id] = nil
    pendingSampleByChar[id] = nil
end

-- Record (6s CD): arm 12s sampler on selected enemy.
local function startRecord(player, enemy, opts)
    opts = opts or {}
    if not isArchivist(player) then return false, 'not_archivist' end
    if not enemy or not enemy.isMob or not enemy:isMob() or not enemy.isAlive or not enemy:isAlive() then
        return false, 'invalid_enemy'
    end
    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_RECORD_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 6 then return false, 'on_recast' end
    if player.setLocalVar then player:setLocalVar(VAR_RECORD_CD, now) end

    pendingSampleByChar[player:getID()] = { enemyId = enemy:getID(), spawnGen = opts.spawnGen or 0, untilSec = now + 12 }
    return true
end

-- Sample completed hostile non-auto action ID + category for 60s.
-- Max 1 record at Lv10-49, max 2 distinct records at Lv50+ (3rd replaces oldest).
local function onEnemyActionCompleted(player, enemy, actionId, category, opts)
    opts = opts or {}
    if not isArchivist(player) or opts.isAutoAttack then return nil end
    local pending = pendingSampleByChar[player:getID()]
    local now = xi.overlords.nowSec()
    if not pending or now > pending.untilSec or not enemy or enemy:getID() ~= pending.enemyId or (opts.spawnGen or 0) ~= pending.spawnGen then
        return nil
    end
    pendingSampleByChar[player:getID()] = nil

    local list = recordsByArchivist[player:getID()] or {}
    local maxSlots = player:getMainLvl() >= 50 and 2 or 1
    local rec = { enemyId = enemy:getID(), spawnGen = opts.spawnGen or 0, actionId = actionId, category = category, untilSec = now + 60 }
    list[#list + 1] = rec
    while #list > maxSlots do
        table.remove(list, 1)
    end
    recordsByArchivist[player:getID()] = list
    return rec
end

-- File Countermeasure (15s CD, 15/20y, 20/25s duration, 20/25/25/30% reduction).
-- One active filed page per Archivist; solo can file on self.
local function fileCountermeasure(player, ally, recordIndex)
    if not isArchivist(player) then return nil, 'not_archivist' end
    if not ally or not ally.isPC or not ally:isPC() or not ally.isAlive or not ally:isAlive() then
        return nil, 'invalid_ally'
    end
    local maxRange = player:getMainLvl() >= 30 and 20 or 15
    if ally:getID() ~= player:getID() and player.checkDistance and player:checkDistance(ally) > maxRange then
        return nil, 'out_of_range'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_FILE_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 15 then return nil, 'on_recast' end

    local list = recordsByArchivist[player:getID()] or {}
    local rec = list[recordIndex or 1]
    if not rec or now > rec.untilSec then return nil, 'no_valid_record' end

    if player.setLocalVar then player:setLocalVar(VAR_FILE_CD, now) end

    -- Remove any previous active page filed by this Archivist
    for vid, vlist in pairs(pagesByVictim) do
        for i = #vlist, 1, -1 do
            if vlist[i].ownerId == player:getID() then table.remove(vlist, i) end
        end
    end

    local lvl = player:getMainLvl()
    local page =
    {
        ownerId  = player:getID(),
        enemyId  = rec.enemyId,
        spawnGen = rec.spawnGen,
        actionId = rec.actionId,
        pct      = scale(lvl, 20, 25, 25, 30),
        untilSec = now + (lvl >= 70 and 25 or 20),
    }
    pagesByVictim[ally:getID()] = pagesByVictim[ally:getID()] or {}
    table.insert(pagesByVictim[ally:getID()], page)
    return page
end

-- Exact action ID + same enemy + spawnGen match only; scripted HP sets/kills bypass.
-- Multiple pages on one victim consume ONLY the highest on that action; wrong action never consumes.
local function applyFiledCountermeasure(victim, enemy, actionId, damage, opts)
    opts = opts or {}
    if type(damage) ~= 'number' or damage <= 0 or opts.isScriptedHpSet or opts.isUnavoidableKill then
        return damage, 0
    end
    local list = victim and victim.getID and pagesByVictim[victim:getID()] or nil
    if not list or #list == 0 then return damage, 0 end

    local now = xi.overlords.nowSec()
    local bestIdx, bestPct = nil, 0
    for i = #list, 1, -1 do
        local p = list[i]
        if now > p.untilSec then
            table.remove(list, i)
        elseif enemy and enemy:getID() == p.enemyId and (opts.spawnGen or 0) == p.spawnGen and p.actionId == actionId then
            if p.pct > bestPct then
                bestPct = p.pct
                bestIdx = i
            end
        end
    end
    if not bestIdx then return damage, 0 end

    table.remove(list, bestIdx)
    local red = math.floor(damage * bestPct / 100)
    return math.max(0, damage - red), bestPct
end

xi.overlords.archivist =
{
    startRecord              = startRecord,
    onEnemyActionCompleted   = onEnemyActionCompleted,
    fileCountermeasure       = fileCountermeasure,
    applyFiledCountermeasure = applyFiledCountermeasure,
    clearState               = clearState,
}

if SCH ~= nil then
    spec.registerCrystal(xi.job.SCH,
    {
        id = 3,
        key = KEY,
        name = 'Archivist',
        abr = 'ARC',
        role = 'Support',
        icon = 'archivist',
        reqLevel = 10,
        description = 'A methodical Scholar who records exact enemy action IDs and files targeted Countermeasure pages to blunt repeated boss mechanics.',
        highlights =
        {
            'Record (6s CD, 60s memory) captures exact enemy action ID (1 slot Lv10–49, 2 slots Lv50+).',
            'File Countermeasure (15s CD, 15/20y, 20/25s): reduces next exact matching action from that enemy by 20/25/25/30%.',
            'Wrong action never consumes page; multiple pages consume only highest; scripted HP sets bypass.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.MPP,  scale(level, 6, 10, 14, 18) },
                { xi.mod.MACC, scale(level, 8, 14, 22, 30) },
                { xi.mod.HPP,  scale(level, 4, 6, 8, 10) },
            }
        end,
        onRemove = clearState,
    })
end

return m
