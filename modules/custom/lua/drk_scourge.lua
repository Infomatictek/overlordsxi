-----------------------------------
-- OverlordsXI DRK 3: Scourge (Sequence E — Targeted Defense/Support)
-- Global single-slot enemy curse (Withering / Ash / Famine) + hard-immunity fallback.
-- Additive to drk_specs.lua (preserves Dreadnought & Reaper).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_drk_scourge')
local spec = xi.overlords.spec
local DRK = xi.job.DRK
local KEY = 'scourge'

local VAR_CURSE_CD    = 'OX_SCR_CURSE_CD'
local VAR_FALLBACK_CD = 'OX_SCR_IMMUNE_FALLBACK_CD'

local curseByTarget = {}    -- One global curse slot per enemy key "zoneId:targetId:spawnGen"
local fallbackByTarget = {} -- Hard-immunity one-hit fallback per enemy key

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isScourge(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == DRK and player:getMainLvl() >= 10 and
        spec.is(player, DRK, KEY)
end

local function tKey(target, spawnGen)
    local z = target and target.getZoneID and target:getZoneID() or 0
    local id = target and target.getID and target:getID() or 0
    local g = spawnGen or 0
    return string.format('%d:%d:%d', z, id, g)
end

-- Cast Withering (physical TP), Ash (damaging spells), or Famine (Lv30+, self-heals).
-- 12s shared recast, 24s duration. Resisted cast leaves existing curse intact.
-- Explicit hard immunity grants party half reduction on next matching hit within 8s (24s ICD),
-- ONLY if that same attack category has no active Scourge reduction.
local function castCurse(player, target, kind, opts)
    opts = opts or {}
    if not isScourge(player) then return nil, 'not_scourge' end
    if kind ~= 'withering' and kind ~= 'ash' and kind ~= 'famine' then return nil, 'invalid_curse' end
    if kind == 'famine' and player:getMainLvl() < 30 then return nil, 'level_too_low' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil, 'invalid_target'
    end

    local now = xi.overlords.nowSec()
    local last = player.getLocalVar and (player:getLocalVar(VAR_CURSE_CD) or 0) or 0
    if last > now then last = 0 end
    if last ~= 0 and (now - last) < 12 then return nil, 'on_recast' end
    if player.setLocalVar then player:setLocalVar(VAR_CURSE_CD, now) end

    local key = tKey(target, opts.spawnGen)
    local existing = curseByTarget[key]
    if existing and now >= existing.untilSec then
        curseByTarget[key] = nil
        existing = nil
    end

    local lvl = player:getMainLvl()
    local pct = kind == 'famine' and scale(lvl, 0, 20, 25, 30) or scale(lvl, 8, 8, 12, 15)

    if opts.hardImmune then
        -- Never proc fallback if same attack category already has an active Scourge curse.
        if existing and existing.kind == kind then
            return nil, 'existing_curse_active'
        end
        local lastFb = player.getLocalVar and (player:getLocalVar(VAR_FALLBACK_CD) or 0) or 0
        if lastFb > now then lastFb = 0 end
        if lastFb ~= 0 and (now - lastFb) < 24 then return nil, 'fallback_on_icd' end
        if player.setLocalVar then player:setLocalVar(VAR_FALLBACK_CD, now) end

        local fb = { kind = kind, pct = math.floor(pct / 2), untilSec = now + 8, consumed = false }
        fallbackByTarget[key] = fb
        return fb, 'immunity_fallback'
    end

    if opts.resisted then
        -- Normal resist leaves any existing curse active untouched.
        return existing, 'resisted'
    end

    local curse = { kind = kind, pct = pct, untilSec = now + 24, casterId = player:getID() }
    curseByTarget[key] = curse
    return curse, 'applied'
end

-- Evaluate damage reduction for physical TP (withering) or damaging spell (ash).
-- Never affects physical autos or scripted HP sets/fatal moves.
local function applyCurseDamageReduction(target, attackCategory, damage, opts)
    opts = opts or {}
    if type(damage) ~= 'number' or damage <= 0 or opts.isAutoAttack or opts.isScriptedHpSet then
        return damage, 0
    end
    local matchKind = (attackCategory == 'physical_tp' and 'withering')
        or (attackCategory == 'damaging_spell' and 'ash') or nil
    if not matchKind then return damage, 0 end

    local now = xi.overlords.nowSec()
    local key = tKey(target, opts.spawnGen)
    local curse = curseByTarget[key]
    if curse and now < curse.untilSec and curse.kind == matchKind then
        local red = math.floor(damage * curse.pct / 100)
        return math.max(0, damage - red), curse.pct
    end
    local fb = fallbackByTarget[key]
    if fb and not fb.consumed and now < fb.untilSec and fb.kind == matchKind then
        fb.consumed = true
        local red = math.floor(damage * fb.pct / 100)
        return math.max(0, damage - red), fb.pct
    end
    return damage, 0
end

-- Evaluate Famine enemy self-heal reduction (never affects scripted resets or phase transitions).
local function applyFamineHealReduction(target, healAmount, opts)
    opts = opts or {}
    if type(healAmount) ~= 'number' or healAmount <= 0 or opts.isScriptedReset then
        return healAmount, 0
    end
    local now = xi.overlords.nowSec()
    local key = tKey(target, opts.spawnGen)
    local curse = curseByTarget[key]
    if curse and now < curse.untilSec and curse.kind == 'famine' then
        local red = math.floor(healAmount * curse.pct / 100)
        return math.max(0, healAmount - red), curse.pct
    end
    local fb = fallbackByTarget[key]
    if fb and not fb.consumed and now < fb.untilSec and fb.kind == 'famine' then
        fb.consumed = true
        local red = math.floor(healAmount * fb.pct / 100)
        return math.max(0, healAmount - red), fb.pct
    end
    return healAmount, 0
end

xi.overlords.scourge =
{
    castCurse                 = castCurse,
    applyCurseDamageReduction = applyCurseDamageReduction,
    applyFamineHealReduction  = applyFamineHealReduction,
}

if DRK ~= nil then
    spec.registerCrystal(xi.job.DRK,
    {
        id = 3,
        key = KEY,
        name = 'Scourge',
        abr = 'SCR',
        role = 'Support',
        icon = 'scourge',
        reqLevel = 10,
        description = 'A hex-wielding Dark Knight maintaining one surgical suppression curse per enemy (Withering, Ash, or Famine) with hard-immunity fallback.',
        highlights =
        {
            'One global Scourge curse slot per enemy (12s shared recast, 24s): Withering (TP), Ash (spells), Famine (Lv30+ self-heals).',
            'Damage curses reduce by 8/8/12/15%; Famine reduces non-scripted self-heals by 20/25/30%.',
            'Hard immunity grants one-hit half-potency fallback (8s, 24s ICD) only when no active same-category curse exists.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.MACC, scale(level, 10, 18, 28, 38) },
                { xi.mod.MPP,  scale(level, 6, 10, 14, 18) },
                { xi.mod.HPP,  scale(level, 4, 6, 8, 10) },
            }
        end,
    })
end

return m
