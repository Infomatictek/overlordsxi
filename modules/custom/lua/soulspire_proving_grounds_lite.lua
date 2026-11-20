-----------------------------------
-- SoulspireXI Soul Proving Grounds Lite (NPC Testing Arena)
--
-- Features:
--   - Existing FFXI NPC model (look 2433, The Arbiter) in GM Home (zone 210)
--     at (-5, 0, 5) — 10 yalms clear of GM Home's sample Menu Example NPC.
--   - Native customMenu only: zero player-facing chat commands, zero DAT edits,
--     zero custom animations, zero new monster models, zero custom UI.
--   - Complete native menu flow:
--       1. Encounter Type (Physical Bruiser / Magic-heavy Caster / AoE Boss / Training Dummy)
--       2. Effective Player Level (10 / 30 / 50 / 75 / Match Current Level)
--       3. Difficulty (Even Match +0 / Very Tough +3 / Incredibly Tough +5 / Extreme +8)
--       4. Enemy Classification (Normal / NM)
--   - Native non-destructive level synchronization via xi.effect.LEVEL_RESTRICTION
--     applied consistently across all participating party members before combat,
--     with automatic SoulspireXI Soul/HP/Pet/Clone rescaling and guaranteed restoration
--     on victory, defeat, reset, timeout, repeat, exit, disconnect, zoning, or relog.
--   - Boss level calculated from Effective Player Level + Difficulty offset (supports
--     boss levels above 75 up to Lv83).
--   - Full chronological event log, 1s snapshots, accurate combat-start timing,
--     explicit write-failure reporting, and native post-encounter feedback tagging.
-----------------------------------
require('modules/module_utils')
require('scripts/globals/player')
require('scripts/zones/GM_Home/Zone')
require('modules/custom/lua/boss_like_combat_and_exp')
require('modules/custom/lua/soulspire_proving_grounds_registry')
require('modules/custom/lua/soulspire_proving_grounds_telemetry')

local m = Module:new('soulspire_proving_grounds_lite')

xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.soulspire.provingGrounds = xi.soulspire.provingGrounds or {}
xi.soulspire.provingGrounds.arena = xi.soulspire.provingGrounds.arena or {}

local A = xi.soulspire.provingGrounds.arena
local R = xi.soulspire.provingGrounds.registry
local T = xi.soulspire.provingGrounds.telemetry

local ARENA_ZONE = R.ARENA_ZONE_ID
local EXIT_DEST  = { x = 0, y = 3, z = 2, rot = 192, zone = (xi.zone and xi.zone.RULUDE_GARDENS) or 243 }

local activeSession = nil
local previousChoiceByChar = {}
local lastCompletedRunByChar = {}

local function tell(player, message)
    if player ~= nil and player.printToPlayer then
        player:printToPlayer('[Crucible] ' .. tostring(message), xi.msg.channel.SYSTEM_3, '')
    end
end

local function openLater(player, builder)
    if player == nil or not player.timer then
        return
    end
    player:timer(50, function(p)
        if p and p:getZoneID() == ARENA_ZONE then
            p:customMenu(builder(p))
        end
    end)
end

