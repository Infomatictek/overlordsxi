-----------------------------------
-- OverlordsXI RNG 1: Sniper (Sequence D — Offensive Opening)
-- Low-volume committed single-shot Sightline Shot (20y, 3s/4s aim, 12s recast).
-- Additive to rng_specs.lua (must load after rng_specs.lua; preserves Huntsman).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_rng_sniper')
local spec = xi.overlords.spec
local RNG = xi.job.RNG
local KEY = 'sniper'

local VAR_RECAST_UNTIL = 'OX_SNP_RECAST_UNTIL'
local aimStateByChar = {}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isSniper(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == RNG and player:getMainLvl() >= 10 and
        spec.is(player, RNG, KEY)
end

local function clearAim(player)
    if player and player.getID then
        aimStateByChar[player:getID()] = nil
    end
end

local function startSightlineAim(player, target, pos)
    if not isSniper(player) then return false, 'not_sniper' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return false, 'invalid_target'
    end
    if player.checkDistance and player:checkDistance(target) > 20 then
        return false, 'out_of_range'
    end
    local now = xi.overlords.nowSec()
    local recastUntil = player.getLocalVar and (player:getLocalVar(VAR_RECAST_UNTIL) or 0) or 0
    if now < recastUntil then
        return false, 'on_recast'
    end
    aimStateByChar[player:getID()] =
    {
        startedAt = now,
        targetId  = target:getID(),
        x         = pos and pos.x or 0,
        z         = pos and pos.z or 0,
    }
    return true, 'aiming'
end

-- Resolve Sightline Shot at release.
-- Moving >1y, losing LOS, changing target, or incapacitation cancels aim (0 ammo, 3s retry).
-- Resolved miss spends 1 ammo and 12s recast. Eagle Eye Shot never inherits Sightline multiplier.
local function resolveSightlineShot(player, target, baseShotDamage, opts)
    opts = opts or {}
    if not isSniper(player) then return nil, 'not_sniper' end
    local state = aimStateByChar[player:getID()]
    if not state then return nil, 'not_aiming' end

    local now = xi.overlords.nowSec()
    local elapsed = now - state.startedAt
    local dx = (opts.x or state.x) - state.x
    local dz = (opts.z or state.z) - state.z
    local movedDist = math.sqrt(dx * dx + dz * dz)

    local cancelled = opts.incapacitated or opts.lostLOS or (movedDist > 1.0) or
        not target or not target.isAlive or not target:isAlive() or
        target:getID() ~= state.targetId or elapsed < 3.0

    aimStateByChar[player:getID()] = nil

    if cancelled then
        if player.setLocalVar then
            player:setLocalVar(VAR_RECAST_UNTIL, now + 3) -- 3s retry, 0 ammo spent
        end
        return 0, { cancelled = true, ammoSpent = 0, retrySec = 3 }
    end

    if player.setLocalVar then
        player:setLocalVar(VAR_RECAST_UNTIL, now + 12) -- 12s recast, 1 ammo spent
    end

    if opts.missed then
        return 0, { cancelled = false, missed = true, ammoSpent = 1, projectiles = 1 }
    end

    local lvl = player:getMainLvl()
    local racc = scale(lvl, 10, 20, 20, 30)
    local mult
    if lvl >= 70 and elapsed >= 4.0 then
        mult = 3.2
    elseif lvl >= 50 and elapsed >= 4.0 then
        mult = 2.8
    elseif lvl >= 30 then
        mult = 2.3
    else
        mult = 2.0
    end

    return math.floor((baseShotDamage or 0) * mult), {
        cancelled = false,
        missed = false,
        ammoSpent = 1,
        projectiles = 1,
        raccBonus = racc,
        multiplier = mult,
    }
end

xi.overlords.sniper =
{
    startSightlineAim    = startSightlineAim,
    resolveSightlineShot = resolveSightlineShot,
    clearAim             = clearAim,
}

if RNG ~= nil then
    spec.registerCrystal(xi.job.RNG,
    {
        id = 1,
        key = KEY,
        name = 'Sniper',
        abr = 'SNP',
        role = 'Damage',
        icon = 'sniper',
        reqLevel = 10,
        description = 'A deliberate marksman who plants in a firing lane and commits a single high-precision Sightline Shot with low ammo burn.',
        highlights =
        {
            'Sightline Shot (20y, 3s/4s aim, 12s recast): +10/20/20/30 RACC and 2.0/2.3/2.8/3.2x single-shot damage.',
            'Moving >1y, losing LOS, target swap, or incapacitation cancels aim with 0 ammo spent and a 3s retry.',
            'Resolved misses spend 1 ammo and 12s recast; Eagle Eye Shot never inherits the Sightline multiplier.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.MARKSMANSHIP, scale(level, 12, 22, 34, 46) },
                { xi.mod.RACC,         scale(level, 12, 22, 34, 46) },
                { xi.mod.RATT,         scale(level, 12, 24, 38, 54) },
                { xi.mod.AGI,          scale(level, 6, 12, 18, 25) },
            }
        end,
        onRemove = clearAim,
    })
end

return m
