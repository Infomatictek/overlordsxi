-----------------------------------
-- OverlordsXI GEO 3: Terramancer (Sequence D — Offensive Opening)
-- Delayed target-owned ground faults (Shallow Fault +2s / Deep Fault +4s).
-- Fixed snapshot position, 2D <=3y & |dy| <=3y eruption check, no replacement target.
-- Additive to geo_specs.lua (must load after geo_specs.lua; preserves Verdant).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_geo_terramancer')
local spec = xi.overlords.spec
local GEO = xi.job.GEO
local KEY = 'terramancer'

local VAR_FAULT_CD = 'OX_TRM_FAULT_CD'
local activeFaultByChar = {}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isTerramancer(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == GEO and player:getMainLvl() >= 10 and
        spec.is(player, GEO, KEY)
end

local function clearFault(player)
    if player and player.getID then
        activeFaultByChar[player:getID()] = nil
    end
end

-- Place Shallow Fault (Lv10+, +2s fuse, 7% MP) or Deep Fault (Lv30+, +4s fuse, 12% MP).
-- Shared 8s recast, 18y range, one outstanding fault per caster (rejects replacement without cost).
local function placeFault(player, target, kind, targetPos, opts)
    opts = opts or {}
    if not isTerramancer(player) then return nil, 'not_terramancer' end
    if kind ~= 'shallow' and kind ~= 'deep' then return nil, 'invalid_kind' end
    if kind == 'deep' and player:getMainLvl() < 30 then return nil, 'level_too_low' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil, 'invalid_target'
    end
    if player.checkDistance and player:checkDistance(target) > 18 then
        return nil, 'out_of_range'
    end

    local now = xi.overlords.nowSec()
    local existing = activeFaultByChar[player:getID()]
    if existing and now < existing.eruptAt then
        return nil, 'fault_already_active' -- Reject replacement without cost
    end

    local last = player.getLocalVar and (player:getLocalVar(VAR_FAULT_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 8 then
        return nil, 'on_recast'
    end

    local maxMP = player.getMaxMP and player:getMaxMP() or 100
    local mpCost = math.max(1, math.ceil(maxMP * (kind == 'deep' and 0.12 or 0.07)))
    local fuse = kind == 'deep' and 4 or 2

    if player.setLocalVar then
        player:setLocalVar(VAR_FAULT_CD, now)
    end

    local fault =
    {
        kind       = kind,
        targetId   = target:getID(),
        spawnGen   = opts.spawnGen or 0,
        zoneId     = target.getZoneID and target:getZoneID() or 0,
        x          = targetPos and targetPos.x or 0,
        y          = targetPos and targetPos.y or 0,
        z          = targetPos and targetPos.z or 0,
        radius     = 3.0,
        eruptAt    = now + fuse,
        mpCost     = mpCost,
    }
    activeFaultByChar[player:getID()] = fault
    return fault
end

-- Resolve fault at fuse expiry.
-- Samples original target only (same ID, spawnGen, zone, alive, claimed, 2D <=3y, |dy| <=3y).
-- Spectators / second mobs on the marker NEVER take damage.
local function resolveFault(player, target, currentPos, stoneBaseDamage, opts)
    opts = opts or {}
    local fault = player and player.getID and activeFaultByChar[player:getID()] or nil
    if not fault then return 0, { hit = false, reason = 'no_fault' } end

    local now = xi.overlords.nowSec()
    if now < fault.eruptAt then
        return 0, { hit = false, reason = 'fuse_pending' }
    end

    activeFaultByChar[player:getID()] = nil

    if not isTerramancer(player) or opts.lostClaim or not target or
       not target.isAlive or not target:isAlive() or
       target:getID() ~= fault.targetId or
       (opts.spawnGen or 0) ~= fault.spawnGen or
       (target.getZoneID and target:getZoneID() or 0) ~= fault.zoneId then
        return 0, { hit = false, reason = 'target_invalid_or_unclaimed' }
    end

    local dx = (currentPos and currentPos.x or 0) - fault.x
    local dz = (currentPos and currentPos.z or 0) - fault.z
    local dy = math.abs((currentPos and currentPos.y or 0) - fault.y)
    local dist2d = math.sqrt(dx * dx + dz * dz)

    if dist2d > fault.radius or dy > 3.0 then
        return 0, { hit = false, reason = 'moved_out_of_fault', dist2d = dist2d, dy = dy }
    end

    local lvl = player:getMainLvl()
    local mult
    if fault.kind == 'deep' then
        mult = scale(lvl, 2.8, 2.8, 3.2, 3.6)
    else
        mult = scale(lvl, 1.8, 1.8, 2.0, 2.2)
    end
    return math.floor((stoneBaseDamage or 0) * mult), { hit = true, kind = fault.kind, multiplier = mult }
end

xi.overlords.terramancer =
{
    placeFault   = placeFault,
    resolveFault = resolveFault,
    clearFault   = clearFault,
}

if GEO ~= nil then
    spec.registerCrystal(xi.job.GEO,
    {
        id = 3,
        key = KEY,
        name = 'Terramancer',
        abr = 'TRM',
        role = 'Damage',
        icon = 'terramancer',
        reqLevel = 10,
        description = 'A seismic Geomancer who predicts enemy position with delayed target-locked Shallow (+2s) and Deep (+4s) ground faults.',
        highlights =
        {
            'Shallow Fault (Lv10, +2s, 1.8/1.8/2.0/2.2x Stone) & Deep Fault (Lv30, +4s, 2.8/3.2/3.6x Stone), shared 8s recast.',
            'Locks fixed position, target ID, spawn generation, and zone; erupts only if original claimed target is within 3y 2D and 3y vertical.',
            'One outstanding fault per caster; spectators never take damage; cleans up on Soul swap, zone, death, or claim loss.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.INT,  scale(level, 8, 15, 22, 30) },
                { xi.mod.MATT, scale(level, 10, 18, 28, 38) },
                { xi.mod.MACC, scale(level, 8, 15, 24, 34) },
            }
        end,
        onRemove = clearFault,
    })
end

return m