local function getParticipatingActors(owner)
    local actors = {}
    local seen = {}
    if owner == nil then
        return actors
    end

    local function addActor(ent)
        if ent ~= nil and ent.isPC and ent:isPC() and ent.getID and ent.getZoneID then
            local id = ent:getID()
            if not seen[id] and ent:getZoneID() == ARENA_ZONE then
                seen[id] = true
                actors[#actors + 1] = ent
            end
        end
    end

    addActor(owner)
    if owner.getParty then
        local party = owner:getParty()
        if type(party) == 'table' then
            for _, member in ipairs(party) do
                addActor(member)
            end
        end
    end

    return actors
end

local function isParticipant(session, player)
    if session == nil or player == nil or not player.getID then
        return false
    end
    local pid = player:getID()
    if session.ownerId == pid then
        return true
    end
    return session.participantIds ~= nil and session.participantIds[pid] == true
end

local function isMobActive(mob)
    if mob == nil then
        return false
    end
    if mob.isAlive and not mob:isAlive() then
        return false
    end
    if mob.getStatus and xi.status and xi.status.DISAPPEAR and mob:getStatus() == xi.status.DISAPPEAR then
        return false
    end
    return true
end

local function isOwnerStillInArena(session)
    if session == nil then
        return false
    end
    local owner = session.owner
    if owner == nil then
        return false
    end
    local ok, inZone = pcall(function()
        return owner:getZoneID() == ARENA_ZONE
    end)
    return ok and inZone
end

local function printSummaryToOwner(owner, record)
    if owner == nil or record == nil or record.metrics == nil then
        return
    end
    local off = record.metrics.offense or {}
    local def = record.metrics.defense or {}
    local thr = record.metrics.threat or {}
    local saf = record.metrics.safety or {}
    local logSt = record.logging_status or {}

    pcall(function()
        if owner:getZoneID() ~= ARENA_ZONE then
            return
        end
        local dpsStr = type(off.sustained_dps) == 'number' and string.format('%.1f', off.sustained_dps) or tostring(off.sustained_dps)
        local burstStr = type(off.burst_dps_10s) == 'number' and string.format('%.1f', off.burst_dps_10s) or tostring(off.burst_dps_10s)
        tell(owner, string.format(
            'Run %s [%s] %s (%s) Lv.%d vs Synced Lv.%d (Orig Lv.%d) | Combat: %.1fs (Prep: %.1fs)',
            tostring(record.run_id),
            tostring(record.outcome),
            tostring(record.boss_type),
            tostring(record.boss_preset),
            tonumber(record.actual_boss_level) or 0,
            tonumber(record.effective_combat_level) or 0,
            tonumber(record.original_character_level) or 0,
            tonumber(record.encounter_duration_sec) or 0,
            tonumber(record.prep_duration_sec) or 0
        ))
        tell(owner, string.format(
            'Total Dmg: %d (DPS: %s, Peak 10s: %s) | Auto %d | WS %d (%d) | Spell %d | Pet/Clone %d | IncDmg: %d (Spike %d) | Enmity: %d | Clean: %s',
            tonumber(off.total_damage) or 0,
            dpsStr,
            burstStr,
            tonumber(off.autoattack_damage) or 0,
            tonumber(off.weaponskill_damage) or 0,
            tonumber(off.weaponskill_uses) or 0,
            tonumber(off.spell_damage) or 0,
            tonumber(off.pet_and_clone_damage) or 0,
            tonumber(def.actual_incoming_damage) or 0,
            tonumber(def.max_damage_spike) or 0,
            tonumber(thr.enmity_generation) or 0,
            tostring(saf.progression_clean)
        ))
        if logSt.ok == false then
            local errText = type(logSt.errors) == 'table' and table.concat(logSt.errors, '; ') or 'write_failed'
            tell(owner, 'LOGGING WARNING: Incomplete combat recording! ' .. errText)
            print('[ProvingGrounds][LOGGING_ERROR] run_id=' .. tostring(record.run_id) .. ' errors=' .. errText)
        else
            tell(owner, string.format(
                'Saved log (%d events, %d snapshots). Speak to The Arbiter to tag gameplay feedback.',
                tonumber(logSt.events_written) or 0,
                tonumber(logSt.snapshots_written) or 0
            ))
        end
    end)
end

-- Restores level sync, skill-up locks, listeners, telemetry, and mob cleanup safely under any exit condition.
function A.cleanupSession(reason, opts)
    opts = opts or {}
    local session = activeSession
    if session == nil then
        return nil
    end

    -- Clear lock immediately to prevent re-entrant cleanup.
    activeSession = nil

    -- Finalize telemetry BEFORE despawning mob or restoring level sync so final state matches combat level.
    local record = nil
    if session.telemetry then
        local ok, res = pcall(function()
            return T.finishSession(session.telemetry, reason or 'reset', { writeLog = opts.writeLog ~= false })
        end)
        if ok then
            record = res
        end
    end

    if record ~= nil and session.ownerId ~= nil then
        lastCompletedRunByChar[session.ownerId] =
        {
            run_id     = record.run_id,
            soul_key   = record.soul_key,
            boss_type  = record.boss_type,
            boss_level = record.actual_boss_level,
            outcome    = record.outcome,
        }
    end

    -- Despawn trial mob cleanly if still alive/present.
    if opts.despawnMob ~= false and session.mob ~= nil then
        pcall(function()
            if session.mob.setStatus and xi.status and xi.status.DISAPPEAR then
                session.mob:setStatus(xi.status.DISAPPEAR)
            end
        end)
    end

    -- Remove skill-up locks, disconnect listeners, AND restore native level sync for ALL participants.
    if session.participants then
        for _, actor in ipairs(session.participants) do
            pcall(function()
                R.applySkillupLock(actor, false)
                R.restoreLevelSync(actor)
                if actor.removeListener then
                    actor:removeListener(session.ownerDespawnTag)
                end
            end)
        end
    end

    if opts.notifyOwner ~= false and record ~= nil and session.owner ~= nil then
        printSummaryToOwner(session.owner, record)
    end

    return record
end

local function findCurrent()
    if activeSession == nil then
        return nil
    end
    if not isMobActive(activeSession.mob) then
        A.cleanupSession('timeout_or_despawn', { despawnMob = false })
        return nil
    end
    if not isOwnerStillInArena(activeSession) then
        A.cleanupSession('owner_left_arena', { despawnMob = true, notifyOwner = false })
        return nil
    end
    return activeSession
end

function A.getActiveSession()
    return findCurrent()
end

function A.getLastCompletedRun(player)
    if player == nil or not player.getID then
        return nil
    end
    return lastCompletedRunByChar[player:getID()]
end

function A.recordFeedback(player, tagKey, note)
    local lastRun = A.getLastCompletedRun(player)
    if not lastRun then
        tell(player, 'No completed Proving Grounds run found to attach feedback to.')
        return false, 'no_completed_run'
    end

    local label = tagKey
    for _, opt in ipairs(T.FEEDBACK_OPTIONS) do
        if opt.key == tagKey then
            label = opt.label
            break
        end
    end

    local ok, err = T.saveFeedback(lastRun.run_id, {
        source     = 'npc_menu',
        tag        = tagKey,
        label      = label,
        note       = note,
        soul_key   = lastRun.soul_key,
        boss_type  = lastRun.boss_type,
        boss_level = lastRun.boss_level,
    })
    if not ok then
        tell(player, 'LOGGING WARNING: Failed to save feedback: ' .. tostring(err))
        return false, err
    end

    tell(player, string.format('Recorded feedback [%s] for run %s.', tostring(label), tostring(lastRun.run_id)))
    return true, nil
end

function A.resetTrial(player)
    local current = findCurrent()
    if not current then
        -- Ensure no lingering sync/skillup lock even if no trial is active.
        R.applySkillupLock(player, false)
        R.restoreLevelSync(player)
        tell(player, 'No trial is currently active.')
        return false, 'no_active_trial'
    end

    if not isParticipant(current, player) then
        tell(player, string.format(
            'Arena is locked by %s\'s active trial (%s Lv.%d). Wait for them to finish or reset.',
            tostring(current.ownerName or 'another tester'),
            tostring(current.encounter.bossLabel),
            tonumber(current.encounter.bossLevel) or 0
        ))
        return false, 'locked_by_other'
    end

    A.cleanupSession('reset', { despawnMob = true, notifyOwner = true })
    tell(player, 'Trial cleared, level sync restored, and arena lock released.')
    return true, nil
end

-- Starts a Proving Grounds trial with native level synchronization and full difficulty/preset config.
-- Supports both new signature:
--   A.startTrial(player, bossType, effectivePlayerLevel, { difficulty = 'very_tough', bossPreset = 'nm', ... })
-- and legacy 3-arg call:
--   A.startTrial(player, bossType, level) -> defaults to Even Match (+0), Normal preset.
function A.startTrial(player, bossType, effectivePlayerLevel, opts)
    opts = opts or {}
    if not player or player:getZoneID() ~= ARENA_ZONE then
        return false, 'not_in_arena'
    end

    local current = findCurrent()
    if current then
        if isParticipant(current, player) then
            tell(player, 'You already have an active trial. Choose Reset before starting a new encounter.')
        else
            tell(player, string.format(
                'Arena is currently locked by %s (%s Lv.%d). Only one trial may run at a time.',
                tostring(current.ownerName or 'another tester'),
                tostring(current.encounter.bossLabel),
                tonumber(current.encounter.bossLevel) or 0
            ))
        end
        return false, 'arena_locked'
    end

    local arch = R.ARCHETYPES[bossType]
    if not arch then
        tell(player, 'Unknown encounter type.')
        return false, 'unknown_archetype'
    end
    if not arch.npcAvailable then
        tell(player, string.format('%s is currently unavailable: %s', arch.label, tostring(arch.unavailableReason or 'not yet verified')))
        return false, 'archetype_unavailable'
    end

    local zone = player:getZone()
    if not zone then
        tell(player, 'Arena zone is unavailable.')
        return false, 'zone_unavailable'
    end

    -- Resolve effective target player level (from unsynced level when matching current level).
    local ownerOrigLvl = R.getUnsyncedLevel(player)
    local targetPlayerLvl
    if opts.matchPlayerLevel == true or effectivePlayerLevel == nil then
        targetPlayerLvl = math.max(R.MIN_LEVEL, math.min(R.MAX_LEVEL, ownerOrigLvl))
    else
        targetPlayerLvl = math.floor(tonumber(effectivePlayerLevel) or 0)
    end

    if targetPlayerLvl < R.MIN_LEVEL or targetPlayerLvl > R.MAX_LEVEL then
        tell(player, string.format('Unsupported effective player level (%d). Supported range: %d-%d.', targetPlayerLvl, R.MIN_LEVEL, R.MAX_LEVEL))
        return false, 'unsupported_level'
    end

    local diffMeta, diffKey = R.resolveDifficulty(opts.difficulty or 'even_match')
    if not diffMeta then
        tell(player, 'Unsupported difficulty: ' .. tostring(opts.difficulty))
        return false, 'unsupported_difficulty'
    end

    local presetKey = string.lower(tostring(opts.bossPreset or 'normal'))
    if not R.BOSS_PRESETS[presetKey] then
        tell(player, 'Unsupported enemy classification: ' .. tostring(opts.bossPreset))
        return false, 'unsupported_preset'
    end

    local participants = getParticipatingActors(player)
    -- Pre-validate that NO participating player is below the requested effective player level
    -- (never silently allow an invalid upward level-sync benchmark).
    for _, actor in ipairs(participants) do
        local aOrig = R.getUnsyncedLevel(actor)
        if aOrig < targetPlayerLvl then
            local msg = string.format(
                '%s is Lv.%d and cannot sync upward to Lv.%d. Select Match Current Level or <= Lv.%d.',
                actor.getName and actor:getName() or 'Participant',
                aOrig,
                targetPlayerLvl,
                aOrig
            )
            tell(player, msg)
            return false, 'cannot_sync_upward'
        end
    end

    -- Boss level is ALWAYS calculated from effective synced player level + difficulty offset.
    local computedBossLvl = targetPlayerLvl + diffMeta.levelDelta
    local partyComp = (#participants > 1) and 'party' or 'solo'

    local encounter, err = R.buildEncounterConfig({
        bossType         = bossType,
        playerLevel      = targetPlayerLvl,
        bossLevel        = computedBossLvl,
        difficulty       = diffKey,
        bossPreset       = presetKey,
        durationSec      = R.DEFAULT_DURATION_SEC,
        partyComposition = partyComp,
    })
    if not encounter then
        tell(player, 'Encounter configuration error: ' .. tostring(err))
        return false, err
    end

    -- Apply native level sync + skill-up lock to ALL participating party members BEFORE combat begins.
    local syncedActors = {}
    local primarySyncVerification = nil
    local participantIds = {}
    for idx, actor in ipairs(participants) do
        local syncOk, syncErr, verification = R.applyLevelSync(actor, targetPlayerLvl)
        if not syncOk then
            -- Roll back any already-synced participants cleanly.
            for _, prevActor in ipairs(syncedActors) do
                R.applySkillupLock(prevActor, false)
                R.restoreLevelSync(prevActor)
            end
            tell(player, 'Level sync failed: ' .. tostring(syncErr))
            return false, syncErr or 'level_sync_failed'
        end
        R.applySkillupLock(actor, true)
        syncedActors[#syncedActors + 1] = actor
        participantIds[actor:getID()] = true
        if idx == 1 then
            primarySyncVerification = verification
        end
    end

    local ownerId = player:getID()
    local ownerDespawnTag = string.format('PG_OWNER_DESPAWN_%d', ownerId)

    local telemetryRef = nil
    local mob, spawnErr = R.spawnTrialMob(zone, encounter, {
        spawnLifetimeSec = R.DEFAULT_DURATION_SEC,
        onMobSkillChosen = function(chosenMob, target, skillId)
            if telemetryRef and telemetryRef.onBossSkillChosen then
                telemetryRef.onBossSkillChosen(chosenMob, target, skillId)
            end
        end,
        onMobDeath = function(deadMob)
            if activeSession and activeSession.mob and activeSession.mob:getID() == deadMob:getID() then
                A.cleanupSession('victory', { despawnMob = false, notifyOwner = true })
            end
        end,
        onMobDespawn = function(despawnedMob)
            if activeSession and activeSession.mob and activeSession.mob:getID() == despawnedMob:getID() then
                A.cleanupSession('timeout', { despawnMob = false, notifyOwner = true })
            end
        end,
    })

    if not mob then
        for _, actor in ipairs(syncedActors) do
            R.applySkillupLock(actor, false)
            R.restoreLevelSync(actor)
        end
        tell(player, 'Could not spawn trial opponent: ' .. tostring(spawnErr))
        return false, spawnErr
    end

    local telemetrySession = T.beginSession({
        mob            = mob,
        actors         = participants,
        encounter      = encounter,
        testMode       = 'manual',
        originalLevel  = primarySyncVerification and primarySyncVerification.original_level or ownerOrigLvl,
        effectiveLevel = primarySyncVerification and primarySyncVerification.effective_level or targetPlayerLvl,
        levelSync      = primarySyncVerification,
    })
    telemetryRef = telemetrySession

    activeSession =
    {
        mob             = mob,
        encounter       = encounter,
        owner           = player,
        ownerId         = ownerId,
        ownerName       = player.getName and player:getName() or 'Tester',
        participants    = participants,
        participantIds  = participantIds,
        telemetry       = telemetrySession,
        levelSync       = primarySyncVerification,
        ownerDespawnTag = ownerDespawnTag,
    }

    -- Persist FULL encounter settings for 1-click Repeat Previous Encounter.
    previousChoiceByChar[ownerId] =
    {
        bossType             = bossType,
        effectivePlayerLevel = targetPlayerLvl,
        matchPlayerLevel     = opts.matchPlayerLevel == true,
        difficulty           = diffKey,
        bossPreset           = presetKey,
    }

    if player.addListener then
        player:addListener('DESPAWN', ownerDespawnTag, function(leavingPlayer)
            if activeSession and activeSession.ownerId == leavingPlayer:getID() then
                A.cleanupSession('owner_disconnected_or_zoned', { despawnMob = true, notifyOwner = false })
            end
        end)
    end

    local extremeTag = encounter.extremeChallenge and ' [EXTREME - NON-BASELINE]' or ''
    tell(player, string.format(
        '%s (%s) Lv.%d spawned vs Effective Lv.%d (Orig Lv.%d, %s)%s.',
        encounter.bossLabel,
        encounter.bossPresetLabel,
        encounter.bossLevel,
        targetPlayerLvl,
        primarySyncVerification and primarySyncVerification.original_level or ownerOrigLvl,
        encounter.difficultyLabel,
        extremeTag
    ))
    tell(player, string.format(
        '%s Live boss scaling active. Combat timer begins on first hostile action. Zero EXP/gil/loot/skill-ups.',
        encounter.behaviorProfile.summary or ''
    ))
    return true, activeSession
end

function A.repeatTrial(player)
    if not player or not player.getID then
        return false, 'invalid_player'
    end
    local prev = previousChoiceByChar[player:getID()]
    if not prev then
        tell(player, 'No previous encounter recorded yet. Start an encounter first.')
        return false, 'no_previous'
    end

    local current = findCurrent()
    if current then
        if not isParticipant(current, player) then
            tell(player, 'Arena is locked by another player\'s active trial.')
            return false, 'locked_by_other'
        end
        A.cleanupSession('reset_for_repeat', { despawnMob = true, notifyOwner = false })
    end

    local targetLvl = prev.matchPlayerLevel
        and math.max(R.MIN_LEVEL, math.min(R.MAX_LEVEL, R.getUnsyncedLevel(player)))
        or prev.effectivePlayerLevel

    return A.startTrial(player, prev.bossType, targetLvl, {
        matchPlayerLevel = prev.matchPlayerLevel,
        difficulty       = prev.difficulty,
        bossPreset       = prev.bossPreset,
    })
end

function A.exitArena(player)
    if not player then
        return
    end
    local current = findCurrent()
    if current and isParticipant(current, player) then
        A.cleanupSession('owner_exited', { despawnMob = true, notifyOwner = false })
    else
        R.applySkillupLock(player, false)
        R.restoreLevelSync(player)
    end
    tell(player, 'Level sync restored. Exiting Soul Proving Grounds to Ru\'Lude Gardens.')
    if player.setPos then
        player:setPos(EXIT_DEST.x, EXIT_DEST.y, EXIT_DEST.z, EXIT_DEST.rot, EXIT_DEST.zone)
    end
end

-----------------------------------
-- Native customMenu Hierarchy (Zero chat commands, zero custom UI/DATs)
-----------------------------------
local rootMenu
local encounterTypeMenu
local levelMenu
local difficultyMenu
local presetMenu
local feedbackMenu

presetMenu = function(player, bossType, effectiveLvl, matchPlayerLvl, difficultyKey)
    local arch = R.ARCHETYPES[bossType]
    local diff = R.DIFFICULTIES[difficultyKey]
    local bossLvl = effectiveLvl + (diff and diff.levelDelta or 0)
    local options = {}

    for _, pKey in ipairs(R.BOSS_PRESET_ORDER) do
        local preset = R.BOSS_PRESETS[pKey]
        local chosenPreset = pKey
        options[#options + 1] =
        {
            string.format('%s (Boss Lv.%d)', preset.label, bossLvl),
            function(p)
                A.startTrial(p, bossType, effectiveLvl, {
                    matchPlayerLevel = matchPlayerLvl,
                    difficulty       = difficultyKey,
                    bossPreset       = chosenPreset,
                })
            end,
        }
    end
    options[#options + 1] =
    {
        'Back',
        function(p)
            openLater(p, function(pl)
                return difficultyMenu(pl, bossType, effectiveLvl, matchPlayerLvl)
            end)
        end,
    }

    return
    {
        title   = string.format('%s Lv.%d - Classification', arch and arch.label or bossType, bossLvl),
        options = options,
    }
end

difficultyMenu = function(player, bossType, effectiveLvl, matchPlayerLvl)
    local arch = R.ARCHETYPES[bossType]
    local options = {}

    for _, dKey in ipairs(R.DIFFICULTY_ORDER) do
        local diff = R.DIFFICULTIES[dKey]
        local chosenDiff = dKey
        local bossLvl = effectiveLvl + diff.levelDelta
        options[#options + 1] =
        {
            string.format('%s -> Boss Lv.%d', diff.label, bossLvl),
            function(p)
                openLater(p, function(pl)
                    return presetMenu(pl, bossType, effectiveLvl, matchPlayerLvl, chosenDiff)
                end)
            end,
        }
    end
    options[#options + 1] =
    {
        'Back',
        function(p)
            openLater(p, function(pl)
                return levelMenu(pl, bossType)
            end)
        end,
    }

    return
    {
        title   = string.format('%s (Sync Lv.%d) - Difficulty', arch and arch.label or bossType, effectiveLvl),
        options = options,
    }
end

levelMenu = function(player, bossType)
    local arch = R.ARCHETYPES[bossType]
    local curOrig = R.getUnsyncedLevel(player)
    local options = {}

    for _, level in ipairs(R.LEVELS) do
        local chosen = level
        local suffix = (curOrig < chosen) and ' [Too High]' or ''
        options[#options + 1] =
        {
            string.format('Effective Level %d%s', chosen, suffix),
            function(p)
                if R.getUnsyncedLevel(p) < chosen then
                    tell(p, string.format('Your character is Lv.%d and cannot sync upward to Lv.%d.', R.getUnsyncedLevel(p), chosen))
                    return
                end
                openLater(p, function(pl)
                    return difficultyMenu(pl, bossType, chosen, false)
                end)
            end,
        }
    end

    local matchedLvl = math.max(R.MIN_LEVEL, math.min(R.MAX_LEVEL, curOrig))
    options[#options + 1] =
    {
        string.format('Match Current Level (Lv.%d)', matchedLvl),
        function(p)
            local ml = math.max(R.MIN_LEVEL, math.min(R.MAX_LEVEL, R.getUnsyncedLevel(p)))
            openLater(p, function(pl)
                return difficultyMenu(pl, bossType, ml, true)
            end)
        end,
    }
    options[#options + 1] =
    {
        'Back',
        function(p)
            openLater(p, encounterTypeMenu)
        end,
    }

    return
    {
        title   = string.format('Crucible - %s Effective Level', arch and arch.label or bossType),
        options = options,
    }
end

encounterTypeMenu = function(player)
    local options = {}
    for _, key in ipairs(R.NPC_ARCHETYPE_ORDER) do
        local arch = R.ARCHETYPES[key]
        if arch and arch.npcAvailable then
            local chosenKey = key
            options[#options + 1] =
            {
                arch.label,
                function(p)
                    openLater(p, function(pl)
                        return levelMenu(pl, chosenKey)
                    end)
                end,
            }
        end
    end
    options[#options + 1] =
    {
        'Unavailable Archetypes Info',
        function(p)
            for _, key in ipairs(R.MATRIX_ARCHETYPE_ORDER) do
                local arch = R.ARCHETYPES[key]
                if arch and not arch.npcAvailable then
                    tell(p, string.format('%s [Unavailable]: %s', arch.label, tostring(arch.unavailableReason)))
                end
            end
        end,
    }
    options[#options + 1] =
    {
        'Back',
        function(p)
            openLater(p, rootMenu)
        end,
    }

    return
    {
        title   = 'Crucible - Select Encounter Type',
        options = options,
    }
end

feedbackMenu = function(player)
    local lastRun = A.getLastCompletedRun(player)
    local options = {}
    for _, opt in ipairs(T.FEEDBACK_OPTIONS) do
        local chosenKey = opt.key
        options[#options + 1] =
        {
            opt.label,
            function(p)
                if chosenKey == 'skip' then
                    tell(p, 'Skipped feedback for last run.')
                else
                    A.recordFeedback(p, chosenKey)
                end
            end,
        }
    end
    options[#options + 1] =
    {
        'Back',
        function(p)
            openLater(p, rootMenu)
        end,
    }

    local title = lastRun
        and string.format('Feedback (%s Lv.%d)', tostring(lastRun.boss_type), tonumber(lastRun.boss_level) or 0)
        or 'Feedback (No Recent Run)'
    return
    {
        title   = title,
        options = options,
    }
end

rootMenu = function(player)
    local prev = player and player.getID and previousChoiceByChar[player:getID()] or nil
    local repeatLabel = 'Repeat Previous Encounter'
    if prev then
        local arch = R.ARCHETYPES[prev.bossType]
        local diff = R.DIFFICULTIES[prev.difficulty]
        local lvlLabel = prev.matchPlayerLevel and 'Match' or ('Lv.' .. tostring(prev.effectivePlayerLevel))
        local presetTag = (prev.bossPreset == 'nm') and 'NM' or 'Norm'
        repeatLabel = string.format(
            'Repeat: %s (%s +%d %s)',
            arch and arch.label or prev.bossType,
            lvlLabel,
            diff and diff.levelDelta or 0,
            presetTag
        )
    end

    local options =
    {
        {
            'Start Encounter',
            function(p)
                openLater(p, encounterTypeMenu)
            end,
        },
        {
            'Reset Active Encounter',
            function(p)
                A.resetTrial(p)
            end,
        },
        {
            repeatLabel,
            function(p)
                A.repeatTrial(p)
            end,
        },
    }

    if A.getLastCompletedRun(player) ~= nil then
        options[#options + 1] =
        {
            'Record Feedback (Last Run)',
            function(p)
                openLater(p, feedbackMenu)
            end,
        }
    end

    options[#options + 1] =
    {
        'Exit Proving Grounds',
        function(p)
            A.exitArena(p)
        end,
    }
    options[#options + 1] =
    {
        'Close',
        function() end,
    }

    return
    {
        title   = 'The Arbiter - Soul Proving Grounds',
        options = options,
    }
end

m:addOverride('xi.zones.GM_Home.Zone.onInitialize', function(zone)
    super(zone)
    if zone:getID() ~= ARENA_ZONE then
        return
    end
    zone:insertDynamicEntity({
        objtype    = xi.objType.NPC,
        name       = 'Crucible_Arbiter',
        packetName = 'The Arbiter',
        look       = 2433,
        x          = R.NPC_POS.x,
        y          = R.NPC_POS.y,
        z          = R.NPC_POS.z,
        rotation   = R.NPC_POS.rotation,
        widescan   = 1,
        onTrigger  = function(player)
            player:customMenu(rootMenu(player))
        end,
    })
end)

-- Cleanup and restore level sync on player death inside GM Home if all participating players are dead.
m:addOverride('xi.player.onPlayerDeath', function(player)
    super(player)
    if activeSession == nil or player == nil or not isParticipant(activeSession, player) then
        return
    end
    local anyAlive = false
    for _, actor in ipairs(activeSession.participants or {}) do
        local ok, alive = pcall(function()
            return actor:getZoneID() == ARENA_ZONE and actor:isAlive()
        end)
        if ok and alive then
            anyAlive = true
            break
        end
    end
    if not anyAlive then
        A.cleanupSession('defeat', { despawnMob = true, notifyOwner = true })
    end
end)

-- Safety net for zoning out, disconnect relog, and server-restart crash recovery:
-- restores any lingering Proving Grounds level restriction or skill-up lock cleanly.
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player == nil or not player.getZoneID then
        return
    end
    local inArena = (player:getZoneID() == ARENA_ZONE)
    local isActiveParticipant = (activeSession ~= nil and isParticipant(activeSession, player))

    if not inArena then
        R.applySkillupLock(player, false)
        if activeSession ~= nil and activeSession.ownerId == player:getID() then
            A.cleanupSession('owner_zoned_out', { despawnMob = true, notifyOwner = false })
        else
            R.restoreLevelSync(player)
        end
    elseif not isActiveParticipant then
        -- Player logged back into GM Home after a disconnect or server restart with no active session.
        if player.getCharVar and player:getCharVar('[ProvingGrounds]SyncActive') == 1 then
            R.applySkillupLock(player, false)
            R.restoreLevelSync(player)
        end
    end
end)

return m
