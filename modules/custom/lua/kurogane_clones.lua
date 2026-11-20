-----------------------------------
-- OverlordsXI Shinobi (internal key: kurogane) — dynamic Shadow Clone backend
-- & Feint -> Switch -> Cascade Tactical Squad Command Engine
--
-- Real dynamic MOB entities are used so every clone has its own native AI,
-- pathing, HP, independent attack timer, and AoE vulnerability.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')

local m = Module:new('kurogane_clones')

xi.overlords = xi.overlords or {}
xi.overlords.kurogane = xi.overlords.kurogane or {}
local K = xi.overlords.kurogane
local spec = xi.overlords.spec

-- Production default: enabled unless explicitly toggled off by GM/tests.
if K.ENABLE_EXPERIMENTAL_CLONES == nil then
    K.ENABLE_EXPERIMENTAL_CLONES = true
end
if K.ENABLE_EXPERIMENTAL_COMBAT == nil then
    K.ENABLE_EXPERIMENTAL_COMBAT = true
end
K.MAX_ACTIVE = 5
K.LIFETIME_MIN = 25
K.LIFETIME_MAX = 30
-- Glass-cannon baseline: clamp(20 + (ownerLevel * 2), 40, 170) -> 170 HP at Lv.75.
-- Survives minor spikes and 1 incidental AoE (-30% magic splash), dies to
-- heavy boss AoE and direct melee hits. Never derives HP from owner gear.
K.HP_BASE = 20
K.HP_PER_LEVEL = 2
K.HP_MIN = 40
K.HP_MAX = 170
K.MAX_ENGAGE_ATTEMPTS = 3
-- Production Tier-1 shadow-clone melee tuning: 5 living clones collectively
-- contribute ~25-35% of total Shinobi DPS without inheriting random monster
-- damage bonuses or uncontrolled multi-hit procs.
K.CLONE_PHYS_DMG_MOD = -60
K.EXPERIMENTAL_PHYS_DAMAGE_PENALTY = K.CLONE_PHYS_DMG_MOD
-- Modest magic splash dampening (-30% MDT) so incidental spikes/AoE do not
-- instantly delete a healthy squad, while heavy boss AoE & direct hits remain lethal.
K.CLONE_MAGIC_DMG_TAKEN_MOD = -3000

-- Existing JA constants (preserved)
K.PHANTOM_ASSAULT_DURATION = 8
K.PHANTOM_ASSAULT_DELAY_MULT = 0.75 -- 25% shorter native autoattack interval (~33.3% higher frequency)

-- Tactical cycle constants (server-authoritative Feint -> Switch -> Cascade)
K.PHASE_BUILDING     = 0
K.PHASE_FEINT        = 1
K.PHASE_SWITCH       = 2
K.PHASE_CASCADE      = 3
K.BUILD_FEINT_WINDOW = 6   -- seconds for 2 distinct living clones to land verified hits
K.PHASE_DURATION     = 20  -- seconds before active tactical phase expires
K.OPENING_DURATION   = 12  -- False Assault owner-only offensive opening window
K.MIRROR_STEP_DUR    = 10  -- (+2s with Opening) alternating rhythm shift
K.SHADOW_PIN_DUR     = 12  -- (+2s with Opening) concentrated focus window
K.MIRROR_CADENCE_SEC = 3   -- seconds per alternating fast/heavy cadence beat
K.MAX_CLONE_PHYS_DELTA = 36 -- hard cap on temporary clone PHYS_DMG_DEALT bonus (-60 + 36 = -24 max)

K.PHASE_NAMES =
{
    [0] = 'Building',
    [1] = 'Feint',
    [2] = 'Switch',
    [3] = 'Cascade',
}

K.COMMAND_TAGS =
{
    false_assault   = 'FA',
    mirror_step     = 'MS',
    crosscut        = 'CC',
    shadow_pin      = 'SP',
    thunder_relay   = 'TR',
    final_mirage    = 'FM',
    shadow_legion   = 'SL',
    phantom_assault = 'PA',
}

K._owners = K._owners or {}
K._serial = K._serial or 0

local OWNER_DEATH_LISTENER = 'OX_KRG_CLONE_OWNER_DEATH'
local OWNER_DISENGAGE_LISTENER = 'OX_KRG_CLONE_OWNER_DISENGAGE'
local ATTACK_LISTENER = 'OX_KRG_CLONE_ATTACK'
local DEATH_LISTENER = 'OX_KRG_CLONE_DEATH'
local DESPAWN_LISTENER = 'OX_KRG_CLONE_DESPAWN'
local LOOK_FIELDS = { 'face', 'race', 'head', 'body', 'hands', 'legs', 'feet', 'main', 'sub', 'ranged', 'modelSize' }

local function nowSec()
    if xi.overlords and xi.overlords.nowSec then
        return xi.overlords.nowSec()
    end
    return os.time()
end

local function newTacticsState()
    return {
        phase           = K.PHASE_BUILDING,
        phaseExpiresAt  = 0,
        lastCommandId   = nil,
        recentHits      = {},
        openingUntil    = 0,
        openingSource   = nil,
        mirrorUntil     = 0,
        mirrorStartedAt = 0,
        mirrorEmpowered = false,
        pinUntil        = 0,
        pinEmpowered    = false,
        pinTargetId     = 0,
    }
end

local function isKurogane(player)
    if not player or not player.isPC or not player:isPC() or
        player:getMainJob() ~= xi.job.NIN or player:getMainLvl() < 10 then
        return false
    end

    -- Avoid recursive spec.refreshPlayer/onApply calls while reading the Soul.
    return spec.is(player, xi.job.NIN, 'kurogane')
end

local function zoneId(entity)
    if not entity then
        return nil
    end

    if entity.getZoneID then
        return entity:getZoneID()
    end

    local zone = entity.getZone and entity:getZone() or nil
    return zone and zone.getID and zone:getID() or nil
end

local function isValidTarget(owner, target, requireAlive)
    local ownerZone = zoneId(owner)
    local targetAlive = target and target.isAlive and target:isAlive() or false
    return owner and target and ownerZone ~= nil and owner.isAlive and owner:isAlive() and
        target.isMob and target:isMob() and (not requireAlive or targetAlive) and
        ownerZone == zoneId(target)
end

local function ownerTargets(owner, targetId, requireAlive)
    if not owner or not owner.isEngaged or not owner:isEngaged() then
        return false
    end

    local target = owner.getTarget and owner:getTarget() or nil
    return isValidTarget(owner, target, requireAlive) and target:getID() == targetId
end

local function ownerStillFighting(owner, targetId)
    return ownerTargets(owner, targetId, true)
end

local function pruneTactics(state, now)
    if not state then
        return nil
    end
    local tactics = state.tactics
    if not tactics then
        tactics = newTacticsState()
        state.tactics = tactics
    end

    -- Expire timed windows deterministically on server time.
    if tactics.phase > K.PHASE_BUILDING and now >= (tactics.phaseExpiresAt or 0) then
        tactics.phase = K.PHASE_BUILDING
        tactics.phaseExpiresAt = 0
        tactics.lastCommandId = nil
        tactics.recentHits = {}
    end
    if tactics.openingUntil > 0 and now >= tactics.openingUntil then
        tactics.openingUntil = 0
        tactics.openingSource = nil
    end
    if tactics.mirrorUntil > 0 and now >= tactics.mirrorUntil then
        tactics.mirrorUntil = 0
        tactics.mirrorStartedAt = 0
        tactics.mirrorEmpowered = false
    end
    if tactics.pinUntil > 0 and (now >= tactics.pinUntil or tactics.pinTargetId ~= state.targetId) then
        tactics.pinUntil = 0
        tactics.pinEmpowered = false
        tactics.pinTargetId = 0
    end

    -- Prune recent Build-Feint hits to only living clones within BUILD_FEINT_WINDOW.
    local livingIds = {}
    for _, record in ipairs(state.clones or {}) do
        if record.mob and record.mob.isAlive and record.mob:isAlive() and (record.expiresAt or 0) > now then
            livingIds[record.mobId] = true
        end
    end
    local distinct = 0
    for mobId, hitAt in pairs(tactics.recentHits) do
        if not livingIds[mobId] or (now - hitAt) > K.BUILD_FEINT_WINDOW then
            tactics.recentHits[mobId] = nil
        else
            distinct = distinct + 1
        end
    end
    tactics.distinctHits = math.min(2, distinct)
    return tactics
end

local function applyModDelta(mob, modId, currentApplied, targetVal)
    local delta = targetVal - (currentApplied or 0)
    if delta ~= 0 and mob and mob.addMod and modId then
        pcall(function() mob:addMod(modId, delta) end)
    end
    return targetVal
end

