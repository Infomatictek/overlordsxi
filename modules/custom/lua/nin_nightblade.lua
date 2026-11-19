-----------------------------------
-- OverlordsXI NIN 3: Nightblade (Sequence E — Targeted Defense/Support)
-- Reactive Severing Seal (spells) & Blunting Seal (physical TP moves) on active enemy cast sequences.
-- Additive to nin_specs.lua (preserves Shinobi/kurogane & Kagemusha).
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')

local m = Module:new('overlords_nin_nightblade')
local spec = xi.overlords.spec
local NIN = xi.job.NIN
local KEY = 'nightblade'

local VAR_SEAL_UNTIL = 'OX_NGB_SEAL_RECAST_UNTIL'
local sealByActionSeq = {} -- Keyed by "targetId:actionSeq" -> { kind, reductionPct, interrupted, untilSec }

local function scale(lvl, a, b, c, d)
    if lvl >= 70 then return d end
    if lvl >= 50 then return c end
    if lvl >= 30 then return b end
    return a
end

local function isNightblade(player)
    return player ~= nil and player.isPC and player:isPC() and
        player:getMainJob() == NIN and player:getMainLvl() >= 10 and
        spec.is(player, NIN, KEY)
end

-- Cast Severing Seal ('spell') or Blunting Seal ('physical_tp'), 15y, 0.5s cast, no tools.
-- Shared recast 20s (Lv10-49) / 18s (Lv50+). Mismatch / no active cast -> no effect, 3s retry (no resources spent).
-- One seal per enemy action sequence; another Nightblade cannot layer it.
local function castSeal(player, target, sealKind, activeAction)
    if not isNightblade(player) then return nil, 'not_nightblade' end
    if sealKind ~= 'severing' and sealKind ~= 'blunting' then return nil, 'invalid_seal' end
    if not target or not target.isMob or not target:isMob() or not target.isAlive or not target:isAlive() then
        return nil, 'invalid_target'
    end
    if player.checkDistance and player:checkDistance(target) > 15 then
        return nil, 'out_of_range'
    end

    local now = xi.overlords.nowSec()
    local recastUntil = player.getLocalVar and (player:getLocalVar(VAR_SEAL_UNTIL) or 0) or 0
    if now < recastUntil then return nil, 'on_recast' end

    local expectedCat = sealKind == 'severing' and 'spell' or 'physical_tp'
    if not activeAction or activeAction.cancelled or activeAction.completed or activeAction.category ~= expectedCat then
        -- Mismatch retry: 3s retry only, never interrupts by fishing mismatches.
        if player.setLocalVar then player:setLocalVar(VAR_SEAL_UNTIL, now + 3) end
        return nil, 'mismatch_retry'
    end

    local seqKey = string.format('%d:%s', target:getID(), tostring(activeAction.seq))
    local existing = sealByActionSeq[seqKey]
    if existing and now < existing.untilSec then
        return nil, 'already_sealed'
    end

    local lvl = player:getMainLvl()
    local cd = lvl >= 50 and 18 or 20
    if player.setLocalVar then player:setLocalVar(VAR_SEAL_UNTIL, now + cd) end

    if activeAction.isScriptedExecution then
        return { interrupted = false, reductionPct = 0 }, 'scripted_immune'
    end

    local rec
    if sealKind == 'severing' then
        if not activeAction.uninterruptible and activeAction.interruptRollPasses ~= false then
            rec = { kind = 'severing', interrupted = true, reductionPct = 0, untilSec = now + 8 }
        else
            rec = { kind = 'severing', interrupted = false, reductionPct = scale(lvl, 8, 10, 10, 12), untilSec = now + 8 }
        end
    else
        rec = { kind = 'blunting', interrupted = false, reductionPct = scale(lvl, 10, 13, 13, 16), untilSec = now + 8 }
    end
    sealByActionSeq[seqKey] = rec
    return rec, rec.interrupted and 'interrupted' or 'weakened'
end

local function applySealedActionDamage(target, actionSeq, damage, opts)
    opts = opts or {}
    if type(damage) ~= 'number' or damage <= 0 or opts.isScriptedExecution then return damage end
    local seqKey = string.format('%d:%s', target:getID(), tostring(actionSeq))
    local rec = sealByActionSeq[seqKey]
    if not rec then return damage end
    if xi.overlords.nowSec() > rec.untilSec then
        sealByActionSeq[seqKey] = nil
        return damage
    end
    if rec.interrupted then return 0 end
    local red = math.floor(damage * rec.reductionPct / 100)
    return math.max(0, damage - red)
end

local function clearActionSequence(target, actionSeq)
    if target and target.getID then
        sealByActionSeq[string.format('%d:%s', target:getID(), tostring(actionSeq))] = nil
    end
end

xi.overlords.nightblade =
{
    castSeal                = castSeal,
    applySealedActionDamage = applySealedActionDamage,
    clearActionSequence     = clearActionSequence,
}

if NIN ~= nil then
    spec.registerCrystal(xi.job.NIN,
    {
        id = 3,
        key = KEY,
        name = 'Nightblade',
        abr = 'NGB',
        role = 'Support',
        icon = 'nightblade',
        reqLevel = 10,
        description = 'A reactive control Ninja who answers active enemy spell and physical TP telegraphs with Severing and Blunting Seals.',
        highlights =
        {
            'Severing Seal interrupts spells (or reduces uninterruptible spell damage by 8/10/10/12%); Blunting Seal reduces physical TP by 10/13/13/16%.',
            'Shared 20/18s recast, 0.5s cast, no tools; mismatch sets a 3s retry with no effect and never interrupts.',
            'One seal per enemy cast sequence; expires on resolution/cancel or 8s; scripted executions unaffected.',
        },
        mods = function(_player, level)
            return
            {
                { xi.mod.NINJUTSU, scale(level, 12, 20, 30, 42) },
                { xi.mod.MACC,     scale(level, 10, 18, 28, 38) },
            }
        end,
    })
end

return m
