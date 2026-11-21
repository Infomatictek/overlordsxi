-----------------------------------
-- SoulspireXI — Burrows Reborn: The First Descent (Playable Level 10 Prototype)
--
-- Features:
--   - Native Meeble Burrows instanced zone: Ghoyu's Reverie (zone 129, instance 12901).
--   - True concurrent party isolation via LandSandBoat CInstance + instance:insertDynamicEntity.
--   - Real "Burrows Expedition Guide" NPCs in safe hubs accessible to fresh Lv. 10 players:
--       Port San d'Oria, Bastok Mines, Port Windurst, and Ru'Lude Gardens
--       (plus an in-instance Guide NPC for status & safe exit at any time).
--   - Two difficulty modes: Low Man (1-3, tuned for 2) & Full Party (4-6, tuned for 6).
--   - Native Lv. 10 level synchronization via SoulspireXI's Proving Grounds registry
--     (xi.effect.LEVEL_RESTRICTION + Soul/HP/Pet/Clone rescaling) with guaranteed
--     state restoration on victory, failure, exit, disconnect, zoning, or relog.
--   - Three connected encounters with cross-encounter boss adaptations:
--       1. The Burrow Shaman (ritual cast -> interrupt/defeat to deny boss empowerment)
--       2. The Stoneguard (Iron Shell Stance -> timing/magic break; defeat weakens boss armor)
--       3. Grudgeburrow (telegraphed heavy slam, manageable AoE, vulnerability windows,
--          and dynamic adaptations from Encounters 1 & 2)
--   - Zero rewards (0 EXP, 0 gil, 0 items, 0 currencies, 0 titles, 0 skill-ups).
--   - Zero pheromone sacks, entry charges, grimoires, prerequisites, or replay locks.
-----------------------------------
local hasServerRuntime = (Module ~= nil and Module.new ~= nil)
if hasServerRuntime then
    require('modules/module_utils')
    require('scripts/globals/experience_points')
    require('scripts/globals/player')
    require('scripts/zones/Port_San_dOria/Zone')
    require('scripts/zones/Bastok_Mines/Zone')
    require('scripts/zones/Port_Windurst/Zone')
    require('scripts/zones/RuLude_Gardens/Zone')
    require('scripts/zones/Ghoyus_Reverie/Zone')
    require('modules/custom/lua/boss_like_combat_and_exp')
    require('modules/custom/lua/soulspire_proving_grounds_registry')
    require('modules/custom/lua/soulspire_burrows_config')
end

xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.soulspire.burrows = xi.soulspire.burrows or {}
xi.soulspire.burrows.instance = xi.soulspire.burrows.instance or {}
xi.soulspire.burrows.runtime = xi.soulspire.burrows.runtime or {}

local C = xi.soulspire.burrows.config
local R = xi.soulspire.provingGrounds and xi.soulspire.provingGrounds.registry or nil
local B = xi.soulspire.burrows.runtime
local I = xi.soulspire.burrows.instance

local nextRunSeq = 0
local sessionsByRunId = {}
local pendingEntryByLeaderId = {}
local playerRunId = {}

-- Zero-shell directory creator via LuaJIT FFI on Windows (matching SoulspireXI telemetry).
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
    local accum = (norm:sub(1, 1) == '/') and '/' or ''
    for segment in norm:gmatch('[^/]+') do
        if accum == '' or accum == '/' then
            accum = accum .. segment
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

local function diagError(msg)
    print('[BurrowsReborn][ERROR] ' .. tostring(msg))
end

local function nowUtcIso()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function nowUtcFileStamp()
    return os.date('!%Y%m%d_%H%M%S')
end

local function initSessionLogger(session)
    if session == nil or session.loggerInitialized then
        return
    end
    session.loggerInitialized = true
    local logDir = C.resolveLogDir()
    ensureDir(logDir)

    local stamp = nowUtcFileStamp()
    local entropy = math.floor(((os.clock() or 0) * 100000 + (session.runId or 0) * 997 + (os.time() or 0)) % 65536)
    session.sessionId = string.format('r%d_%04x', tonumber(session.runId) or 0, entropy)
    session.logDir = logDir
    session.eventLogPath = string.format('%s/burrows_%s_%s.jsonl', logDir, stamp, session.sessionId)
    session.summaryPath = string.format('%s/burrows_%s_%s_summary.json', logDir, stamp, session.sessionId)
    session.runsIndexPath = (type(C.LOG_RUNS_PATH) == 'string' and C.LOG_RUNS_PATH ~= '')
        and C.LOG_RUNS_PATH
        or (logDir .. '/runs.jsonl')
    session.startedAtUtc = nowUtcIso()
    session.logBuffer = {}
    session.eventCount = 0
    session.encounterTimings = {}
    session.combatStats =
    {
        damageDealt         = 0,
        damageReceived      = 0,
        healingTotal        = 0,
        healingObserved     = false,
        playerDeaths        = 0,
        weaponskills        = 0,
        spellsCast          = 0,
        abilitiesUsed       = 0,
        interrupts          = 0,
        enmityTargetChanges = 0,
    }
end

local function flushEventLog(session)
    if session == nil or not session.logBuffer or #session.logBuffer == 0 then
        return true
    end
    if not session.eventLogPath or session.eventLogPath == '' then
        initSessionLogger(session)
    end
    ensureDir(session.logDir)
    local fh, err = io.open(session.eventLogPath, 'a')
    if not fh then
        diagError(string.format('Failed to open event log %s: %s', tostring(session.eventLogPath), tostring(err)))
        return false
    end
    local ok, werr = pcall(function()
        fh:write(table.concat(session.logBuffer, '\n') .. '\n')
        fh:flush()
    end)
    fh:close()
    if not ok then
        diagError(string.format('Failed to write event log %s: %s', tostring(session.eventLogPath), tostring(werr)))
        return false
    end
    session.logBuffer = {}
    return true
end

