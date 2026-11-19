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
K.DAMAGE_ENABLED = false -- visual/targeting validation first; no fake DPS
K._owners = K._owners or {}
K._serial = K._serial or 0

local function isKurogane(player)
    if not player or not player.isPC or not player:isPC() or player:getMainJob() ~= xi.job.NIN or player:getMainLvl() < 10 then
        return false
    end
    -- Avoid recursive spec.refreshPlayer/onApply calls while reading the active Soul.
    return spec.is(player, xi.job.NIN, 'kurogane')
end

local function isValidTarget(owner, target)
    return owner and target and owner.isAlive and owner:isAlive()
        and target.isMob and target:isMob() and target.isAlive and target:isAlive()
        and owner.getZone and target.getZone
        and owner:getZone() == target:getZone()
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
    return state.owner == owner and state.zone == owner:getZone()
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
            -- Each clone decides independently; actual combat damage deliberately
            -- disabled until owner credit, animations and boss AoE are proven.
            local choice = math.random(1, 100)
            rec.action = choice <= 55 and 1 or (choice <= 75 and 2 or (choice <= 92 and 3 or 4))
            rec.nextActionAt = now + (0.7 + math.random() * 1.2)
            if rec.mob.lookAt then pcall(function() rec.mob:lookAt(target:getPos()) end) end
        end
    end
    setCount(owner, state)
    if #state.clones == 0 then
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
    mob:setMaxHP(1)
    mob:setHP(1)
    return mob
end

function K.spawn(owner, count)
    if not K.ENABLE_EXPERIMENTAL_CLONES then return false, 'experimental clone entities disabled' end
    if not isKurogane(owner) then return false, 'Kurogane required' end
    local target = owner.getTarget and owner:getTarget() or nil
    if not isValidTarget(owner, target) then return false, 'engage a valid mob first' end

    local id = owner:getID()
    local state = K._owners[id]
    if state and state.zone ~= owner:getZone() then
        K.dismissAll(owner)
        state = nil
    end
    if not state then
        state = { owner = owner, zone = owner:getZone(), clones = {} }
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
    if spawned > 0 and owner.timer then
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
