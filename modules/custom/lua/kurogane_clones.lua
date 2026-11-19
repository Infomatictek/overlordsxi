-----------------------------------
-- OverlordsXI Kurogane — dynamic Shadow Clone test backend
--
-- Real dynamic MOB entities are used so every clone has its own native AI,
-- pathing, HP, attack timer, and AoE vulnerability. The feature remains
-- GM-gated until docs/kurogane-shadow-clones.md is verified in game.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')

local m = Module:new('kurogane_clones')

xi.overlords = xi.overlords or {}
xi.overlords.kurogane = xi.overlords.kurogane or {}
local K = xi.overlords.kurogane
local spec = xi.overlords.spec

K.ENABLE_EXPERIMENTAL_CLONES = K.ENABLE_EXPERIMENTAL_CLONES == true
K.ENABLE_EXPERIMENTAL_COMBAT = K.ENABLE_EXPERIMENTAL_COMBAT == true
K.MAX_ACTIVE = 5
K.LIFETIME_MIN = 6
K.LIFETIME_MAX = 10
K.MAX_ENGAGE_ATTEMPTS = 3
K.EXPERIMENTAL_PHYS_DAMAGE_PENALTY = -95
K._owners = K._owners or {}
K._serial = K._serial or 0

local OWNER_DEATH_LISTENER = 'OX_KRG_CLONE_OWNER_DEATH'
local OWNER_DISENGAGE_LISTENER = 'OX_KRG_CLONE_OWNER_DISENGAGE'
local ATTACK_LISTENER = 'OX_KRG_CLONE_ATTACK'
local DEATH_LISTENER = 'OX_KRG_CLONE_DEATH'
local DESPAWN_LISTENER = 'OX_KRG_CLONE_DESPAWN'
local LOOK_FIELDS = { 'face', 'race', 'head', 'body', 'hands', 'legs', 'feet', 'main', 'sub', 'ranged', 'modelSize' }

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