local function logEvent(session, eventType, payload, flushNow)
    if session == nil then
        return
    end
    if not session.loggerInitialized then
        initSessionLogger(session)
    end
    if (session.eventCount or 0) >= (C.LOG_MAX_EVENTS or 25000) then
        return
    end
    local entry =
    {
        schema_version = C.SCHEMA_VERSION,
        session_id     = session.sessionId,
        event          = tostring(eventType or 'unknown'),
        timestamp_utc  = nowUtcIso(),
        elapsed_sec    = session.elapsedSec or 0,
        stage          = session.stage or 0,
    }
    if type(payload) == 'table' then
        for k, v in pairs(payload) do
            entry[k] = v
        end
    end
    session.eventCount = (session.eventCount or 0) + 1
    session.logBuffer[#session.logBuffer + 1] = C.encodeJson(entry)
    if flushNow or #session.logBuffer >= (C.LOG_FLUSH_BATCH_SIZE or 32) then
        flushEventLog(session)
    end
end

local function writeTelemetryRecord(session, outcome)
    if session == nil or session.telemetryWritten then
        return nil
    end
    if not session.loggerInitialized then
        initSessionLogger(session)
    end
    session.telemetryWritten = true
    session.endedAtUtc = nowUtcIso()

    logEvent(session, 'session_end', {
        outcome        = outcome or session.outcome or 'unknown',
        cleanup_status = session.cleanupStatus or 'completed',
    }, true)

    local record = C.buildTelemetryRecord(session, outcome)
    session.lastTelemetryRecord = record

    ensureDir(session.logDir)
    local jsonLine = C.encodeJson(record)

    local sfh, serr = io.open(session.summaryPath, 'w')
    if sfh then
        local ok, werr = pcall(function()
            sfh:write(jsonLine .. '\n')
            sfh:flush()
        end)
        sfh:close()
        if not ok then
            diagError(string.format('Failed to write summary %s: %s', tostring(session.summaryPath), tostring(werr)))
        end
    else
        diagError(string.format('Failed to open summary %s: %s', tostring(session.summaryPath), tostring(serr)))
    end

    local rfh, rerr = io.open(session.runsIndexPath, 'a')
    if rfh then
        local ok, werr = pcall(function()
            rfh:write(jsonLine .. '\n')
            rfh:flush()
        end)
        rfh:close()
        if not ok then
            diagError(string.format('Failed to write runs index %s: %s', tostring(session.runsIndexPath), tostring(werr)))
        end
    else
        diagError(string.format('Failed to open runs index %s: %s', tostring(session.runsIndexPath), tostring(rerr)))
    end

    return record
end

local function attachPlayerCombatListeners(session, player)
    if session == nil or player == nil or not player.addListener then
        return
    end
    local tag = 'BURROWS_PLOG_' .. tostring(session.runId)
    local pId = player.getID and player:getID() or 0
    local pName = player.getName and player:getName() or 'unknown'

    player:addListener('TAKE_DAMAGE', tag, function(target, amount, attacker, attackType, damageType)
        local dmg = tonumber(amount) or 0
        if session.combatStats then
            session.combatStats.damageReceived = session.combatStats.damageReceived + dmg
        end
        logEvent(session, 'damage_received', {
            target_id     = pId,
            target_name   = pName,
            attacker_name = (attacker and attacker.getName and attacker:getName()) or 'unknown',
            amount        = dmg,
            attack_type   = tonumber(attackType) or 0,
            damage_type   = tonumber(damageType) or 0,
            hp_after      = (target and target.getHP and target:getHP()) or 0,
            max_hp        = (target and target.getMaxHP and target:getMaxHP()) or 0,
        }, false)
    end)

    player:addListener('MAGIC_USE', tag, function(caster, target, spell)
        if session.combatStats then
            session.combatStats.spellsCast = session.combatStats.spellsCast + 1
        end
        logEvent(session, 'spell_cast', {
            actor_id    = pId,
            actor_name  = pName,
            spell_id    = (spell and spell.getID and spell:getID()) or 0,
            target_name = (target and target.getName and target:getName()) or '',
        }, false)
    end)

    player:addListener('ABILITY_USE', tag, function(actor, target, ability)
        if session.combatStats then
            session.combatStats.abilitiesUsed = session.combatStats.abilitiesUsed + 1
        end
        logEvent(session, 'ability_used', {
            actor_id    = pId,
            actor_name  = pName,
            ability_id  = (ability and ability.getID and ability:getID()) or 0,
            target_name = (target and target.getName and target:getName()) or '',
        }, false)
    end)

    player:addListener('DEATH', tag, function(deadChar, killer)
        if session.combatStats then
            session.combatStats.playerDeaths = session.combatStats.playerDeaths + 1
        end
        logEvent(session, 'player_death', {
            char_id     = pId,
            char_name   = pName,
            killer_name = (killer and killer.getName and killer:getName()) or 'unknown',
        }, true)
    end)
end

local function detachPlayerCombatListeners(player, runId)
    if player == nil or not player.removeListener or runId == nil then
        return
    end
    local tag = 'BURROWS_PLOG_' .. tostring(runId)
    pcall(function()
        player:removeListener(tag)
    end)
end

local function tell(player, message)
    if player ~= nil and player.printToPlayer then
        local chan = (xi.msg and xi.msg.channel and xi.msg.channel.SYSTEM_3) or 0
        player:printToPlayer(tostring(message), chan, '')
    end
end

local function broadcast(session, message)
    if session == nil then
        return
    end
    local sent = {}
    if session.instance and session.instance.getChars then
        local ok, chars = pcall(function()
            return session.instance:getChars()
        end)
        if ok and type(chars) == 'table' then
            for _, p in pairs(chars) do
                if p and p.getID and not sent[p:getID()] then
                    sent[p:getID()] = true
                    tell(p, message)
                end
            end
        end
    end
    for _, p in ipairs(session.participants or {}) do
        if p and p.getID and not sent[p:getID()] then
            local ok, inZone = pcall(function()
                return p:getZoneID() == C.INSTANCE_ZONE_ID
            end)
            if ok and inZone then
                sent[p:getID()] = true
                tell(p, message)
            end
        end
    end
end

local function openLater(player, builder)
    if player == nil then
        return
    end
    if player.timer then
        player:timer(50, function(p)
            if p and p.customMenu then
                p:customMenu(builder(p))
            end
        end)
    elseif player.customMenu then
        player:customMenu(builder(player))
    end
end

local function getUnsyncedLevel(player)
    if R and R.getUnsyncedLevel then
        return R.getUnsyncedLevel(player)
    end
    if player and player.getMainLvl then
        return player:getMainLvl() or 0
    end
    return 0
end

local function getActiveSoulKey(player)
    if xi and xi.soulspire and xi.soulspire.spec and xi.soulspire.spec.getActiveSpecKey then
        local ok, key = pcall(xi.soulspire.spec.getActiveSpecKey, player)
        if ok and key then
            return tostring(key)
        end
    end
    return 'none'
end

local function saveReturnCharVars(player, ret)
    if player == nil or not player.setCharVar or ret == nil then
        return
    end
    player:setCharVar('[BurrowsReborn]Active', 1)
    player:setCharVar('[BurrowsReborn]RetZone', math.floor(tonumber(ret.zoneId) or C.FALLBACK_RETURN.zoneId))
    player:setCharVar('[BurrowsReborn]RetX', math.floor((tonumber(ret.x) or 0) * 100))
    player:setCharVar('[BurrowsReborn]RetY', math.floor((tonumber(ret.y) or 0) * 100))
    player:setCharVar('[BurrowsReborn]RetZ', math.floor((tonumber(ret.z) or 0) * 100))
    player:setCharVar('[BurrowsReborn]RetRot', math.floor(tonumber(ret.rotation) or 0))
end

local function readReturnCharVars(player)
    if player ~= nil and player.getCharVar then
        local z = player:getCharVar('[BurrowsReborn]RetZone')
        if z and z > 0 then
            return
            {
                zoneId   = z,
                x        = (player:getCharVar('[BurrowsReborn]RetX') or 0) / 100,
                y        = (player:getCharVar('[BurrowsReborn]RetY') or 0) / 100,
                z        = (player:getCharVar('[BurrowsReborn]RetZ') or 0) / 100,
                rotation = player:getCharVar('[BurrowsReborn]RetRot') or 0,
            }
        end
    end
    return C.getReturnPosForZoneId(C.FALLBACK_RETURN.zoneId)
end

local function clearReturnCharVars(player)
    if player == nil or not player.setCharVar then
        return
    end
    player:setCharVar('[BurrowsReborn]Active', 0)
    player:setCharVar('[BurrowsReborn]RetZone', 0)
    player:setCharVar('[BurrowsReborn]RetX', 0)
    player:setCharVar('[BurrowsReborn]RetY', 0)
    player:setCharVar('[BurrowsReborn]RetZ', 0)
    player:setCharVar('[BurrowsReborn]RetRot', 0)
end

local function isMobAlive(mob)
    if mob == nil then
        return false
    end
    local ok, alive = pcall(function()
        if mob.isAlive and not mob:isAlive() then
            return false
        end
        if mob.getStatus and xi.status and xi.status.DISAPPEAR and mob:getStatus() == xi.status.DISAPPEAR then
            return false
        end
        return true
    end)
    return ok and alive
end

local function applyNoRewardFlags(mob)
    if mob == nil then
        return
    end
    if R and R.applyNoProgressionMobFlags then
        R.applyNoProgressionMobFlags(mob)
    end
    if mob.setLocalVar then
        mob:setLocalVar('[BurrowsReborn]ExpeditionMob', 1)
    end
    if mob.setDropID then
        mob:setDropID(0)
    end
    if mob.setMobMod and xi.mobMod then
        if xi.mobMod.NO_DROPS then
            mob:setMobMod(xi.mobMod.NO_DROPS, 1)
        end
        if xi.mobMod.GIL_MAX then
            mob:setMobMod(xi.mobMod.GIL_MAX, -1)
        end
        if xi.mobMod.EXP_BONUS then
            mob:setMobMod(xi.mobMod.EXP_BONUS, -100)
        end
    end
    if mob.setCallForHelpFlag then
        mob:setCallForHelpFlag(true)
    end
end

local function applyScaledHp(mob, multiplier)
    if mob == nil or multiplier == nil or multiplier <= 0 then
        return
    end
    pcall(function()
        if mob.getMaxHP and mob.setMobMod and xi.mobMod and xi.mobMod.HP_STANDBACK == nil then
            -- noop guard
        end
        if mob.getMaxHP and mob.addMod and xi.mod and xi.mod.HPP then
            local deltaPct = math.floor((multiplier - 1.0) * 100)
            if deltaPct ~= 0 then
                mob:addMod(xi.mod.HPP, deltaPct)
            end
        end
        if mob.updateHealth then
            mob:updateHealth()
        end
        if mob.setHP and mob.getMaxHP then
            mob:setHP(mob:getMaxHP())
        end
    end)
end

local function safeAddMod(entity, modId, amount)
    if entity ~= nil and modId ~= nil and amount ~= 0 and entity.addMod then
        pcall(function()
            entity:addMod(modId, amount)
        end)
    end
end

local function safeDelMod(entity, modId, amount)
    if entity ~= nil and modId ~= nil and amount ~= 0 and entity.delMod then
        pcall(function()
            entity:delMod(modId, amount)
        end)
    end
end

-- Restores a player's original unsynced state cleanly and optionally warps them safely back to hub.
function B.restorePlayerState(player, opts)
    opts = opts or {}
    if player == nil then
        return false
    end

    local charId = player.getID and player:getID() or nil
    local activeRunId = charId and playerRunId[charId] or nil
    local session = activeRunId and sessionsByRunId[activeRunId] or nil
    if activeRunId then
        detachPlayerCombatListeners(player, activeRunId)
    end
    local ret = opts.returnPos
    if ret == nil and session and charId and session.returnPosByCharId then
        ret = session.returnPosByCharId[charId]
    end
    if ret == nil then
        ret = readReturnCharVars(player)
    end

    -- Clear dead state safely before restoring/warping so players never arrive dead in town.
    pcall(function()
        if player.isAlive and not player:isAlive() then
            if player.setStatus and xi.status and xi.status.NORMAL then
                player:setStatus(xi.status.NORMAL)
            end
            if player.setHP and player.getMaxHP then
                player:setHP(math.max(1, player:getMaxHP()))
            end
        end
    end)

    if R and R.applySkillupLock then
        pcall(R.applySkillupLock, player, false)
    end
    if R and R.restoreLevelSync then
        pcall(R.restoreLevelSync, player)
    end

    clearReturnCharVars(player)
    if charId then
        playerRunId[charId] = nil
    end

    if opts.warpToHub and ret and player.setPos then
        pcall(function()
            player:setPos(ret.x, ret.y, ret.z, ret.rotation, ret.zoneId)
        end)
    end

    return true
end

function B.getSessionByInstance(instance)
    if instance == nil or not instance.getLocalVar then
        return nil
    end
    local runId = instance:getLocalVar('[BurrowsReborn]RunId')
    if runId and runId > 0 then
        return sessionsByRunId[runId]
    end
    return nil
end

function B.getSessionForPlayer(player)
    if player == nil or not player.getID then
        return nil
    end
    local runId = playerRunId[player:getID()]
    if runId then
        return sessionsByRunId[runId]
    end
    if player.getInstance then
        local inst = player:getInstance()
        if inst then
            return B.getSessionByInstance(inst)
        end
    end
    return nil
end

function B.getAllActiveSessions()
    return sessionsByRunId
end

function B._resetStateForTests()
    nextRunSeq = 0
    sessionsByRunId = {}
    pendingEntryByLeaderId = {}
    playerRunId = {}
end

local function spawnExpeditionMob(session, encDef, level, hpMult, pos, callbacks)
    callbacks = callbacks or {}
    local instance = session.instance
    if instance == nil or not instance.insertDynamicEntity then
        return nil
    end

    local allowed = encDef.allowedSkills
    local lastTargetId = 0
    local def =
    {
        objtype               = xi.objType and xi.objType.MOB or 2,
        name                  = encDef.entityName,
        packetName            = encDef.packetName,
        groupId               = encDef.groupId,
        groupZoneId           = encDef.groupZoneId,
        minLevel              = level,
        maxLevel              = level,
        x                     = pos.x,
        y                     = pos.y,
        z                     = pos.z,
        rotation              = pos.rotation or 64,
        respawn               = 0,
        releaseIdOnDisappear  = true,
        specialSpawnAnimation = false,
        onMobSpawn = function(m)
            applyNoRewardFlags(m)
            if m.setMobMod and xi.mobMod and xi.mobMod.NO_AGGRO then
                m:setMobMod(xi.mobMod.NO_AGGRO, 1)
            end
            if encDef.spellList and encDef.spellList > 0 then
                if m.setSpellList then
                    m:setSpellList(encDef.spellList)
                end
                if m.setMagicCastingEnabled then
                    m:setMagicCastingEnabled(true)
                end
            else
                if m.setMagicCastingEnabled then
                    m:setMagicCastingEnabled(false)
                end
            end
            if callbacks.onMobSpawn then
                callbacks.onMobSpawn(m)
            end
        end,
        onMobEngage = function(m, target)
            lastTargetId = (target and target.getID and target:getID()) or 0
            logEvent(session, 'mob_engage', {
                mob_id      = (m and m.getID and m:getID()) or 0,
                mob_name    = encDef.packetName,
                target_id   = lastTargetId,
                target_name = (target and target.getName and target:getName()) or '',
            }, true)
            if callbacks.onMobEngage then
                callbacks.onMobEngage(m, target)
            end
        end,
        onMobFight = function(m, target)
            if m.setCallForHelpFlag and m.getCallForHelpFlag and not m:getCallForHelpFlag() then
                m:setCallForHelpFlag(true)
            end
            local curTargetId = (target and target.getID and target:getID()) or 0
            if curTargetId ~= 0 and curTargetId ~= lastTargetId then
                local prevId = lastTargetId
                lastTargetId = curTargetId
                if session.combatStats then
                    session.combatStats.enmityTargetChanges = session.combatStats.enmityTargetChanges + 1
                end
                logEvent(session, 'enmity_target_change', {
                    mob_name       = encDef.packetName,
                    prev_target_id = prevId,
                    new_target_id  = curTargetId,
                    new_target     = (target and target.getName and target:getName()) or '',
                }, false)
            end
            if callbacks.onMobFight then
                callbacks.onMobFight(m, target)
            end
        end,
        onMobDeath = function(deadMob, killer, optParams)
            logEvent(session, 'mob_death', {
                mob_id      = (deadMob and deadMob.getID and deadMob:getID()) or 0,
                mob_name    = encDef.packetName,
                killer_id   = (killer and killer.getID and killer:getID()) or 0,
                killer_name = (killer and killer.getName and killer:getName()) or '',
            }, true)
            if callbacks.onMobDeath then
                callbacks.onMobDeath(deadMob, killer, optParams)
            end
        end,
    }

    if encDef.spellList and encDef.spellList > 0 then
        def.spellList = encDef.spellList
    end

    if type(allowed) == 'table' and #allowed > 0 then
        def.onMobMobskillChoose = function(m, target, skillId)
            local idx = ((m.getLocalVar and m:getLocalVar('[BurrowsReborn]SkillIdx') or 0) % #allowed) + 1
            if m.setLocalVar then
                m:setLocalVar('[BurrowsReborn]SkillIdx', idx)
            end
            return allowed[idx]
        end
    end

    local mob = instance:insertDynamicEntity(def)
    if not mob then
        return nil
    end

    applyNoRewardFlags(mob)
    if mob.setSpawn then
        mob:setSpawn(pos.x, pos.y, pos.z, pos.rotation or 64)
    end
    if mob.spawn then
        mob:spawn()
    end
    if mob.getMainLvl and mob:getMainLvl() ~= level and mob.setMobLevel then
        mob:setMobLevel(level)
    end

    if xi.customBossServer and xi.customBossServer.applyMobScaling then
        if not mob.getLocalVar or mob:getLocalVar('[CustomBoss]Applied') ~= 1 then
            pcall(xi.customBossServer.applyMobScaling, mob)
        end
    end

    applyScaledHp(mob, hpMult)
    applyNoRewardFlags(mob)

    if mob.setMobMod and xi.mobMod and xi.mobMod.NO_AGGRO then
        mob:setMobMod(xi.mobMod.NO_AGGRO, 1)
    end

    if mob.addListener then
        local mTag = 'BURROWS_MLOG_' .. tostring(session.runId) .. '_' .. tostring(encDef.id)
        mob:addListener('TAKE_DAMAGE', mTag, function(m, amount, attacker, attackType, damageType)
            local dmg = tonumber(amount) or 0
            if session.combatStats then
                session.combatStats.damageDealt = session.combatStats.damageDealt + dmg
            end
            logEvent(session, 'damage_dealt', {
                actor_id    = (attacker and attacker.getID and attacker:getID()) or 0,
                actor_name  = (attacker and attacker.getName and attacker:getName()) or 'unknown',
                target_name = encDef.packetName,
                amount      = dmg,
                attack_type = tonumber(attackType) or 0,
                damage_type = tonumber(damageType) or 0,
                mob_hpp     = (m and m.getHPP and m:getHPP()) or 0,
            }, false)
        end)
        mob:addListener('WEAPONSKILL_TAKE', mTag, function(m, user, wsid)
            if session.combatStats then
                session.combatStats.weaponskills = session.combatStats.weaponskills + 1
            end
            logEvent(session, 'weaponskill_used', {
                actor_id    = (user and user.getID and user:getID()) or 0,
                actor_name  = (user and user.getName and user:getName()) or 'unknown',
                target_name = encDef.packetName,
                ws_id       = tonumber(wsid) or 0,
            }, false)
        end)
        mob:addListener('MAGIC_TAKE', mTag, function(m, caster, spell)
            logEvent(session, 'spell_hit', {
                actor_id    = (caster and caster.getID and caster:getID()) or 0,
                actor_name  = (caster and caster.getName and caster:getName()) or 'unknown',
                target_name = encDef.packetName,
                spell_id    = (spell and spell.getID and spell:getID()) or 0,
            }, false)
        end)
    end

    logEvent(session, 'mob_spawn', {
        mob_id   = (mob.getID and mob:getID()) or 0,
        mob_name = encDef.packetName,
        level    = level,
        max_hp   = (mob.getMaxHP and mob:getMaxHP()) or 0,
    }, true)

    session.activeMobs[#session.activeMobs + 1] = mob
    return mob
end

-----------------------------------
-- Stage 3: Grudgeburrow (Final Boss)
-----------------------------------
local function clearBossExposedWindow(session)
    local b = session.bossState
    if not b or not b.exposedActive or not isMobAlive(b.mob) then
        return
    end
    b.exposedActive = false
    local bonusDt = (session.bossAdaptations and session.bossAdaptations.exposedBonusDtPct or 30) * 100
    safeDelMod(b.mob, xi.mod and xi.mod.DMGPHYS, bonusDt)
    safeDelMod(b.mob, xi.mod and xi.mod.DMGMAGIC, 2500)
    safeDelMod(b.mob, xi.mod and xi.mod.DEFP, -25)
    logEvent(session, 'boss_exposed_end', { mob_name = C.ENCOUNTERS.grudgeburrow.packetName }, false)
    broadcast(session, 'Grudgeburrow recovers its footing.')
end

local function startBossExposedWindow(session)
    local b = session.bossState
    if not b or not isMobAlive(b.mob) then
        return
    end
    local cfg = session.mode.grudgeburrow
    local bonusDt = (session.bossAdaptations and session.bossAdaptations.exposedBonusDtPct or 30) * 100
    b.exposedActive = true
    b.exposedRemaining = cfg.exposedDurationSec
    safeAddMod(b.mob, xi.mod and xi.mod.DMGPHYS, bonusDt)
    safeAddMod(b.mob, xi.mod and xi.mod.DMGMAGIC, 2500)
    safeAddMod(b.mob, xi.mod and xi.mod.DEFP, -25)
    logEvent(session, 'boss_exposed_start', {
        mob_name     = C.ENCOUNTERS.grudgeburrow.packetName,
        duration_sec = cfg.exposedDurationSec,
        bonus_dt_pct = math.floor(bonusDt / 100),
    }, false)
    broadcast(session, 'Grudgeburrow\'s shell fractures, leaving it vulnerable!')
end

local function computeMitigatedHeavyDamage(target, rawDmg)
    local dmg = rawDmg
    if target ~= nil and target.hasStatusEffect and xi.effect then
        -- Reward active tanking / mitigation cooldowns cleanly.
        if xi.effect.COPY_IMAGE and target:hasStatusEffect(xi.effect.COPY_IMAGE) then
            dmg = math.floor(dmg * 0.50)
        end
        if (xi.effect.DEFENDER and target:hasStatusEffect(xi.effect.DEFENDER))
            or (xi.effect.SENTINEL and target:hasStatusEffect(xi.effect.SENTINEL))
            or (xi.effect.RAMPART and target:hasStatusEffect(xi.effect.RAMPART))
            or (xi.effect.PALISADE and target:hasStatusEffect(xi.effect.PALISADE))
            or (xi.effect.PHALANX and target:hasStatusEffect(xi.effect.PHALANX))
        then
            dmg = math.floor(dmg * 0.65)
        end
    end
    if target ~= nil and target.getMaxHP then
        local cap = math.floor((target:getMaxHP() or 200) * 0.70)
        dmg = math.min(dmg, math.max(15, cap))
    end
    return math.max(10, dmg)
end

local function resolveBossHeavySlam(session)
    local b = session.bossState
    if not b or not isMobAlive(b.mob) then
        return
    end
    local cfg = session.mode.grudgeburrow
    local adapt = session.bossAdaptations
    local target = (b.mob.getTarget and b.mob:getTarget()) or nil
    if target == nil then
        for _, p in ipairs(session.participants or {}) do
            if p and p.isAlive and p:isAlive() and p.getZoneID and p:getZoneID() == C.INSTANCE_ZONE_ID then
                target = p
                break
            end
        end
    end
    if target ~= nil and (not target.isAlive or target:isAlive()) then
        local rawDmg = math.floor(cfg.heavyBaseDmg * (adapt.heavyDmgMult or 1.0))
        local finalDmg = computeMitigatedHeavyDamage(target, rawDmg)
        pcall(function()
            if target.takeDamage then
                target:takeDamage(finalDmg, b.mob, xi.attackType and xi.attackType.PHYSICAL or 1, xi.damageType and xi.damageType.BLUNT or 3)
            end
        end)
        local tName = (target.getName and target:getName()) or 'its target'
        logEvent(session, 'boss_mechanic_resolve', {
            mechanic    = 'crushing_mandibles',
            target_name = tName,
            damage      = finalDmg,
        }, false)
        broadcast(session, string.format('Grudgeburrow strikes %s with Crushing Mandibles!', tName))
    end
    b.heavySlamsResolved = (b.heavySlamsResolved or 0) + 1
    startBossExposedWindow(session)
end

local function resolveBossAoeTremor(session)
    local b = session.bossState
    if not b or not isMobAlive(b.mob) then
        return
    end
    local cfg = session.mode.grudgeburrow
    local adapt = session.bossAdaptations
    local baseDmg = math.floor(cfg.aoeBaseDmg * (adapt.aoeDmgMult or 1.0))
    local hitCount = 0

    local targets = {}
    if session.instance and session.instance.getChars then
        local ok, chars = pcall(function()
            return session.instance:getChars()
        end)
        if ok and type(chars) == 'table' then
            for _, p in pairs(chars) do
                targets[#targets + 1] = p
            end
        end
    else
        for _, p in ipairs(session.participants or {}) do
            targets[#targets + 1] = p
        end
    end

    for _, p in ipairs(targets) do
        if p and (not p.isAlive or p:isAlive()) then
            local cap = p.getMaxHP and math.floor((p:getMaxHP() or 200) * 0.45) or baseDmg
            local dmg = math.max(8, math.min(baseDmg, cap))
            pcall(function()
                if p.takeDamage then
                    p:takeDamage(dmg, b.mob, xi.attackType and xi.attackType.MAGICAL or 2, xi.damageType and xi.damageType.EARTH or 8)
                end
                if adapt.tremorAppliesDebuff and p.addStatusEffect and xi.effect and xi.effect.DEFENSE_DOWN then
                    p:addStatusEffect(xi.effect.DEFENSE_DOWN, 15, 0, 10)
                end
            end)
            hitCount = hitCount + 1
        end
    end

    b.aoeTremorsResolved = (b.aoeTremorsResolved or 0) + 1
    logEvent(session, 'boss_mechanic_resolve', {
        mechanic       = 'burrowing_tremor',
        targets_hit    = hitCount,
        debuff_applied = adapt.tremorAppliesDebuff == true,
    }, false)
    broadcast(session, 'Grudgeburrow unleashes Burrowing Tremor!')
end

-- Dynamically recalculates and applies Grudgeburrow's exact adaptation modifiers
-- in real time as hidden-unlock encounters (Burrow Shaman / Stoneguard) resolve.
local function syncBossAdaptationMods(session)
    if session == nil then
        return
    end
    local adapt = C.computeBossAdaptations(session)
    session.bossAdaptations = adapt

    local b = session.bossState
    if not b or not isMobAlive(b.mob) then
        return
    end

    local targetAttp   = adapt.attackBonusPct
    local targetDefp   = adapt.defDeltaPct
    local targetPhysDt = adapt.physDtDeltaPct * 100

    local dAttp   = targetAttp - (b.appliedAttp or 0)
    local dDefp   = targetDefp - (b.appliedDefp or 0)
    local dPhysDt = targetPhysDt - (b.appliedPhysDt or 0)

    if dAttp ~= 0 then
        safeAddMod(b.mob, xi.mod and xi.mod.ATTP, dAttp)
        b.appliedAttp = targetAttp
    end
    if dDefp ~= 0 then
        safeAddMod(b.mob, xi.mod and xi.mod.DEFP, dDefp)
        b.appliedDefp = targetDefp
    end
    if dPhysDt ~= 0 then
        safeAddMod(b.mob, xi.mod and xi.mod.DMGPHYS, dPhysDt)
        b.appliedPhysDt = targetPhysDt
    end

    local cfg = session.mode.grudgeburrow
    b.heavyCadence = math.max(12, cfg.heavyIntervalSec + adapt.heavyIntervalDeltaSec)
    b.aoeCadence   = math.max(16, cfg.aoeIntervalSec + adapt.aoeIntervalDeltaSec)
    if not b.engaged then
        b.nextHeavyAt = b.heavyCadence - cfg.heavyTelegraphSec
        b.nextAoeAt   = b.aoeCadence - cfg.aoeWarningSec
    end
end

local function spawnStage3Boss(session)
    if session.bossState ~= nil or session.finished then
        return
    end
    session.bossAdaptations = C.computeBossAdaptations(session)

    local cfg = session.mode.grudgeburrow
    local adapt = session.bossAdaptations
    local heavyCadence = math.max(12, cfg.heavyIntervalSec + adapt.heavyIntervalDeltaSec)
    local aoeCadence = math.max(16, cfg.aoeIntervalSec + adapt.aoeIntervalDeltaSec)

    session.bossState =
    {
        mob                = nil,
        engaged            = false,
        combatSec          = 0,
        nextHeavyAt        = heavyCadence - cfg.heavyTelegraphSec,
        heavyTelegraphLeft = 0,
        heavyCadence       = heavyCadence,
        nextAoeAt          = aoeCadence - cfg.aoeWarningSec,
        aoeWarningLeft     = 0,
        aoeCadence         = aoeCadence,
        exposedActive      = false,
        exposedRemaining   = 0,
        heavySlamsResolved = 0,
        aoeTremorsResolved = 0,
        appliedAttp        = 0,
        appliedDefp        = 0,
        appliedPhysDt      = 0,
    }

    local mob = spawnExpeditionMob(session, C.ENCOUNTERS.grudgeburrow, cfg.level, cfg.hpMultiplier, C.ARENA_POS.grudgeburrow, {
        onMobEngage = function()
            if session.bossState then
                session.bossState.engaged = true
            end
        end,
        onMobDeath = function()
            clearBossExposedWindow(session)
            if not session.finished then
                session.finished = true
                session.outcome = 'victory'
                session.exitCountdown = C.VICTORY_EXIT_SEC
                writeTelemetryRecord(session, 'victory')
                broadcast(session, 'Grudgeburrow has been defeated! Returning to town shortly...')
                if session.instance and session.instance.complete then
                    pcall(function()
                        session.instance:complete()
                    end)
                end
            end
        end,
    })

    if mob then
        session.bossState.mob = mob
        syncBossAdaptationMods(session)
    end
end

local function tickStage3Boss(session)
    local b = session.bossState
    if not b or not isMobAlive(b.mob) then
        return
    end
    if not b.engaged then
        if b.mob.getTarget and b.mob:getTarget() ~= nil then
            b.engaged = true
        else
            return
        end
    end

    b.combatSec = b.combatSec + 1

    if (b.phase or 1) == 1 and b.mob.getHPP then
        local hpp = b.mob:getHPP() or 100
        if hpp <= 50 then
            b.phase = 2
            b.heavyCadence = math.max(10, (b.heavyCadence or 16) - 2)
            b.aoeCadence = math.max(14, (b.aoeCadence or 20) - 2)
            logEvent(session, 'boss_phase_change', {
                phase         = 2,
                hpp           = hpp,
                heavy_cadence = b.heavyCadence,
                aoe_cadence   = b.aoeCadence,
            }, true)
            broadcast(session, 'Grudgeburrow lets out a furious roar!')
        end
    end

    if b.exposedActive then
        b.exposedRemaining = b.exposedRemaining - 1
        if b.exposedRemaining <= 0 then
            clearBossExposedWindow(session)
        end
    end

    -- Telegraphed Heavy Attack cycle
    if b.heavyTelegraphLeft > 0 then
        b.heavyTelegraphLeft = b.heavyTelegraphLeft - 1
        if b.heavyTelegraphLeft <= 0 then
            resolveBossHeavySlam(session)
            b.nextHeavyAt = b.combatSec + b.heavyCadence - session.mode.grudgeburrow.heavyTelegraphSec
        end
    elseif b.combatSec >= b.nextHeavyAt then
        b.heavyTelegraphLeft = session.mode.grudgeburrow.heavyTelegraphSec
        local t = b.mob.getTarget and b.mob:getTarget() or nil
        local tName = (t and t.getName and t:getName()) or 'the front line'
        logEvent(session, 'boss_mechanic_telegraph', {
            mechanic    = 'crushing_mandibles',
            target_name = tName,
        }, false)
        broadcast(session, 'Grudgeburrow draws back for Crushing Mandibles!')
    end

    -- Manageable Area Damage cycle
    if b.aoeWarningLeft > 0 then
        b.aoeWarningLeft = b.aoeWarningLeft - 1
        if b.aoeWarningLeft <= 0 then
            resolveBossAoeTremor(session)
            b.nextAoeAt = b.combatSec + b.aoeCadence - session.mode.grudgeburrow.aoeWarningSec
        end
    elseif b.combatSec >= b.nextAoeAt then
        b.aoeWarningLeft = session.mode.grudgeburrow.aoeWarningSec
        logEvent(session, 'boss_mechanic_telegraph', {
            mechanic = 'burrowing_tremor',
        }, false)
        broadcast(session, 'Grudgeburrow gathers earthen force...')
    end
end

-----------------------------------
-- Stage 2: The Stoneguard (Defensive Stance & Armor Break)
-----------------------------------
local function endStoneguardExposed(session)
    local sg = session.stoneguardState
    if not sg or not sg.exposedActive or not isMobAlive(sg.mob) then
        return
    end
    sg.exposedActive = false
    safeDelMod(sg.mob, xi.mod and xi.mod.DMGPHYS, 3500)
    safeDelMod(sg.mob, xi.mod and xi.mod.DMGMAGIC, 2500)
    safeDelMod(sg.mob, xi.mod and xi.mod.DEFP, -35)
    broadcast(session, 'The Stoneguard steadies its shield — Guard Broken window ended.')
end

local function enterStoneguardExposed(session, brokenEarly)
    local sg = session.stoneguardState
    if not sg or not isMobAlive(sg.mob) then
        return
    end
    if sg.stanceActive then
        sg.stanceActive = false
        safeDelMod(sg.mob, xi.mod and xi.mod.DMGPHYS, -6500)
        safeDelMod(sg.mob, xi.mod and xi.mod.MDEF, 20)
    end
    if brokenEarly then
        session.stoneguardCleanBreak = true
        syncBossAdaptationMods(session)
    end
    local dur = session.mode.stoneguard.exposedDurationSec
    sg.exposedActive = true
    sg.exposedRemaining = dur
    safeAddMod(sg.mob, xi.mod and xi.mod.DMGPHYS, 3500)
    safeAddMod(sg.mob, xi.mod and xi.mod.DMGMAGIC, 2500)
    safeAddMod(sg.mob, xi.mod and xi.mod.DEFP, -35)
    if brokenEarly then
        broadcast(session, string.format(
            'IRON SHELL SHATTERED! The Stoneguard is EXPOSED for %ds!',
            dur
        ))
    else
        broadcast(session, string.format(
            'The Stoneguard drops Iron Shell and lowers its guard — EXPOSED for %ds!',
            dur
        ))
    end
end

local function enterStoneguardStance(session)
    local sg = session.stoneguardState
    if not sg or not isMobAlive(sg.mob) then
        return
    end
    local cfg = session.mode.stoneguard
    sg.stanceActive = true
    sg.stanceRemaining = cfg.stanceDurationSec
    sg.magicDamageInStance = 0
    safeAddMod(sg.mob, xi.mod and xi.mod.DMGPHYS, -6500)
    safeAddMod(sg.mob, xi.mod and xi.mod.MDEF, 20)
    if sg.mob.useMobAbility then
        pcall(function()
            sg.mob:useMobAbility(C.ENCOUNTERS.stoneguard.stanceSkillId)
        end)
    end
    broadcast(session, string.format(
        'The Stoneguard retreats into IRON SHELL STANCE (%ds)! Melee strikes rebound off its carapace — hold TP or break it with magic!',
        cfg.stanceDurationSec
    ))
end

local function spawnStage2Stoneguard(session)
    if session.stoneguardState ~= nil or session.finished then
        return
    end

    local cfg = session.mode.stoneguard
    session.stoneguardState =
    {
        mob                 = nil,
        engaged             = false,
        combatSec           = 0,
        nextStanceAt        = 10,
        stanceActive        = false,
        stanceRemaining     = 0,
        exposedActive       = false,
        exposedRemaining    = 0,
        magicDamageInStance = 0,
    }

    local mob = spawnExpeditionMob(session, C.ENCOUNTERS.stoneguard, cfg.level, cfg.hpMultiplier, C.ARENA_POS.stoneguard, {
        onMobEngage = function()
            if session.stoneguardState then
                session.stoneguardState.engaged = true
            end
        end,
        onMobDeath = function()
            session.stoneguardDefeated = true
            if session.stoneguardState then
                session.stoneguardState.stanceActive = false
                session.stoneguardState.exposedActive = false
            end
            syncBossAdaptationMods(session)
            broadcast(session, 'The Stoneguard crumbles. Cracks spiderweb across the cavern floor as a distant weight gives way.')
        end,
    })

    if mob then
        session.stoneguardState.mob = mob
        if mob.addListener then
            mob:addListener('TAKE_DAMAGE', 'BURROWS_SG_DMG_' .. tostring(session.runId), function(m, amount, attacker, attackType, damageType)
                local sg = session.stoneguardState
                if not sg or not sg.stanceActive then
                    return
                end
                local isMagic = (xi.attackType and attackType == xi.attackType.MAGICAL)
                if isMagic then
                    sg.magicDamageInStance = sg.magicDamageInStance + (tonumber(amount) or 0)
                    if sg.magicDamageInStance >= cfg.magicBreakThreshold then
                        enterStoneguardExposed(session, true)
                    end
                elseif attacker ~= nil and attacker.takeDamage and (not attacker.isAlive or attacker:isAlive()) then
                    local cap = attacker.getMaxHP and math.floor((attacker:getMaxHP() or 150) * 0.15) or cfg.retaliationDmg
                    local spike = math.max(4, math.min(cfg.retaliationDmg, cap))
                    pcall(function()
                        attacker:takeDamage(spike, m, xi.attackType and xi.attackType.PHYSICAL or 1, xi.damageType and xi.damageType.PIERCING or 2)
                    end)
                end
            end)
        end
    end
end

local function tickStage2Stoneguard(session)
    local sg = session.stoneguardState
    if not sg or not isMobAlive(sg.mob) then
        return
    end
    if not sg.engaged then
        if sg.mob.getTarget and sg.mob:getTarget() ~= nil then
            sg.engaged = true
        else
            return
        end
    end

    sg.combatSec = sg.combatSec + 1

    if sg.stanceActive then
        -- Defense Down also shatters Iron Shell early.
        local hasDefDown = sg.mob.hasStatusEffect and xi.effect and xi.effect.DEFENSE_DOWN and sg.mob:hasStatusEffect(xi.effect.DEFENSE_DOWN)
        if hasDefDown then
            enterStoneguardExposed(session, true)
            sg.nextStanceAt = sg.combatSec + session.mode.stoneguard.stanceIntervalSec
            return
        end
        sg.stanceRemaining = sg.stanceRemaining - 1
        if sg.stanceRemaining <= 0 then
            enterStoneguardExposed(session, false)
            sg.nextStanceAt = sg.combatSec + session.mode.stoneguard.stanceIntervalSec
        end
    elseif sg.exposedActive then
        sg.exposedRemaining = sg.exposedRemaining - 1
        if sg.exposedRemaining <= 0 then
            endStoneguardExposed(session)
        end
    elseif sg.combatSec >= sg.nextStanceAt then
        enterStoneguardStance(session)
    end
end

-----------------------------------
-- Hidden Unlock: The Burrow Shaman (Ritual Caster)
-----------------------------------
local function breakShamanRitual(session, reason)
    local sh = session.shamanState
    if not sh or sh.ritualState ~= 'channeling' then
        return
    end
    sh.ritualState = 'broken'
    session.shamanRitualBroken = true
    if session.combatStats then
        session.combatStats.interrupts = session.combatStats.interrupts + 1
    end
    syncBossAdaptationMods(session)
    logEvent(session, 'shaman_ritual_interrupted', { reason = tostring(reason or 'disrupted') }, true)
    broadcast(session, 'The incantation fades.')
end

local function completeShamanRitual(session)
    local sh = session.shamanState
    if not sh or sh.ritualState ~= 'channeling' then
        return
    end
    sh.ritualState = 'completed'
    session.shamanRitualBroken = false
    syncBossAdaptationMods(session)
    logEvent(session, 'shaman_ritual_completed', { outcome = 'completed' }, true)
    broadcast(session, 'A dark pulse ripples through the cavern.')
end

local function checkStage1Complete(session)
    local sh = session.shamanState
    if not sh or sh.cleared then
        return
    end
    if isMobAlive(sh.mob) or isMobAlive(sh.acolyte) then
        return
    end
    sh.cleared = true
    if sh.ritualState ~= 'completed' then
        session.shamanRitualBroken = true
        syncBossAdaptationMods(session)
    end
end

local function spawnStage1Shaman(session)
    if session.shamanState ~= nil or session.finished then
        return
    end
    local cfg = session.mode.shaman
    session.shamanState =
    {
        mob                = nil,
        acolyte            = nil,
        engaged            = false,
        combatSec          = 0,
        ritualState        = 'pending', -- pending -> channeling -> broken | completed
        ritualRemaining    = cfg.ritualDurationSec,
        ritualStartHpp     = 100,
        cleared            = false,
    }

    local shaman = spawnExpeditionMob(session, C.ENCOUNTERS.shaman, cfg.level, cfg.hpMultiplier, C.ARENA_POS.shaman, {
        onMobSpawn = function(m)
            if m.setMobMod and xi.mobMod and xi.mobMod.MAGIC_COOL then
                m:setMobMod(xi.mobMod.MAGIC_COOL, cfg.magicCoolSec)
            end
        end,
        onMobEngage = function()
            if session.shamanState then
                session.shamanState.engaged = true
            end
        end,
        onMobDeath = function()
            if session.shamanState and session.shamanState.ritualState == 'channeling' then
                breakShamanRitual(session, 'Shaman defeated')
            elseif session.shamanState and session.shamanState.ritualState == 'pending' then
                session.shamanState.ritualState = 'broken'
                session.shamanRitualBroken = true
                syncBossAdaptationMods(session)
                broadcast(session, 'The Burrow Shaman falls silent — a resonant hum fades somewhere deeper in the cavern.')
            end
            checkStage1Complete(session)
        end,
    })

    if shaman then
        session.shamanState.mob = shaman
        if shaman.addListener then
            shaman:addListener('WEAPONSKILL_TAKE', 'BURROWS_SHAMAN_WS_' .. tostring(session.runId), function()
                if session.shamanState and session.shamanState.ritualState == 'channeling' then
                    breakShamanRitual(session, 'Weapon Skill interrupt')
                end
            end)
            shaman:addListener('TAKE_DAMAGE', 'BURROWS_SHAMAN_DMG_' .. tostring(session.runId), function(m)
                local sh = session.shamanState
                if sh and sh.ritualState == 'channeling' and m.getHPP then
                    local lost = sh.ritualStartHpp - (m:getHPP() or 0)
                    if lost >= cfg.ritualBreakHpPct then
                        breakShamanRitual(session, 'Heavy burst damage')
                    end
                end
            end)
        end
    end

    if cfg.spawnAcolyte then
        local acolyte = spawnExpeditionMob(session, C.ENCOUNTERS.acolyte, cfg.acolyteLevel, cfg.acolyteHpMultiplier, C.ARENA_POS.acolyte, {
            onMobDeath = function()
                checkStage1Complete(session)
            end,
        })
        session.shamanState.acolyte = acolyte
    end
end

local function tickStage1Shaman(session)
    local sh = session.shamanState
    if not sh or sh.cleared or not isMobAlive(sh.mob) then
        return
    end
    if not sh.engaged then
        if sh.mob.getTarget and sh.mob:getTarget() ~= nil then
            sh.engaged = true
        else
            return
        end
    end

    sh.combatSec = sh.combatSec + 1
    local cfg = session.mode.shaman

    if sh.ritualState == 'pending' and sh.combatSec >= cfg.ritualStartDelaySec then
        sh.ritualState = 'channeling'
        sh.ritualRemaining = cfg.ritualDurationSec
        sh.ritualStartHpp = (sh.mob.getHPP and sh.mob:getHPP()) or 100
        logEvent(session, 'shaman_ritual_start', {
            duration_sec = cfg.ritualDurationSec,
            start_hpp    = sh.ritualStartHpp,
        }, true)
        broadcast(session, 'The Burrow Shaman begins an ominous incantation...')
    elseif sh.ritualState == 'channeling' then
        -- Check Stun or Silence status effects for reliable FFXI spell/ability interruption.
        local stunned = sh.mob.hasStatusEffect and xi.effect and xi.effect.STUN and sh.mob:hasStatusEffect(xi.effect.STUN)
        local silenced = sh.mob.hasStatusEffect and xi.effect and xi.effect.SILENCE and sh.mob:hasStatusEffect(xi.effect.SILENCE)
        if stunned then
            breakShamanRitual(session, 'Stun')
            return
        elseif silenced then
            breakShamanRitual(session, 'Silence')
            return
        end

        sh.ritualRemaining = sh.ritualRemaining - 1
        if sh.ritualRemaining <= 0 then
            completeShamanRitual(session)
        end
    end
end

-----------------------------------
-- In-Instance Guide NPC Menu
-----------------------------------
local function buildInInstanceGuideMenu(player, session)
    local modeLabel = session and session.mode and session.mode.shortLabel or 'Expedition'
    return
    {
        title = string.format('Burrows (%s)', modeLabel),
        options =
        {
            {
                'Time Remaining',
                function(p)
                    if not session then
                        tell(p, 'No active expedition found.')
                        return
                    end
                    local rem = math.max(0, C.TIME_LIMIT_SEC - (session.elapsedSec or 0))
                    tell(p, string.format('Time remaining: %dm %02ds.', math.floor(rem / 60), rem % 60))
                end,
            },
            {
                'Exit Expedition Safely',
                function(p)
                    local exitingId = p and p.getID and p:getID() or 0
                    tell(p, 'Returning you safely to town.')
                    if session then
                        logEvent(session, 'player_manual_exit', {
                            char_id   = exitingId,
                            char_name = (p and p.getName and p:getName()) or '',
                        }, true)
                    end
                    B.restorePlayerState(p, { warpToHub = true })
                    if session and not session.finished then
                        local remaining = 0
                        if session.instance and session.instance.getChars then
                            local ok, chars = pcall(function() return session.instance:getChars() end)
                            if ok and type(chars) == 'table' then
                                for _, c in pairs(chars) do
                                    if c and c.getID and c:getID() ~= exitingId then
                                        remaining = remaining + 1
                                    end
                                end
                            end
                        end
                        if remaining == 0 then
                            session.finished = true
                            session.outcome = 'abandoned'
                            B.concludeSession(session, 'abandoned')
                        end
                    end
                end,
            },
            {
                'Close',
                function() end,
            },
        },
    }
end

local tickSession

local function spawnInInstanceGuide(session)
    if session.instance == nil or not session.instance.insertDynamicEntity then
        return
    end
    local pos = C.ARENA_POS.guideNpc
    local guide = session.instance:insertDynamicEntity({
        objtype    = xi.objType and xi.objType.NPC or 4,
        name       = 'Burrows_Exit_Guide',
        packetName = C.NPC_PACKET_NAME,
        look       = C.NPC_LOOK_ID,
        x          = pos.x,
        y          = pos.y,
        z          = pos.z,
        rotation   = pos.rotation,
        widescan   = 1,
        onTrigger  = function(player)
            player:customMenu(buildInInstanceGuideMenu(player, session))
        end,
    })
    session.guideNpc = guide

    if guide ~= nil and guide.timer ~= nil then
        local function scheduleHeartbeat()
            if sessionsByRunId[session.runId] ~= session then
                return
            end
            guide:timer(1000, function()
                if sessionsByRunId[session.runId] ~= session then
                    return
                end
                session.lastTimerTickAt = os.time()
                if tickSession then
                    tickSession(session, nil)
                end
                if sessionsByRunId[session.runId] == session then
                    scheduleHeartbeat()
                end
            end)
        end
        scheduleHeartbeat()
    end
end

-----------------------------------
-- Instance Teardown & Safe Return
-----------------------------------
function B.concludeSession(session, outcome)
    if session == nil then
        return
    end
    if not session.telemetryWritten then
        writeTelemetryRecord(session, outcome or session.outcome or 'ended')
    end

    local restoredIds = {}
    if session.instance and session.instance.getChars then
        local ok, chars = pcall(function()
            return session.instance:getChars()
        end)
        if ok and type(chars) == 'table' then
            for _, p in pairs(chars) do
                if p and p.getID then
                    restoredIds[p:getID()] = true
                    B.restorePlayerState(p, { warpToHub = true })
                end
            end
        end
    end

    for _, p in ipairs(session.participants or {}) do
        if p and p.getID and not restoredIds[p:getID()] then
            local ok, inInst = pcall(function()
                return p:getZoneID() == C.INSTANCE_ZONE_ID
            end)
            if ok and inInst then
                B.restorePlayerState(p, { warpToHub = true })
            else
                -- Player already left or disconnected; clear tracking cleanly.
                playerRunId[p:getID()] = nil
            end
        end
    end

    sessionsByRunId[session.runId] = nil
end

-----------------------------------
-- Hub NPC Entry Flow & Native Menus
-----------------------------------
function B.requestEntry(requester, modeKey)
    if requester == nil or not requester.getID then
        return false, 'invalid_requester'
    end

    local leaderId = requester:getID()
    if pendingEntryByLeaderId[leaderId] ~= nil then
        tell(requester, 'Your expedition entry is already being prepared. Please wait a moment.')
        return false, 'entry_in_progress'
    end

    local party = (requester.getParty and requester:getParty()) or { requester }
    local check = C.validatePartyEligibility(requester, party, modeKey, getUnsyncedLevel)
    if not check.ok then
        tell(requester, check.reason)
        return false, check.code
    end

    local hubZoneId = requester.getZoneID and requester:getZoneID() or C.FALLBACK_RETURN.zoneId
    local returnPos = C.getReturnPosForZoneId(hubZoneId)

    pendingEntryByLeaderId[leaderId] =
    {
        leaderId    = leaderId,
        modeKey     = modeKey,
        mode        = check.mode,
        members     = check.members,
        hubZoneId   = hubZoneId,
        returnPos   = returnPos,
        requestedAt = os.time(),
    }

    tell(requester, string.format('Preparing your descent into The First Descent (%s)...', check.mode.shortLabel))

    if requester.createInstance then
        requester:createInstance(C.INSTANCE_ID)
    else
        pendingEntryByLeaderId[leaderId] = nil
        tell(requester, 'Instance service is currently unavailable.')
        return false, 'instance_unavailable'
    end

    return true, nil
end

function B.buildHubMenu(player)
    return
    {
        title = 'SoulspireXI: First Descent',
        options =
        {
            {
                'Enter: Low Man (1-3)',
                function(p)
                    B.requestEntry(p, 'low_man')
                end,
            },
            {
                'Enter: Full Party (4-6)',
                function(p)
                    B.requestEntry(p, 'full_party')
                end,
            },
            {
                'What are the Burrows?',
                function(p)
                    tell(p, 'Our researchers uncovered strange tremors beneath the Burrows. All adventurers are synchronized to Level 10 while inside, and your full strength returns the moment you leave.')
                    tell(p, 'Low Man (1-3 players) is tuned for solo or small groups. Full Party (4-6 players) brings heavier threats that reward coordinated tanking, healing, and interrupts.')
                    tell(p, 'Grudgeburrow waits at the heart of the cavern. Other denizens lurk along the chamber flanks — observant parties may decide whether to challenge the boss directly or explore first.')
                    openLater(p, B.buildHubMenu)
                end,
            },
            {
                'Leave',
                function() end,
            },
        },
    }
end

-----------------------------------
-- LandSandBoat CInstance Callbacks (Delegated by the_first_descent.lua)
-----------------------------------
function I.onInstanceCreated(instance)
    if instance == nil then
        return
    end
    nextRunSeq = nextRunSeq + 1
    local runId = nextRunSeq
    if instance.setLocalVar then
        instance:setLocalVar('[BurrowsReborn]RunId', runId)
    end
    if instance.setTimeLimit then
        instance:setTimeLimit(C.TIME_LIMIT_SEC)
    end

    sessionsByRunId[runId] =
    {
        runId                = runId,
        instance             = instance,
        modeKey              = 'low_man',
        mode                 = C.MODES.low_man,
        participants         = {},
        participantIds       = {},
        participantRecords   = {},
        participantSouls     = {},
        initialPartySize     = 0,
        returnPosByCharId    = {},
        activeMobs           = {},
        stage                = 0,
        elapsedSec           = 0,
        emptySec             = 0,
        wipeSec              = 0,
        exitCountdown        = 0,
        finished             = false,
        outcome              = nil,
        telemetryWritten     = false,
        shamanRitualBroken   = false,
        stoneguardDefeated   = false,
        stoneguardCleanBreak = false,
        bossAdaptations      = nil,
        initialized          = false,
    }
end

function I.onInstanceCreatedCallback(requester, instance)
    if requester == nil or instance == nil then
        return
    end

    local leaderId = requester:getID()
    local pending = pendingEntryByLeaderId[leaderId]
    pendingEntryByLeaderId[leaderId] = nil

    local session = B.getSessionByInstance(instance)
    if session == nil then
        I.onInstanceCreated(instance)
        session = B.getSessionByInstance(instance)
    end

    if pending then
        session.modeKey = pending.modeKey
        session.mode = pending.mode
        session.participants = pending.members
        session.initialPartySize = #pending.members
    else
        session.participants = { requester }
        session.initialPartySize = 1
    end

    initSessionLogger(session)

    -- Apply native Lv. 10 level sync + skill-up lock to ALL participants before entry.
    local synced = {}
    for _, member in ipairs(session.participants) do
        local mId = member:getID()
        local retPos = (pending and pending.returnPos) or C.getReturnPosForZoneId(member.getZoneID and member:getZoneID() or C.FALLBACK_RETURN.zoneId)
        local unsyncedLvl = getUnsyncedLevel(member)
        local soulKey = getActiveSoulKey(member)

        if R and R.applyLevelSync then
            local ok, err = R.applyLevelSync(member, C.EFFECTIVE_LEVEL)
            if not ok then
                for _, prev in ipairs(synced) do
                    B.restorePlayerState(prev, { warpToHub = false })
                end
                tell(requester, 'Level 10 sync failed: ' .. tostring(err))
                session.cleanupStatus = 'level_sync_failed'
                writeTelemetryRecord(session, 'entry_failed')
                if instance.fail then
                    pcall(function() instance:fail() end)
                end
                sessionsByRunId[session.runId] = nil
                return
            end
        end

        if R and R.applySkillupLock then
            pcall(R.applySkillupLock, member, true)
        end

        session.participantIds[mId] = true
        session.returnPosByCharId[mId] = retPos
        session.participantSouls[#session.participantSouls + 1] = soulKey
        session.participantRecords[#session.participantRecords + 1] =
        {
            char_id        = mId,
            name           = (member.getName and member:getName()) or 'unknown',
            main_job       = (member.getMainJob and member:getMainJob()) or 0,
            sub_job        = (member.getSubJob and member:getSubJob()) or 0,
            unsynced_level = unsyncedLvl,
            soul           = soulKey,
        }
        playerRunId[mId] = session.runId
        saveReturnCharVars(member, retPos)
        attachPlayerCombatListeners(session, member)
        synced[#synced + 1] = member
    end

    logEvent(session, 'session_start', {
        expedition      = C.EXPEDITION_ID,
        mode            = session.modeKey,
        instance_id     = C.INSTANCE_ID,
        effective_level = C.EFFECTIVE_LEVEL,
        party_size      = session.initialPartySize,
        participants    = session.participantRecords,
        souls           = session.participantSouls,
        log_dir         = session.logDir,
        event_log_path  = session.eventLogPath,
        summary_path    = session.summaryPath,
    }, true)

    -- Spawn in-instance Guide + ALL encounter mobs at the beginning:
    -- Grudgeburrow is showcased front-and-center; Shaman & Stoneguard lurk on
    -- separated flanks as non-obvious hidden unlocks that weaken Grudgeburrow live.
    session.initialized = true
    session.stage = 3
    spawnInInstanceGuide(session)
    spawnStage3Boss(session)
    spawnStage1Shaman(session)
    spawnStage2Stoneguard(session)

    -- Zone every participant into the isolated Ghoyu's Reverie instance.
    for _, member in ipairs(synced) do
        if member.setInstance then
            member:setInstance(instance)
        end
        if member.setPos then
            member:setPos(0, 0, 0, 0, C.INSTANCE_ZONE_ID)
        end
    end
end

function I.afterInstanceRegister(player)
    local session = B.getSessionForPlayer(player)
    if session == nil then
        return
    end
    if player.countdown and session.instance and session.instance.getTimeLimit then
        pcall(function()
            player:countdown(session.instance:getTimeLimit())
        end)
    end
    tell(player, 'You have entered The First Descent. Speak to the Burrows Guide beside you to exit at any time.')
end

tickSession = function(session, elapsedOverride)
    if session == nil then
        return
    end
    local instance = session.instance
    if elapsedOverride ~= nil then
        session.elapsedSec = tonumber(elapsedOverride) or ((session.elapsedSec or 0) + 1)
    else
        session.elapsedSec = (session.elapsedSec or 0) + 1
    end

    -- Handle post-victory or post-wipe exit grace countdown.
    if session.finished then
        if session.exitCountdown > 0 then
            session.exitCountdown = session.exitCountdown - 1
            if session.exitCountdown <= 0 then
                B.concludeSession(session, session.outcome)
            end
        end
        return
    end

    -- Check time limit expiry.
    if session.elapsedSec >= C.TIME_LIMIT_SEC then
        session.finished = true
        session.outcome = 'timeout'
        broadcast(session, 'Your time in the Burrows has expired. Returning to town...')
        if instance.fail then
            pcall(function() instance:fail() end)
        else
            B.concludeSession(session, 'timeout')
        end
        return
    end

    -- Check active players inside the instance for empty-instance teardown or party wipe.
    local chars = {}
    if instance.getChars then
        local ok, res = pcall(function() return instance:getChars() end)
        if ok and type(res) == 'table' then
            for _, p in pairs(res) do
                chars[#chars + 1] = p
            end
        end
    else
        for _, p in ipairs(session.participants or {}) do
            if p and p.getZoneID and p:getZoneID() == C.INSTANCE_ZONE_ID then
                chars[#chars + 1] = p
            end
        end
    end

    if #chars == 0 then
        session.emptySec = session.emptySec + 1
        if session.emptySec >= C.EMPTY_GRACE_SEC then
            session.finished = true
            session.outcome = 'abandoned'
            B.concludeSession(session, 'abandoned')
        end
        return
    else
        session.emptySec = 0
    end

    local anyAlive = false
    for _, p in ipairs(chars) do
        if (not p.isAlive or p:isAlive()) and (not p.getHP or (p:getHP() or 0) > 0) then
            anyAlive = true
            break
        end
    end

    if not anyAlive then
        if session.wipeSec == 0 then
            broadcast(session, 'Your party has fallen. Returning to town shortly...')
        end
        session.wipeSec = session.wipeSec + 1
        if session.wipeSec >= C.WIPE_EXIT_SEC then
            session.finished = true
            session.outcome = 'defeat'
            if instance.fail then
                pcall(function() instance:fail() end)
            else
                B.concludeSession(session, 'defeat')
            end
        end
        return
    else
        session.wipeSec = 0
    end

    -- Tick all active encounters concurrently (all mobs spawn at instance start).
    tickStage1Shaman(session)
    tickStage2Stoneguard(session)
    tickStage3Boss(session)
end

function I.onInstanceTimeUpdate(instance, elapsed)
    local session = B.getSessionByInstance(instance)
    if session == nil then
        return
    end
    if session.lastTimerTickAt ~= nil and (os.time() - session.lastTimerTickAt) < 2 then
        return
    end
    tickSession(session, elapsed)
end

function I.onInstanceProgressUpdate(instance, progress)
    -- Reserved for future expedition milestones.
end

function I.onInstanceComplete(instance)
    local session = B.getSessionByInstance(instance)
    if session ~= nil and not session.telemetryWritten then
        writeTelemetryRecord(session, 'victory')
    end
end

function I.onInstanceFailure(instance)
    local session = B.getSessionByInstance(instance)
    if session ~= nil then
        B.concludeSession(session, session.outcome or 'failure')
    elseif instance and instance.getChars then
        local ok, chars = pcall(function() return instance:getChars() end)
        if ok and type(chars) == 'table' then
            for _, p in pairs(chars) do
                B.restorePlayerState(p, { warpToHub = true })
            end
        end
    end
end

-----------------------------------
-- Server Module Hooks
-----------------------------------
if hasServerRuntime then
    local m = Module:new('soulspire_burrows_first_descent')

    -- Spawn Burrows Expedition Guide NPCs in all safe starter hubs + Ru'Lude Gardens.
    for _, hub in ipairs(C.HUB_GUIDES) do
        local hubCfg = hub
        m:addOverride(string.format('xi.zones.%s.Zone.onInitialize', hubCfg.zoneName), function(zone)
            super(zone)
            zone:insertDynamicEntity({
                objtype    = xi.objType.NPC,
                name       = 'Burrows_Guide',
                packetName = C.NPC_PACKET_NAME,
                look       = C.NPC_LOOK_ID,
                x          = hubCfg.x,
                y          = hubCfg.y,
                z          = hubCfg.z,
                rotation   = hubCfg.rotation,
                widescan   = 1,
                onTrigger  = function(player)
                    tell(player, 'Welcome, adventurer! Our researchers have uncovered something dangerous beneath the Burrows. Are you willing to investigate?')
                    player:customMenu(B.buildHubMenu(player))
                end,
            })
        end)
    end

    -- Belt-and-suspenders EXP suppression: Burrows Reborn mobs ALWAYS yield 0 EXP.
    m:addOverride('xi.experiencePoints.calculate', function(member, mob, data)
        if mob ~= nil and mob.getLocalVar and mob:getLocalVar('[BurrowsReborn]ExpeditionMob') == 1 then
            return { exp = 0, chainActive = false, chainWindow = 0 }
        end
        return super(member, mob, data)
    end)

    -- Ensure Ghoyu's Reverie fallback onInstanceZoneIn returns stranded players safely to their hub.
    m:addOverride('xi.zones.Ghoyus_Reverie.Zone.onInstanceZoneIn', function(player, instance)
        if player ~= nil and player:getInstance() == nil and player.getCharVar and player:getCharVar('[BurrowsReborn]Active') == 1 then
            B.restorePlayerState(player, { warpToHub = true })
            return
        end
        super(player, instance)
    end)

    -- Disconnect / relog / zoning-out safety net:
    -- Guarantees original level, Soul scaling, skill-up lock, and safe hub position are always restored.
    m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
        super(player, firstLogin, zoning)
        if player == nil or not player.getZoneID then
            return
        end
        local zoneId = player:getZoneID()
        local inBurrows = (zoneId == C.INSTANCE_ZONE_ID)
        local inUnknownZone = (zoneId == 0)
        local activeVar = (player.getCharVar and player:getCharVar('[BurrowsReborn]Active') == 1) or false
        local session = B.getSessionForPlayer(player)

        if (inBurrows or inUnknownZone) and activeVar and session == nil then
            -- Relogged into Ghoyu's Reverie (or LandSandBoat's zone 0 fallback) after instance ended or server restarted.
            B.restorePlayerState(player, { warpToHub = true })
            tell(player, 'Your previous expedition has ended. Returning you safely to town.')
        elseif not inBurrows and (activeVar or session ~= nil) then
            B.restorePlayerState(player, { warpToHub = false })
            tell(player, 'Your level sync has been restored.')
        end
    end)

    return m
end

return B
