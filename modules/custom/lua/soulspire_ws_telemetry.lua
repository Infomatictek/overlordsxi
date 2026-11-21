-----------------------------------
-- SoulspireXI — WS Talent Combat Instrumentation & Soul-Hook Executor
--
-- Phase 7 structured combat telemetry for WS talents:
--   - Zero production log spam (active only when ENABLED, player debug var
--     OX_WS_TELEMETRY_DEBUG == 1, or an active Proving Grounds session exists).
--   - Distinguishes:
--       allocated | eligible | activated | applied | condition_not_met |
--       blocked_by_restriction | proc_failed | unexpected_outcome
--   - Executes reusable Soul-branch post-WS hooks (resource_build,
--     clone_interaction, tp_refund, mp_siphon) with deterministic pre/post state.
-----------------------------------
local E = require('modules/custom/lua/soulspire_ws_eligibility')
local M = require('modules/custom/lua/soulspire_ws_soul_mechanics')

xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.soulspire.wsTelemetry = xi.soulspire.wsTelemetry or {}

local W = xi.soulspire.wsTelemetry

W.ENABLED      = false
W.MAX_RECENT   = 512
W.recentEvents = {}
W._seq         = 0

W.STATUS =
{
    ALLOCATED              = 'allocated',
    ELIGIBLE               = 'eligible',
    ACTIVATED              = 'activated',
    APPLIED                = 'applied',
    CONDITION_NOT_MET      = 'condition_not_met',
    BLOCKED_BY_RESTRICTION = 'blocked_by_restriction',
    PROC_FAILED            = 'proc_failed',
    UNEXPECTED_OUTCOME     = 'unexpected_outcome',
}

local function nowMs()
    if getMonotonicSeconds then
        return math.floor(getMonotonicSeconds() * 1000 + 0.5)
    end
    return os.time() * 1000
end

