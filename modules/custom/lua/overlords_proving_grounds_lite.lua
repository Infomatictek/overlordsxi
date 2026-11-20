-----------------------------------
-- OverlordsXI Soul Proving Grounds Lite (NPC Testing Arena)
--
-- Features:
--   - Existing FFXI NPC model (look 2433, The Arbiter) in GM Home (zone 210).
--   - Native customMenu only: zero player-facing chat commands, zero DAT edits,
--     zero custom animations, zero new monster models, zero custom UI.
--   - Driven 100% by the shared encounter registry (overlords_proving_grounds_registry.lua)
--     so manual and automated combat tests share identical encounters & rules.
--   - Full integration with xi.customBossServer (boss_like_combat_and_exp.lua).
--   - Defense-in-depth no-progression safeguards (0 EXP, 0 gil, 0 loot, 0 skill-ups,
--     0 RoE/BLU learning/quests/missions/titles).
--   - Single locked testing session preventing cross-group interference, with
--     reliable cleanup on victory, defeat, timeout, reset, repeat, disconnect,
--     zoning, server restart, and spawn failures.
--   - Server-authoritative telemetry logging (overlords_proving_grounds_telemetry.lua).
-----------------------------------
require('modules/module_utils')
require('scripts/globals/player')
require('scripts/zones/GM_Home/Zone')
require('modules/custom/lua/boss_like_combat_and_exp')
require('modules/custom/lua/overlords_proving_grounds_registry')
require('modules/custom/lua/overlords_proving_grounds_telemetry')

local m = Module:new('overlords_proving_grounds_lite')

xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.provingGrounds = xi.overlords.provingGrounds or {}
xi.overlords.provingGrounds.arena = xi.overlords.provingGrounds.arena or {}

local A = xi.overlords.provingGrounds.arena
local R = xi.overlords.provingGrounds.registry
local T = xi.overlords.provingGrounds.telemetry

local ARENA_ZONE = R.ARENA_ZONE_ID
local EXIT_DEST  = { x = 0, y = 3, z = 2, rot = 192, zone = (xi.zone and xi.zone.RULUDE_GARDENS) or 243 }

