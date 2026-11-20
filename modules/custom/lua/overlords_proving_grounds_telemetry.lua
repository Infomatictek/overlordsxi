-----------------------------------
-- OverlordsXI Soul Proving Grounds — Server-Authoritative Combat Telemetry
--
-- Dedicated testing logger separate from any player-facing parser.
-- Attaches temporary listeners strictly to the active Proving Grounds trial mob
-- and participating combat actors (plus pets/clones), detaches cleanly on exit,
-- and exports machine-readable JSONL records.
--
-- Honesty guarantee:
--   Only metrics that can be measured accurately from authoritative server hooks
--   and entity state are reported numerically. Unsupported metrics emit explicit
--   "unavailable" values rather than fabricated estimates.
-----------------------------------
local hasServerRuntime = (Module ~= nil and Module.new ~= nil)
if hasServerRuntime then
    require('modules/module_utils')
    require('modules/custom/lua/overlords_proving_grounds_registry')
end

xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.provingGrounds = xi.overlords.provingGrounds or {}
xi.overlords.provingGrounds.telemetry = xi.overlords.provingGrounds.telemetry or {}

local T = xi.overlords.provingGrounds.telemetry

T.UNAVAILABLE       = 'unavailable'
T.DEFAULT_LOG_PATH  = 'log/proving_grounds_runs.jsonl'
T.BURST_WINDOW_SEC  = 10
T.SPIKE_HP_FRACTION = 0.25

local runSequence = 0

local DEFENSIVE_COOLDOWN_KEYWORDS =
{
    'defender', 'sentinel', 'rampart', 'invincible', 'palisade', 'reprisal',
    'third_eye', 'seigan', 'counterstance', 'dodge', 'chakra', 'perfect_dodge',
    'evasion', 'utsusemi', 'issekigan', 'battuta', 'vallation', 'valiance',
    'liement', 'pflug', 'one_for_all', 'phalanx', 'stoneskin', 'ward',
}

local function nowWallSec()
    if GetSystemTime then
        return GetSystemTime()
    end
    return os.time()
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

    local spec = xi and xi.overlords and xi.overlords.spec or nil
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

local function isPetOrCloneOf(entity, primaryActors)
    if entity == nil then
        return false
    end
    if entity.isPet and entity:isPet() then
        local master = entity.getMaster and entity:getMaster() or nil
        if master and master.getID and primaryActors[master:getID()] then
            return true
        end
    end
    -- Kurogane shadow clones / ally dynamic mobs carry owner attribution localVar or PLAYER allegiance
    if entity.isMob and entity:isMob() and entity.getAllegiance and xi.allegiance then
        if entity:getAllegiance() == xi.allegiance.PLAYER then
            return true
        end
    end
    return false
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

local function detectServerCommitSha(explicitSha)
    if type(explicitSha) == 'string' and explicitSha ~= '' then
        return explicitSha
    end
    return 'unknown'
end

