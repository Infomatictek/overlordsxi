-----------------------------------
-- OverlordsXI DRG 2: Skyborn (Sequence E — Targeted Defense/Support Tank)
-- Grounding Cry cold-start threat (200 CE / 700 VE) + Skyward Guard one-hit intercept.
-- Keeps targetability and hate list intact during BOTH guard and landing (never Super Jump).
-- Additive to drg_specs.lua (preserves Wyvernheart & Lancer).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_drg_skyborn')
local spec = xi.overlords.spec
local DRG = xi.job.DRG
local KEY = 'skyborn'

local VAR_CRY_CD       = 'OX_SKY_CRY_CD'
local VAR_GUARD_CD     = 'OX_SKY_GUARD_CD'
local VAR_WARD_HP      = 'OX_SKY_WARD_HP'
local VAR_WARD_UNTIL   = 'OX_SKY_WARD_UNTIL'

local activeGuardByChar = {}

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isSkyborn(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == DRG and player:getMainLvl() >= 10 and
        spec.is(player, DRG, KEY)
end

local function clearState(player)
    if not player then return end
    if player.getID then activeGuardByChar[player:getID()] = nil end
    if player.setLocalVar then
        player:setLocalVar(VAR_WARD_HP, 0)
        player:setLocalVar(VAR_WARD_UNTIL, 0)
    end
end

-- Grounding Cry (15y, 16s CD, 0 TP, no /WAR): 200 CE / 700 VE on one living enemy.
local function executeGroundingCry(player, target)
    if not isSkyborn(player) then return false, 'not_skyborn' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return false, 'invalid_target'
    end
    if player.checkDistance and player:checkDistance(target) > 15 then
        return false, 'out_of_range'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_CRY_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 16 then return false, 'on_recast' end
    if player.setLocalVar then player:setLocalVar(VAR_CRY_CD, now) end

    if target.addEnmity then
        target:addEnmity(player, 200, 700)
    end
    return true, 'enmity_applied'
end

-- Skyward Guard (20s CD, 1.5s stance): Dragoon stays targetable & keeps full hate list.
local function startSkywardGuard(player, target)
    if not isSkyborn(player) then return nil, 'not_skyborn' end
    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_GUARD_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 20 then return nil, 'on_recast' end
    if player.setLocalVar then player:setLocalVar(VAR_GUARD_CD, now) end

    local lvl = player:getMainLvl()
    local guard =
    {
        untilSec     = now + 1.5,
        reductionPct = scale(lvl, 35, 40, 45, 50),
        wardPct      = scale(lvl, 0, 5, 8, 10),
        target       = target,
        targetable   = true,
        hateRetained = true,
        consumedSeq  = nil,
        landed       = false,
    }
    activeGuardByChar[player:getID()] = guard
    return guard
end

local function finishLanding(player, guard, intercepted)
    if guard.landed then return end
    guard.landed = true
    activeGuardByChar[player:getID()] = nil

    -- Landing adds +100 CE / +300 VE to original living enemy only (never damages nearby mobs).
    local tgt = guard.target
    if tgt and tgt.isAlive and tgt:isAlive() and tgt.addEnmity then
        tgt:addEnmity(player, 100, 300)
    end
    if intercepted and guard.wardPct > 0 and player.setLocalVar then
        local maxHP = player.getMaxHP and player:getMaxHP() or 0
        local ward = math.floor(maxHP * guard.wardPct / 100)
        player:setLocalVar(VAR_WARD_HP, ward)
        player:setLocalVar(VAR_WARD_UNTIL, xi.overlords.nowSec() + 5)
    end
end

-- Evaluate incoming direct enemy action targeting the Dragoon during Skyward Guard.
-- Multi-hit move shares one actionSeq; scripted fatal/HP-set effects excluded.
local function resolveGuardedHit(player, damage, opts)
    opts = opts or {}
    if type(damage) ~= 'number' or damage <= 0 or opts.isScriptedFatalOrHpSet then
        return damage, false
    end
    local guard = player and player.getID and activeGuardByChar[player:getID()] or nil
    if not guard then return damage, false end

    local now = xi.overlords.nowSec()
    if now > guard.untilSec then
        finishLanding(player, guard, false)
        return damage, false
    end

    local red = math.floor(damage * guard.reductionPct / 100)
    local out = math.max(0, damage - red)
    finishLanding(player, guard, true)
    return out, true
end

xi.overlords.skyborn =
{
    executeGroundingCry = executeGroundingCry,
    startSkywardGuard   = startSkywardGuard,
    resolveGuardedHit   = resolveGuardedHit,
    finishLanding       = finishLanding,
    clearState          = clearState,
}

if DRG ~= nil then
    spec.registerCrystal(xi.job.DRG,
    {
        id = 2,
        key = KEY,
        name = 'Skyborn',
        abr = 'SKY',
        role = 'Tank',
        icon = 'skyborn',
        reqLevel = 10,
        description = 'A polearm tank who opens with Grounding Cry and times 1.5s Skyward Guard to mitigate a telegraphed hit while keeping targetability and hate.',
        highlights =
        {
            'Grounding Cry (15y, 16s CD, 0 TP, no /WAR): +200 CE / +700 VE on one enemy.',
            'Skyward Guard (20s CD, 1.5s): reduces first qualifying hit by 35/40/45/50%, lands with +100 CE / +300 VE and 5/8/10% HP ward (Lv30+).',
            'Retains targetability and full hate list throughout (never calls Super Jump); scripted HP-set/fatal hits excluded.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.POLEARM, scale(level, 10, 20, 30, 42) },
                { xi.mod.HPP,     scale(level, 10, 14, 18, 22) },
                { xi.mod.ENMITY,  scale(level, 20, 30, 40, 50) },
                { xi.mod.DMG,    -scale(level, 500, 700, 1000, 1200) },
            }
        end,
        onRemove = clearState,
    })
end

return m