-- Deterministic, idempotent recalculation of temporary delay/damage/acc mods
-- for a single clone. Prevents stacking leaks across Phantom Assault, Mirror
-- Step, and Shadow Pin, and guarantees clean restoration on expiry/dismissal.
local function recomputeCloneCombatMods(record, state, now, livingCount)
    if not record or not record.mob then
        return
    end
    local mob = record.mob
    local baseDelay = record.baseDelay or 240
    local delayMult = 1.0
    local targetPhys = 0
    local targetAcc = 0

    if record.phantomActive then
        if now < (record.phantomExpiresAt or 0) then
            delayMult = delayMult * K.PHANTOM_ASSAULT_DELAY_MULT
        else
            record.phantomActive = false
            record.phantomExpiresAt = 0
        end
    end

    local tactics = state and state.tactics or nil
    if tactics then
        if (tactics.mirrorUntil or 0) > now then
            local beat = math.floor(math.max(0, now - (tactics.mirrorStartedAt or now)) / K.MIRROR_CADENCE_SEC)
            local parity = ((record.slotParity or 0) + beat) % 2
            -- Reward maintaining multiple living clones (+4% per extra living clone, up to +16% at 5).
            local multiBonus = 4 * math.min(4, math.max(0, (livingCount or 1) - 1))
            targetPhys = targetPhys + multiBonus
            if parity == 0 then
                -- Fast cadence beat
                delayMult = delayMult * 0.85
            else
                -- Heavy cadence beat
                targetPhys = targetPhys + (tactics.mirrorEmpowered and 18 or 14)
            end
        end

        if (tactics.pinUntil or 0) > now and tactics.pinTargetId == state.targetId then
            targetPhys = targetPhys + (tactics.pinEmpowered and 14 or 10)
            targetAcc = targetAcc + (tactics.pinEmpowered and 35 or 25)
        end
    end

    targetPhys = math.max(0, math.min(K.MAX_CLONE_PHYS_DELTA, targetPhys))
    local targetDelay = math.max(100, math.floor(baseDelay * delayMult + 0.5))

    if record.appliedDelay ~= targetDelay and mob.setDelay then
        pcall(function() mob:setDelay(targetDelay) end)
        record.appliedDelay = targetDelay
    end
    if xi.mod then
        record.appliedPhysDelta = applyModDelta(mob, xi.mod.PHYS_DMG_DEALT, record.appliedPhysDelta, targetPhys)
        record.appliedAccDelta = applyModDelta(mob, xi.mod.ACC, record.appliedAccDelta, targetAcc)
    end
end

local function restoreCloneMods(record)
    if not record then
        return
    end
    local mob = record.mob
    if mob then
        if record.baseDelay and record.appliedDelay ~= record.baseDelay and mob.setDelay then
            pcall(function() mob:setDelay(record.baseDelay) end)
        end
        if xi.mod then
            record.appliedPhysDelta = applyModDelta(mob, xi.mod.PHYS_DMG_DEALT, record.appliedPhysDelta, 0)
            record.appliedAccDelta = applyModDelta(mob, xi.mod.ACC, record.appliedAccDelta, 0)
        end
    end
    record.appliedDelay = record.baseDelay
    record.phantomActive = false
    record.phantomExpiresAt = 0
end

local function recomputeAllCloneMods(state, now)
    if not state or not state.clones then
        return
    end
    local livingCount = 0
    for _, record in ipairs(state.clones) do
        if record.mob and record.mob.isAlive and record.mob:isAlive() and (record.expiresAt or 0) > now then
            livingCount = livingCount + 1
        end
    end
    for _, record in ipairs(state.clones) do
        if record.mob and record.mob.isAlive and record.mob:isAlive() and (record.expiresAt or 0) > now then
            recomputeCloneCombatMods(record, state, now, livingCount)
        end
    end
end

