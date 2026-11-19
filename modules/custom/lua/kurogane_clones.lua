-----------------------------------
-- OverlordsXI Kurogane — experimental dynamic Shadow Clones
--
-- First in-game vertical slice, NOT a finished combat implementation.
-- Uses independently spawned dynamic MOB entities (not the single pet slot).
-- Configured OFF until in-game entity/allegiance/AoE behavior is verified.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')

xi.overlords = xi.overlords or {}
xi.overlords.kurogane = xi.overlords.kurogane or {}
local K = xi.overlords.kurogane
local spec = xi.overlords.spec

-- Set true on a test server ONLY. Do not use in production until the checklist
-- in docs/kurogane-shadow-clones.md has passed (especially AoE/player allegiance).
K.ENABLE_EXPERIMENTAL_CLONES = K.ENABLE_EXPERIMENTAL_CLONES == true
K.MAX_ACTIVE = 5
K.LIFETIME_MIN = 6
K.LIFETIME_MAX = 10
-- A second explicit GM gate is required before clones may receive attack enmity.
-- Native mob auto-attacks are not owner-credited yet; never enable on production.
K.ENABLE_EXPERIMENTAL_COMBAT = false
K.EXPERIMENTAL_PHYS_DAMAGE_PENALTY = -95
K._owners = K._owners or {}
K._serial = K._serial or 0

local function isKurogane(player)
    if not player or not player.isPC or not player:isPC() or player:getMainJob() ~= xi.job.NIN or player:getMainLvl() < 10 then
        return false
    end
    -- Avoid recursive spec.refreshPlayer/onApply calls while reading the active Soul.
    return spec.is(player, xi.job.NIN, 'kurogane')
end

local function zoneId(entity)
    if not entity then return nil end
    if entity.getZoneID then return entity:getZoneID() end
    local zone = entity.getZone and entity:getZone() or nil
    return zone and zone.getID and zone:getID() or nil
end

local function isValidTarget(owner, target)
    local ownerZone = zoneId(owner)
    return owner and target and ownerZone ~= nil and owner.isAlive and owner:isAlive()
        and target.isMob and target:isMob() and target.isAlive and target:isAlive()
        and ownerZone == zoneId(target)
end

