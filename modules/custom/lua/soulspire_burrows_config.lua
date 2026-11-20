-----------------------------------
-- SoulspireXI — Burrows Reborn: The First Descent (Configuration & Rules)
--
-- Shared pure-Lua configuration, party eligibility validation, encounter
-- scaling tables, Grudgeburrow adaptation calculator, and telemetry formatter.
-- Safe to load both inside LandSandBoat and in standalone Lua unit tests.
-----------------------------------
local hasServerRuntime = (Module ~= nil and Module.new ~= nil)
if hasServerRuntime then
    require('modules/module_utils')
end

xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.soulspire.burrows = xi.soulspire.burrows or {}
xi.soulspire.burrows.config = xi.soulspire.burrows.config or {}

local C = xi.soulspire.burrows.config

C.SCHEMA_VERSION   = '1.0.0'
C.SERVER_NAME      = 'SoulspireXI'
C.EXPEDITION_ID    = 'the_first_descent'
C.EXPEDITION_NAME  = 'Burrows Reborn: The First Descent'
C.INSTANCE_ID      = 12901
C.INSTANCE_ZONE_ID = (xi.zone and xi.zone.GHOYUS_REVERIE) or 129
C.EFFECTIVE_LEVEL  = 10
C.TIME_LIMIT_SEC   = 1800 -- 30 minutes
C.VICTORY_EXIT_SEC = 12   -- Grace period before safe return on victory
C.WIPE_EXIT_SEC    = 8    -- Grace period before safe return on full wipe
C.EMPTY_GRACE_SEC  = 20   -- Grace period before tearing down an empty instance
C.NPC_LOOK_ID      = 2433 -- Existing FFXI NPC model (no DAT edits)
C.LOG_BASE_DIR     = 'log/burrows_reborn'
C.LOG_RUNS_PATH    = 'log/burrows_reborn/runs.jsonl'

-- Safe hub locations accessible to fresh Level 10 players across all starting
-- nations plus Ru'Lude Gardens (each positioned clear of Starter Weapons Moogles).
C.HUB_GUIDES =
{
    {
        zoneName = 'Port_San_dOria',
        zoneId   = (xi.zone and xi.zone.PORT_SAN_DORIA) or 232,
        label    = 'Port San d\'Oria (Mog House Plaza)',
        x        = -2.500,
        y        = 0.000,
        z        = -2.000,
        rotation = 64,
        returnPos = { x = -1.500, y = 0.000, z = -3.500, rotation = 64 },
    },
    {
        zoneName = 'Bastok_Mines',
        zoneId   = (xi.zone and xi.zone.BASTOK_MINES) or 234,
        label    = 'Bastok Mines (Concourse)',
        x        = 80.000,
        y        = 0.000,
        z        = -64.102,
        rotation = 109,
        returnPos = { x = 80.000, y = 0.000, z = -62.500, rotation = 109 },
    },
    {
        zoneName = 'Port_Windurst',
        zoneId   = (xi.zone and xi.zone.PORT_WINDURST) or 240,
        label    = 'Port Windurst (Orastery Plaza)',
        x        = 181.500,
        y        = -11.999,
        z        = 217.730,
        rotation = 223,
        returnPos = { x = 181.500, y = -11.999, z = 216.000, rotation = 223 },
    },
    {
        zoneName = 'RuLude_Gardens',
        zoneId   = (xi.zone and xi.zone.RULUDE_GARDENS) or 243,
        label    = 'Ru\'Lude Gardens (Palace Terrace)',
        x        = 3.700,
        y        = 8.999,
        z        = -41.341,
        rotation = 128,
        returnPos = { x = 2.500, y = 8.999, z = -40.000, rotation = 128 },
    },
}

C.FALLBACK_RETURN =
{
    zoneId   = (xi.zone and xi.zone.RULUDE_GARDENS) or 243,
    x        = 0.000,
    y        = 3.000,
    z        = 2.000,
    rotation = 192,
}