local function pickVal(val, rank)
    if type(val) == 'table' then
        return val[rank] or val[#val]
    end
    return val
end

function W.isActiveFor(player)
    if W.ENABLED then
        return true
    end
    if player ~= nil and player.getLocalVar and player:getLocalVar('OX_WS_TELEMETRY_DEBUG') == 1 then
        return true
    end
    local pgT = xi.soulspire and xi.soulspire.provingGrounds and xi.soulspire.provingGrounds.telemetry
    if pgT ~= nil and pgT.hasActiveSessionFor and pgT.hasActiveSessionFor(player) then
        return true
    end
    return false
end

function W.clearRecent()
    W.recentEvents = {}
    W._seq = 0
end

function W.emit(attacker, ws, soulKey, node, rank, phase, status, details)
    if not W.isActiveFor(attacker) then
        return nil
    end

    W._seq = W._seq + 1
    local normSoul = E.normalizeSoulKey(soulKey) or tostring(soulKey or 'generic')
    local wsId = ws and ws.id or 0
    local nodeKey = node and node.key or 'unknown'
    local payload =
    {
        event           = 'ws_talent_eval',
        seq             = W._seq,
        ts_ms           = nowMs(),
        soul_key        = normSoul,
        job_id          = attacker and attacker.getMainJob and attacker:getMainJob() or 0,
        ws_id           = wsId,
        ws_key          = ws and ws.key or '',
        talent_id       = string.format('ws:%u:%s:%s', wsId, normSoul, tostring(nodeKey)),
        node_key        = nodeKey,
        branch          = (node and node.branch) or 'damage',
        tier            = (node and node.tier) or 1,
        rank            = rank or 0,
        phase           = phase or 'pre_ws',
        status          = status or W.STATUS.ACTIVATED,
        reason          = details and details.reason or '',
        pre_state       = details and details.pre_state or {},
        applied_effects = details and details.applied_effects or {},
        post_state      = details and details.post_state or {},
    }

    if #W.recentEvents >= W.MAX_RECENT then
        table.remove(W.recentEvents, 1)
    end
    table.insert(W.recentEvents, payload)

    local pgT = xi.soulspire and xi.soulspire.provingGrounds and xi.soulspire.provingGrounds.telemetry
    if pgT ~= nil and pgT.recordWsTalentEvent then
        pgT.recordWsTalentEvent(attacker, payload)
    end

    return payload
end

-- Executes reusable Soul-branch post-WS hooks with deterministic pre/post state capture
function W.applySoulHookPostWS(attacker, target, ws, soulKey, node, rank, hook)
    if attacker == nil or type(hook) ~= 'table' or (rank or 0) <= 0 then
        return nil
    end
    local normSoul = E.normalizeSoulKey(soulKey) or tostring(soulKey or 'generic')
    local preState = {}
    local postState = {}
    local applied = {}
    local status = W.STATUS.APPLIED
    local reason = ''

    -- 1. Soul resource / stack build (e.g., Grit, Zeal, Cadence, Crimson Flow, Grapeshot, Ashura, Bloodlust, Clone Sync, Conduction)
    if (hook.kind == 'resource_build' or hook.kind == 'clone_interaction') and type(hook.localVar) == 'string' then
        local cur = (attacker.getLocalVar and attacker:getLocalVar(hook.localVar)) or 0
        local delta = pickVal(hook.delta, rank) or 1
        local cap = hook.maxStack or 10
        local nxt = math.min(cap, cur + delta)
        preState[hook.localVar] = cur
        if attacker.setLocalVar then
            attacker:setLocalVar(hook.localVar, nxt)
        end
        postState[hook.localVar] = nxt
        applied.soul_resource = { var = hook.localVar, delta = nxt - cur, cap = cap, hook_id = hook.id }
    elseif hook.kind == 'resource_build' and hook.conductionAdd ~= nil then
        local delta = pickVal(hook.conductionAdd, rank) or 1
        local cur = (attacker.getLocalVar and attacker:getLocalVar('OX_CONDUCTION')) or 0
        preState.OX_CONDUCTION = cur
        postState.OX_CONDUCTION = cur + delta
        applied.soul_resource = { var = 'OX_CONDUCTION', delta = delta, hook_id = hook.id }
    end

    -- 2. Bounded TP Refund (anti-infinite-TP guardrail: hard-capped at 350 TP per WS)
    if hook.tpRefund ~= nil and attacker.addTP then
        local preTp = attacker.getTP and attacker:getTP() or 0
        local refund = math.min(350, math.max(0, pickVal(hook.tpRefund, rank) or 0))
        preState.tp = preTp
        if refund > 0 then
            attacker:addTP(refund)
        end
        postState.tp = attacker.getTP and attacker:getTP() or (preTp + refund)
        applied.tp_refund = refund
    end

    -- 3. Bounded MP Siphon (blocked on no-MP Souls like Chi Weaver / PUP)
    if hook.mpReturn ~= nil and attacker.addMP then
        if M.isNoMpSoul(normSoul) then
            status = W.STATUS.BLOCKED_BY_RESTRICTION
            reason = 'no_mp_soul_restriction'
        else
            local preMp = attacker.getMP and attacker:getMP() or 0
            local gain = math.min(120, math.max(0, pickVal(hook.mpReturn, rank) or 0))
            preState.mp = preMp
            if gain > 0 then
                attacker:addMP(gain)
            end
            postState.mp = attacker.getMP and attacker:getMP() or (preMp + gain)
            applied.mp_gain = gain
        end
    end

    -- 4. Party pulse / Pet TP+Heal / Next-WS Prime / Enmity / Debuff / Stance Soul hooks
    if hook.kind == 'party_pulse' then
        applied.soul_hook = {
            hook_id = hook.id, kind = hook.kind,
            party_tp = hook.partyTp and pickVal(hook.partyTp, rank) or 0,
            party_heal_pct = hook.partyHealPct and pickVal(hook.partyHealPct, rank) or 0,
        }
    elseif hook.kind == 'pet_tp_heal' then
        local pet = attacker.getPet and attacker:getPet() or nil
        if pet ~= nil and pet:isAlive() then
            applied.pet_interaction = {
                hook_id = hook.id,
                pet_tp = hook.petTp and pickVal(hook.petTp, rank) or 0,
                eos_heal = hook.eosHeal and pickVal(hook.eosHeal, rank) or 0,
            }
        else
            applied.soul_hook = {
                hook_id = hook.id, kind = hook.kind, pet_present = false,
                bonus_wsd = hook.bonusWsd and pickVal(hook.bonusWsd, rank) or 0,
            }
        end
    elseif hook.kind == 'next_ws_prime' then
        applied.next_ws_primer = {
            hook_id = hook.id,
            next_wsd = hook.nextWsd and pickVal(hook.nextWsd, rank) or 0,
            next_tp = hook.nextTp and pickVal(hook.nextTp, rank) or 0,
        }
    elseif hook.kind == 'enmity_surge' then
        applied.enmity_modifier = {
            hook_id = hook.id,
            enmity = hook.enmity and pickVal(hook.enmity, rank) or 0,
        }
    elseif hook.kind == 'debuff_extend' then
        applied.target_debuff = {
            hook_id = hook.id,
            debuff = hook.targetDebuff,
            power = hook.debuffPower and pickVal(hook.debuffPower, rank) or 0,
        }
    elseif hook.kind == 'stance_empower' then
        applied.stance_empower = {
            hook_id = hook.id,
            bonus_wsd = hook.bonusWsd and pickVal(hook.bonusWsd, rank) or 0,
            matt = hook.matt and pickVal(hook.matt, rank) or 0,
        }
    end

    return W.emit(attacker, ws, normSoul, node, rank, 'post_ws', status, {
        reason          = reason,
        pre_state       = preState,
        applied_effects = applied,
        post_state      = postState,
    })
end

return W