local function setCount(owner, state)
    if owner and owner.setLocalVar then
        owner:setLocalVar('OX_KRG_CLONE_COUNT', state and #state.clones or 0)
        local rem = 0
        if state and #state.clones > 0 then
            local now = xi.overlords.nowSec()
            for _, record in ipairs(state.clones) do
                local left = math.max(0, record.expiresAt - now)
                if rem == 0 or left < rem then rem = left end
            end
        end
        owner:setLocalVar('OX_KRG_NEXT_EXP', math.ceil(rem))
    end
end

local function dismissMob(record)
    if not record or not record.mob then return end
    local mob = record.mob
    if mob.isAlive and mob:isAlive() then
        if type(DespawnMob) == 'function' then
            pcall(DespawnMob, mob:getID())
        elseif mob.setStatus then
            pcall(function() mob:setStatus(xi.status.DISAPPEAR) end)
        end
    end
end

local function removeAt(state, index)
    local record = table.remove(state.clones, index)
    dismissMob(record)
end

function K.dismissAll(owner)
    if not owner or not owner.getID then return end
    local id = owner:getID()
    local state = K._owners[id]
    if state then
        for i = #state.clones, 1, -1 do removeAt(state, i) end
        K._owners[id] = nil
    end
    setCount(owner, nil)
end

local function validForState(owner, state)
    return state.ownerId == owner:getID() and state.zoneId == zoneId(owner)
        and isKurogane(owner) and owner.isAlive and owner:isAlive()
end

local function tickOwner(owner, state)
    if K._owners[owner:getID()] ~= state then return end
    if not validForState(owner, state) then
        K.dismissAll(owner)
        return
    end
    local target = owner.getTarget and owner:getTarget() or nil
    local now = xi.overlords.nowSec()
    for i = #state.clones, 1, -1 do
        local rec = state.clones[i]
        if now >= rec.expiresAt or not rec.mob or not rec.mob:isAlive() then
            removeAt(state, i)
        elseif not isValidTarget(owner, target) or target:getID() ~= rec.targetId then
            -- Never auto-acquire an unrelated enemy.
            removeAt(state, i)
        elseif now >= rec.nextActionAt then
            -- Staggered native MOB engagement. The clone gets enmity toward ONLY
            -- the owner's current target and LSB handles pathing/auto-attacks.
            -- No scripted WS, Ninjutsu or fake damage: those need owner attribution.
            rec.nextActionAt = now + (0.7 + math.random() * 1.2)
            if K.ENABLE_EXPERIMENTAL_COMBAT and not rec.engaged then
                if rec.mob.updateEnmity then
                    local ok = pcall(function() rec.mob:updateEnmity(target) end)
                    rec.engaged = ok
                    rec.action = ok and 1 or 0
                end
            elseif rec.mob.lookAt and not K.ENABLE_EXPERIMENTAL_COMBAT then
                pcall(function() rec.mob:lookAt(target:getPos()) end)
            end
        end
    end
    setCount(owner, state)
    if #state.clones == 0 then
        state.timerRunning = false
        K._owners[owner:getID()] = nil
    elseif owner.timer then
        owner:timer(350, function(actor)
            if actor and K._owners[actor:getID()] == state then
                tickOwner(actor, state)
            end
        end)
    end
end

local function makeClone(owner, target, index)
    if not (xi.allegiance and xi.allegiance.PLAYER) then
        return nil, 'PLAYER allegiance unavailable; refusing hostile MOB spawn'
    end
    local zone = owner.getInstance and owner:getInstance() or nil
    if not zone then zone = owner:getZone() end
    if not zone or not zone.insertDynamicEntity then return nil, 'dynamic entities unavailable' end

    K._serial = K._serial + 1
    local theta = index * 2.399963 + math.random() * 0.3
    local x = owner:getXPos() + math.cos(theta) * 1.4
    local z = owner:getZPos() + math.sin(theta) * 1.4
    local model = owner.getModelId and owner:getModelId() or 0
    local mob = zone:insertDynamicEntity({
        objtype = xi.objType.MOB,
        allegiance = xi.allegiance and xi.allegiance.PLAYER or nil,
        name = ('KRG_%d_%d'):format(owner:getID(), K._serial),
        packetName = owner:getName() .. "'s Shadow",
        x = x, y = owner:getYPos(), z = z,
        rotation = owner:getRotPos(),
        look = model,
        minLevel = owner:getMainLvl(),
        maxLevel = owner:getMainLvl(),
        dropId = 0,
        isAggroable = false,
        releaseIdOnDisappear = true,
        specialSpawnAnimation = true,
    })
    if not mob then return nil, 'dynamic MOB creation failed' end

    -- The Lua binding supplies equipment look data, but whether a dynamic
    -- MOB can display a full player look must be checked on the target client.
    if owner.getEquipmentModelIds and mob.setLook then
        pcall(function() mob:setLook(owner:getEquipmentModelIds()) end)
    end
    if mob.setMobMod and xi.mobMod then
        if xi.mobMod.NO_DROPS then mob:setMobMod(xi.mobMod.NO_DROPS, 1) end
        if xi.mobMod.NO_EXP then mob:setMobMod(xi.mobMod.NO_EXP, 1) end
    end
    if mob.setDropID then mob:setDropID(0) end
    mob:spawn()
    -- Set offense to minimal test values. Real damage budgeting and ownership
    -- cannot be implemented faithfully using native allied-MOB melee alone.
    if mob.addMod and xi.mod and xi.mod.PHYS_DMG_DEALT then
        mob:addMod(xi.mod.PHYS_DMG_DEALT, K.EXPERIMENTAL_PHYS_DAMAGE_PENALTY)
    end
    if mob.setMod and xi.mod and xi.mod.ATTP then mob:setMod(xi.mod.ATTP, -90) end
    if mob.setMod and xi.mod and xi.mod.MACC then mob:setMod(xi.mod.MACC, -500) end
    if mob.setMod and xi.mod and xi.mod.MATT then mob:setMod(xi.mod.MATT, -100) end
    mob:setMaxHP(1)
    mob:setHP(1)
    -- Native AI shouldn't move/engage until its independent startup delay.
    if mob.stun then mob:stun(300 + math.random(250, 950)) end
    return mob
end

function K.spawn(owner, count)
    if not K.ENABLE_EXPERIMENTAL_CLONES then return false, 'experimental clone entities disabled' end
    if not isKurogane(owner) then return false, 'Kurogane required' end
    local target = owner.getTarget and owner:getTarget() or nil
    if not isValidTarget(owner, target) or (owner.isEngaged and not owner:isEngaged()) then
        return false, 'engage and select a valid mob first'
    end

    local id = owner:getID()
    local state = K._owners[id]
    if state and state.zoneId ~= zoneId(owner) then
        K.dismissAll(owner)
        state = nil
    end
    if not state then
        state = { ownerId = owner:getID(), zoneId = zoneId(owner), clones = {} }
        K._owners[id] = state
    end
    local spawned = 0
    for i = 1, math.min(5, math.max(0, math.floor(count or 0))) do
        while #state.clones >= K.MAX_ACTIVE do removeAt(state, 1) end
        local ok, mobOrErr, err = pcall(makeClone, owner, target, i)
        if not ok or not mobOrErr then
            -- Fail closed and remove anything created by this cast.
            K.dismissAll(owner)
            return false, ok and (err or 'unknown spawn failure') or tostring(mobOrErr)
        end
        local now = xi.overlords.nowSec()
        state.clones[#state.clones + 1] = {
            mob = mobOrErr,
            targetId = target:getID(),
            expiresAt = now + math.random(K.LIFETIME_MIN, K.LIFETIME_MAX),
            nextActionAt = now + 0.25 + math.random() * 1.2,
            action = 0,
        }
        spawned = spawned + 1
    end
    setCount(owner, state)
    if spawned > 0 and owner.timer and not state.timerRunning then
        state.timerRunning = true
        owner:timer(350, function(actor)
            if actor and K._owners[actor:getID()] == state then
                tickOwner(actor, state)
            end
        end)
    end
    return true, spawned
end

function K.getSnapshot(owner)
    local state = owner and owner.getID and K._owners[owner:getID()] or nil
    if not state then return { clones = 0, next_exp = 0 } end
    if not validForState(owner, state) then
        K.dismissAll(owner)
        return { clones = 0, next_exp = 0 }
    end
    local now, count, nextExp = xi.overlords.nowSec(), 0, 0
    for _, record in ipairs(state.clones) do
        if record.mob and record.mob:isAlive() and record.expiresAt > now then
            count = count + 1
            local remaining = record.expiresAt - now
            if nextExp == 0 or remaining < nextExp then nextExp = remaining end
        end
    end
    return { clones = count, next_exp = math.ceil(nextExp) }
end

return K
