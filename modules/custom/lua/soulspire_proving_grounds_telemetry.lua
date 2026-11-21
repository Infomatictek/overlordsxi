-----------------------------------
-- SoulspireXI Soul Proving Grounds — Server-Authoritative Combat Recorder
--
-- Extends the JSONL summary logger into a full combat recorder:
--   1. Compact summary index:       log/proving_grounds/runs.jsonl
--      (plus backwards-compatible   log/proving_grounds_runs.jsonl)
--   2. Chronological combat events: log/proving_grounds/events/<run_id>.jsonl
--   3. 1-second combat snapshots:   log/proving_grounds/snapshots/<run_id>.jsonl
--   4. Optional gameplay feedback:  log/proving_grounds/feedback/<run_id>.json
--
-- Guarantees:
--   - True millisecond-precision monotonic timestamps (getMonotonicSeconds()).
--   - Separate preparation phase vs combat phase (first hostile action starts
--     the combat clock; prep time never inflates DPS).
--   - Zero double-counting of Weapon Skills; correlated boss AoE events;
--     owner-verified pet & Shinobi clone attribution.
--   - Bounded in-memory event buffers with batch flushing (never opens/closes
--     files per single event) and explicit write-failure detection/reporting.
--   - Unsupported metrics explicitly emit "unavailable" (never fabricated 0s).
--   - No passwords, account IDs, IP addresses, or personal identifiers logged.
-----------------------------------
local hasServerRuntime = (Module ~= nil and Module.new ~= nil)
if hasServerRuntime then
    require('modules/module_utils')
    require('modules/custom/lua/soulspire_proving_grounds_registry')
end

xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.soulspire.provingGrounds = xi.soulspire.provingGrounds or {}
xi.soulspire.provingGrounds.telemetry = xi.soulspire.provingGrounds.telemetry or {}

local T = xi.soulspire.provingGrounds.telemetry

T.TELEMETRY_SCHEMA_VERSION = '2.0.0'
T.UNAVAILABLE              = 'unavailable'
T.DEFAULT_BASE_DIR         = 'log/proving_grounds'
T.LEGACY_RUNS_LOG_PATH     = 'log/proving_grounds_runs.jsonl'
T.BURST_WINDOW_SEC         = 10
T.SPIKE_HP_FRACTION        = 0.25
T.FLUSH_BATCH_SIZE         = 64
T.MAX_EVENTS_PER_RUN       = 25000
T.MAX_SNAPSHOTS_PER_RUN    = 3600
T.BOSS_HP_THRESHOLDS       = { 75, 50, 25, 0 }

T.FEEDBACK_OPTIONS =
{
    { key = 'felt_great',            label = 'Felt Great' },
    { key = 'damage_felt_weak',      label = 'Damage Felt Weak' },
    { key = 'survival_felt_bad',     label = 'Survival Felt Bad' },
    { key = 'resource_problems',     label = 'Resource Problems' },
    { key = 'mechanics_felt_unfair', label = 'Mechanics Felt Unfair' },
    { key = 'skip',                  label = 'Skip Feedback' },
}

local runSequence = 0
local activeSessionsByActor = {}

function T.hasActiveSessionFor(player)
    if player == nil or not player.getID then
        return false
    end
    local sess = activeSessionsByActor[player:getID()]
    return sess ~= nil and not sess.ended
end

