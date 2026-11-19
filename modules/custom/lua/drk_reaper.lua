-----------------------------------
-- OverlordsXI DRK 1: Reaper (Sequence D — Offensive Opening)
-- Enemy recovery window execution with Finality (4y, 16s CD, Scythe).
-- Additive to drk_specs.lua (must load after drk_specs.lua; preserves Dreadnought).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_drk_reaper')
local spec = xi.overlords.spec
local DRK = xi.job.DRK
local KEY = 'reaper'

local VAR_FINALITY_CD = 'OX_RPR_FINALITY_CD'

-- Per-target recovery tracking keyed by "zoneId:targetId:spawnGen".
local targetRecovery = {}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isReaper(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == DRK and player:getMainLvl() >= 10 and
        spec.is(player, DRK, KEY)
end

local function hasScythe(player)
    return player ~= nil and player.getWeaponSkillType and
        player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.SCYTHE
end

local function tKey(target, spawnGen)
    local z = target and target.getZoneID and target:getZoneID() or 0
    local id = target and target.getID and target:getID() or 0
    local g = spawnGen or (target and target.getLocalVar and target:getLocalVar('OX_SPAWN_GEN')) or 0
    return string.format('%d:%d:%d', z, id, g)
end

-- Record enemy completed damaging spell/TP move (multi-hit move = 1 sequence) -> opens 5s recovery window
-- and resets regular-round counter. Never counts player actions or periodic ticks.
local function onEnemyActionComplete(target, opts)
    opts = opts or {}
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return false
    end
    if opts.isPlayerAction or opts.isPeriodicTick then return false end

    local now = xi.overlords.nowSec()
    local key = tKey(target, opts.spawnGen)
    local rec = targetRecovery[key] or { openUntil = 0, rounds = 0, lastSeq = nil }

    if opts.isDamagingSpellOrTpMove then
        if opts.actionSeq ~= nil and rec.lastSeq == opts.actionSeq then
            return false -- Multi-hit move opens once per sequence
        end
        rec.lastSeq = opts.actionSeq
        rec.openUntil = now + 5
        rec.rounds = 0
        targetRecovery[key] = rec
        return true
    elseif opts.isRegularAttackRound then
        if opts.roundSeq ~= nil and rec.lastRoundSeq == opts.roundSeq then
            return false -- Multiple subhits in one round count once
        end
        rec.lastRoundSeq = opts.roundSeq
        rec.rounds = rec.rounds + 1
        if rec.rounds >= 6 then
            rec.openUntil = now + 5
            rec.rounds = 0
        end
        targetRecovery[key] = rec
        return rec.openUntil >= now
    end
    return false
end

local function isInRecovery(target, spawnGen)
    local rec = targetRecovery[tKey(target, spawnGen)]
    if not rec then return false, 0 end
    local now = xi.overlords.nowSec()
    if now <= rec.openUntil then
        return true, rec.openUntil - now
    end
    return false, 0
end

-- Finality: 4y, 16s CD, 1.3x base or 2.3/2.6/2.6/3.0x during 5s recovery window (+15/20% below 25% HP at Lv50/70).
-- Ordinary resolved miss still starts personal recast; recovery window is consumed ONLY on a landed recovery strike.
local function executeFinality(player, target, normalizedHit, opts)
    opts = opts or {}
    if not isReaper(player) or not hasScythe(player) then return nil, 'invalid_state' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil, 'invalid_target'
    end
    if player.checkDistance and player:checkDistance(target) > 4 then
        return nil, 'out_of_range'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_FINALITY_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 16 then
        return nil, 'on_recast'
    end

    if player.setLocalVar then
        player:setLocalVar(VAR_FINALITY_CD, now)
    end

    if opts.missed then
        return 0, { missed = true, usedRecovery = false }
    end

    local key = tKey(target, opts.spawnGen)
    local rec = targetRecovery[key]
    local inRec = rec ~= nil and now <= rec.openUntil
    local lvl = player:getMainLvl()

    local mult = 1.3
    local usedRecovery = false
    if inRec then
        mult = scale(lvl, 2.3, 2.6, 2.6, 3.0)
        usedRecovery = true
        rec.openUntil = 0 -- Consumed only on landed recovery strike
    end

    local dmg = math.floor((normalizedHit or 0) * mult)
    if usedRecovery then
        local hpp = opts.targetHPP or (target.getHPP and target:getHPP()) or 100
        if lvl >= 50 and hpp < 25 then
            local execPct = lvl >= 70 and 120 or 115
            dmg = math.floor(dmg * execPct / 100)
        end
    end

    return dmg, { missed = false, usedRecovery = usedRecovery, multiplier = mult }
end

xi.overlords.reaper =
{
    onEnemyActionComplete = onEnemyActionComplete,
    isInRecovery          = isInRecovery,
    executeFinality       = executeFinality,
}

if DRK ~= nil then
    spec.registerCrystal(xi.job.DRK,
    {
        id = 1,
        key = KEY,
        name = 'Reaper',
        abr = 'RPR',
        role = 'Damage',
        icon = 'reaper',
        reqLevel = 10,
        description = 'A Scythe executioner who punishes enemy recovery windows after damaging spells, TP moves, or every sixth ordinary attack round.',
        highlights =
        {
            'Finality (4y, 16s CD): 1.3x normalized scythe hit, escalating to 2.3/2.6/2.6/3.0x during a 5s enemy recovery window.',
            'Below 25% target HP adds +15% (Lv50) / +20% (Lv70) to landed recovery strikes.',
            'Ordinary misses start personal recast without consuming the recovery window; periodic ticks never open recovery.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.SCYTHE, scale(level, 12, 22, 34, 46) },
                { xi.mod.STR,    scale(level, 6, 12, 18, 25) },
                { xi.mod.ACC,    scale(level, 10, 18, 28, 40) },
                { xi.mod.ATT,    scale(level, 12, 24, 38, 54) },
            }
        end,
    })
end

return m