local function setCount(owner, state)
    if not owner or not owner.setLocalVar then
        return
    end

    owner:setLocalVar('OX_KRG_CLONE_COUNT', state and #state.clones or 0)
    local remaining = 0
    if state and #state.clones > 0 then
        local now = xi.overlords.nowSec()
        for _, record in ipairs(state.clones) do
            local left = math.max(0, record.expiresAt - now)
            if remaining == 0 or left < remaining then
                remaining = left
            end
        end
    end

    owner:setLocalVar('OX_KRG_NEXT_EXP', math.ceil(remaining))
end

local function removeOwnerListeners(owner)
    if owner and owner.removeListener then
        pcall(function() owner:removeListener(OWNER_DEATH_LISTENER) end)
        pcall(function() owner:removeListener(OWNER_DISENGAGE_LISTENER) end)
    end
end

local function dismissMob(record)
    if not record or not record.mob then
        return
    end

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

    local owner = type(GetPlayerByID) == 'function' and GetPlayerByID(ownerId) or nil
    if owner then
        setCount(owner, state)
    end
    clearStateIfEmpty(ownerId, state)
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
                for index = #state.clones, 1, -1 do
                    removeAt(state, index, true)
                end
            end
        end
    end
end

local function validForState(owner, state)
    return state.ownerId == owner:getID() and state.zoneId == zoneId(owner) and
        isKurogane(owner) and owner.isAlive and owner:isAlive()
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

    local now = xi.overlords.nowSec()
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
            dismissMob({ mob = actor })
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
                dismissMob({ mob = actor })
            end
        end
    end)

    mob:removeListener(DEATH_LISTENER)
    mob:addListener('DEATH', DEATH_LISTENER, function(actor)
        forgetMob(ownerId, actor:getID())
    end)

    mob:removeListener(DESPAWN_LISTENER)
    mob:addListener('DESPAWN', DESPAWN_LISTENER, function(actor)
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
        if xi.mobMod.MULTI_HIT then mob:setMobMod(xi.mobMod.MULTI_HIT, 0) end
    end
    if mob.setDropID then mob:setDropID(0) end
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

    -- Conservative, single-hit native melee while ownership/balance is tested.
    if mob.addMod and xi.mod then
        if xi.mod.PHYS_DMG_DEALT then mob:addMod(xi.mod.PHYS_DMG_DEALT, K.EXPERIMENTAL_PHYS_DAMAGE_PENALTY) end
        if xi.mod.DOUBLE_ATTACK then mob:addMod(xi.mod.DOUBLE_ATTACK, -100) end
        if xi.mod.TRIPLE_ATTACK then mob:addMod(xi.mod.TRIPLE_ATTACK, -100) end
        if xi.mod.QUAD_ATTACK then mob:addMod(xi.mod.QUAD_ATTACK, -100) end
        if xi.mod.DESPAWN_TIME_REDUCTION then mob:addMod(xi.mod.DESPAWN_TIME_REDUCTION, 15) end
    end
    if mob.setMod and xi.mod then
        if xi.mod.ATTP then mob:setMod(xi.mod.ATTP, -90) end
        if xi.mod.MACC then mob:setMod(xi.mod.MACC, -500) end
        if xi.mod.MATT then mob:setMod(xi.mod.MATT, -100) end
    end
    if mob.setDelay then mob:setDelay(math.random(210, 270)) end
    if mob.setMaxHP then mob:setMaxHP(1) end
    if mob.setHP then mob:setHP(1) end
    if not mob.getHP or mob:getHP() ~= 1 then
        dismissMob({ mob = mob })
        return nil, 'cannot enforce 1 HP on dynamic clone'
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
        dismissMob({ mob = mob })
        return nil, lookInfo
    end

    return mob, lookInfo, posInfo
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

function K.spawn(owner, count)
    if not K.ENABLE_EXPERIMENTAL_CLONES then
        return false, 'experimental clone entities disabled'
    end
    if not isKurogane(owner) then
        return false, 'Kurogane required'
    end

    local target = owner.getTarget and owner:getTarget() or nil
    if not isValidTarget(owner, target, true) or not ownerStillFighting(owner, target and target:getID() or 0) then
        return false, 'engage a valid mob first'
    end

    local ownerId = owner:getID()
    local targetId = target:getID()
    local state = K._owners[ownerId]
    if state and (state.zoneId ~= zoneId(owner) or state.targetId ~= targetId) then
        K.dismissAll(owner)
        state = nil
    end
    if not state then
        state = {
            ownerId = ownerId,
            zoneId = zoneId(owner),
            targetId = targetId,
            clones = {},
            lastError = '',
        }
        K._owners[ownerId] = state
    end

    attachOwnerListeners(owner)
    local spawned = 0
    local createdIds = {}
    local wanted = math.min(K.MAX_ACTIVE, math.max(0, math.floor(tonumber(count) or 0)))
    if wanted == 0 then
        clearStateIfEmpty(ownerId, state)
        return false, 'clone count must be between 1 and 5'
    end
    for index = 1, wanted do
        while #state.clones >= K.MAX_ACTIVE do
            removeAt(state, 1, true)
        end

        local ok, mobOrError, lookInfo, posInfo = pcall(makeClone, owner, target, index)
        if not ok or not mobOrError then
            state.lastError = ok and tostring(lookInfo or 'unknown spawn failure') or tostring(mobOrError)
            -- Roll back only this request's entities. Pre-existing clones stay
            -- alive; a partial dynamic-entity allocation never leaks.
            for recordIndex = #state.clones, 1, -1 do
                if createdIds[state.clones[recordIndex].mobId] then
                    removeAt(state, recordIndex, true)
                end
            end
            setCount(owner, state)
            clearStateIfEmpty(ownerId, state)
            return false, state.lastError
        end

        local now = xi.overlords.nowSec()
        local lifetime = math.random(K.LIFETIME_MIN, K.LIFETIME_MAX)
        local record = {
            mob = mobOrError,
            mobId = mobOrError:getID(),
            targetId = targetId,
            expiresAt = now + lifetime,
            nextEngageAt = now + math.randomFloat(0.25, 1.4),
            attempts = 0,
            action = 0,
            appearanceCopied = true,
            appearanceInfo = lookInfo,
            positionInfo = posInfo,
            attributedHits = 0,
            attributedDamage = 0,
        }
        state.clones[#state.clones + 1] = record
        createdIds[record.mobId] = true
        installCloneListeners(mobOrError, ownerId, targetId)

        -- The entity owns expiry, so logout cannot strand it when the player's
        -- timer queue disappears.
        if mobOrError.timer then
            mobOrError:timer(lifetime * 1000, function(actor)
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

function K.getSnapshot(owner)
    local state = owner and owner.getID and K._owners[owner:getID()] or nil
    if not state then
        return {
            clones = 0, engaged = 0, inactive = 0, startup = 0,
            wrong_target = 0, appearance_ok = 0, next_exp = 0,
            target_id = 0, target_alive = false, owner_engaged = false,
            attributed_hits = 0, attempts = 0, diagnostic = '', last_error = '',
        }
    end

    if not validForState(owner, state) then
        K.dismissAll(owner)
        return K.getSnapshot(owner)
    end

    local now = xi.overlords.nowSec()
    local snapshot = {
        clones = 0, engaged = 0, inactive = 0, startup = 0,
        wrong_target = 0, appearance_ok = 0, next_exp = 0,
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