local activeSession = nil
local previousChoiceByChar = {}

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

    local ok = pcall(function()
        if owner:getZoneID() ~= ARENA_ZONE then
            return
        end
        tell(owner, string.format(
            'Result [%s] %s Lv.%d | Duration: %.1fs | Total Dmg: %d (%.1f DPS, Peak 10s: %.1f)',
            tostring(record.outcome),
            tostring(record.boss_type),
            tonumber(record.boss_level) or 0,
            tonumber(record.encounter_duration_sec) or 0,
            tonumber(off.total_damage) or 0,
            tonumber(off.sustained_dps) or 0,
            tonumber(off.burst_dps_10s) or 0
        ))
        tell(owner, string.format(
            'Offense: Auto %d | WS %d (%d uses) | Spell %d | Pet %d | Incoming Dmg: %d (Max Spike %d) | Enmity: %d | Progression Clean: %s',
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
    end)
    if not ok then
        return
    end
end

-- Cleans up the active session safely under any exit condition.
function A.cleanupSession(reason, opts)
    opts = opts or {}
    local session = activeSession
    if session == nil then
        return nil
    end

    -- Clear module-level lock immediately to prevent re-entrant double cleanup.
    activeSession = nil

    -- Remove owner lifecycle listeners & skill-up locks on all participants.
    if session.participants then
        for _, actor in ipairs(session.participants) do
            pcall(function()
                R.applySkillupLock(actor, false)
                if actor.removeListener then
                    actor:removeListener(session.ownerDespawnTag)
                    actor:removeListener(session.ownerTickTag)
                end
            end)
        end
    end

    -- Finalize telemetry before despawning mob so final threat/resource readings exist.
    local record = nil
    if session.telemetry then
        local ok, res = pcall(function()
            return T.finishSession(session.telemetry, reason or 'reset', { writeLog = opts.writeLog ~= false })
        end)
        if ok then
            record = res
        end
    end

    -- Despawn trial mob cleanly if still present.
    if opts.despawnMob ~= false and session.mob ~= nil then
        pcall(function()
            if session.mob.setStatus and xi.status and xi.status.DISAPPEAR then
                session.mob:setStatus(xi.status.DISAPPEAR)
            end
        end)
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

function A.resetTrial(player)
    local current = findCurrent()
    if not current then
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
    tell(player, 'Trial cleared and arena lock released.')
    return true, nil
end

function A.startTrial(player, bossType, level, opts)
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

    local playerLvl = math.max(R.MIN_LEVEL, math.min(R.MAX_LEVEL, player:getMainLvl()))
    local selectedLvl = math.floor(tonumber(level) or playerLvl)
    if selectedLvl < R.MIN_LEVEL or selectedLvl > (R.MAX_LEVEL + 8) then
        tell(player, string.format('Unsupported level (%d). Supported range: %d-%d.', selectedLvl, R.MIN_LEVEL, R.MAX_LEVEL))
        return false, 'unsupported_level'
    end

    local difficulty = 'even_match'
    local gap = selectedLvl - playerLvl
    if gap >= 8 then
        difficulty = 'boss_plus_8'
    elseif gap >= 3 then
        difficulty = 'boss_plus_3'
    end

    local encounter, err = R.buildEncounterConfig({
        bossType         = bossType,
        bossLevel        = selectedLvl,
        playerLevel      = playerLvl,
        difficulty       = difficulty,
        bossPreset       = opts.bossPreset or 'normal',
        durationSec      = R.DEFAULT_DURATION_SEC,
        partyComposition = 'solo',
    })
    if not encounter then
        tell(player, 'Encounter configuration error: ' .. tostring(err))
        return false, err
    end

    local participants = getParticipatingActors(player)
    local participantIds = {}
    for _, actor in ipairs(participants) do
        participantIds[actor:getID()] = true
        R.applySkillupLock(actor, true)
    end

    local ownerId = player:getID()
    local ownerDespawnTag = string.format('PG_OWNER_DESPAWN_%d', ownerId)
    local ownerTickTag    = string.format('PG_OWNER_TICK_%d', ownerId)

    local mob, spawnErr = R.spawnTrialMob(zone, encounter, {
        spawnLifetimeSec = R.DEFAULT_DURATION_SEC,
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
        -- Roll back skill-up lock on spawn failure; never leave a stale lock.
        for _, actor in ipairs(participants) do
            R.applySkillupLock(actor, false)
        end
        tell(player, 'Could not spawn trial opponent: ' .. tostring(spawnErr))
        return false, spawnErr
    end

    local telemetrySession = T.beginSession({
        mob       = mob,
        actors    = participants,
        encounter = encounter,
        testMode  = 'manual',
    })

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
        ownerDespawnTag = ownerDespawnTag,
        ownerTickTag    = ownerTickTag,
    }

    -- Save previous encounter selection for 1-click Repeat.
    previousChoiceByChar[ownerId] =
    {
        bossType         = bossType,
        bossLevel        = selectedLvl,
        matchPlayerLevel = opts.matchPlayerLevel == true,
        bossPreset       = encounter.bossPreset,
    }

    -- Attach cleanup listener for player disconnect / zone-out.
    if player.addListener then
        player:addListener('DESPAWN', ownerDespawnTag, function(leavingPlayer)
            if activeSession and activeSession.ownerId == leavingPlayer:getID() then
                A.cleanupSession('owner_disconnected_or_zoned', { despawnMob = true, notifyOwner = false })
            end
        end)
    end

    tell(player, string.format(
        '%s (Lv.%d) spawned. %s',
        encounter.bossLabel,
        encounter.bossLevel,
        encounter.behaviorProfile.summary or ''
    ))
    tell(player, 'Live boss scaling active. Zero EXP/gil/loot/skill-ups. Auto-despawns in 10 minutes.')
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
        and math.max(R.MIN_LEVEL, math.min(R.MAX_LEVEL, player:getMainLvl()))
        or prev.bossLevel

    return A.startTrial(player, prev.bossType, targetLvl, {
        matchPlayerLevel = prev.matchPlayerLevel,
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
    end
    tell(player, 'Exiting Soul Proving Grounds to Ru\'Lude Gardens.')
    if player.setPos then
        player:setPos(EXIT_DEST.x, EXIT_DEST.y, EXIT_DEST.z, EXIT_DEST.rot, EXIT_DEST.zone)
    end
end

-- Native customMenu hierarchy (no chat commands required).
local rootMenu
local encounterTypeMenu
local levelMenu

levelMenu = function(player, bossType)
    local arch = R.ARCHETYPES[bossType]
    local options = {}
    for _, level in ipairs(R.LEVELS) do
        local chosen = level
        options[#options + 1] =
        {
            string.format('Level %d', chosen),
            function(p)
                A.startTrial(p, bossType, chosen, { matchPlayerLevel = false })
            end,
        }
    end
    options[#options + 1] =
    {
        'Match Player Level (10-75)',
        function(p)
            local lvl = math.max(R.MIN_LEVEL, math.min(R.MAX_LEVEL, p:getMainLvl()))
            A.startTrial(p, bossType, lvl, { matchPlayerLevel = true })
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
        title   = string.format('Crucible - %s Level', arch and arch.label or bossType),
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

rootMenu = function(player)
    local prev = player and player.getID and previousChoiceByChar[player:getID()] or nil
    local repeatLabel = 'Repeat Previous Encounter'
    if prev then
        local arch = R.ARCHETYPES[prev.bossType]
        local lvlLabel = prev.matchPlayerLevel and 'Match' or ('Lv.' .. tostring(prev.bossLevel))
        repeatLabel = string.format('Repeat: %s (%s)', arch and arch.label or prev.bossType, lvlLabel)
    end

    return
    {
        title = 'The Arbiter - Soul Proving Grounds',
        options =
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
            {
                'Exit Proving Grounds',
                function(p)
                    A.exitArena(p)
                end,
            },
            {
                'Close',
                function() end,
            },
        },
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

-- Cleanup on player death inside GM Home if all participating players are dead.
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

-- Safety net: clear any leftover skill-up lock whenever a player zones anywhere outside GM Home.
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player ~= nil and player.getZoneID and player:getZoneID() ~= ARENA_ZONE then
        R.applySkillupLock(player, false)
        if activeSession ~= nil and activeSession.ownerId == player:getID() then
            A.cleanupSession('owner_zoned_out', { despawnMob = true, notifyOwner = false })
        end
    end
end)

return m