local function setCount(owner, state)
    if not owner or not owner.setLocalVar then
        return
    end

    local now = nowSec()
    owner:setLocalVar('OX_KRG_CLONE_COUNT', state and #state.clones or 0)
    local remaining = 0
    local phantomRem = 0
    if state and #state.clones > 0 then
        for _, record in ipairs(state.clones) do
            local left = math.max(0, record.expiresAt - now)
            if remaining == 0 or left < remaining then
                remaining = left
            end
            if record.phantomActive and (record.phantomExpiresAt or 0) > now then
                local pLeft = record.phantomExpiresAt - now
                if pLeft > phantomRem then
                    phantomRem = pLeft
                end
            end
        end
    end

    local tactics = state and pruneTactics(state, now) or nil
    local phase = tactics and tactics.phase or 0
    local phaseRem = (tactics and phase > 0) and math.max(0, math.ceil((tactics.phaseExpiresAt or 0) - now)) or 0
    local feintHits = tactics and (tactics.distinctHits or 0) or 0
    local openingRem = (tactics and (tactics.openingUntil or 0) > now) and math.max(0, math.ceil(tactics.openingUntil - now)) or 0

    owner:setLocalVar('OX_KRG_NEXT_EXP', math.ceil(remaining))
    owner:setLocalVar('OX_KRG_PHANTOM_REM', math.ceil(phantomRem))
    owner:setLocalVar('OX_KRG_PHASE', phase)
    owner:setLocalVar('OX_KRG_PHASE_REM', phaseRem)
    owner:setLocalVar('OX_KRG_FEINT_HITS', feintHits)
    owner:setLocalVar('OX_KRG_OPENING_REM', openingRem)
end

local function removeOwnerListeners(owner)
    if owner and owner.removeListener then
        pcall(function() owner:removeListener(OWNER_DEATH_LISTENER) end)
        pcall(function() owner:removeListener(OWNER_DISENGAGE_LISTENER) end)
    end
end

local function clearCloneEnmity(record)
    if not record or not record.mob then
        return
    end
    local mob = record.mob
    local target = nil
    if record.targetId and type(GetMobByID) == 'function' then
        local ok, t = pcall(GetMobByID, record.targetId)
        if ok then
            target = t
        end
    end
    -- Remove the clone from the target's enmity container BEFORE the dynamic
    -- entity is despawned/freed (prevents dangling PEnmityOwner pointers!).
    if target and target.clearEnmityForEntity then
        pcall(function() target:clearEnmityForEntity(mob) end)
    end
    if target and mob.clearEnmityForEntity then
        pcall(function() mob:clearEnmityForEntity(target) end)
    end
end

local function dismissMob(record)
    if not record or not record.mob then
        return
    end

    clearCloneEnmity(record)
    restoreCloneMods(record)
    local mob = record.mob
    if mob.removeListener then
        pcall(function() mob:removeListener(ATTACK_LISTENER) end)
        pcall(function() mob:removeListener(DEATH_LISTENER) end)
        pcall(function() mob:removeListener(DESPAWN_LISTENER) end)
    end

    local shouldDespawn = true
    if mob.isSpawned then
        local ok, spawned = pcall(function() return mob:isSpawned() end)
        shouldDespawn = not ok or spawned
    end

    if shouldDespawn and type(DespawnMob) == 'function' then
        pcall(DespawnMob, mob:getID())
    elseif shouldDespawn and mob.setStatus then
        pcall(function() mob:setStatus(xi.status.DISAPPEAR) end)
    end
end

local function removeAt(state, index, despawn)
    local record = table.remove(state.clones, index)
    if despawn ~= false then
        dismissMob(record)
    end
    return record
end

local function clearStateIfEmpty(ownerId, state)
    if #state.clones > 0 then
        return
    end

    state.timerRunning = false
    state.tactics = newTacticsState()
    if K._owners[ownerId] == state then
        K._owners[ownerId] = nil
    end

    local owner = type(GetPlayerByID) == 'function' and GetPlayerByID(ownerId) or nil
    if owner then
        removeOwnerListeners(owner)
        setCount(owner, nil)
    end
end

local function forgetMob(ownerId, mobId)
    local state = K._owners[ownerId]
    if not state then
        return
    end

    for index = #state.clones, 1, -1 do
        if state.clones[index].mobId == mobId then
            removeAt(state, index, false)
            break
        end
    end

    if state.tactics and state.tactics.recentHits then
        state.tactics.recentHits[mobId] = nil
    end

    local owner = type(GetPlayerByID) == 'function' and GetPlayerByID(ownerId) or nil
    if #state.clones > 0 then
        recomputeAllCloneMods(state, nowSec())
        if owner then
            setCount(owner, state)
        end
    else
        clearStateIfEmpty(ownerId, state)
    end
end

function K.resetTactics(owner)
    if not owner or not owner.getID then
        return
    end
    local state = K._owners[owner:getID()]
    if state then
        state.tactics = newTacticsState()
        recomputeAllCloneMods(state, nowSec())
    end
    setCount(owner, state)
end

function K.dismissAll(owner)
    if not owner or not owner.getID then
        return
    end

    local ownerId = owner:getID()
    local state = K._owners[ownerId]
    if state then
        -- Clear the table first so entity callbacks cannot re-enter this state.
        K._owners[ownerId] = nil
        state.timerRunning = false
        state.tactics = newTacticsState()
        for index = #state.clones, 1, -1 do
            removeAt(state, index, true)
        end
    end

    removeOwnerListeners(owner)
    setCount(owner, nil)
end

function K.dismissAllOwners()
    local ownerIds = {}
    for ownerId in pairs(K._owners) do
        ownerIds[#ownerIds + 1] = ownerId
    end

    for _, ownerId in ipairs(ownerIds) do
        local owner = type(GetPlayerByID) == 'function' and GetPlayerByID(ownerId) or nil
        if owner then
            K.dismissAll(owner)
        else
            local state = K._owners[ownerId]
            K._owners[ownerId] = nil
            if state then
                state.tactics = newTacticsState()
                for index = #state.clones, 1, -1 do
                    removeAt(state, index, true)
                end
            end
        end
    end
end

local function validForState(owner, state)
    local curLvl = owner and owner.getMainLvl and tonumber(owner:getMainLvl()) or 0
    return state.ownerId == owner:getID() and state.zoneId == zoneId(owner) and
        isKurogane(owner) and owner.isAlive and owner:isAlive() and
        (state.ownerLevel == nil or state.ownerLevel == curLvl)
end

local function getActualTarget(mob)
    if not mob or not mob.getTarget then
        return nil
    end

    local ok, target = pcall(function() return mob:getTarget() end)
    return ok and target or nil
end

local function hasExactEngagement(record)
    local mob = record.mob
    if not mob or not mob.isEngaged then
        return false, nil
    end

    local ok, engaged = pcall(function() return mob:isEngaged() end)
    local actualTarget = getActualTarget(mob)
    local actualId = actualTarget and actualTarget.getID and actualTarget:getID() or nil
    return ok and engaged and actualId == record.targetId, actualId
end

local function requestEngagement(record, target, now)
    record.attempts = (record.attempts or 0) + 1
    local ok, err = pcall(function()
        -- Populate the clone's own enmity container, then ask the native MOB
        -- controller to choose its highest-hate target. Unlike updateEnmity(),
        -- this request survives a busy AI tick.
        record.mob:addEnmity(target, 1, 1)
        record.mob:updateTarget()
    end)

    if not ok then
        record.inactiveReason = 'engage API error: ' .. tostring(err)
    else
        local engaged, actualId = hasExactEngagement(record)
        if engaged then
            record.action = 1
            record.inactiveReason = nil
        elseif actualId and actualId ~= record.targetId then
            record.inactiveReason = ('wrong target %s'):format(tostring(actualId))
        else
            record.inactiveReason = 'AI pending attack state'
        end
    end

    -- Bounded, independently jittered retries. No per-frame polling loop.
    record.nextEngageAt = now + math.randomFloat(0.45, 0.8)
end

local function tickOwner(owner, state)
    if not owner or K._owners[owner:getID()] ~= state then
        return
    end

    if not validForState(owner, state) then
        K.dismissAll(owner)
        return
    end

    if not K.ENABLE_EXPERIMENTAL_CLONES then
        K.dismissAll(owner)
        return
    end

    local target = owner.getTarget and owner:getTarget() or nil
    if not ownerStillFighting(owner, state.targetId) or not isValidTarget(owner, target, true) then
        state.lastError = 'owner no longer engaged with the summoned target'
        K.dismissAll(owner)
        return
    end

    local now = nowSec()
    pruneTactics(state, now)

    for index = #state.clones, 1, -1 do
        local record = state.clones[index]
        local alive = record.mob and record.mob.isAlive and record.mob:isAlive()
        if now >= record.expiresAt or not alive then
            removeAt(state, index, true)
        else
            local engaged, actualId = hasExactEngagement(record)
            if engaged then
                record.action = 1
                record.inactiveReason = nil
            elseif actualId and actualId ~= record.targetId then
                record.inactiveReason = ('wrong target %s'):format(tostring(actualId))
            elseif K.ENABLE_EXPERIMENTAL_COMBAT and
                now >= record.nextEngageAt and
                (record.attempts or 0) < K.MAX_ENGAGE_ATTEMPTS then
                requestEngagement(record, target, now)
            elseif K.ENABLE_EXPERIMENTAL_COMBAT and
                (record.attempts or 0) >= K.MAX_ENGAGE_ATTEMPTS then
                record.inactiveReason = ('inactive after %d engine requests'):format(record.attempts)
            elseif not K.ENABLE_EXPERIMENTAL_COMBAT then
                record.inactiveReason = 'combat disabled'
            end

            if not engaged and record.mob.lookAt and target.getPos then
                pcall(function() record.mob:lookAt(target:getPos()) end)
            end
        end
    end

    recomputeAllCloneMods(state, now)
    setCount(owner, state)
    if #state.clones == 0 then
        clearStateIfEmpty(owner:getID(), state)
    elseif owner.timer then
        owner:timer(250, function(actor)
            if actor and K._owners[actor:getID()] == state then
                tickOwner(actor, state)
            end
        end)
    end
end

local function visibleLooksMatch(owner, mob)
    if not owner.getLookSnapshot or not mob.getLookSnapshot then
        return false, 'authoritative getLookSnapshot binding unavailable'
    end

    local okOwner, ownerLook = pcall(function() return owner:getLookSnapshot() end)
    local okMob, mobLook = pcall(function() return mob:getLookSnapshot() end)
    if not okOwner or not okMob or type(ownerLook) ~= 'table' or type(mobLook) ~= 'table' then
        return false, 'engine look snapshot failed'
    end

    for _, field in ipairs(LOOK_FIELDS) do
        if tonumber(ownerLook[field]) ~= tonumber(mobLook[field]) then
            return false, ('look mismatch %s owner=%s clone=%s'):format(
                field, tostring(ownerLook[field]), tostring(mobLook[field]))
        end
    end

    return true, 'engine authoritative 8/8 slots'
end

-- Read-only GM probe: server-side look equality can be true even when both
-- source and clone contain zero/default armor models. Expose actual slot IDs.
local function lookSummary(entity)
    if not entity or not entity.getLookSnapshot then return 'snapshot unavailable' end
    local ok, look = pcall(function() return entity:getLookSnapshot() end)
    if not ok or type(look) ~= 'table' then return 'snapshot failed' end
    local fields = { 'face', 'race', 'head', 'body', 'hands', 'legs', 'feet', 'main', 'sub', 'ranged', 'modelSize', 'lookType' }
    local out = {}
    for _, field in ipairs(fields) do
        out[#out + 1] = field .. '=' .. tostring(look[field] or '?')
    end
    return table.concat(out, ' ')
end

function K.getLookDiagnostics(owner)
    if not owner or not owner.getID then return nil, 'invalid owner' end
    local state = K._owners[owner:getID()]
    local clone = state and state.clones and state.clones[1] and state.clones[1].mob or nil
    if not clone or not clone.isAlive or not clone:isAlive() then
        return { owner = lookSummary(owner), clone = 'no active clone' }
    end
    return { owner = lookSummary(owner), clone = lookSummary(clone) }
end

local function chooseSpawnPosition(owner, navZone, index)
    local ownerPos = { x = owner:getXPos(), y = owner:getYPos(), z = owner:getZPos() }
    if not navZone or not navZone.isNavigablePoint then
        return ownerPos, 'owner position (navmesh API unavailable)'
    end

    for attempt = 0, 3 do
        local theta = index * 2.399963 + attempt * 0.71 + math.randomFloat(0, 0.2)
        local radius = 1.1 + attempt * 0.35
        local candidate = {
            x = ownerPos.x + math.cos(theta) * radius,
            y = ownerPos.y,
            z = ownerPos.z + math.sin(theta) * radius,
        }
        local ok, navigable = pcall(function() return navZone:isNavigablePoint(candidate) end)
        if ok and navigable then
            return candidate, ('navmesh offset %.1f'):format(radius)
        end
    end

    return ownerPos, 'owner position (offsets were not navigable)'
end

local function recordAttribution(ownerId, mobId, damage, err)
    local state = K._owners[ownerId]
    if not state then
        return
    end

    for _, record in ipairs(state.clones) do
        if record.mobId == mobId then
            if err then
                record.attributionError = err
                state.lastError = err
            else
                record.attributedHits = (record.attributedHits or 0) + 1
                record.attributedDamage = (record.attributedDamage or 0) + math.max(0, damage or 0)
                record.attributionError = nil
            end
            return
        end
    end
end

-- Build Feint: strictly driven by real, verified, owner-attributed clone hits.
-- Requires two distinct living clones to land verified hits on the engaged enemy
-- within K.BUILD_FEINT_WINDOW (6 seconds). Never fabricated by timers.
local function onVerifiedCloneHit(owner, ownerId, mobId, now)
    local state = K._owners[ownerId]
    if not state then
        return false
    end
    local tactics = pruneTactics(state, now)
    if not tactics then
        return false
    end

    -- Verify the hitting clone is still tracked and alive.
    local aliveRecord = false
    for _, record in ipairs(state.clones) do
        if record.mobId == mobId and record.mob and record.mob.isAlive and record.mob:isAlive() and (record.expiresAt or 0) > now then
            aliveRecord = true
            break
        end
    end
    if not aliveRecord then
        return false
    end

    if tactics.phase == K.PHASE_BUILDING then
        tactics.recentHits[mobId] = now
        pruneTactics(state, now)
        if (tactics.distinctHits or 0) >= 2 then
            tactics.phase = K.PHASE_FEINT
            tactics.phaseExpiresAt = now + K.PHASE_DURATION
            tactics.lastCommandId = nil
            tactics.recentHits = {}
            tactics.distinctHits = 0
            setCount(owner, state)
            if owner and owner.printToPlayer then
                owner:printToPlayer('[Shinobi] Feint Ready! (20s) Issue a squad command to begin the tactical sequence.', xi.msg.channel.SYSTEM_3)
            end
            return true
        end
        setCount(owner, state)
    end
    return false
end

-- Exposed strictly for automated regression testing of the real attribution handler
-- without duplicating combat logic. Never called by timers or client input.
K._onVerifiedCloneHit = onVerifiedCloneHit

local function installCloneListeners(mob, ownerId, targetId)
    mob:removeListener(ATTACK_LISTENER)
    mob:addListener('ATTACK', ATTACK_LISTENER, function(actor, struckTarget, action)
        -- Native MOB damage normally puts the clone itself on the enemy's
        -- threat table. Zero it synchronously so a clone can never tank.
        if struckTarget and struckTarget.resetEnmity then
            pcall(function() struckTarget:resetEnmity(actor) end)
        end

        local owner = type(GetPlayerByID) == 'function' and GetPlayerByID(ownerId) or nil
        if not owner or not isKurogane(owner) or not owner.isAlive or not owner:isAlive() or
            not struckTarget or struckTarget:getID() ~= targetId or zoneId(owner) ~= zoneId(struckTarget) or
            not ownerTargets(owner, targetId, false) then
            recordAttribution(ownerId, actor:getID(), 0, 'owner unavailable or target changed during clone attack')
            dismissMob({ mob = actor, targetId = targetId })
            return
        end

        local damage = 0
        if action and action.getParam then
            local ok, result = pcall(function() return action:getParam(struckTarget:getID()) end)
            if ok then
                damage = math.max(0, math.floor(tonumber(result) or 0))
            end
        end

        -- No second damage application occurs. The focused engine helper moves
        -- final-attacker, reward claim, threat, and RoE damage credit together.
        if damage > 0 then
            local ok, attributed = pcall(function()
                return struckTarget:attributeDamageTo(owner, damage)
            end)
            local attributionError = nil
            if not ok or attributed ~= true then
                attributionError = 'owner attribution failed: ' .. tostring(ok and attributed or attributed)
            end
            recordAttribution(ownerId, actor:getID(), damage, attributionError)
            if attributionError then
                dismissMob({ mob = actor, targetId = targetId })
            else
                onVerifiedCloneHit(owner, ownerId, actor:getID(), nowSec())
            end
        end
    end)

    mob:removeListener(DEATH_LISTENER)
    mob:addListener('DEATH', DEATH_LISTENER, function(actor)
        clearCloneEnmity({ mob = actor, targetId = targetId })
        forgetMob(ownerId, actor:getID())
    end)

    mob:removeListener(DESPAWN_LISTENER)
    mob:addListener('DESPAWN', DESPAWN_LISTENER, function(actor)
        clearCloneEnmity({ mob = actor, targetId = targetId })
        forgetMob(ownerId, actor:getID())
    end)
end

local function makeClone(owner, target, index)
    if not (xi.allegiance and xi.allegiance.PLAYER) then
        return nil, 'PLAYER allegiance unavailable; refusing hostile MOB spawn'
    end

    if not owner.getLookSnapshot then
        return nil, 'authoritative appearance engine patch is not installed'
    end
    if not target.attributeDamageTo then
        return nil, 'authoritative owner-attribution engine patch is not installed'
    end

    local navZone = owner.getZone and owner:getZone() or nil
    local container = owner.getInstance and owner:getInstance() or nil
    if not container then
        container = navZone
    end
    if not container or not container.insertDynamicEntity then
        return nil, 'dynamic entities unavailable'
    end

    local pos, posInfo = chooseSpawnPosition(owner, navZone, index)
    K._serial = K._serial + 1
    local mob = container:insertDynamicEntity({
        objtype = xi.objType.MOB,
        allegiance = xi.allegiance.PLAYER,
        name = ('KRG_%d_%d'):format(owner:getID(), K._serial),
        packetName = owner:getName() .. "'s Shadow",
        x = pos.x,
        y = pos.y,
        z = pos.z,
        rotation = owner:getRotPos(),
        -- Engine-side copy of the visible player look_t before insertion.
        lookSource = owner,
        minLevel = owner:getMainLvl(),
        maxLevel = owner:getMainLvl(),
        dropId = 0,
        isAggroable = false,
        releaseIdOnDisappear = true,
        specialSpawnAnimation = true,
    })
    if not mob then
        return nil, 'dynamic MOB creation or authoritative appearance copy failed'
    end

    if mob.setMobMod and xi.mobMod then
        if xi.mobMod.NO_DROPS then mob:setMobMod(xi.mobMod.NO_DROPS, 1) end
        if xi.mobMod.NO_EXP then mob:setMobMod(xi.mobMod.NO_EXP, 1) end
        if xi.mobMod.NO_DESPAWN then mob:setMobMod(xi.mobMod.NO_DESPAWN, 1) end
        if xi.mobMod.NO_STANDBACK then mob:setMobMod(xi.mobMod.NO_STANDBACK, 1) end
        if xi.mobMod.MULTI_HIT then mob:setMobMod(xi.mobMod.MULTI_HIT, 0) end
    end
    if mob.setDropID then mob:setDropID(0) end
    if mob.setMobAbilityEnabled then mob:setMobAbilityEnabled(false) end
    if mob.setMagicCastingEnabled then mob:setMagicCastingEnabled(false) end
    if mob.setRoamFlags and xi.roamFlag and xi.roamFlag.SCRIPTED then
        mob:setRoamFlags(xi.roamFlag.SCRIPTED)
    end
    if mob.setSpawn then mob:setSpawn(pos.x, pos.y, pos.z, owner:getRotPos()) end

    mob:spawn()

    -- Generic engine cleanup hook: dynamic entities carrying this owner ID are
    -- despawned synchronously when that character leaves the zone or logs out.
    if mob.setLocalVar then
        mob:setLocalVar('dynamicOwnerId', owner:getID())
    end

    -- Spawn() resets battle context; restore it for battlefields/confrontation.
    if mob.setBattleID and owner.getBattleID then
        mob:setBattleID(owner:getBattleID())
    end
    if mob.copyConfrontationEffect and owner.getTargID then
        pcall(function() mob:copyConfrontationEffect(owner:getTargID()) end)
    end

    local ownerLevel = owner.getMainLvl and tonumber(owner:getMainLvl()) or 1
    -- Production single-hit shadow melee: deterministic level-scaled weapon
    -- damage and Tier-1 squad budget, no multi-hit procs or monster bonuses.
    if mob.setDamage then
        local baseDmg = math.max(6, math.floor(ownerLevel * 0.55 + 5))
        pcall(function() mob:setDamage(baseDmg) end)
    end
    if mob.addMod and xi.mod then
        if xi.mod.PHYS_DMG_DEALT then mob:addMod(xi.mod.PHYS_DMG_DEALT, K.CLONE_PHYS_DMG_MOD) end
        if xi.mod.DMGMAGIC then mob:addMod(xi.mod.DMGMAGIC, K.CLONE_MAGIC_DMG_TAKEN_MOD) end
        if xi.mod.DOUBLE_ATTACK then mob:addMod(xi.mod.DOUBLE_ATTACK, -100) end
        if xi.mod.TRIPLE_ATTACK then mob:addMod(xi.mod.TRIPLE_ATTACK, -100) end
        if xi.mod.QUAD_ATTACK then mob:addMod(xi.mod.QUAD_ATTACK, -100) end
        if xi.mod.ENMITY then mob:addMod(xi.mod.ENMITY, -100) end
    end
    if mob.setMod and xi.mod then
        if xi.mod.MACC then mob:setMod(xi.mod.MACC, -500) end
        if xi.mod.MATT then mob:setMod(xi.mod.MATT, -100) end
        -- Zero inherited job-trait HP/HPP/BASE_HP mods (e.g. Max HP Boost at Lv75)
        -- so setMaxHP(cloneHP) enforces exact glass-cannon maxHP (40..170).
        if xi.mod.HP then mob:setMod(xi.mod.HP, 0) end
        if xi.mod.HPP then mob:setMod(xi.mod.HPP, 0) end
        if xi.mod.BASE_HP then mob:setMod(xi.mod.BASE_HP, 0) end
    end
    local baseDelay = math.random(210, 270)
    if mob.setDelay then mob:setDelay(baseDelay) end
    local cloneHP = math.max(K.HP_MIN, math.min(K.HP_MAX,
        K.HP_BASE + math.floor(ownerLevel * K.HP_PER_LEVEL)))
    if mob.setMaxHP then mob:setMaxHP(cloneHP) end
    if mob.setHP then mob:setHP(cloneHP) end
    if not mob.getHP or mob:getHP() ~= cloneHP then
        dismissMob({ mob = mob })
        return nil, 'cannot enforce shadow HP on dynamic clone'
    end

    -- Zero threat makes the clone eligible for enemy AoE selection. Its
    -- ATTACK listener removes any positive native threat immediately.
    local aoeOk, aoeErr = pcall(function() target:addBaseEnmity(mob) end)
    if not aoeOk then
        dismissMob({ mob = mob })
        return nil, 'cannot register clone for enemy AoE: ' .. tostring(aoeErr)
    end

    local lookOk, lookInfo = visibleLooksMatch(owner, mob)
    if not lookOk then
        dismissMob({ mob = mob, targetId = target:getID() })
        return nil, lookInfo
    end

    return mob, lookInfo, posInfo, baseDelay
end

local function attachOwnerListeners(owner)
    if not owner or not owner.addListener then
        return
    end

    owner:removeListener(OWNER_DEATH_LISTENER)
    owner:removeListener(OWNER_DISENGAGE_LISTENER)
    owner:addListener('DEATH', OWNER_DEATH_LISTENER, function(actor)
        K.dismissAll(actor)
    end)
    owner:addListener('DISENGAGE', OWNER_DISENGAGE_LISTENER, function(actor)
        K.dismissAll(actor)
    end)
end

function K.canSpawn(owner)
    if not K.ENABLE_EXPERIMENTAL_CLONES then
        return false, 'shadow clone backend disabled'
    end
    if not isKurogane(owner) then
        return false, 'Shinobi required'
    end

    local target = owner.getTarget and owner:getTarget() or nil
    if not isValidTarget(owner, target, true) or not ownerStillFighting(owner, target and target:getID() or 0) then
        return false, 'engage a valid enemy first'
    end

    return true, target
end

function K.hasLivingClones(owner)
    if not owner or not owner.getID or not isKurogane(owner) then
        return 0, nil
    end
    local state = K._owners[owner:getID()]
    if not state or not validForState(owner, state) then
        return 0, nil
    end
    local target = owner.getTarget and owner:getTarget() or nil
    if not isValidTarget(owner, target, true) or not ownerStillFighting(owner, state.targetId) then
        return 0, nil
    end

    local now = nowSec()
    local living = {}
    for _, record in ipairs(state.clones) do
        if record.mob and record.mob.isAlive and record.mob:isAlive() and record.expiresAt > now then
            living[#living + 1] = record
        end
    end
    return #living, living, target, state
end

-- Shared pre-cast validator for all Shinobi squad commands (spells & JAs).
-- Returns ok, reasonOrTarget, count, living, state.
function K.canCommand(owner, explicitTarget, minClones)
    if not isKurogane(owner) then
        return false, 'Shinobi required'
    end
    local count, living, activeTarget, state = K.hasLivingClones(owner)
    local req = math.max(1, tonumber(minClones) or 1)
    if count < req or not living or not activeTarget or not state then
        return false, 'requires living shadows and an engaged target'
    end
    if explicitTarget ~= nil and explicitTarget.getID and explicitTarget:getID() ~= activeTarget:getID() then
        return false, 'target must be your engaged enemy'
    end
    return true, activeTarget, count, living, state
end

function K.spawn(owner, count)
    local okSpawn, targetOrErr = K.canSpawn(owner)
    if not okSpawn then
        return false, targetOrErr
    end

    local target = targetOrErr
    local ownerId = owner:getID()
    local targetId = target:getID()
    local ownerLvl = owner.getMainLvl and tonumber(owner:getMainLvl()) or 10
    local state = K._owners[ownerId]
    if state and (state.zoneId ~= zoneId(owner) or state.targetId ~= targetId or state.ownerLevel ~= ownerLvl) then
        K.dismissAll(owner)
        state = nil
    end
    if not state then
        state = {
            ownerId = ownerId,
            zoneId = zoneId(owner),
            targetId = targetId,
            ownerLevel = ownerLvl,
            clones = {},
            tactics = newTacticsState(),
            lastError = '',
        }
        K._owners[ownerId] = state
    end

    attachOwnerListeners(owner)
    local wanted = math.min(K.MAX_ACTIVE, math.max(0, math.floor(tonumber(count) or 0)))
    if wanted == 0 then
        clearStateIfEmpty(ownerId, state)
        return false, 'clone count must be between 1 and 5'
    end

    -- Transactional staging: create and validate every replacement clone BEFORE
    -- evicting any pre-existing clone so a failure (including dynamic-entity
    -- allocation cap) never loses an active clone.
    local staged = {}
    for index = 1, wanted do
        local ok, mobOrError, lookInfo, posInfo, baseDelay = pcall(makeClone, owner, target, index)
        if not ok or not mobOrError then
            state.lastError = ok and tostring(lookInfo or 'unknown spawn failure') or tostring(mobOrError)
            for stagedIndex = #staged, 1, -1 do
                dismissMob(staged[stagedIndex])
            end
            setCount(owner, state)
            clearStateIfEmpty(ownerId, state)
            return false, state.lastError
        end

        local now = nowSec()
        local lifetime = math.random(K.LIFETIME_MIN, K.LIFETIME_MAX)
        staged[#staged + 1] = {
            mob = mobOrError,
            mobId = mobOrError:getID(),
            targetId = targetId,
            expiresAt = now + lifetime,
            lifetime = lifetime,
            baseDelay = baseDelay or 240,
            appliedDelay = baseDelay or 240,
            appliedPhysDelta = 0,
            appliedAccDelta = 0,
            slotParity = (K._serial % 2),
            phantomActive = false,
            phantomExpiresAt = 0,
            nextEngageAt = now + math.randomFloat(0.25, 1.4),
            attempts = 0,
            action = 0,
            appearanceCopied = true,
            appearanceInfo = lookInfo,
            positionInfo = posInfo,
            attributedHits = 0,
            attributedDamage = 0,
        }
    end

    -- All replacements succeeded; now evict only the oldest clones needed to
    -- stay at or below K.MAX_ACTIVE, then commit the staged clones.
    local toEvict = math.max(0, (#state.clones + #staged) - K.MAX_ACTIVE)
    for _ = 1, toEvict do
        local evicted = removeAt(state, 1, true)
        if evicted and state.tactics and state.tactics.recentHits then
            state.tactics.recentHits[evicted.mobId] = nil
        end
    end

    local spawned = 0
    for _, record in ipairs(staged) do
        local lifetime = record.lifetime
        record.lifetime = nil
        state.clones[#state.clones + 1] = record
        installCloneListeners(record.mob, ownerId, targetId)

        -- The entity owns expiry, so logout cannot strand it when the player's
        -- timer queue disappears.
        if record.mob.timer then
            record.mob:timer(lifetime * 1000, function(actor)
                if actor and type(DespawnMob) == 'function' then
                    pcall(DespawnMob, actor:getID())
                end
            end)
        end

        spawned = spawned + 1
    end

    local first = state.clones[#state.clones - spawned + 1]
    state.lastSpawnInfo = ('look=%d/%d authoritative; target=%d; first=%s; %s'):format(
        spawned, spawned, targetId, first and first.mobId or 0, first and first.positionInfo or 'unknown position')
    state.lastError = ''
    recomputeAllCloneMods(state, nowSec())
    setCount(owner, state)

    if spawned > 0 and owner.timer and not state.timerRunning then
        state.timerRunning = true
        owner:timer(250, function(actor)
            if actor and K._owners[actor:getID()] == state then
                tickOwner(actor, state)
            end
        end)
    end

    return true, spawned
end

-----------------------------------
-- Bounded Single-Target Strike & Tactical Cycle Engine
-----------------------------------
local function computeStrikeUnit(owner, target)
    local lvl     = owner.getMainLvl and tonumber(owner:getMainLvl()) or 10
    local strStat = owner.getStat and owner:getStat(xi.mod.STR) or lvl
    local dexStat = owner.getStat and owner:getStat(xi.mod.DEX) or lvl
    local att     = owner.getStat and owner:getStat(xi.mod.ATT) or (lvl * 4)
    local def     = target.getStat and target:getStat(xi.mod.DEF) or math.max(1, lvl * 3)
    local ratio   = math.max(0.65, math.min(1.65, att / math.max(1, def)))
    -- Tier-1 balanced per-clone unit: ~24 at Lv10, ~43 at Lv30, ~62 at Lv50, ~90 at Lv75 EM (~77 at +3).
    -- Combined with player dual-katana melee/WS and clone autoattacks, keeps total DPS in Tier-1 budget.
    return math.max(8, math.floor((11 + lvl * 0.65 + (strStat + dexStat) * 0.14) * ratio))
end

-- Executes a single bounded, owner-attributed physical strike from one living clone.
-- Re-validates owner, target, and clone at execution time; never applies damage twice,
-- never generates skillchains/AoE/extra TP, and only records attribution if takeDamage succeeds.
local function applyBoundedCloneStrike(owner, ownerId, target, targetId, record, baseDmg)
    local liveOwner = (type(GetPlayerByID) == 'function' and GetPlayerByID(ownerId)) or owner
    if not liveOwner or not isKurogane(liveOwner) or not liveOwner.isAlive or not liveOwner:isAlive() then
        return 0, false
    end
    if not ownerStillFighting(liveOwner, targetId) then
        return 0, false
    end
    if not record or not record.mob or not record.mob.isAlive or not record.mob:isAlive() then
        return 0, false
    end
    if not isValidTarget(liveOwner, target, true) then
        return 0, false
    end

    if record.mob.lookAt and target.getPos then
        pcall(function() record.mob:lookAt(target:getPos()) end)
    end

    local variance = 0.92 + math.random() * 0.16
    local dmg = math.max(1, math.floor(baseDmg * variance))
    if not target.takeDamage then
        return 0, false
    end

    local okDmg = pcall(function()
        target:takeDamage(dmg, liveOwner, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
    end)
    if not okDmg then
        return 0, false
    end

    if target.resetEnmity then
        pcall(function() target:resetEnmity(record.mob) end)
    end
    recordAttribution(ownerId, record.mobId, dmg, nil)
    return dmg, true
end

-- Schedules a staggered sequence of bounded clone strikes obeying a strict
-- total damage cap across all participating clones.
local function dispatchStaggeredStrikes(owner, target, living, perHitBases, staggerMs, totalBudgetCap)
    local ownerId = owner:getID()
    local targetId = target:getID()
    local plannedSum = 0
    for i = 1, #perHitBases do
        plannedSum = plannedSum + math.max(1, math.floor(perHitBases[i]))
    end
    local scale = 1.0
    if totalBudgetCap and totalBudgetCap > 0 and plannedSum > totalBudgetCap then
        scale = totalBudgetCap / plannedSum
    end

    local immediateActual = 0
    local scheduledHits = 0
    local expectedTotal = 0
    for idx, record in ipairs(living) do
        local rawBase = perHitBases[idx]
        if rawBase and rawBase > 0 then
            local boundedBase = math.max(1, math.floor(rawBase * scale))
            expectedTotal = expectedTotal + boundedBase
            scheduledHits = scheduledHits + 1
            local delayMs = (idx - 1) * (staggerMs or 0)
            if delayMs == 0 or not owner.timer then
                local dealt = applyBoundedCloneStrike(owner, ownerId, target, targetId, record, boundedBase)
                immediateActual = immediateActual + dealt
            else
                owner:timer(delayMs, function()
                    applyBoundedCloneStrike(owner, ownerId, target, targetId, record, boundedBase)
                end)
            end
        end
    end

    return scheduledHits, immediateActual, expectedTotal
end

-- Capped Cascade Coordinated Strike triggered when a qualifying different command
-- is executed during Cascade Ready. Resets the tactical cycle afterwards.
local function triggerCascadeStrike(owner, target, living, unit, openingBonus)
    local count = math.min(K.MAX_ACTIVE, #living)
    local perClone = math.floor(unit * (openingBonus and 0.52 or 0.45))
    local cap = math.floor(unit * 2.50)
    local bases = {}
    local participating = {}
    for i = 1, count do
        participating[i] = living[i]
        bases[i] = perClone
    end
    local hits, immediate, expected = dispatchStaggeredStrikes(owner, target, participating, bases, 70, cap)
    return hits, immediate, expected
end

-- Server-authoritative tactical phase transition helper.
-- Enforces:
--   * Repeating the same command CANNOT advance Switch -> Cascade or trigger Cascade.
--   * False Assault's Opening only empowers the next DIFFERENT successful squad command.
--   * Final Mirage consumes the active phase directly for its finisher scaling.
local function processTacticalCommand(owner, state, target, living, cmdId, opts)
    opts = opts or {}
    local now = nowSec()
    local tactics = pruneTactics(state, now)
    local unit = computeStrikeUnit(owner, target)

    local openingConsumed = false
    if not opts.preserveOpening and (tactics.openingUntil or 0) > now and tactics.openingSource ~= cmdId then
        openingConsumed = true
        tactics.openingUntil = 0
        tactics.openingSource = nil
    end

    local prevPhase = tactics.phase
    local result = {
        unit             = unit,
        previousPhase    = prevPhase,
        newPhase         = prevPhase,
        openingConsumed  = openingConsumed,
        advanced         = false,
        repeated         = false,
        cascadeTriggered = false,
        cascadeHits      = 0,
        cascadeExpected  = 0,
    }

    if opts.consumeAllPhases then
        tactics.phase = K.PHASE_BUILDING
        tactics.phaseExpiresAt = 0
        tactics.lastCommandId = nil
        tactics.recentHits = {}
        tactics.distinctHits = 0
        result.newPhase = K.PHASE_BUILDING
        result.cascadeTriggered = (prevPhase == K.PHASE_CASCADE)
        return result
    end

    if prevPhase == K.PHASE_FEINT then
        tactics.phase = K.PHASE_SWITCH
        tactics.phaseExpiresAt = now + K.PHASE_DURATION
        tactics.lastCommandId = cmdId
        result.newPhase = K.PHASE_SWITCH
        result.advanced = true
    elseif prevPhase == K.PHASE_SWITCH then
        if cmdId ~= tactics.lastCommandId then
            tactics.phase = K.PHASE_CASCADE
            tactics.phaseExpiresAt = now + K.PHASE_DURATION
            tactics.lastCommandId = cmdId
            result.newPhase = K.PHASE_CASCADE
            result.advanced = true
        else
            result.repeated = true
        end
    elseif prevPhase == K.PHASE_CASCADE then
        if cmdId ~= tactics.lastCommandId then
            local cHits, _cImm, cExp = triggerCascadeStrike(owner, target, living, unit, openingConsumed)
            tactics.phase = K.PHASE_BUILDING
            tactics.phaseExpiresAt = 0
            tactics.lastCommandId = nil
            tactics.recentHits = {}
            tactics.distinctHits = 0
            result.newPhase = K.PHASE_BUILDING
            result.cascadeTriggered = true
            result.cascadeHits = cHits
            result.cascadeExpected = cExp
        else
            result.repeated = true
        end
    end

    return result
end

local function phaseSuffix(tac)
    if tac.cascadeTriggered and (tac.cascadeExpected or 0) > 0 then
        return string.format(' [CASCADE! %d shadows struck for ~%d dmg -> cycle reset]', tac.cascadeHits, tac.cascadeExpected)
    elseif tac.newPhase == K.PHASE_SWITCH and tac.advanced then
        return ' [Phase -> Switch Ready (20s): use a different command]'
    elseif tac.newPhase == K.PHASE_CASCADE and tac.advanced then
        return ' [Phase -> Cascade Ready (20s): next different command triggers Cascade]'
    elseif tac.repeated then
        return ' [Repeat command: use a different squad command to advance phase]'
    end
    return ''
end

-----------------------------------
-- Shinobi Ninjutsu Squad Commands (Spells 320, 323, 326, 329, 332, 335)
-----------------------------------

-- Spell 320 (Katon: Ichi) — False Assault (Lv10)
-- Establishes a short owner-only offensive Opening (+25% next DIFFERENT squad command)
-- and executes a swift single-clone feint tap. No enemy debuff, no party bonus.
function K.executeFalseAssault(owner, explicitTarget)
    local okCmd, targetOrErr, count, living, state = K.canCommand(owner, explicitTarget, 1)
    if not okCmd then
        return false, targetOrErr
    end

    local target = targetOrErr
    local now = nowSec()
    local tac = processTacticalCommand(owner, state, target, living, 'false_assault', { preserveOpening = true })
    local tactics = state.tactics
    tactics.openingUntil = now + K.OPENING_DURATION
    tactics.openingSource = 'false_assault'

    local feintDmg = math.max(1, math.floor(tac.unit * 0.45))
    local dealt = applyBoundedCloneStrike(owner, owner:getID(), target, target:getID(), living[1], feintDmg)

    setCount(owner, state)
    if owner.printToPlayer then
        owner:printToPlayer(
            string.format('[Shinobi] False Assault! Feint strike (%d dmg) created an Opening (12s: +25%% next different command).%s',
                dealt, phaseSuffix(tac)),
            xi.msg.channel.SYSTEM_3)
    end
    return true, { damage = dealt, count = count, tactics = tac }
end

-- Spell 323 (Hyoton: Ichi) — Mirror Step (Lv10)
-- Shifts living clones into an alternating fast/heavy attack rhythm for 10s (12s w/ Opening).
-- Rewards maintaining multiple living clones (+4% clone melee per extra living clone).
-- No invulnerability, evasion bonus, or tanking utility.
function K.executeMirrorStep(owner, explicitTarget)
    local okCmd, targetOrErr, count, living, state = K.canCommand(owner, explicitTarget, 1)
    if not okCmd then
        return false, targetOrErr
    end

    local target = targetOrErr
    local now = nowSec()
    local tac = processTacticalCommand(owner, state, target, living, 'mirror_step')
    local dur = K.MIRROR_STEP_DUR + (tac.openingConsumed and 2 or 0)
    local tactics = state.tactics
    tactics.mirrorUntil = now + dur
    tactics.mirrorStartedAt = now
    tactics.mirrorEmpowered = tac.openingConsumed == true

    recomputeAllCloneMods(state, now)
    setCount(owner, state)
    if owner.printToPlayer then
        owner:printToPlayer(
            string.format('[Shinobi] Mirror Step! %d %s shifted to alternating rhythm for %ds%s.%s',
                count, count == 1 and 'shadow' or 'shadows', dur,
                tac.openingConsumed and ' (Opening empowered)' or '', phaseSuffix(tac)),
            xi.msg.channel.SYSTEM_3)
    end
    return true, { duration = dur, count = count, empowered = tac.openingConsumed, tactics = tac }
end

-- Spell 326 (Huton: Ichi) — Crosscut (Lv10)
-- Coordinated rapid single-target slashes from surviving clones (90ms stagger, bounded cap).
-- Owner-attributed once per clone, no AoE, no skillchain.
function K.executeCrosscut(owner, explicitTarget)
    local okCmd, targetOrErr, count, living, state = K.canCommand(owner, explicitTarget, 1)
    if not okCmd then
        return false, targetOrErr
    end

    local target = targetOrErr
    local tac = processTacticalCommand(owner, state, target, living, 'crosscut')
    local mult = tac.openingConsumed and 0.68 or 0.55
    local perClone = math.max(1, math.floor(tac.unit * mult))
    local cap = math.floor(tac.unit * 3.60)
    local participating = {}
    local bases = {}
    for i = 1, math.min(K.MAX_ACTIVE, count) do
        participating[i] = living[i]
        bases[i] = perClone
    end

    local hits, immediate, expected = dispatchStaggeredStrikes(owner, target, participating, bases, 90, cap)
    setCount(owner, state)
    if owner.printToPlayer then
        owner:printToPlayer(
            string.format('[Shinobi] Crosscut! %d %s launched rapid coordinated strikes (~%d dmg)%s.%s',
                hits, hits == 1 and 'shadow' or 'shadows', expected,
                tac.openingConsumed and ' [Opening]' or '', phaseSuffix(tac)),
            xi.msg.channel.SYSTEM_3)
    end
    return true, { hits = hits, immediate = immediate, expected = expected, count = count, tactics = tac }
end

-- Spell 329 (Doton: Ichi) — Shadow Pin (Lv30)
-- Concentrates all living clones onto the owner's engaged target for 12s (14s w/ Opening):
-- refreshes engagement/facing on mobile bosses, extends active tactical phase by +4s (cap 20s),
-- and grants living clones +ACC and +melee damage against the pinned target.
-- Never immobilizes, stuns, binds, slows, or debuffs the enemy; never forces enmity onto clones.
function K.executeShadowPin(owner, explicitTarget)
    local okCmd, targetOrErr, count, living, state = K.canCommand(owner, explicitTarget, 1)
    if not okCmd then
        return false, targetOrErr
    end

    local target = targetOrErr
    local now = nowSec()
    local tac = processTacticalCommand(owner, state, target, living, 'shadow_pin')
    local dur = K.SHADOW_PIN_DUR + (tac.openingConsumed and 2 or 0)
    local tactics = state.tactics
    tactics.pinUntil = now + dur
    tactics.pinEmpowered = tac.openingConsumed == true
    tactics.pinTargetId = target:getID()

    -- Extend active tactical phase window by +4s (capped at PHASE_DURATION from now).
    if tactics.phase > K.PHASE_BUILDING and (tactics.phaseExpiresAt or 0) > now then
        tactics.phaseExpiresAt = math.min(now + K.PHASE_DURATION, tactics.phaseExpiresAt + 4)
    end

    -- Refresh clone focus & bounded re-engagement on mobile targets without forcing clone enmity.
    for _, record in ipairs(living) do
        if record.mob then
            if record.mob.lookAt and target.getPos then
                pcall(function() record.mob:lookAt(target:getPos()) end)
            end
            local engaged = hasExactEngagement(record)
            if not engaged and K.ENABLE_EXPERIMENTAL_COMBAT then
                record.attempts = math.min(record.attempts or 0, K.MAX_ENGAGE_ATTEMPTS - 1)
                requestEngagement(record, target, now)
            end
            if target.resetEnmity then
                pcall(function() target:resetEnmity(record.mob) end)
            end
        end
    end

    recomputeAllCloneMods(state, now)
    setCount(owner, state)
    if owner.printToPlayer then
        owner:printToPlayer(
            string.format('[Shinobi] Shadow Pin! %d %s locked onto target for %ds (+ACC/+melee, phase extended)%s.%s',
                count, count == 1 and 'shadow' or 'shadows', dur,
                tac.openingConsumed and ' [Opening]' or '', phaseSuffix(tac)),
            xi.msg.channel.SYSTEM_3)
    end
    return true, { duration = dur, count = count, empowered = tac.openingConsumed, tactics = tac }
end

-- Spell 332 (Raiton: Ichi) — Thunder Relay (Lv50)
-- High-tempo sequential escalating clone strikes (60ms cadence).
-- Requires 2+ living clones for the full escalating relay chain; bounded total cap.
-- No AoE, recursive triggers, or unintended TP generation.
function K.executeThunderRelay(owner, explicitTarget)
    local okCmd, targetOrErr, count, living, state = K.canCommand(owner, explicitTarget, 1)
    if not okCmd then
        return false, targetOrErr
    end

    local target = targetOrErr
    local tac = processTacticalCommand(owner, state, target, living, 'thunder_relay')
    local relayScale = tac.openingConsumed and 1.20 or 1.00
    local participating = {}
    local bases = {}
    local relayCurve = { 0.55, 0.70, 0.85, 1.00, 1.15 }
    local cap = math.floor(tac.unit * 5.25)

    if count == 1 then
        -- Single clone cannot form a relay chain: reduced single strike.
        participating[1] = living[1]
        bases[1] = math.max(1, math.floor(tac.unit * 0.50 * relayScale))
    else
        local n = math.min(K.MAX_ACTIVE, count)
        for i = 1, n do
            participating[i] = living[i]
            bases[i] = math.max(1, math.floor(tac.unit * relayCurve[i] * relayScale))
        end
    end

    local hits, immediate, expected = dispatchStaggeredStrikes(owner, target, participating, bases, 60, cap)
    setCount(owner, state)
    if owner.printToPlayer then
        owner:printToPlayer(
            string.format('[Shinobi] Thunder Relay! %d-link %s (~%d dmg)%s.%s',
                hits, hits >= 2 and 'escalating relay' or 'partial strike (needs 2+ shadows for full relay)',
                expected, tac.openingConsumed and ' [Opening]' or '', phaseSuffix(tac)),
            xi.msg.channel.SYSTEM_3)
    end
    return true, { hits = hits, immediate = immediate, expected = expected, fullRelay = count >= 2, count = count, tactics = tac }
end

-- Spell 335 (Suiton: Ichi) — Final Mirage (Lv70)
-- High-commitment single-target squad finisher. Consumes active tactical phase
-- (and Opening if active) to deliver a capped, sequence-rewarding payoff scaling
-- with surviving clones (1..5).
function K.executeFinalMirage(owner, explicitTarget)
    local okCmd, targetOrErr, count, living, state = K.canCommand(owner, explicitTarget, 1)
    if not okCmd then
        return false, targetOrErr
    end

    local target = targetOrErr
    local tac = processTacticalCommand(owner, state, target, living, 'final_mirage', { consumeAllPhases = true })
    local phaseMults =
    {
        [K.PHASE_BUILDING] = 1.00,
        [K.PHASE_FEINT]    = 1.20,
        [K.PHASE_SWITCH]   = 1.40,
        [K.PHASE_CASCADE]  = 1.70,
    }
    local phaseMult = phaseMults[tac.previousPhase] or 1.00
    if tac.openingConsumed then
        phaseMult = phaseMult + 0.15
    end

    local n = math.min(K.MAX_ACTIVE, count)
    local perClone = math.max(1, math.floor(tac.unit * 0.75 * phaseMult))
    local hardCap = math.floor(tac.unit * 7.50)
    local participating = {}
    local bases = {}
    for i = 1, n do
        participating[i] = living[i]
        bases[i] = perClone
    end

    local hits, immediate, expected = dispatchStaggeredStrikes(owner, target, participating, bases, 80, hardCap)
    setCount(owner, state)
    if owner.printToPlayer then
        local phaseLabel = K.PHASE_NAMES[tac.previousPhase] or 'Cold'
        owner:printToPlayer(
            string.format('[Shinobi] Final Mirage! %d %s consumed %s%s for a finishing strike (~%d dmg).',
                hits, hits == 1 and 'shadow' or 'shadows',
                tac.previousPhase > 0 and (phaseLabel .. ' phase') or 'no phase',
                tac.openingConsumed and ' + Opening' or '', expected),
            xi.msg.channel.SYSTEM_3)
    end
    return true, { hits = hits, immediate = immediate, expected = expected, consumedPhase = tac.previousPhase, count = count, tactics = tac }
end

-----------------------------------
-- Existing Custom Job Abilities (487 Shadow Legion, 488 Phantom Assault)
-----------------------------------

-- Signature JA 1: Shadow Legion (90s CD)
-- Every surviving shadow launches one staggered single-target strike at the
-- engaged enemy, attributed to the owner exactly once. At 5 clones, combined
-- damage is tuned to roughly one comparable Katana weaponskill.
-- Integrates naturally with Opening and the Feint -> Switch -> Cascade cycle.
function K.executeShadowLegion(owner, explicitTarget)
    local okCmd, targetOrErr, count, living, state = K.canCommand(owner, explicitTarget, 1)
    if not okCmd then
        return false, targetOrErr
    end

    local target = targetOrErr
    local tac = processTacticalCommand(owner, state, target, living, 'shadow_legion')
    local mult = tac.openingConsumed and 1.20 or 1.00
    local perCloneBase = math.max(1, math.floor(tac.unit * mult))
    local cap = math.floor(tac.unit * 6.00)
    local participating = {}
    local bases = {}
    for i = 1, math.min(K.MAX_ACTIVE, count) do
        participating[i] = living[i]
        bases[i] = perCloneBase
    end

    local hits, immediate, expected = dispatchStaggeredStrikes(owner, target, participating, bases, 120, cap)
    setCount(owner, state)
    return true, hits, expected, immediate, tac
end

-- Signature JA 2: Phantom Assault (30s CD, 8s duration)
-- Grants currently living clones a 25% shorter native autoattack interval
-- (~33.3% higher attack frequency) for 8 seconds. Does not stack recursively,
-- does not apply to clones summoned afterward, and does not alter player haste.
-- Integrates naturally with the Feint -> Switch -> Cascade cycle.
function K.executePhantomAssault(owner)
    local okCmd, targetOrErr, count, living, state = K.canCommand(owner, nil, 1)
    if not okCmd then
        return false, targetOrErr
    end

    local target = targetOrErr
    local now = nowSec()
    local tac = processTacticalCommand(owner, state, target, living, 'phantom_assault')
    local expiresAt = now + K.PHANTOM_ASSAULT_DURATION
    local boosted = 0

    for _, record in ipairs(living) do
        record.baseDelay = record.baseDelay or 240
        record.phantomActive = true
        record.phantomExpiresAt = expiresAt
        recomputeCloneCombatMods(record, state, now, count)
        if record.mob and record.mob.timer then
            local tokenExp = expiresAt
            record.mob:timer(K.PHANTOM_ASSAULT_DURATION * 1000, function()
                if record.phantomActive and record.phantomExpiresAt == tokenExp then
                    record.phantomActive = false
                    record.phantomExpiresAt = 0
                    recomputeCloneCombatMods(record, state, nowSec(), #(state.clones or {}))
                end
            end)
        end
        boosted = boosted + 1
    end

    setCount(owner, state)
    return true, boosted, K.PHANTOM_ASSAULT_DURATION, tac
end

function K.getSnapshot(owner)
    local state = owner and owner.getID and K._owners[owner:getID()] or nil
    if not state then
        return {
            clones = 0, engaged = 0, inactive = 0, startup = 0,
            wrong_target = 0, appearance_ok = 0, next_exp = 0, phantom_rem = 0,
            phase = 0, phase_name = 'Building', phase_rem = 0, feint_hits = 0,
            opening_rem = 0, mirror_rem = 0, pin_rem = 0, last_cmd = '',
            target_id = 0, target_alive = false, owner_engaged = false,
            attributed_hits = 0, attempts = 0, diagnostic = '', last_error = '',
        }
    end

    if not validForState(owner, state) or not ownerStillFighting(owner, state.targetId) then
        K.dismissAll(owner)
        return K.getSnapshot(owner)
    end

    local now = nowSec()
    local tactics = pruneTactics(state, now)
    local phase = tactics and tactics.phase or 0
    local phaseRem = (tactics and phase > 0) and math.max(0, math.ceil((tactics.phaseExpiresAt or 0) - now)) or 0
    local openingRem = (tactics and (tactics.openingUntil or 0) > now) and math.max(0, math.ceil(tactics.openingUntil - now)) or 0
    local mirrorRem = (tactics and (tactics.mirrorUntil or 0) > now) and math.max(0, math.ceil(tactics.mirrorUntil - now)) or 0
    local pinRem = (tactics and (tactics.pinUntil or 0) > now) and math.max(0, math.ceil(tactics.pinUntil - now)) or 0
    local lastCmdTag = (tactics and tactics.lastCommandId and K.COMMAND_TAGS[tactics.lastCommandId]) or ''

    local snapshot = {
        clones = 0, engaged = 0, inactive = 0, startup = 0,
        wrong_target = 0, appearance_ok = 0, next_exp = 0, phantom_rem = 0,
        phase = phase, phase_name = K.PHASE_NAMES[phase] or 'Building', phase_rem = phaseRem,
        feint_hits = tactics and (tactics.distinctHits or 0) or 0,
        opening_rem = openingRem, mirror_rem = mirrorRem, pin_rem = pinRem,
        last_cmd = lastCmdTag,
        target_id = state.targetId, attributed_hits = 0, attempts = 0,
        diagnostic = state.lastSpawnInfo or '', last_error = state.lastError or '',
    }

    local ownerTarget = owner.getTarget and owner:getTarget() or nil
    snapshot.target_alive = isValidTarget(owner, ownerTarget, true) and ownerTarget:getID() == state.targetId
    snapshot.owner_engaged = ownerStillFighting(owner, state.targetId)

    for _, record in ipairs(state.clones) do
        if record.mob and record.mob:isAlive() and record.expiresAt > now then
            snapshot.clones = snapshot.clones + 1
            snapshot.attempts = snapshot.attempts + (record.attempts or 0)
            snapshot.attributed_hits = snapshot.attributed_hits + (record.attributedHits or 0)
            if record.appearanceCopied then
                snapshot.appearance_ok = snapshot.appearance_ok + 1
            end
            if record.phantomActive and (record.phantomExpiresAt or 0) > now then
                local pRem = record.phantomExpiresAt - now
                if pRem > snapshot.phantom_rem then
                    snapshot.phantom_rem = pRem
                end
            end

            local engaged, actualId = hasExactEngagement(record)
            if engaged then
                snapshot.engaged = snapshot.engaged + 1
            elseif actualId and actualId ~= record.targetId then
                snapshot.wrong_target = snapshot.wrong_target + 1
                snapshot.inactive = snapshot.inactive + 1
            elseif (record.attempts or 0) == 0 and now < record.nextEngageAt then
                snapshot.startup = snapshot.startup + 1
            else
                snapshot.inactive = snapshot.inactive + 1
            end

            if record.attributionError and snapshot.last_error == '' then
                snapshot.last_error = record.attributionError
            elseif record.inactiveReason and snapshot.last_error == '' and
                (record.attempts or 0) >= K.MAX_ENGAGE_ATTEMPTS then
                snapshot.last_error = record.inactiveReason
            end

            local remaining = record.expiresAt - now
            if snapshot.next_exp == 0 or remaining < snapshot.next_exp then
                snapshot.next_exp = remaining
            end
        end
    end

    snapshot.next_exp = math.ceil(snapshot.next_exp)
    snapshot.phantom_rem = math.ceil(snapshot.phantom_rem)
    return snapshot
end

-- Drop stale Lua userdata when a fresh CCharEntity reuses a character ID.
-- Entity-owned expiry/despawn timers clean any old dynamic MOBs.
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    if player and player.isPC and player:isPC() and player.getID then
        K._owners[player:getID()] = nil
        removeOwnerListeners(player)
        setCount(player, nil)
    end
    super(player, firstLogin, zoning)
end)

return m