-- Verified walkable chamber coordinates inside Ghoyu's Reverie (zone 129).
-- Players enter at the southern staging area (z=416) facing north (rot=192)
-- toward the open encounter floor (x=450..466, z=434..464).
C.ARENA_POS =
{
    entry        = { x = 458.000, y = 0.000, z = 416.000, rotation = 192 },
    guideNpc     = { x = 430.9652, y = 0.5000, z = 400.6440, rotation = 238 },
    shaman       = { x = 458.000, y = 0.200, z = 438.000, rotation = 64  },
    acolyte      = { x = 453.000, y = 0.200, z = 438.000, rotation = 64  },
    stoneguard   = { x = 458.000, y = 0.200, z = 442.000, rotation = 64  },
    grudgeburrow = { x = 458.000, y = 0.200, z = 446.000, rotation = 64  },
}

-- Two difficulty modes, both fighting at effective Level 10.
C.MODES =
{
    low_man =
    {
        id                 = 'low_man',
        label              = 'Low Man (1-3 Players)',
        shortLabel         = 'Low Man',
        description        = 'Balanced primarily around 2 players at effective Lv. 10.',
        minPlayers         = 1,
        maxPlayers         = 3,
        targetPlayers      = 2,
        shaman =
        {
            level                   = 10,
            hpMultiplier            = 0.85,
            ritualStartDelaySec     = 6,
            ritualDurationSec       = 28,
            ritualBreakHpPct        = 25, -- Burst >=25% HP during ritual breaks it (in addition to Stun/Silence/WS)
            spawnAcolyte            = false,
            acolyteLevel            = 10,
            acolyteHpMultiplier     = 0.55,
            magicCoolSec            = 14,
        },
        stoneguard =
        {
            level                   = 11,
            hpMultiplier            = 0.95,
            stanceIntervalSec       = 22,
            stanceDurationSec       = 12,
            exposedDurationSec      = 8,
            retaliationDmg          = 14,
            magicBreakThreshold     = 65, -- Cumulative magic damage during Iron Shell shatters it early
        },
        grudgeburrow =
        {
            level                   = 12,
            hpMultiplier            = 1.15,
            heavyTelegraphSec       = 5,
            heavyIntervalSec        = 22,
            heavyBaseDmg            = 72,
            aoeWarningSec           = 3,
            aoeIntervalSec          = 28,
            aoeBaseDmg              = 42,
            exposedDurationSec      = 8,
        },
    },
    full_party =
    {
        id                 = 'full_party',
        label              = 'Full Party (4-6 Players)',
        shortLabel         = 'Full Party',
        description        = 'Balanced primarily around 6 players at effective Lv. 10.',
        minPlayers         = 4,
        maxPlayers         = 6,
        targetPlayers      = 6,
        shaman =
        {
            level                   = 11,
            hpMultiplier            = 2.15,
            ritualStartDelaySec     = 6,
            ritualDurationSec       = 26,
            ritualBreakHpPct        = 22,
            spawnAcolyte            = true,
            acolyteLevel            = 10,
            acolyteHpMultiplier     = 0.90,
            magicCoolSec            = 11,
        },
        stoneguard =
        {
            level                   = 12,
            hpMultiplier            = 2.45,
            stanceIntervalSec       = 20,
            stanceDurationSec       = 12,
            exposedDurationSec      = 8,
            retaliationDmg          = 22,
            magicBreakThreshold     = 140,
        },
        grudgeburrow =
        {
            level                   = 13,
            hpMultiplier            = 2.85,
            heavyTelegraphSec       = 5,
            heavyIntervalSec        = 20,
            heavyBaseDmg            = 105,
            aoeWarningSec           = 3,
            aoeIntervalSec          = 26,
            aoeBaseDmg              = 58,
            exposedDurationSec      = 8,
        },
    },
}

C.MODE_ORDER = { 'low_man', 'full_party' }