-- Starts a new server-authoritative telemetry session for one encounter.
function T.beginSession(opts)
    opts = opts or {}
    local mob       = opts.mob
    local actors    = opts.actors or {}
    local encounter = opts.encounter or {}
    local clockFn   = opts.clockFn or nowWallSec

    runSequence = runSequence + 1
    local startWall = nowWallSec()
    local startClk  = clockFn()
    local runId     = opts.runId or string.format('pg_%d_%d', startWall, runSequence)

    local primaryActor = actors[1]
    local actorMap = {}
    for _, a in ipairs(actors) do
        if a and a.getID then
            actorMap[a:getID()] = a
        end
    end

    local soulInfo = resolveSoulIdentity(primaryActor)
    local tagPrefix = 'PG_TELEM_' .. runId .. '_'

    local session =
    {
        runId             = runId,
        testMode          = opts.testMode or 'manual',
        serverCommitSha   = detectServerCommitSha(opts.serverCommitSha),
        logPath           = opts.logPath or T.DEFAULT_LOG_PATH,
        encounter         = encounter,
        mob               = mob,
        actors            = actors,
        primaryActor      = primaryActor,
        actorMap          = actorMap,
        soulInfo          = soulInfo,
        clockFn           = clockFn,
        startWall         = startWall,
        startClock        = startClk,
        ended             = false,
        tagPrefix         = tagPrefix,
        boundEntities     = {},

        -- Internal rolling state
        damageTimeline    = {}, -- { t = elapsedSec, dmg = amount }
        lastTpByActor     = {},
        lastMpByActor     = {},
        lastHpByActor     = {},
        lastHealTimeSec   = nil,
        maxHealGapSec     = 0,
        lastThreatLeader  = nil,

        -- Measured counters
        counters =
        {
            -- Offense
            totalDamage          = 0,
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
            overhealing          = 0,
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

            -- Resources & Pets
            tpGenerated          = 0,
            tpSpent              = 0,
            buffSamples          = 0,
            activeBuffTotal      = 0,
            activeDebuffTotal    = 0,
            petSamples           = 0,
            petAliveSamples      = 0,
            petDeaths            = 0,
            petSeen              = false,

            -- Safety verification counters
            expEventsObserved    = 0,
            expPointsObserved    = 0,
        },
    }

    local function elapsedNow()
        return math.max(0, session.clockFn() - session.startClock)
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

    local function recordOffenseDamage(amount, sourceKind)
        local dmg = math.max(0, math.floor(tonumber(amount) or 0))
        if dmg <= 0 then
            return
        end
        local c = session.counters
        c.totalDamage = c.totalDamage + dmg
        if sourceKind == 'pet' then
            c.petAndCloneDamage = c.petAndCloneDamage + dmg
        elseif sourceKind == 'ws' then
            c.weaponSkillDamage = c.weaponSkillDamage + dmg
        elseif sourceKind == 'spell' then
            c.spellDamage = c.spellDamage + dmg
        elseif sourceKind == 'auto' then
            c.autoAttackDamage = c.autoAttackDamage + dmg
        else
            c.otherDamage = c.otherDamage + dmg
        end
        session.damageTimeline[#session.damageTimeline + 1] =
        {
            t   = elapsedNow(),
            dmg = dmg,
        }
    end

    local function sampleResourcesAndThreat()
        if session.ended then
            return
        end
        local c = session.counters

        for _, actor in ipairs(session.actors) do
            if actor and actor.getID then
                local id = actor:getID()

                -- TP tracking (positive deltas = generated)
                if actor.getTP then
                    local curTp = actor:getTP() or 0
                    local prevTp = session.lastTpByActor[id]
                    if prevTp ~= nil and curTp > prevTp then
                        c.tpGenerated = c.tpGenerated + (curTp - prevTp)
                    end
                    session.lastTpByActor[id] = curTp
                end

                -- MP tracking (negative deltas = consumed, positive deltas = recovered)
                if actor.getMP then
                    local curMp = actor:getMP() or 0
                    local prevMp = session.lastMpByActor[id]
                    if prevMp ~= nil then
                        if curMp < prevMp then
                            c.mpConsumed = c.mpConsumed + (prevMp - curMp)
                        elseif curMp > prevMp then
                            c.mpRecovered = c.mpRecovered + (curMp - prevMp)
                        end
                    end
                    session.lastMpByActor[id] = curMp
                end

                -- Pet presence & survival sampling
                if actor.hasPet and actor:hasPet() and actor.getPet then
                    local pet = actor:getPet()
                    if pet ~= nil then
                        c.petSeen = true
                        c.petSamples = c.petSamples + 1
                        if not pet.isAlive or pet:isAlive() then
                            c.petAliveSamples = c.petAliveSamples + 1
                        end
                    end
                elseif c.petSeen then
                    c.petSamples = c.petSamples + 1
                end

                -- Buff count sampling
                if actor.getStatusEffects then
                    local effects = actor:getStatusEffects()
                    if type(effects) == 'table' then
                        c.buffSamples = c.buffSamples + 1
                        c.activeBuffTotal = c.activeBuffTotal + #effects
                    end
                end
            end
        end

        -- Mob debuff & threat sampling
        if session.mob ~= nil and (not session.mob.isAlive or session.mob:isAlive()) then
            if session.mob.getStatusEffects then
                local mobEffects = session.mob:getStatusEffects()
                if type(mobEffects) == 'table' then
                    c.activeDebuffTotal = c.activeDebuffTotal + #mobEffects
                end
            end

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
                    local curTargetId = currentTarget.getID and currentTarget:getID() or nil
                    local primaryId = session.primaryActor.getID and session.primaryActor:getID() or nil
                    if curTargetId ~= nil and curTargetId == primaryId then
                        c.primaryTargetSamples = c.primaryTargetSamples + 1
                    end
                    if session.lastThreatLeader ~= nil and session.lastThreatLeader == primaryId and curTargetId ~= primaryId then
                        c.threatLosses = c.threatLosses + 1
                    end
                    session.lastThreatLeader = curTargetId
                end
            end
        end
    end

    session.sampleNow = sampleResourcesAndThreat

    -- Seed initial resource readings
    for _, actor in ipairs(actors) do
        if actor and actor.getID then
            local id = actor:getID()
            if actor.getTP then session.lastTpByActor[id] = actor:getTP() or 0 end
            if actor.getMP then session.lastMpByActor[id] = actor:getMP() or 0 end
            if actor.getHP then session.lastHpByActor[id] = actor:getHP() or 0 end
        end
    end

    -- Bind mob-side listeners (damage taken by boss, boss swings)
    if mob ~= nil then
        -- Track recent WS damage flag to avoid double-counting WS inside TAKE_DAMAGE
        session.pendingWsCredit = 0

        bindListener(mob, 'TAKE_DAMAGE', 'MOB_DMG', function(defender, amount, attacker, attackType, damageType)
            if session.ended then
                return
            end
            local dmg = math.max(0, math.floor(tonumber(amount) or 0))
            if dmg <= 0 then
                return
            end
            if isPetOrCloneOf(attacker, session.actorMap) then
                recordOffenseDamage(dmg, 'pet')
            elseif attacker and attacker.getID and session.actorMap[attacker:getID()] then
                if session.pendingWsCredit > 0 then
                    session.pendingWsCredit = session.pendingWsCredit - 1
                    -- Already credited in WEAPONSKILL_USE
                    return
                end
                if xi.attackType and attackType == xi.attackType.MAGICAL then
                    recordOffenseDamage(dmg, 'spell')
                else
                    recordOffenseDamage(dmg, 'auto')
                end
            end
        end)

        bindListener(mob, 'MELEE_SWING_HIT', 'MOB_SWING_HIT', function(attacker, target, attack)
            if session.ended then
                return
            end
            if target and target.getID and session.actorMap[target:getID()] then
                session.counters.incomingSwingsHit = session.counters.incomingSwingsHit + 1
            end
        end)

        bindListener(mob, 'MELEE_SWING_MISS', 'MOB_SWING_MISS', function(attacker, target, attack)
            if session.ended then
                return
            end
            if target and target.getID and session.actorMap[target:getID()] then
                session.counters.incomingSwingsMissed = session.counters.incomingSwingsMissed + 1
            end
        end)

        bindListener(mob, 'EFFECTS_TICK', 'MOB_TICK', function()
            sampleResourcesAndThreat()
        end)
    end

    -- Bind actor-side listeners
    for idx, actor in ipairs(actors) do
        if actor ~= nil then
            local pfx = 'A' .. tostring(idx) .. '_'

            bindListener(actor, 'MELEE_SWING_HIT', pfx .. 'HIT', function(att, targ, attack)
                if session.ended then
                    return
                end
                session.counters.meleeHits = session.counters.meleeHits + 1
                if attack and attack.isCritical and attack:isCritical() then
                    session.counters.critHits = session.counters.critHits + 1
                end
            end)

            bindListener(actor, 'MELEE_SWING_MISS', pfx .. 'MISS', function(att, targ, attack)
                if session.ended then
                    return
                end
                session.counters.meleeMisses = session.counters.meleeMisses + 1
            end)

            bindListener(actor, 'WEAPONSKILL_USE', pfx .. 'WS', function(att, targ, skill, spentTP, action, damage)
                if session.ended then
                    return
                end
                local c = session.counters
                c.wsUses = c.wsUses + 1
                c.tpSpent = c.tpSpent + math.max(0, math.floor(tonumber(spentTP) or 0))
                local wsDmg = math.max(0, math.floor(tonumber(damage) or 0))
                if wsDmg > 0 then
                    session.pendingWsCredit = (session.pendingWsCredit or 0) + 1
                    recordOffenseDamage(wsDmg, 'ws')
                end
                sampleResourcesAndThreat()
            end)

            bindListener(actor, 'ABILITY_USE', pfx .. 'JA', function(user, targ, ability, action)
                if session.ended then
                    return
                end
                session.counters.abilityUses = session.counters.abilityUses + 1
                local abName = ability and ability.getName and ability:getName() or ''
                if isDefensiveAbilityName(abName) then
                    session.counters.defensiveCdUses = session.counters.defensiveCdUses + 1
                end
                sampleResourcesAndThreat()
            end)

            bindListener(actor, 'MAGIC_USE', pfx .. 'MAG', function(caster, targ, spell, action)
                if session.ended then
                    return
                end
                local c = session.counters
                c.spellCasts = c.spellCasts + 1
                -- Track healing spells cast on participating actors
                if targ and targ.getID and session.actorMap[targ:getID()] and action and action.getParam then
                    local spellGroup = spell and spell.getSpellGroup and spell:getSpellGroup() or nil
                    local healedAmt = tonumber(action:getParam(targ:getID())) or 0
                    if healedAmt > 0 and (spellGroup == nil or (xi.magic and xi.magic.spellGroup and spellGroup == xi.magic.spellGroup.WHITE)) then
                        local maxHp = targ.getMaxHP and targ:getMaxHP() or 0
                        local curHp = targ.getHP and targ:getHP() or 0
                        -- Estimate effective heal cleanly when HP was below max
                        local eff = math.min(healedAmt, math.max(0, maxHp))
                        c.effectiveHealing = c.effectiveHealing + eff
                        c.healEvents = c.healEvents + 1
                        local tNow = elapsedNow()
                        if session.lastHealTimeSec ~= nil then
                            local gap = tNow - session.lastHealTimeSec
                            if gap > session.maxHealGapSec then
                                session.maxHealGapSec = gap
                            end
                        end
                        session.lastHealTimeSec = tNow
                    end
                end
                sampleResourcesAndThreat()
            end)

            bindListener(actor, 'MAGIC_INTERRUPTED', pfx .. 'MAGINT', function()
                if session.ended then
                    return
                end
                session.counters.spellInterrupts = session.counters.spellInterrupts + 1
            end)

            bindListener(actor, 'TAKE_DAMAGE', pfx .. 'TDMG', function(defender, amount, attacker)
                if session.ended then
                    return
                end
                local dmg = math.max(0, math.floor(tonumber(amount) or 0))
                if dmg <= 0 then
                    return
                end
                local c = session.counters
                c.actualIncomingDamage = c.actualIncomingDamage + dmg
                c.incomingHits = c.incomingHits + 1
                if dmg > c.maxDamageSpike then
                    c.maxDamageSpike = dmg
                end
                local maxHp = defender.getMaxHP and defender:getMaxHP() or 0
                if maxHp > 0 and dmg >= (maxHp * T.SPIKE_HP_FRACTION) then
                    c.spikeHitCount = c.spikeHitCount + 1
                end
            end)

            bindListener(actor, 'DEATH', pfx .. 'DEATH', function()
                if session.ended then
                    return
                end
                session.counters.deaths = session.counters.deaths + 1
            end)

            bindListener(actor, 'EXPERIENCE_POINTS', pfx .. 'EXP', function(pc, killedMob, exp)
                if session.ended then
                    return
                end
                session.counters.expEventsObserved = session.counters.expEventsObserved + 1
                session.counters.expPointsObserved = session.counters.expPointsObserved + (tonumber(exp) or 0)
            end)

            bindListener(actor, 'EFFECTS_TICK', pfx .. 'TICK', function()
                sampleResourcesAndThreat()
            end)
        end
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
end

-- Finalizes a telemetry session, computes authoritative metrics, detaches listeners,
-- and writes a JSONL line (unless opts.writeLog == false).
function T.finishSession(session, outcome, opts)
    if session == nil then
        return nil
    end
    opts = opts or {}

    if not session.ended then
        if session.sampleNow then
            pcall(session.sampleNow)
        end
        session.ended = true
    end

    T.detachSession(session)

    local durationSec = tonumber(opts.durationSec)
    if durationSec == nil then
        durationSec = math.max(0.001, session.clockFn() - session.startClock)
    end
    durationSec = math.max(0.001, durationSec)

    local c = session.counters
    local totalSwings = c.meleeHits + c.meleeMisses
    local hitRate = totalSwings > 0 and round4(c.meleeHits / totalSwings) or T.UNAVAILABLE
    local critRate = c.meleeHits > 0 and round4(c.critHits / c.meleeHits) or T.UNAVAILABLE

    local sustainedDps = round4(c.totalDamage / durationSec)
    local burstDps     = computePeakBurstDps(session.damageTimeline, T.BURST_WINDOW_SEC)
    local petDps       = c.petSeen and round4(c.petAndCloneDamage / durationSec) or 0
    local petUptimePct = (c.petSeen and c.petSamples > 0) and round4((c.petAliveSamples / c.petSamples) * 100) or T.UNAVAILABLE
    local petSurvival  = c.petSeen and (c.petDeaths == 0 and c.petAliveSamples > 0) or T.UNAVAILABLE

    local aggroUptimePct = c.threatSamples > 0 and round4((c.primaryTargetSamples / c.threatSamples) * 100) or T.UNAVAILABLE
    local hps            = round4(c.effectiveHealing / durationSec)
    local mpEfficiency   = c.mpConsumed > 0 and round4((c.totalDamage + c.effectiveHealing) / c.mpConsumed) or T.UNAVAILABLE
    local avgBuffCount   = c.buffSamples > 0 and round4(c.activeBuffTotal / c.buffSamples) or T.UNAVAILABLE

    local enc = session.encounter or {}
    local soul = session.soulInfo or {}

    local record =
    {
        run_id                 = session.runId,
        timestamp_utc          = os.date('!%Y-%m-%dT%H:%M:%SZ', session.startWall),
        encounter_id           = enc.encounterId or 'unknown',
        encounter_version      = enc.version or '1.0.0',
        soul_name              = soul.soul_name or 'None',
        soul_key               = soul.soul_key or 'none',
        job                    = soul.job or 'UNKNOWN',
        role                   = soul.role or 'Unassigned',
        tier                   = soul.tier or 'Unassigned',
        character_level        = enc.playerLevel or soul.level or 0,
        boss_type              = enc.bossType or 'unknown',
        boss_level             = enc.bossLevel or 0,
        level_gap              = enc.levelGap or 0,
        difficulty             = enc.difficulty or 'even_match',
        boss_preset            = enc.bossPreset or 'normal',
        gear_profile           = enc.gearProfile or 'unknown',
        party_composition      = enc.partyComposition or 'solo',
        encounter_duration_sec = round4(durationSec),
        server_commit_sha      = session.serverCommitSha,
        test_mode              = session.testMode,
        outcome                = tostring(outcome or 'completed'),
        seed                   = enc.seed ~= nil and enc.seed or T.UNAVAILABLE,
        metrics =
        {
            offense =
            {
                total_damage         = c.totalDamage,
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
                healing_downtime_sec = c.healEvents > 1 and round4(session.maxHealGapSec) or T.UNAVAILABLE,
            },
            threat =
            {
                enmity_generation    = c.maxTotalEnmity,
                max_ce               = c.maxCe,
                max_ve               = c.maxVe,
                threat_samples       = c.threatSamples,
                tank_aggro_uptime_pct = aggroUptimePct,
                threat_losses        = c.threatLosses,
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
                soul_specific_metrics = T.UNAVAILABLE,
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
            raw_incoming_damage    = 'unavailable: TAKE_DAMAGE listener receives post-mitigation final damage only',
            mitigated_damage       = 'unavailable: depends on raw_incoming_damage',
            block_parry_evade_split = 'unavailable: MELEE_SWING_MISS aggregates dodge/parry/shadow misses without split',
            overhealing            = 'unavailable: MAGIC_USE action param reports applied HP recovery without pre-cap amount',
            soul_specific_metrics  = 'unavailable: per-Soul custom gauge hooks not yet instrumented in Stage B POC',
        },
    }

    if opts.writeLog ~= false then
        local path = opts.logPath or session.logPath or T.DEFAULT_LOG_PATH
        pcall(function()
            local fh = io.open(path, 'a')
            if fh then
                fh:write(T.encodeJson(record) .. '\n')
                fh:close()
            end
        end)
    end

    return record
end

return T
