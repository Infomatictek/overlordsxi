-----------------------------------
-- OverlordsXI DRG 1: Lancer (Sequence D — Offensive Opening)
-- Distance-gated Spineshatter Vault (4-12y launch lane, terrain validation, follow-up Jump).
-- Additive to drg_specs.lua (must load after drg_specs.lua; preserves Wyvernheart).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_drg_lancer')
local spec = xi.overlords.spec
local DRG = xi.job.DRG
local KEY = 'lancer'

local VAR_VAULT_UNTIL    = 'OX_LNC_VAULT_RECAST_UNTIL'
local VAR_FOLLOWUP_UNTIL = 'OX_LNC_JUMP_FOLLOWUP_UNTIL'

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isLancer(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == DRG and player:getMainLvl() >= 10 and
        spec.is(player, DRG, KEY)
end

local function hasPolearm(player)
    return player ~= nil and player.getWeaponSkillType and
        player:getWeaponSkillType(xi.slot.MAIN) == xi.skill.POLEARM
end

local function clearState(player)
    if player and player.setLocalVar then
        player:setLocalVar(VAR_FOLLOWUP_UNTIL, 0)
    end
end

-- Spineshatter Vault: locks one enemy 4-12y away, 18s CD.
-- 4-7y = 1.6x normalized polearm hit; >7-12y = 2.2/2.5/2.5/2.8x.
-- Invalid/blocked terrain cancels displacement and damage with 3s retry.
-- On landed long Vault (>7-12y) at Lv50+, native Jump within 5s gains +15% (Lv50) / +20% (Lv70) once.
local function executeVault(player, target, normalizedHit, opts)
    opts = opts or {}
    if not isLancer(player) or not hasPolearm(player) then return nil, 'invalid_state' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil, 'invalid_target'
    end

    local now = xi.overlords.nowSec()
    local recastUntil = player.getLocalVar and (player:getLocalVar(VAR_VAULT_UNTIL) or 0) or 0
    if now < recastUntil then return nil, 'on_recast' end

    local dist = opts.distance or (player.checkDistance and player:checkDistance(target)) or 0
    if dist < 4.0 or dist > 12.0 then
        return nil, 'invalid_launch_range'
    end

    if opts.pathBlocked or opts.invalidTerrain then
        if player.setLocalVar then
            player:setLocalVar(VAR_VAULT_UNTIL, now + 3)
        end
        return 0, { cancelled = true, displaced = false, retrySec = 3 }
    end

    if player.setLocalVar then
        player:setLocalVar(VAR_VAULT_UNTIL, now + 18)
    end

    local lvl = player:getMainLvl()
    local isLong = dist > 7.0
    local mult = isLong and scale(lvl, 2.2, 2.5, 2.5, 2.8) or 1.6
    local dmg = math.floor((normalizedHit or 0) * mult)

    if isLong and dmg > 0 and lvl >= 50 and player.setLocalVar then
        player:setLocalVar(VAR_FOLLOWUP_UNTIL, now + 5)
    end

    return dmg, { cancelled = false, displaced = true, longLane = isLong, multiplier = mult }
end

local function consumeJumpFollowup(player, baseJumpDamage)
    if not isLancer(player) or type(baseJumpDamage) ~= 'number' or baseJumpDamage <= 0 then
        return baseJumpDamage, false
    end
    local now = xi.overlords.nowSec()
    local untilSec = player.getLocalVar and (player:getLocalVar(VAR_FOLLOWUP_UNTIL) or 0) or 0
    if untilSec == 0 or now > untilSec then
        clearState(player)
        return baseJumpDamage, false
    end
    clearState(player)
    local pct = player:getMainLvl() >= 70 and 20 or 15
    return math.floor(baseJumpDamage * (100 + pct) / 100), true
end

xi.overlords.lancer =
{
    executeVault        = executeVault,
    consumeJumpFollowup = consumeJumpFollowup,
    clearState          = clearState,
}

if DRG ~= nil then
    spec.registerCrystal(xi.job.DRG,
    {
        id = 1,
        key = KEY,
        name = 'Lancer',
        abr = 'LNC',
        role = 'Damage',
        icon = 'lancer',
        reqLevel = 10,
        description = 'A polearm vanguard who commits launch lanes with Spineshatter Vault (4–12y) and chains long-lane impacts into empowered native Jumps.',
        highlights =
        {
            'Spineshatter Vault (4–12y, 18s CD): 1.6x polearm hit at 4–7y, 2.2/2.5/2.5/2.8x at >7–12y.',
            'Blocked terrain cancels displacement and damage with a 3s retry; no threat shed or immunity.',
            'At Lv50+, landed long-lane Vault empowers native Jump within 5s by +15% (Lv50) / +20% (Lv70) once.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.POLEARM, scale(level, 12, 22, 34, 46) },
                { xi.mod.STR,     scale(level, 6, 12, 18, 25) },
                { xi.mod.ACC,     scale(level, 10, 18, 28, 40) },
                { xi.mod.ATT,     scale(level, 12, 24, 38, 54) },
            }
        end,
        onRemove = clearState,
    })
end

return m