function T.recordWsTalentEvent(attacker, payload)
    if attacker == nil or not attacker.getID or type(payload) ~= 'table' then
        return false
    end
    local session = activeSessionsByActor[attacker:getID()]
    if session == nil or session.ended then
        return false
    end
    if (session.eventsWritten + #session.eventBuffer) >= T.MAX_EVENTS_PER_RUN then
        session.eventsDropped = (session.eventsDropped or 0) + 1
        return false
    end
    session.eventBuffer[#session.eventBuffer + 1] = T.encodeJson(payload)
    return true
end

local DEFENSIVE_COOLDOWN_KEYWORDS =
{
    'defender', 'sentinel', 'rampart', 'invincible', 'palisade', 'reprisal',
    'third_eye', 'seigan', 'counterstance', 'dodge', 'chakra', 'perfect_dodge',
    'evasion', 'utsusemi', 'issekigan', 'battuta', 'vallation', 'valiance',
    'liement', 'pflug', 'one_for_all', 'phalanx', 'stoneskin', 'ward',
}

-- Zero-shell directory creator via LuaJIT FFI (Windows kernel32 CreateDirectoryA)
-- so xi_map never flashes a console window when ensuring log/proving_grounds dirs.
local winCreateDir = nil
do
    local ok, ffi = pcall(require, 'ffi')
    if ok and ffi and ffi.os == 'Windows' then
        pcall(ffi.cdef, [[
            int CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);
        ]])
        winCreateDir = function(dirPath)
            pcall(function()
                ffi.C.CreateDirectoryA(dirPath, nil)
            end)
        end
    end
end

local function ensureDir(path)
    if type(path) ~= 'string' or path == '' then
        return
    end
    local norm = path:gsub('\\', '/')
    local accum = ''
    for segment in norm:gmatch('[^/]+') do
        if accum == '' then
            accum = segment
        else
            accum = accum .. '/' .. segment
        end
        if not segment:match('^%a:$') then
            if winCreateDir then
                winCreateDir(accum)
            else
                pcall(os.execute, 'mkdir -p "' .. accum .. '" >/dev/null 2>&1')
            end
        end
    end
end

local function nowWallSec()
    if GetSystemTime then
        return GetSystemTime()
    end
    return os.time()
end

local function nowMonotonicMs()
    if getMonotonicSeconds then
        return math.floor(getMonotonicSeconds() * 1000 + 0.5)
    end
    return nowWallSec() * 1000
end

local function sanitizeRunSegment(text)
    local s = tostring(text or 'unknown'):lower()
    s = s:gsub('[^a-z0-9_]+', '_')
    s = s:gsub('^_+', ''):gsub('_+$', '')
    if s == '' then
        return 'unknown'
    end
    return s:sub(1, 32)
end

local function escapeJsonString(str)
    local s = tostring(str)
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\b', '\\b')
    s = s:gsub('\f', '\\f')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return '"' .. s .. '"'
end

local function isArray(tbl)
    if type(tbl) ~= 'table' then
        return false
    end
    local count = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= 'number' or k < 1 or math.floor(k) ~= k then
            return false
        end
        count = count + 1
    end
    return count > 0 and count == #tbl
end

function T.encodeJson(val)
    local tv = type(val)
    if val == nil then
        return 'null'
    elseif tv == 'boolean' then
        return val and 'true' or 'false'
    elseif tv == 'number' then
        if val ~= val or val == math.huge or val == -math.huge then
            return 'null'
        end
        if math.floor(val) == val then
            return string.format('%d', val)
        end
        return string.format('%.4f', val)
    elseif tv == 'string' then
        return escapeJsonString(val)
    elseif tv == 'table' then
        if isArray(val) then
            local parts = {}
            for i = 1, #val do
                parts[i] = T.encodeJson(val[i])
            end
            return '[' .. table.concat(parts, ',') .. ']'
        else
            local keys = {}
            for k, _ in pairs(val) do
                keys[#keys + 1] = tostring(k)
            end
            table.sort(keys)
            local parts = {}
            for _, k in ipairs(keys) do
                parts[#parts + 1] = escapeJsonString(k) .. ':' .. T.encodeJson(val[k])
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    end
    return escapeJsonString(tostring(val))
end

local function round4(n)
    if type(n) ~= 'number' then
        return n
    end
    return math.floor(n * 10000 + 0.5) / 10000
end

-- Safe explicit-error batch file appender. Never swallows I/O failures.
local function appendLinesToFile(path, lines)
    if type(lines) ~= 'table' or #lines == 0 then
        return true, nil
    end
    local fh, openErr = io.open(path, 'a')
    if not fh then
        return false, string.format('open_failed(%s): %s', tostring(path), tostring(openErr))
    end
    local payload = table.concat(lines, '\n') .. '\n'
    local writeOk, writeErr = fh:write(payload)
    local closeOk, closeErr = fh:close()
    if not writeOk then
        return false, string.format('write_failed(%s): %s', tostring(path), tostring(writeErr))
    end
    if closeOk == false then
        return false, string.format('close_failed(%s): %s', tostring(path), tostring(closeErr))
    end
    return true, nil
end

local function writeWholeFile(path, content)
    local fh, openErr = io.open(path, 'w')
    if not fh then
        return false, string.format('open_failed(%s): %s', tostring(path), tostring(openErr))
    end
    local writeOk, writeErr = fh:write(content)
    local closeOk, closeErr = fh:close()
    if not writeOk then
        return false, string.format('write_failed(%s): %s', tostring(path), tostring(writeErr))
    end
    if closeOk == false then
        return false, string.format('close_failed(%s): %s', tostring(path), tostring(closeErr))
    end
    return true, nil
end

local function resolveSoulIdentity(player)
    local out =
    {
        soul_name = 'None',
        soul_key  = 'none',
        job       = 'UNKNOWN',
        role      = 'Unassigned',
        tier      = 'Unassigned',
        level     = 0,
    }
    if player == nil then
        return out
    end

    local jobId = player.getMainJob and player:getMainJob() or 0
    out.level = player.getMainLvl and player:getMainLvl() or 0

    local spec = xi and xi.soulspire and xi.soulspire.spec or nil
    if spec then
        if spec.getJobKey then
            out.job = spec.getJobKey(jobId)
        end
        local active = spec.get and spec.get(player, jobId) or nil
        if active then
            out.soul_key  = active.key or 'none'
            out.soul_name = active.name or out.soul_key
            out.role      = active.role or 'Unassigned'
            if spec.getSpecTier then
                out.tier = spec.getSpecTier(active, player, jobId) or out.role
            else
                out.tier = out.role
            end
        end
    end

    return out
end

local function isDefensiveAbilityName(name)
    if type(name) ~= 'string' then
        return false
    end
    local lower = string.lower(name)
    for _, kw in ipairs(DEFENSIVE_COOLDOWN_KEYWORDS) do
        if string.find(lower, kw, 1, true) then
            return true
        end
    end
    return false
end

local function entityIdOf(ent)
    if ent ~= nil and ent.getID then
        local ok, id = pcall(function() return ent:getID() end)
        if ok then return id end
    end
    return nil
end

local function entityNameOf(ent)
    if ent ~= nil and ent.getName then
        local ok, name = pcall(function() return ent:getName() end)
        if ok and name then return tostring(name) end
    end
    return 'Unknown'
end

local function resolveCompanionOwnership(entity, actorMap)
    if entity == nil then
        return nil, nil
    end
    -- Standard player pet (Avatar, Wyvern, Jug Pet, Automaton, Luopan, Eos/Titania)
    if entity.isPet and entity:isPet() then
        local master = entity.getMaster and entity:getMaster() or nil
        local mid = entityIdOf(master)
        if mid ~= nil and actorMap[mid] ~= nil then
            return 'pet', mid
        end
        return nil, nil
    end

    -- Kurogane Shinobi shadow clone: verify strictly against K._owners[ownerId]
    local K = xi and xi.soulspire and xi.soulspire.kurogane or nil
    local eid = entityIdOf(entity)
    if K and K._owners and eid ~= nil then
        for ownerId, state in pairs(K._owners) do
            if actorMap[ownerId] ~= nil and state and type(state.clones) == 'table' then
                for _, rec in ipairs(state.clones) do
                    if rec and rec.mobId == eid then
                        return 'clone', ownerId
                    end
                end
            end
        end
    end

    -- Fallback: dynamic ally mob explicitly carrying owner localVar
    if entity.getLocalVar then
        local ownerVar = entity:getLocalVar('OX_CLONE_OWNER_ID')
        if ownerVar and ownerVar > 0 and actorMap[ownerVar] ~= nil then
            return 'clone', ownerVar
        end
    end

    return nil, nil
end

local function collectActiveCompanions(actors, actorMap)
    local out = {}
    local seen = {}

    for _, actor in ipairs(actors) do
        local aid = entityIdOf(actor)
        if aid ~= nil then
            if actor.hasPet and actor:hasPet() and actor.getPet then
                local pet = actor:getPet()
                local pid = entityIdOf(pet)
                if pid ~= nil and not seen[pid] then
                    seen[pid] = true
                    out[#out + 1] = { entity = pet, id = pid, kind = 'pet', ownerId = aid }
                end
            end
            local K = xi and xi.soulspire and xi.soulspire.kurogane or nil
            if K and K._owners and K._owners[aid] and type(K._owners[aid].clones) == 'table' then
                for _, rec in ipairs(K._owners[aid].clones) do
                    local cmob = rec and rec.mob or nil
                    local cid = entityIdOf(cmob)
                    if cid ~= nil and not seen[cid] then
                        seen[cid] = true
                        out[#out + 1] = { entity = cmob, id = cid, kind = 'clone', ownerId = aid }
                    end
                end
            end
        end
    end

    return out
end

local function snapshotEffectIds(entity)
    local ids = {}
    if entity == nil or not entity.getStatusEffects then
        return ids
    end
    local ok, list = pcall(function() return entity:getStatusEffects() end)
    if not ok or type(list) ~= 'table' then
        return ids
    end
    for _, eff in ipairs(list) do
        if eff and eff.getEffectType then
            local et = eff:getEffectType()
            if et ~= nil then
                ids[et] = (ids[et] or 0) + 1
            end
        end
    end
    return ids
end

local function countMapKeys(tbl)
    local n = 0
    for _ in pairs(tbl or {}) do
        n = n + 1
    end
    return n
end

local function detectServerCommitSha(explicitSha)
    if type(explicitSha) == 'string' and explicitSha ~= '' then
        return explicitSha
    end
    return 'unknown'
end

local function buildSafeRunId(startWall, encounter)
    runSequence = runSequence + 1
    local ts = os.date('!%Y%m%d_%H%M%S', startWall)
    local bType = sanitizeRunSegment(encounter and encounter.bossType or 'trial')
    local bLvl = math.floor(tonumber(encounter and encounter.bossLevel) or 0)
    return string.format('pg_%s_%03d_%s_lv%d', ts, runSequence, bType, bLvl)
end

-- Saves gameplay feedback to log/proving_grounds/feedback/<run_id>.json.
function T.saveFeedback(runId, feedbackData, opts)
    opts = opts or {}
    if type(runId) ~= 'string' or runId == '' or runId:find('[^a-zA-Z0-9_%-]') then
        return false, 'invalid_run_id', nil
    end

    local baseDir = opts.baseDir or T.DEFAULT_BASE_DIR
    local fbDir = baseDir .. '/feedback'
    ensureDir(fbDir)
    local fbPath = fbDir .. '/' .. runId .. '.json'

    local payload =
    {
        run_id                   = runId,
        telemetry_schema_version = T.TELEMETRY_SCHEMA_VERSION,
        recorded_utc             = os.date('!%Y-%m-%dT%H:%M:%SZ', nowWallSec()),
        source                   = tostring(feedbackData.source or 'npc_menu'),
        tag                      = tostring(feedbackData.tag or 'skip'),
        label                    = tostring(feedbackData.label or feedbackData.tag or 'Skip Feedback'),
        note                     = feedbackData.note and tostring(feedbackData.note) or nil,
        soul_key                 = feedbackData.soul_key and tostring(feedbackData.soul_key) or nil,
        boss_type                = feedbackData.boss_type and tostring(feedbackData.boss_type) or nil,
        boss_level               = feedbackData.boss_level,
    }

    local ok, err = writeWholeFile(fbPath, T.encodeJson(payload) .. '\n')
    return ok, err, fbPath
end

-- Starts a full server-authoritative recording session.
function T.beginSession(opts)
    opts = opts or {}
    local mob       = opts.mob
    local actors    = opts.actors or {}
    local encounter = opts.encounter or {}

    local clockMsFn = opts.clockMsFn
    if clockMsFn == nil and type(opts.clockFn) == 'function' then
        clockMsFn = function()
            return math.floor(opts.clockFn() * 1000 + 0.5)
        end
    end
    if clockMsFn == nil then
        clockMsFn = nowMonotonicMs
    end

    local startWall = nowWallSec()
    local startMs   = clockMsFn()
    local runId     = opts.runId or buildSafeRunId(startWall, encounter)
    if runId:find('[^a-zA-Z0-9_%-]') then
        runId = buildSafeRunId(startWall, encounter)
    end

    local baseDir      = opts.baseDir or T.DEFAULT_BASE_DIR
    local runsPath     = opts.runsPath or (baseDir .. '/runs.jsonl')
    local legacyPath   = opts.legacyLogPath ~= nil and opts.legacyLogPath or T.LEGACY_RUNS_LOG_PATH
    local eventsPath   = baseDir .. '/events/' .. runId .. '.jsonl'
    local snapsPath    = baseDir .. '/snapshots/' .. runId .. '.jsonl'
    local feedbackPath = baseDir .. '/feedback/' .. runId .. '.json'

    if opts.writeLog ~= false then
        ensureDir(baseDir)
        ensureDir(baseDir .. '/events')
        ensureDir(baseDir .. '/snapshots')
        ensureDir(baseDir .. '/feedback')
    end

    local primaryActor = actors[1]
    local actorMap = {}
    for _, a in ipairs(actors) do
        local aid = entityIdOf(a)
        if aid ~= nil then
            actorMap[aid] = a
        end
    end

    local soulInfo  = resolveSoulIdentity(primaryActor)
    local tagPrefix = 'PG_REC_' .. runId .. '_'

    local levelSyncInfo = opts.levelSync or nil
    local originalLevel = opts.originalLevel
        or (levelSyncInfo and levelSyncInfo.original_level)
        or (primaryActor and primaryActor.getMainLvl and primaryActor:getMainLvl())
        or 0
    local effectiveLevel = opts.effectiveLevel
        or (levelSyncInfo and levelSyncInfo.effective_level)
        or (primaryActor and primaryActor.getMainLvl and primaryActor:getMainLvl())
        or 0

    local session =
    {
        runId                = runId,
        testMode             = opts.testMode or 'manual',
        serverCommitSha      = detectServerCommitSha(opts.serverCommitSha),
        writeLog             = (opts.writeLog ~= false),
        baseDir              = baseDir,
        runsPath             = runsPath,
        legacyLogPath        = legacyPath,
        eventsPath           = eventsPath,
        snapshotsPath        = snapsPath,
        feedbackPath         = feedbackPath,
        encounter            = encounter,
        mob                  = mob,
        actors               = actors,
        primaryActor         = primaryActor,
        actorMap             = actorMap,
        soulInfo             = soulInfo,
        originalLevel        = originalLevel,
        effectiveLevel       = effectiveLevel,
        levelSync            = levelSyncInfo,
        clockMsFn            = clockMsFn,
        arenaEntryWall       = startWall,
        arenaEntryMs         = startMs,
        prepStartMs          = startMs,
        combatStartMs        = nil, -- Set strictly on first hostile action!
        combatEndMs          = nil,
        lastEventMs          = startMs,
        lastFlushMs          = startMs,
        ended                = false,
        tagPrefix            = tagPrefix,
        boundEntities        = {},
        boundCompanionIds    = {},

        -- Bounded buffers & I/O health tracking
        eventSeq             = 0,
        eventBuffer          = {},
        eventsWritten        = 0,
        eventsDropped        = 0,
        snapshotBuffer       = {},
        snapshotsWritten     = 0,
        snapshotsDropped     = 0,
        writeErrors          = {},
        warnings             = {},

        -- Rolling combat state
        damageTimeline       = {}, -- { t = combatSec, dmg = amount }
        lastTpByActor        = {},
        lastMpByActor        = {},
        lastHpByActor        = {},
        lastEffectsByEntity  = {},
        lastHealMs           = nil,
        maxHealGapMs         = 0,
        lastThreatLeader     = nil,
        bossThresholdsHit    = {},
        pendingWsCredit      = 0,
        lastBossActionSeq    = nil,
        lastBossActionSkill  = nil,
        lastBossActionMs     = nil,
        lastSnapshotCombatSec = -1,
        prevSnapTotals       = { dmg = 0, pDmg = 0, petDmg = 0, inc = 0, heal = 0 },

        counters =
        {
            -- Offense
            totalDamage          = 0,
            playerDamage         = 0,
            autoAttackDamage     = 0,
            weaponSkillDamage    = 0,
            spellDamage          = 0,
            petAndCloneDamage    = 0,
            otherDamage          = 0,
            meleeHits            = 0,
            meleeMisses          = 0,
            critHits             = 0,
            wsUses               = 0,
            abilityUses          = 0,
            spellCasts           = 0,
            spellInterrupts      = 0,

            -- Defense
            actualIncomingDamage = 0,
            incomingHits         = 0,
            incomingSwingsHit    = 0,
            incomingSwingsMissed = 0,
            maxDamageSpike       = 0,
            spikeHitCount        = 0,
            deaths               = 0,
            defensiveCdUses      = 0,

            -- Healing
            effectiveHealing     = 0,
            healEvents           = 0,
            mpConsumed           = 0,
            mpRecovered          = 0,

            -- Threat
            maxCe                = 0,
            maxVe                = 0,
            maxTotalEnmity       = 0,
            threatSamples        = 0,
            primaryTargetSamples = 0,
            threatLosses         = 0,

            -- Resources & Pets/Clones
            tpGenerated          = 0,
            tpSpent              = 0,
            buffSamples          = 0,
            activeBuffTotal      = 0,
            activeDebuffTotal    = 0,
            petSamples           = 0,
            petAliveSamples      = 0,
            petDeaths            = 0,
            petSeen              = false,
            cloneSeen            = false,

            -- Boss
            bossAbilitiesUsed    = 0,
            bossSpellsCast       = 0,

            -- Safety
            expEventsObserved    = 0,
            expPointsObserved    = 0,
        },
    }

    local function recordWriteError(errMsg)
        if errMsg and errMsg ~= '' then
            session.writeErrors[#session.writeErrors + 1] = tostring(errMsg)
        end
    end

    local function monotonicNowMs()
        local t = session.clockMsFn()
        if t < session.lastEventMs then
            t = session.lastEventMs
        end
        session.lastEventMs = t
        return t
    end

    local function flushEvents()
        if not session.writeLog or #session.eventBuffer == 0 then
            session.eventBuffer = {}
            return true
        end
        local ok, err = appendLinesToFile(session.eventsPath, session.eventBuffer)
        if ok then
            session.eventsWritten = session.eventsWritten + #session.eventBuffer
        else
            recordWriteError(err)
        end
        session.eventBuffer = {}
        session.lastFlushMs = session.lastEventMs
        return ok
    end

    local function flushSnapshots()
        if not session.writeLog or #session.snapshotBuffer == 0 then
            session.snapshotBuffer = {}
            return true
        end
        local ok, err = appendLinesToFile(session.snapshotsPath, session.snapshotBuffer)
        if ok then
            session.snapshotsWritten = session.snapshotsWritten + #session.snapshotBuffer
        else
            recordWriteError(err)
        end
        session.snapshotBuffer = {}
        return ok
    end

    local function markCombatStarted(triggerName)
        if session.combatStartMs ~= nil then
            return session.combatStartMs
        end
        local t = monotonicNowMs()
        session.combatStartMs = t
        -- Emit explicit combat_start lifecycle marker
        if session.eventSeq < T.MAX_EVENTS_PER_RUN then
            session.eventSeq = session.eventSeq + 1
            local ev =
            {
                run_id     = session.runId,
                seq        = session.eventSeq,
                phase      = 'combat',
                session_ms = math.max(0, t - session.arenaEntryMs),
                combat_ms  = 0,
                category   = 'lifecycle',
                event_type = 'combat_start',
                source_id  = entityIdOf(session.primaryActor),
                source_name = entityNameOf(session.primaryActor),
                target_id  = entityIdOf(session.mob),
                target_name = entityNameOf(session.mob),
                value      = tostring(triggerName or 'hostile_action'),
                meta       = { prep_duration_ms = math.max(0, t - session.prepStartMs) },
            }
            session.eventBuffer[#session.eventBuffer + 1] = T.encodeJson(ev)
        end
        return t
    end

    local function emitEvent(category, eventType, source, target, value, meta, isHostile)
        if session.ended and eventType ~= 'session_end' then
            return nil
        end
        if isHostile then
            markCombatStarted(eventType)
        end

        local t = monotonicNowMs()
        if (session.eventsWritten + #session.eventBuffer) >= T.MAX_EVENTS_PER_RUN then
            session.eventsDropped = session.eventsDropped + 1
            return nil
        end

        session.eventSeq = session.eventSeq + 1
        local phase = 'preparation'
        local combatMs = nil
        if eventType == 'session_end' then
            phase = 'post'
            if session.combatStartMs ~= nil then
                combatMs = math.max(0, t - session.combatStartMs)
            end
        elseif session.combatStartMs ~= nil then
            phase = 'combat'
            combatMs = math.max(0, t - session.combatStartMs)
        end

        local ev =
        {
            run_id      = session.runId,
            seq         = session.eventSeq,
            phase       = phase,
            session_ms  = math.max(0, t - session.arenaEntryMs),
            combat_ms   = combatMs,
            category    = category,
            event_type  = eventType,
            source_id   = entityIdOf(source),
            source_name = source ~= nil and entityNameOf(source) or nil,
            target_id   = entityIdOf(target),
            target_name = target ~= nil and entityNameOf(target) or nil,
            value       = value,
            meta        = meta,
        }

        session.eventBuffer[#session.eventBuffer + 1] = T.encodeJson(ev)
        if #session.eventBuffer >= T.FLUSH_BATCH_SIZE or (t - session.lastFlushMs) >= 5000 then
            flushEvents()
        end
        return session.eventSeq
    end

    local function bindListener(entity, eventName, suffix, fn)
        if entity == nil or not entity.addListener then
            return
        end
        local listenerName = tagPrefix .. suffix
        entity:addListener(eventName, listenerName, fn)
        session.boundEntities[#session.boundEntities + 1] =
        {
            entity = entity,
            name   = listenerName,
        }
    end

    local function bindCompanionIfNeeded(comp)
        if comp == nil or comp.entity == nil or comp.id == nil or session.boundCompanionIds[comp.id] then
            return
        end
        session.boundCompanionIds[comp.id] = comp
        if comp.kind == 'pet' then
            session.counters.petSeen = true
        else
            session.counters.cloneSeen = true
        end

        emitEvent('pet', comp.kind == 'pet' and 'pet_spawn' or 'clone_spawn', comp.entity, nil, comp.entity.getMainLvl and comp.entity:getMainLvl() or 0, {
            kind     = comp.kind,
            owner_id = comp.ownerId,
            max_hp   = comp.entity.getMaxHP and comp.entity:getMaxHP() or 0,
        }, false)

        local pfx = 'COMP_' .. tostring(comp.id) .. '_'
        bindListener(comp.entity, 'TAKE_DAMAGE', pfx .. 'TDMG', function(defender, amount, attacker, attackType)
            if session.ended then return end
            local dmg = math.max(0, math.floor(tonumber(amount) or 0))
            if dmg <= 0 then return end
            local corrMeta = { kind = comp.kind, owner_id = comp.ownerId, attack_type = attackType }
            if session.lastBossActionSeq and session.lastBossActionMs and (monotonicNowMs() - session.lastBossActionMs) <= 2500 then
                corrMeta.boss_action_seq = session.lastBossActionSeq
                corrMeta.boss_skill_id = session.lastBossActionSkill
            end
            emitEvent('pet', 'pet_damage_taken', attacker, defender, dmg, corrMeta, true)
        end)

        bindListener(comp.entity, 'DEATH', pfx .. 'DEATH', function(deadComp, killer)
            if session.ended then return end
            session.counters.petDeaths = session.counters.petDeaths + 1
            emitEvent('pet', comp.kind == 'pet' and 'pet_death' or 'clone_death', killer, deadComp, 0, {
                kind     = comp.kind,
                owner_id = comp.ownerId,
            }, false)
        end)

        bindListener(comp.entity, 'DESPAWN', pfx .. 'DESPAWN', function(goneComp)
            if session.ended then return end
            emitEvent('pet', comp.kind == 'pet' and 'pet_despawn' or 'clone_despawn', goneComp, nil, 0, {
                kind     = comp.kind,
                owner_id = comp.ownerId,
            }, false)
        end)
    end

    local function checkBossHpThresholds()
        if session.mob == nil or not session.mob.getHPP then
            return
        end
        local hpp = session.mob:getHPP() or 0
        for _, thresh in ipairs(T.BOSS_HP_THRESHOLDS) do
            if hpp <= thresh and not session.bossThresholdsHit[thresh] then
                session.bossThresholdsHit[thresh] = true
                emitEvent('boss', 'boss_hp_threshold', session.mob, nil, thresh, { hp_pct = hpp }, false)
            end
        end
    end

    local function recordOffenseDamage(amount, sourceKind, attacker, defender, meta)
        local dmg = math.max(0, math.floor(tonumber(amount) or 0))
        if dmg <= 0 then
            return
        end
        markCombatStarted(sourceKind)

        local c = session.counters
        c.totalDamage = c.totalDamage + dmg
        if sourceKind == 'pet' or sourceKind == 'clone' then
            c.petAndCloneDamage = c.petAndCloneDamage + dmg
        else
            c.playerDamage = c.playerDamage + dmg
            if sourceKind == 'ws' then
                c.weaponSkillDamage = c.weaponSkillDamage + dmg
            elseif sourceKind == 'spell' then
                c.spellDamage = c.spellDamage + dmg
            elseif sourceKind == 'auto' then
                c.autoAttackDamage = c.autoAttackDamage + dmg
            else
                c.otherDamage = c.otherDamage + dmg
            end
        end

        local combatSec = session.combatStartMs ~= nil and ((monotonicNowMs() - session.combatStartMs) / 1000.0) or 0
        session.damageTimeline[#session.damageTimeline + 1] =
        {
            t   = math.max(0, combatSec),
            dmg = dmg,
        }

        local evCat = (sourceKind == 'pet' or sourceKind == 'clone') and 'pet' or 'offense'
        local evType = (sourceKind == 'pet' or sourceKind == 'clone') and 'pet_damage' or 'damage_dealt'
        local evMeta = meta or {}
        evMeta.source_kind = sourceKind
        emitEvent(evCat, evType, attacker, defender, dmg, evMeta, true)
        checkBossHpThresholds()
    end

    local function diffEntityEffects(entity, category)
        local eid = entityIdOf(entity)
        if eid == nil then return 0 end
        local cur = snapshotEffectIds(entity)
        local prev = session.lastEffectsByEntity[eid]
        if prev ~= nil then
            for effId, _ in pairs(cur) do
                if prev[effId] == nil then
                    emitEvent(category, 'status_applied', entity, entity, effId, { effect_id = effId }, false)
                end
            end
            for effId, _ in pairs(prev) do
                if cur[effId] == nil then
                    emitEvent(category, 'status_removed', entity, entity, effId, { effect_id = effId }, false)
                end
            end
        end
        session.lastEffectsByEntity[eid] = cur
        return countMapKeys(cur)
    end

    local function sampleResourcesAndThreat()
        if session.ended then
            return
        end
        local c = session.counters

        -- Discover any newly summoned pets / Shinobi clones and bind listeners.
        local comps = collectActiveCompanions(session.actors, session.actorMap)
        for _, comp in ipairs(comps) do
            bindCompanionIfNeeded(comp)
        end

        for _, actor in ipairs(session.actors) do
            local id = entityIdOf(actor)
            if id ~= nil then
                if actor.getTP then
                    local curTp = actor:getTP() or 0
                    local prevTp = session.lastTpByActor[id]
                    if prevTp ~= nil and curTp ~= prevTp then
                        local delta = curTp - prevTp
                        if delta > 0 then
                            c.tpGenerated = c.tpGenerated + delta
                        end
                        emitEvent('resource', 'tp_change', actor, nil, delta, { tp = curTp }, false)
                    end
                    session.lastTpByActor[id] = curTp
                end

                if actor.getMP then
                    local curMp = actor:getMP() or 0
                    local prevMp = session.lastMpByActor[id]
                    if prevMp ~= nil and curMp ~= prevMp then
                        local delta = curMp - prevMp
                        if delta < 0 then
                            c.mpConsumed = c.mpConsumed + (-delta)
                        else
                            c.mpRecovered = c.mpRecovered + delta
                        end
                        emitEvent('resource', 'mp_change', actor, nil, delta, { mp = curMp }, false)
                    end
                    session.lastMpByActor[id] = curMp
                end

                local buffCount = diffEntityEffects(actor, 'resource')
                c.buffSamples = c.buffSamples + 1
                c.activeBuffTotal = c.activeBuffTotal + buffCount
            end
        end

        -- Pet/clone presence & survival sampling
        if #comps > 0 then
            for _, comp in ipairs(comps) do
                c.petSamples = c.petSamples + 1
                local alive = (not comp.entity.isAlive) or comp.entity:isAlive()
                if alive then
                    c.petAliveSamples = c.petAliveSamples + 1
                end
            end
        elseif c.petSeen or c.cloneSeen then
            c.petSamples = c.petSamples + 1
        end

        if session.mob ~= nil and (not session.mob.isAlive or session.mob:isAlive()) then
            local debuffCount = diffEntityEffects(session.mob, 'boss')
            c.activeDebuffTotal = c.activeDebuffTotal + debuffCount

            if session.primaryActor ~= nil then
                local ce = (session.mob.getCE and session.mob:getCE(session.primaryActor)) or 0
                local ve = (session.mob.getVE and session.mob:getVE(session.primaryActor)) or 0
                local total = ce + ve
                if ce > c.maxCe then c.maxCe = ce end
                if ve > c.maxVe then c.maxVe = ve end
                if total > c.maxTotalEnmity then c.maxTotalEnmity = total end

                local currentTarget = session.mob.getTarget and session.mob:getTarget() or nil
                if currentTarget ~= nil then
                    c.threatSamples = c.threatSamples + 1
                    local curTargetId = entityIdOf(currentTarget)
                    local primaryId = entityIdOf(session.primaryActor)
                    if curTargetId ~= nil and curTargetId == primaryId then
                        c.primaryTargetSamples = c.primaryTargetSamples + 1
                    end
                    if session.lastThreatLeader ~= nil and curTargetId ~= session.lastThreatLeader then
                        emitEvent('boss', 'boss_target_change', session.mob, currentTarget, curTargetId or 0, {
                            previous_target_id = session.lastThreatLeader,
                        }, false)
                        if session.lastThreatLeader == primaryId and curTargetId ~= primaryId then
                            c.threatLosses = c.threatLosses + 1
                        end
                    end
                    session.lastThreatLeader = curTargetId
                end
            end
        end
    end

    local function recordSnapshot(forceNow)
        if session.ended or session.combatStartMs == nil then
            return
        end
        local t = monotonicNowMs()
        local combatMs = math.max(0, t - session.combatStartMs)
        local combatSec = math.floor(combatMs / 1000)
        if not forceNow and combatSec <= session.lastSnapshotCombatSec then
            return
        end
        session.lastSnapshotCombatSec = combatSec

        if (session.snapshotsWritten + #session.snapshotBuffer) >= T.MAX_SNAPSHOTS_PER_RUN then
            session.snapshotsDropped = session.snapshotsDropped + 1
            return
        end

        sampleResourcesAndThreat()

        local playersArr = {}
        for _, actor in ipairs(session.actors) do
            local aid = entityIdOf(actor)
            local hp = actor.getHP and actor:getHP() or 0
            local maxHp = actor.getMaxHP and actor:getMaxHP() or 0
            local mp = actor.getMP and actor:getMP() or 0
            local maxMp = actor.getMaxMP and actor:getMaxMP() or 0
            local tp = actor.getTP and actor:getTP() or 0
            local alive = (not actor.isAlive) or actor:isAlive()
            playersArr[#playersArr + 1] =
            {
                id         = aid,
                name       = entityNameOf(actor),
                hp         = hp,
                max_hp     = maxHp,
                hp_pct     = maxHp > 0 and round4((hp / maxHp) * 100) or 0,
                mp         = mp,
                max_mp     = maxMp,
                tp         = tp,
                alive      = alive,
                buff_count = countMapKeys(session.lastEffectsByEntity[aid]),
            }
        end

        local compsArr = {}
        for _, comp in ipairs(collectActiveCompanions(session.actors, session.actorMap)) do
            local chp = comp.entity.getHP and comp.entity:getHP() or 0
            local cmax = comp.entity.getMaxHP and comp.entity:getMaxHP() or 0
            compsArr[#compsArr + 1] =
            {
                id       = comp.id,
                name     = entityNameOf(comp.entity),
                kind     = comp.kind,
                owner_id = comp.ownerId,
                hp       = chp,
                max_hp   = cmax,
                hp_pct   = cmax > 0 and round4((chp / cmax) * 100) or 0,
                alive    = (not comp.entity.isAlive) or comp.entity:isAlive(),
            }
        end

        local bossObj = nil
        if session.mob ~= nil then
            local bid = entityIdOf(session.mob)
            local bhp = session.mob.getHP and session.mob:getHP() or 0
            local bmax = session.mob.getMaxHP and session.mob:getMaxHP() or 0
            local btarg = session.mob.getTarget and session.mob:getTarget() or nil
            local ce = (session.primaryActor and session.mob.getCE and session.mob:getCE(session.primaryActor)) or 0
            local ve = (session.primaryActor and session.mob.getVE and session.mob:getVE(session.primaryActor)) or 0
            bossObj =
            {
                id              = bid,
                name            = entityNameOf(session.mob),
                hp              = bhp,
                max_hp          = bmax,
                hp_pct          = bmax > 0 and round4((bhp / bmax) * 100) or 0,
                target_id       = entityIdOf(btarg),
                target_name     = btarg ~= nil and entityNameOf(btarg) or nil,
                threat_owner_id = entityIdOf(btarg),
                ce_primary      = ce,
                ve_primary      = ve,
                debuff_count    = countMapKeys(session.lastEffectsByEntity[bid]),
            }
        end

        local c = session.counters
        local prev = session.prevSnapTotals
        local interval =
        {
            damage_dealt     = c.totalDamage - prev.dmg,
            player_damage    = c.playerDamage - prev.pDmg,
            pet_clone_damage = c.petAndCloneDamage - prev.petDmg,
            damage_received  = c.actualIncomingDamage - prev.inc,
            healing_done     = c.effectiveHealing - prev.heal,
        }
        prev.dmg    = c.totalDamage
        prev.pDmg   = c.playerDamage
        prev.petDmg = c.petAndCloneDamage
        prev.inc    = c.actualIncomingDamage
        prev.heal   = c.effectiveHealing

        local snap =
        {
            run_id          = session.runId,
            combat_sec      = combatSec,
            combat_ms       = combatMs,
            players         = playersArr,
            boss            = bossObj,
            pets_and_clones = compsArr,
            interval        = interval,
            cumulative      =
            {
                total_damage      = c.totalDamage,
                player_damage     = c.playerDamage,
                pet_clone_damage  = c.petAndCloneDamage,
                incoming_damage   = c.actualIncomingDamage,
                effective_healing = c.effectiveHealing,
            },
            soul_resources  = T.UNAVAILABLE,
        }

        session.snapshotBuffer[#session.snapshotBuffer + 1] = T.encodeJson(snap)
        if #session.snapshotBuffer >= 5 then
            flushSnapshots()
        end
    end

    session.sampleNow      = sampleResourcesAndThreat
    session.recordSnapshot = recordSnapshot
    session.emitEvent      = emitEvent
    session.onBossSkillChosen = function(chosenMob, target, skillId)
        local seq = emitEvent('boss', 'boss_ability_choose', chosenMob, target, skillId, { skill_id = skillId }, true)
        session.lastBossActionSeq   = seq
        session.lastBossActionSkill = skillId
        session.lastBossActionMs    = monotonicNowMs()
    end

    -- Emit initial session_start lifecycle event (preparation phase)
    emitEvent('lifecycle', 'session_start', primaryActor, mob, encounter.bossLevel or 0, {
        encounter_id     = encounter.encounterId,
        boss_type        = encounter.bossType,
        difficulty       = encounter.difficulty,
        boss_preset      = encounter.bossPreset,
        original_level   = originalLevel,
        effective_level  = effectiveLevel,
        level_sync_valid = levelSyncInfo and levelSyncInfo.valid or true,
    }, false)

    -- Seed initial resource & effect readings
    for _, actor in ipairs(actors) do
        local id = entityIdOf(actor)
        if id ~= nil then
            if actor.getTP then session.lastTpByActor[id] = actor:getTP() or 0 end
            if actor.getMP then session.lastMpByActor[id] = actor:getMP() or 0 end
            if actor.getHP then session.lastHpByActor[id] = actor:getHP() or 0 end
            session.lastEffectsByEntity[id] = snapshotEffectIds(actor)
        end
    end
    if mob ~= nil then
        local mid = entityIdOf(mob)
        if mid ~= nil then
            session.lastEffectsByEntity[mid] = snapshotEffectIds(mob)
        end
    end

    -- Bind any companions already present before combat begins
    for _, comp in ipairs(collectActiveCompanions(actors, actorMap)) do
        bindCompanionIfNeeded(comp)
    end

    -- Bind boss-side listeners
    if mob ~= nil then
        bindListener(mob, 'ENGAGE', 'MOB_ENGAGE', function(engagedMob, target)
            if session.ended then return end
            emitEvent('boss', 'boss_engage', engagedMob, target, 1, nil, true)
            recordSnapshot(true)
        end)

        bindListener(mob, 'TAKE_DAMAGE', 'MOB_DMG', function(defender, amount, attacker, attackType, damageType)
            if session.ended then return end
            local dmg = math.max(0, math.floor(tonumber(amount) or 0))
            if dmg <= 0 then return end

            local compKind, compOwnerId = resolveCompanionOwnership(attacker, session.actorMap)
            if compKind ~= nil then
                bindCompanionIfNeeded({ entity = attacker, id = entityIdOf(attacker), kind = compKind, ownerId = compOwnerId })
                recordOffenseDamage(dmg, compKind, attacker, defender, {
                    owner_id    = compOwnerId,
                    attack_type = attackType,
                    damage_type = damageType,
                })
                return
            end

            local aid = entityIdOf(attacker)
            if aid ~= nil and session.actorMap[aid] ~= nil then
                -- Skip duplicate damage recording for Weapon Skills already credited in WEAPONSKILL_USE
                if session.pendingWsCredit > 0 then
                    session.pendingWsCredit = session.pendingWsCredit - 1
                    return
                end
                local kind = (xi.attackType and attackType == xi.attackType.MAGICAL) and 'spell' or 'auto'
                recordOffenseDamage(dmg, kind, attacker, defender, {
                    attack_type = attackType,
                    damage_type = damageType,
                })
            end
        end)

        bindListener(mob, 'MELEE_SWING_HIT', 'MOB_SWING_HIT', function(attacker, target, attack)
            if session.ended then return end
            local tid = entityIdOf(target)
            if tid ~= nil and session.actorMap[tid] ~= nil then
                session.counters.incomingSwingsHit = session.counters.incomingSwingsHit + 1
                emitEvent('defense', 'incoming_swing_hit', attacker, target, 1, {
                    is_critical = (attack and attack.isCritical and attack:isCritical()) or false,
                }, true)
            end
        end)

        bindListener(mob, 'MELEE_SWING_MISS', 'MOB_SWING_MISS', function(attacker, target, attack)
            if session.ended then return end
            local tid = entityIdOf(target)
            if tid ~= nil and session.actorMap[tid] ~= nil then
                session.counters.incomingSwingsMissed = session.counters.incomingSwingsMissed + 1
                emitEvent('defense', 'incoming_swing_missed', attacker, target, 0, nil, true)
            end
        end)

        bindListener(mob, 'WEAPONSKILL_STATE_ENTER', 'MOB_WS_ENTER', function(m, skillId)
            if session.ended then return end
            session.counters.bossAbilitiesUsed = session.counters.bossAbilitiesUsed + 1
            local seq = emitEvent('boss', 'boss_ability_start', m, m:getTarget(), skillId, { skill_id = skillId }, true)
            session.lastBossActionSeq   = seq
            session.lastBossActionSkill = skillId
            session.lastBossActionMs    = monotonicNowMs()
        end)

        bindListener(mob, 'WEAPONSKILL_STATE_EXIT', 'MOB_WS_EXIT', function(m, skillId, completed)
            if session.ended then return end
            emitEvent('boss', 'boss_ability_complete', m, m:getTarget(), skillId, {
                skill_id  = skillId,
                completed = completed == true,
            }, false)
        end)

        bindListener(mob, 'MAGIC_START', 'MOB_MAG_START', function(caster, target, spell)
            if session.ended then return end
            local sid = spell and spell.getID and spell:getID() or 0
            local seq = emitEvent('boss', 'boss_spell_start', caster, target, sid, { spell_id = sid }, true)
            session.lastBossActionSeq   = seq
            session.lastBossActionSkill = sid
            session.lastBossActionMs    = monotonicNowMs()
        end)

        bindListener(mob, 'MAGIC_USE', 'MOB_MAG_USE', function(caster, target, spell)
            if session.ended then return end
            session.counters.bossSpellsCast = session.counters.bossSpellsCast + 1
            local sid = spell and spell.getID and spell:getID() or 0
            emitEvent('boss', 'boss_spell_complete', caster, target, sid, { spell_id = sid }, true)
        end)

        bindListener(mob, 'DEATH', 'MOB_DEATH', function(deadMob, killer)
            if session.ended then return end
            checkBossHpThresholds()
            emitEvent('boss', 'boss_death', killer, deadMob, 0, nil, false)
        end)

        bindListener(mob, 'EFFECTS_TICK', 'MOB_TICK', function()
            if session.ended then return end
            sampleResourcesAndThreat()
            if session.combatStartMs ~= nil then
                recordSnapshot(false)
            end
        end)

        -- Lightweight 1-second timer loop on live xi_map for exact 1s combat snapshots.
        if opts.enableLiveSnapshotTimer ~= false and mob.timer then
            local function scheduleNextSnap(m)
                if session.ended or m == nil or (m.isAlive and not m:isAlive()) then
                    return
                end
                m:timer(1000, function(tm)
                    if session.ended then
                        return
                    end
                    if session.combatStartMs ~= nil then
                        recordSnapshot(false)
                    end
                    scheduleNextSnap(tm)
                end)
            end
            scheduleNextSnap(mob)
        end
    end

    -- Bind actor-side listeners
    for idx, actor in ipairs(actors) do
        if actor ~= nil then
            local pfx = 'A' .. tostring(idx) .. '_'

            bindListener(actor, 'MELEE_SWING_HIT', pfx .. 'HIT', function(att, targ, attack)
                if session.ended then return end
                session.counters.meleeHits = session.counters.meleeHits + 1
                local isCrit = (attack and attack.isCritical and attack:isCritical()) or false
                if isCrit then
                    session.counters.critHits = session.counters.critHits + 1
                end
                emitEvent('offense', isCrit and 'melee_crit' or 'melee_hit', att, targ, 1, { is_critical = isCrit }, true)
            end)

            bindListener(actor, 'MELEE_SWING_MISS', pfx .. 'MISS', function(att, targ)
                if session.ended then return end
                session.counters.meleeMisses = session.counters.meleeMisses + 1
                emitEvent('offense', 'melee_miss', att, targ, 0, nil, true)
            end)

            bindListener(actor, 'WEAPONSKILL_USE', pfx .. 'WS', function(att, targ, skill, spentTP, action, damage)
                if session.ended then return end
                local c = session.counters
                c.wsUses = c.wsUses + 1
                local spent = math.max(0, math.floor(tonumber(spentTP) or 0))
                c.tpSpent = c.tpSpent + spent
                local wsDmg = math.max(0, math.floor(tonumber(damage) or 0))
                local skillId = skill and skill.getID and skill:getID() or 0
                local skillName = skill and skill.getName and skill:getName() or nil

                if wsDmg > 0 then
                    session.pendingWsCredit = session.pendingWsCredit + 1
                    recordOffenseDamage(wsDmg, 'ws', att, targ, {
                        skill_id   = skillId,
                        skill_name = skillName,
                        tp_spent   = spent,
                    })
                else
                    emitEvent('offense', 'weaponskill_use', att, targ, 0, {
                        skill_id   = skillId,
                        skill_name = skillName,
                        tp_spent   = spent,
                    }, true)
                end
                sampleResourcesAndThreat()
            end)

            bindListener(actor, 'ABILITY_USE', pfx .. 'JA', function(user, targ, ability)
                if session.ended then return end
                session.counters.abilityUses = session.counters.abilityUses + 1
                local abId = ability and ability.getID and ability:getID() or 0
                local abName = ability and ability.getName and ability:getName() or ''
                local isHostile = (targ ~= nil and entityIdOf(targ) == entityIdOf(session.mob))
                if isDefensiveAbilityName(abName) then
                    session.counters.defensiveCdUses = session.counters.defensiveCdUses + 1
                    emitEvent('defense', 'defensive_ability_use', user, targ, abId, { ability_name = abName }, isHostile)
                else
                    emitEvent('offense', 'ability_use', user, targ, abId, { ability_name = abName }, isHostile)
                end
                sampleResourcesAndThreat()
            end)

            bindListener(actor, 'MAGIC_START', pfx .. 'MAGSTART', function(caster, targ, spell)
                if session.ended then return end
                local sid = spell and spell.getID and spell:getID() or 0
                local isHostile = (targ ~= nil and entityIdOf(targ) == entityIdOf(session.mob))
                emitEvent('offense', 'spell_start', caster, targ, sid, { spell_id = sid }, isHostile)
            end)

            bindListener(actor, 'MAGIC_USE', pfx .. 'MAG', function(caster, targ, spell, action)
                if session.ended then return end
                local c = session.counters
                c.spellCasts = c.spellCasts + 1
                local sid = spell and spell.getID and spell:getID() or 0
                local isHostile = (targ ~= nil and entityIdOf(targ) == entityIdOf(session.mob))
                emitEvent('offense', 'spell_complete', caster, targ, sid, { spell_id = sid }, isHostile)

                local tid = entityIdOf(targ)
                if tid ~= nil and session.actorMap[tid] ~= nil and action and action.getParam then
                    local spellGroup = spell and spell.getSpellGroup and spell:getSpellGroup() or nil
                    local healedAmt = tonumber(action:getParam(tid)) or 0
                    if healedAmt > 0 and (spellGroup == nil or (xi.magic and xi.magic.spellGroup and spellGroup == xi.magic.spellGroup.WHITE)) then
                        local maxHp = targ.getMaxHP and targ:getMaxHP() or 0
                        local eff = math.min(healedAmt, math.max(0, maxHp))
                        c.effectiveHealing = c.effectiveHealing + eff
                        c.healEvents = c.healEvents + 1
                        local tNow = monotonicNowMs()
                        if session.lastHealMs ~= nil then
                            local gap = tNow - session.lastHealMs
                            if gap > session.maxHealGapMs then
                                session.maxHealGapMs = gap
                            end
                        end
                        session.lastHealMs = tNow
                        emitEvent('defense', 'heal_applied', caster, targ, eff, { spell_id = sid }, false)
                    end
                end
                sampleResourcesAndThreat()
            end)

            bindListener(actor, 'MAGIC_INTERRUPTED', pfx .. 'MAGINT', function(caster, targ, spell)
                if session.ended then return end
                session.counters.spellInterrupts = session.counters.spellInterrupts + 1
                local sid = spell and spell.getID and spell:getID() or 0
                emitEvent('offense', 'spell_interrupt', caster, targ, sid, { spell_id = sid }, false)
            end)

            bindListener(actor, 'TAKE_DAMAGE', pfx .. 'TDMG', function(defender, amount, attacker, attackType, damageType)
                if session.ended then return end
                local dmg = math.max(0, math.floor(tonumber(amount) or 0))
                if dmg <= 0 then return end
                local c = session.counters
                c.actualIncomingDamage = c.actualIncomingDamage + dmg
                c.incomingHits = c.incomingHits + 1
                if dmg > c.maxDamageSpike then
                    c.maxDamageSpike = dmg
                end

                local dmgMeta =
                {
                    attack_type = attackType,
                    damage_type = damageType,
                }
                if session.lastBossActionSeq and session.lastBossActionMs and (monotonicNowMs() - session.lastBossActionMs) <= 2500 then
                    dmgMeta.boss_action_seq = session.lastBossActionSeq
                    dmgMeta.boss_skill_id   = session.lastBossActionSkill
                end

                emitEvent('defense', 'damage_taken', attacker, defender, dmg, dmgMeta, true)

                local maxHp = defender.getMaxHP and defender:getMaxHP() or 0
                if maxHp > 0 and dmg >= (maxHp * T.SPIKE_HP_FRACTION) then
                    c.spikeHitCount = c.spikeHitCount + 1
                    emitEvent('defense', 'damage_spike', attacker, defender, dmg, {
                        hp_share_pct    = round4((dmg / maxHp) * 100),
                        boss_action_seq = dmgMeta.boss_action_seq,
                    }, false)
                end
            end)

            bindListener(actor, 'DEATH', pfx .. 'DEATH', function(deadActor, killer)
                if session.ended then return end
                session.counters.deaths = session.counters.deaths + 1
                emitEvent('defense', 'death', killer, deadActor, 0, nil, false)
            end)

            bindListener(actor, 'EXPERIENCE_POINTS', pfx .. 'EXP', function(pc, killedMob, exp)
                if session.ended then return end
                session.counters.expEventsObserved = session.counters.expEventsObserved + 1
                session.counters.expPointsObserved = session.counters.expPointsObserved + (tonumber(exp) or 0)
            end)

            bindListener(actor, 'EFFECTS_TICK', pfx .. 'TICK', function()
                if session.ended then return end
                sampleResourcesAndThreat()
            end)
        end
    end

    for aid, _ in pairs(actorMap) do
        activeSessionsByActor[aid] = session
    end

    return session
end

local function computePeakBurstDps(timeline, windowSec)
    if type(timeline) ~= 'table' or #timeline == 0 then
        return 0
    end
    local win = math.max(1, tonumber(windowSec) or T.BURST_WINDOW_SEC)
    local bestDmg = 0
    local left = 1
    local running = 0
    for right = 1, #timeline do
        running = running + timeline[right].dmg
        while left <= right and (timeline[right].t - timeline[left].t) > win do
            running = running - timeline[left].dmg
            left = left + 1
        end
        if running > bestDmg then
            bestDmg = running
        end
    end
    return round4(bestDmg / win)
end

-- Detaches all listeners cleanly without mutating gameplay state.
function T.detachSession(session)
    if session == nil or session.boundEntities == nil then
        return
    end
    for _, binding in ipairs(session.boundEntities) do
        if binding.entity and binding.entity.removeListener then
            pcall(function()
                binding.entity:removeListener(binding.name)
            end)
        end
    end
    session.boundEntities = {}
    session.boundCompanionIds = {}
    if type(session.actorMap) == 'table' then
        for aid, _ in pairs(session.actorMap) do
            if activeSessionsByActor[aid] == session then
                activeSessionsByActor[aid] = nil
            end
        end
    end
end

-- Finalizes a session, flushes all buffered events & snapshots, writes summary JSONL,
-- and returns the full record including explicit logging_status.
function T.finishSession(session, outcome, opts)
    if session == nil then
        return nil
    end
    opts = opts or {}

    local endMs = session.clockMsFn()
    if endMs < session.lastEventMs then
        endMs = session.lastEventMs
    end
    session.combatEndMs = endMs

    if not session.ended then
        if session.combatStartMs ~= nil then
            pcall(session.recordSnapshot, true)
        elseif session.sampleNow then
            pcall(session.sampleNow)
        end
        session.emitEvent('lifecycle', 'session_end', session.primaryActor, session.mob, 0, {
            outcome = tostring(outcome or 'completed'),
        }, false)
        session.ended = true
    end

    T.detachSession(session)

    -- Flush remaining buffered events & snapshots
    if session.writeLog and opts.writeLog ~= false then
        if #session.eventBuffer > 0 then
            local ok, err = appendLinesToFile(session.eventsPath, session.eventBuffer)
            if ok then
                session.eventsWritten = session.eventsWritten + #session.eventBuffer
            else
                session.writeErrors[#session.writeErrors + 1] = tostring(err)
            end
            session.eventBuffer = {}
        end
        if #session.snapshotBuffer > 0 then
            local ok, err = appendLinesToFile(session.snapshotsPath, session.snapshotBuffer)
            if ok then
                session.snapshotsWritten = session.snapshotsWritten + #session.snapshotBuffer
            else
                session.writeErrors[#session.writeErrors + 1] = tostring(err)
            end
            session.snapshotBuffer = {}
        end
    end

    local combatStarted = (session.combatStartMs ~= nil)
    local prepDurationSec = combatStarted
        and round4(math.max(0, session.combatStartMs - session.prepStartMs) / 1000.0)
        or round4(math.max(0, endMs - session.prepStartMs) / 1000.0)

    local combatDurationSec = 0
    if opts.durationSec ~= nil and combatStarted then
        combatDurationSec = math.max(0.001, tonumber(opts.durationSec) or 0.001)
    elseif combatStarted then
        combatDurationSec = math.max(0.001, (endMs - session.combatStartMs) / 1000.0)
    end

    local totalSessionSec = round4(math.max(0, endMs - session.arenaEntryMs) / 1000.0)

    local c = session.counters
    local totalSwings = c.meleeHits + c.meleeMisses
    local hitRate = totalSwings > 0 and round4(c.meleeHits / totalSwings) or T.UNAVAILABLE
    local critRate = c.meleeHits > 0 and round4(c.critHits / c.meleeHits) or T.UNAVAILABLE

    local sustainedDps = combatStarted and round4(c.totalDamage / combatDurationSec) or T.UNAVAILABLE
    local burstDps     = combatStarted and computePeakBurstDps(session.damageTimeline, T.BURST_WINDOW_SEC) or T.UNAVAILABLE
    local petDps       = (combatStarted and (c.petSeen or c.cloneSeen)) and round4(c.petAndCloneDamage / combatDurationSec) or (combatStarted and 0 or T.UNAVAILABLE)
    local petUptimePct = ((c.petSeen or c.cloneSeen) and c.petSamples > 0) and round4((c.petAliveSamples / c.petSamples) * 100) or T.UNAVAILABLE
    local petSurvival  = (c.petSeen or c.cloneSeen) and (c.petDeaths == 0 and c.petAliveSamples > 0) or T.UNAVAILABLE

    local aggroUptimePct = c.threatSamples > 0 and round4((c.primaryTargetSamples / c.threatSamples) * 100) or T.UNAVAILABLE
    local hps            = combatStarted and round4(c.effectiveHealing / combatDurationSec) or T.UNAVAILABLE
    local mpEfficiency   = c.mpConsumed > 0 and round4((c.totalDamage + c.effectiveHealing) / c.mpConsumed) or T.UNAVAILABLE
    local avgBuffCount   = c.buffSamples > 0 and round4(c.activeBuffTotal / c.buffSamples) or T.UNAVAILABLE

    local enc  = session.encounter or {}
    local soul = session.soulInfo or {}
    local warnings = {}
    for _, w in ipairs(session.warnings) do warnings[#warnings + 1] = w end

    if not combatStarted then
        warnings[#warnings + 1] = 'combat_never_started'
    end
    if session.eventsDropped > 0 then
        warnings[#warnings + 1] = string.format('events_dropped:%d', session.eventsDropped)
    end
    if session.snapshotsDropped > 0 then
        warnings[#warnings + 1] = string.format('snapshots_dropped:%d', session.snapshotsDropped)
    end

    local syncValid = true
    if session.levelSync ~= nil then
        syncValid = (session.levelSync.valid == true)
        if not syncValid then
            warnings[#warnings + 1] = 'invalid_level_sync'
            for _, sw in ipairs(session.levelSync.warnings or {}) do
                warnings[#warnings + 1] = sw
            end
        end
    end

    local isExtreme = (enc.extremeChallenge == true) or (enc.difficulty == 'extreme') or (enc.difficulty == 'boss_plus_8')
    local validForBalance = syncValid and combatStarted and (not isExtreme) and (c.expPointsObserved == 0)

    local record =
    {
        run_id                   = session.runId,
        telemetry_schema_version = T.TELEMETRY_SCHEMA_VERSION,
        timestamp_utc            = os.date('!%Y-%m-%dT%H:%M:%SZ', session.arenaEntryWall),
        encounter_id             = enc.encounterId or 'unknown',
        encounter_version        = enc.version or '2.0.0',
        soul_name                = soul.soul_name or 'None',
        soul_key                 = soul.soul_key or 'none',
        job                      = soul.job or 'UNKNOWN',
        role                     = soul.role or 'Unassigned',
        tier                     = soul.tier or 'Unassigned',
        original_character_level = session.originalLevel,
        effective_combat_level   = session.effectiveLevel,
        character_level          = session.effectiveLevel, -- Preserved for backwards compatibility
        boss_type                = enc.bossType or 'unknown',
        boss_level               = enc.bossLevel or 0,
        actual_boss_level        = (session.mob and session.mob.getMainLvl and session.mob:getMainLvl()) or enc.bossLevel or 0,
        level_gap                = (enc.bossLevel or 0) - session.effectiveLevel,
        difficulty               = enc.difficulty or 'even_match',
        standard_baseline        = not isExtreme,
        extreme_challenge        = isExtreme,
        boss_preset              = enc.bossPreset or 'normal',
        level_sync               = session.levelSync or
        {
            valid              = syncValid,
            original_level     = session.originalLevel,
            expected_level     = enc.playerLevel or session.effectiveLevel,
            effective_level    = session.effectiveLevel,
            restriction_active = (session.originalLevel > session.effectiveLevel),
            warnings           = {},
        },
        gear_profile             = enc.gearProfile or 'unknown',
        party_composition        = enc.partyComposition or 'solo',
        combat_started           = combatStarted,
        prep_duration_sec        = prepDurationSec,
        encounter_duration_sec   = round4(combatDurationSec),
        total_session_sec        = totalSessionSec,
        timing =
        {
            arena_entry_ms    = session.arenaEntryMs,
            prep_start_ms     = session.prepStartMs,
            combat_start_ms   = session.combatStartMs,
            combat_end_ms     = session.combatEndMs,
            prep_duration_sec = prepDurationSec,
            combat_duration_sec = round4(combatDurationSec),
        },
        server_commit_sha        = session.serverCommitSha,
        test_mode                = session.testMode,
        outcome                  = tostring(outcome or 'completed'),
        seed                     = enc.seed ~= nil and enc.seed or T.UNAVAILABLE,
        valid_for_balance        = validForBalance,
        warnings                 = warnings,
        files =
        {
            runs_index    = session.runsPath,
            events_log    = session.eventsPath,
            snapshots_log = session.snapshotsPath,
            feedback_file = session.feedbackPath,
        },
        metrics =
        {
            offense =
            {
                total_damage         = c.totalDamage,
                player_damage        = c.playerDamage,
                sustained_dps        = sustainedDps,
                burst_dps_10s        = burstDps,
                autoattack_damage    = c.autoAttackDamage,
                weaponskill_damage   = c.weaponSkillDamage,
                spell_damage         = c.spellDamage,
                pet_and_clone_damage = c.petAndCloneDamage,
                melee_hits           = c.meleeHits,
                melee_misses         = c.meleeMisses,
                hit_rate             = hitRate,
                crit_hits            = c.critHits,
                crit_rate            = critRate,
                weaponskill_uses     = c.wsUses,
                ability_uses         = c.abilityUses,
                spell_casts          = c.spellCasts,
                spell_interrupts     = c.spellInterrupts,
            },
            defense =
            {
                raw_incoming_damage    = T.UNAVAILABLE,
                actual_incoming_damage = c.actualIncomingDamage,
                mitigated_damage       = T.UNAVAILABLE,
                block_rate             = T.UNAVAILABLE,
                parry_rate             = T.UNAVAILABLE,
                evasion_rate           = T.UNAVAILABLE,
                incoming_swings_hit    = c.incomingSwingsHit,
                incoming_swings_missed = c.incomingSwingsMissed,
                max_damage_spike       = c.maxDamageSpike,
                spike_hit_count        = c.spikeHitCount,
                deaths                 = c.deaths,
                defensive_cd_uses      = c.defensiveCdUses,
            },
            healing =
            {
                effective_healing    = c.effectiveHealing,
                overhealing          = T.UNAVAILABLE,
                healing_per_second   = hps,
                mp_consumed          = c.mpConsumed,
                mp_recovered         = c.mpRecovered,
                healing_downtime_sec = c.healEvents > 1 and round4(session.maxHealGapMs / 1000.0) or T.UNAVAILABLE,
            },
            threat =
            {
                enmity_generation     = c.maxTotalEnmity,
                max_ce                = c.maxCe,
                max_ve                = c.maxVe,
                threat_samples        = c.threatSamples,
                tank_aggro_uptime_pct = aggroUptimePct,
                threat_losses         = c.threatLosses,
            },
            resources_and_pets =
            {
                tp_generated          = c.tpGenerated,
                tp_spent              = c.tpSpent,
                mp_efficiency         = mpEfficiency,
                avg_active_buffs      = avgBuffCount,
                pet_survival          = petSurvival,
                pet_uptime_pct        = petUptimePct,
                pet_dps               = petDps,
                pet_deaths            = c.petDeaths,
                soul_specific_metrics = T.UNAVAILABLE,
            },
            boss =
            {
                abilities_used = c.bossAbilitiesUsed,
                spells_cast    = c.bossSpellsCast,
            },
            safety =
            {
                exp_events_observed = c.expEventsObserved,
                exp_points_observed = c.expPointsObserved,
                progression_clean   = (c.expEventsObserved == 0 and c.expPointsObserved == 0),
            },
        },
        metric_availability =
        {
            raw_incoming_damage     = 'unavailable: TAKE_DAMAGE listener receives post-mitigation final damage only',
            mitigated_damage        = 'unavailable: depends on raw_incoming_damage',
            block_parry_evade_split = 'unavailable: MELEE_SWING_MISS aggregates dodge/parry/shadow misses without per-reaction split',
            overhealing             = 'unavailable: MAGIC_USE action param reports applied HP recovery without pre-cap amount',
            soul_specific_metrics   = 'unavailable: per-Soul custom gauge hooks not yet instrumented in Lua telemetry',
            spell_resist_tier       = 'unavailable: MAGIC_USE does not expose 1/2, 1/4, 1/8 resist tier directly',
        },
        logging_status =
        {
            ok                = (#session.writeErrors == 0),
            partial_recording = (#session.writeErrors > 0 or session.eventsDropped > 0 or session.snapshotsDropped > 0),
            events_written    = session.eventsWritten,
            events_dropped    = session.eventsDropped,
            snapshots_written = session.snapshotsWritten,
            snapshots_dropped = session.snapshotsDropped,
            errors            = session.writeErrors,
        },
    }

    if session.writeLog and opts.writeLog ~= false then
        local jsonLine = T.encodeJson(record)
        local ok1, err1 = appendLinesToFile(session.runsPath, { jsonLine })
        if not ok1 then
            session.writeErrors[#session.writeErrors + 1] = tostring(err1)
        end
        if type(session.legacyLogPath) == 'string' and session.legacyLogPath ~= '' and session.legacyLogPath ~= session.runsPath then
            local ok2, err2 = appendLinesToFile(session.legacyLogPath, { jsonLine })
            if not ok2 then
                session.writeErrors[#session.writeErrors + 1] = tostring(err2)
            end
        end
        record.logging_status.ok = (#session.writeErrors == 0)
        record.logging_status.partial_recording = (#session.writeErrors > 0 or session.eventsDropped > 0 or session.snapshotsDropped > 0)
        record.logging_status.errors = session.writeErrors
    end

    return record
end

return T