-- Verified native Zone 129 (Ghoyu's Reverie) mob groups with non-zero visible
-- models and HP=0 so stats scale cleanly to Level 10-13.
C.ENCOUNTERS =
{
    shaman =
    {
        id            = 'shaman',
        stage         = 1,
        entityName    = 'Burrow_Shaman',
        packetName    = 'The Burrow Shaman',
        groupId       = 6892, -- Orcish_Hexspinner (BLM/BLM, visible model)
        groupZoneId   = 129,
        spellList     = 21,   -- Beastmen_BLM
        allowedSkills = { 606 }, -- shoulder_attack
    },
    acolyte =
    {
        id            = 'acolyte',
        stage         = 1,
        entityName    = 'Burrow_Acolyte',
        packetName    = 'Burrow Acolyte',
        groupId       = 6888, -- Old_Quadav (WAR/WAR, visible model)
        groupZoneId   = 129,
        spellList     = 0,
        allowedSkills = { 611, 612 }, -- ore_toss, head_butt_quadav
    },
    stoneguard =
    {
        id            = 'stoneguard',
        stage         = 2,
        entityName    = 'The_Stoneguard',
        packetName    = 'The Stoneguard',
        groupId       = 6888, -- Old_Quadav (WAR/WAR, visible model)
        groupZoneId   = 129,
        spellList     = 0,
        allowedSkills = { 612, 613 }, -- head_butt_quadav, shell_bash
        stanceSkillId = 614,          -- shell_guard (native animation)
    },
    grudgeburrow =
    {
        id            = 'grudgeburrow',
        stage         = 3,
        entityName    = 'Grudgeburrow',
        packetName    = 'Grudgeburrow',
        groupId       = 16,   -- Gigas_Flanker (WAR/WAR, visible model 275)
        groupZoneId   = 129,
        spellList     = 0,
        allowedSkills = { 664, 665 }, -- impact_roar, grand_slam
        aoeSkillId    = 665,          -- grand_slam
    },
}

function C.getHubConfigByZoneId(zoneId)
    for _, hub in ipairs(C.HUB_GUIDES) do
        if hub.zoneId == zoneId then
            return hub
        end
    end
    return nil
end

function C.getReturnPosForZoneId(zoneId)
    local hub = C.getHubConfigByZoneId(zoneId)
    if hub and hub.returnPos then
        return
        {
            zoneId   = hub.zoneId,
            x        = hub.returnPos.x,
            y        = hub.returnPos.y,
            z        = hub.returnPos.z,
            rotation = hub.returnPos.rotation,
        }
    end
    return
    {
        zoneId   = C.FALLBACK_RETURN.zoneId,
        x        = C.FALLBACK_RETURN.x,
        y        = C.FALLBACK_RETURN.y,
        z        = C.FALLBACK_RETURN.z,
        rotation = C.FALLBACK_RETURN.rotation,
    }
end

-- Validates party eligibility cleanly for Low Man (1-3) or Full Party (4-6).
-- Zero pheromone sacks, zero gil, zero grimoires, zero prerequisite runs, zero cooldowns.
function C.validatePartyEligibility(requester, partyMembers, modeKey, getUnsyncedLevelFn)
    local mode = C.MODES[modeKey]
    if not mode then
        return { ok = false, code = 'invalid_mode', reason = 'Unknown expedition difficulty mode.' }
    end

    if requester == nil or not requester.getID then
        return { ok = false, code = 'invalid_requester', reason = 'Unable to identify expedition leader.' }
    end

    local members = {}
    local seen = {}
    local function addMember(ent)
        if ent ~= nil and ent.getID and (not ent.isPC or ent:isPC()) then
            local id = ent:getID()
            if not seen[id] then
                seen[id] = true
                members[#members + 1] = ent
            end
        end
    end

    if type(partyMembers) == 'table' and #partyMembers > 0 then
        for _, m in ipairs(partyMembers) do
            addMember(m)
        end
    end
    if not seen[requester:getID()] then
        table.insert(members, 1, requester)
        seen[requester:getID()] = true
    end

    local count = #members
    if count > 6 then
        return
        {
            ok     = false,
            code   = 'alliance_not_allowed',
            reason = string.format('Alliances are not permitted (%d members detected). Form a party of 1-6 players.', count),
        }
    end

    -- Party leader check when in a multi-player party.
    if count > 1 and requester.getPartyLeader then
        local leader = requester:getPartyLeader()
        if leader ~= nil and leader.getID and leader:getID() ~= requester:getID() then
            return
            {
                ok     = false,
                code   = 'not_party_leader',
                reason = string.format(
                    'Only the party leader (%s) may initiate %s.',
                    leader.getName and leader:getName() or 'your leader',
                    C.EXPEDITION_NAME
                ),
            }
        end
    end

    if count < mode.minPlayers or count > mode.maxPlayers then
        return
        {
            ok     = false,
            code   = 'party_size_mismatch',
            reason = string.format(
                '%s requires %d-%d players (current party: %d). Choose %s instead.',
                mode.label,
                mode.minPlayers,
                mode.maxPlayers,
                count,
                (count <= 3) and C.MODES.low_man.label or C.MODES.full_party.label
            ),
        }
    end

    local reqZone = requester.getZoneID and requester:getZoneID() or 0
    for _, member in ipairs(members) do
        local name = (member.getName and member:getName()) or 'Party member'
        if member.getZoneID and member:getZoneID() ~= reqZone then
            return
            {
                ok     = false,
                code   = 'member_wrong_zone',
                reason = string.format('%s must be in the same zone as you before entering.', name),
            }
        end
        if member.isAlive and not member:isAlive() then
            return
            {
                ok     = false,
                code   = 'member_dead',
                reason = string.format('%s is incapacitated and must be raised before entering.', name),
            }
        end
        local lvl = 0
        if type(getUnsyncedLevelFn) == 'function' then
            lvl = tonumber(getUnsyncedLevelFn(member)) or 0
        elseif member.getMainLvl then
            lvl = tonumber(member:getMainLvl()) or 0
        end
        if lvl < C.EFFECTIVE_LEVEL then
            return
            {
                ok     = false,
                code   = 'member_below_level',
                reason = string.format(
                    '%s is Lv.%d. All participants must be at least Lv.%d to enter (higher levels sync down to Lv.%d).',
                    name,
                    lvl,
                    C.EFFECTIVE_LEVEL,
                    C.EFFECTIVE_LEVEL
                ),
            }
        end
    end

    return
    {
        ok      = true,
        code    = 'eligible',
        reason  = nil,
        mode    = mode,
        members = members,
    }
end

-- Computes Grudgeburrow's exact combat adaptations based on Encounters 1 & 2.
function C.computeBossAdaptations(outcomeState)
    outcomeState = outcomeState or {}
    local ritualBroken       = (outcomeState.shamanRitualBroken == true)
    local ritualEmpowered    = not ritualBroken
    local stoneguardDefeated = (outcomeState.stoneguardDefeated == true)
    local cleanBreak         = (outcomeState.stoneguardCleanBreak == true)

    local attackBonusPct     = ritualEmpowered and 18 or 0
    local defDeltaPct        = stoneguardDefeated and -25 or 25
    local physDtDeltaPct     = stoneguardDefeated and 15 or -20 -- Positive = takes MORE physical damage
    local heavyIntervalDelta = ritualEmpowered and -4 or 0
    local aoeIntervalDelta   = ritualEmpowered and -4 or 0
    local heavyDmgMult       = ritualEmpowered and 1.18 or 1.00
    local aoeDmgMult         = ritualEmpowered and 1.15 or 1.00
    local tremorAppliesDebuff = ritualEmpowered
    local exposedBonusDtPct  = cleanBreak and 35 or 30

    local summaryParts = {}
    if ritualEmpowered then
        summaryParts[#summaryParts + 1] = 'RITUAL EMPOWERED (+18% ATK, faster slams, Burrow Tremor inflicts Defense Down)'
    else
        summaryParts[#summaryParts + 1] = 'Ritual Denied (unempowered baseline)'
    end
    if stoneguardDefeated then
        summaryParts[#summaryParts + 1] = 'STONE ARMOR SHATTERED (-25% DEF, +15% physical damage taken)'
    else
        summaryParts[#summaryParts + 1] = 'Stone Armor Intact (+25% DEF, -20% physical damage taken)'
    end

    return
    {
        shamanRitualBroken    = ritualBroken,
        ritualEmpowered       = ritualEmpowered,
        stoneguardDefeated    = stoneguardDefeated,
        armorWeakened         = stoneguardDefeated,
        stoneguardCleanBreak  = cleanBreak,
        attackBonusPct        = attackBonusPct,
        defDeltaPct           = defDeltaPct,
        physDtDeltaPct        = physDtDeltaPct,
        heavyIntervalDeltaSec = heavyIntervalDelta,
        aoeIntervalDeltaSec   = aoeIntervalDelta,
        heavyDmgMult          = heavyDmgMult,
        aoeDmgMult            = aoeDmgMult,
        tremorAppliesDebuff   = tremorAppliesDebuff,
        exposedBonusDtPct     = exposedBonusDtPct,
        summary               = table.concat(summaryParts, ' | '),
    }
end

local function jsonEscape(str)
    local s = tostring(str or '')
    s = s:gsub('\\', '\\\\')
    s = s:gsub('"', '\\"')
    s = s:gsub('\n', '\\n')
    s = s:gsub('\r', '\\r')
    s = s:gsub('\t', '\\t')
    return '"' .. s .. '"'
end

local function encodeJsonValue(val)
    local t = type(val)
    if val == nil then
        return 'null'
    elseif t == 'boolean' then
        return val and 'true' or 'false'
    elseif t == 'number' then
        if val ~= val or val == math.huge or val == -math.huge then
            return 'null'
        end
        return tostring(val)
    elseif t == 'string' then
        return jsonEscape(val)
    elseif t == 'table' then
        local isArray = true
        local maxIdx = 0
        for k, _ in pairs(val) do
            if type(k) ~= 'number' or k <= 0 or math.floor(k) ~= k then
                isArray = false
                break
            end
            if k > maxIdx then
                maxIdx = k
            end
        end
        if isArray then
            local parts = {}
            for i = 1, maxIdx do
                parts[#parts + 1] = encodeJsonValue(val[i])
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
                parts[#parts + 1] = jsonEscape(k) .. ':' .. encodeJsonValue(val[k])
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    end
    return jsonEscape(tostring(val))
end

C.encodeJson = encodeJsonValue

function C.buildTelemetryRecord(session, outcome)
    session = session or {}
    local adaptations = session.bossAdaptations or C.computeBossAdaptations(session)
    return
    {
        schema_version          = C.SCHEMA_VERSION,
        server                  = C.SERVER_NAME,
        expedition              = C.EXPEDITION_ID,
        run_id                  = session.runId or 'burrows_unknown',
        mode                    = session.modeKey or 'low_man',
        effective_level         = C.EFFECTIVE_LEVEL,
        party_size              = session.initialPartySize or 0,
        souls                   = session.participantSouls or {},
        outcome                 = outcome or 'unknown',
        duration_sec            = session.elapsedSec or 0,
        stage_reached           = session.stage or 0,
        shaman_ritual_broken    = adaptations.shamanRitualBroken,
        stoneguard_defeated     = adaptations.stoneguardDefeated,
        stoneguard_clean_break  = adaptations.stoneguardCleanBreak,
        boss_ritual_empowered   = adaptations.ritualEmpowered,
        boss_armor_weakened     = adaptations.armorWeakened,
        rewards_suppressed      = true,
        exp_awarded             = 0,
        gil_awarded             = 0,
        items_awarded           = 0,
    }
end

if hasServerRuntime then
    if not C._moduleRegistered then
        C._moduleRegistered = true
        C._module = Module:new('soulspire_burrows_config')
    end
    return C._module
end

return C
