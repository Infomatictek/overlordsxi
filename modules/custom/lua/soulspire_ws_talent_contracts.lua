-----------------------------------
-- SoulspireXI — Machine-Readable WS Talent Contract Compiler & Effect Taxonomy
--
-- Produces a deterministic, Autoparser-readable contract for every WS talent
-- node across all 66 canonical Souls and their approved weapon families.
--
-- Separates:
--   - Effect Taxonomy (how the engine applies, triggers, observes, validates,
--     and diagnoses failure for each mechanical effect type)
--   - Per-node compiled contract (stable talent_id, branch, tier, prerequisites,
--     mutual exclusions, activation conditions, expected events & deltas,
--     supported levels, and test coverage ID)
-----------------------------------
local E = require('modules/custom/lua/soulspire_ws_eligibility')
local M = require('modules/custom/lua/soulspire_ws_soul_mechanics')

xi = xi or {}
xi.soulspire = xi.soulspire or {}
xi.soulspire.wsTalentContracts = xi.soulspire.wsTalentContracts or {}

local C = xi.soulspire.wsTalentContracts

C.CONTRACT_SCHEMA_VERSION = '2.0.0'
C.CANONICAL_LEVELS = { 10, 30, 50, 75 }

C.BRANCH_BY_COL =
{
    [1] = 'damage',
    [2] = 'utility',
    [3] = 'soul',
    [4] = 'skillchain',
}

-- Shared Machine-Readable Effect Taxonomy
C.EFFECT_TAXONOMY =
{
    ftp_modifier = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.modifier_deltas.ftpMod',
        validation_rule = 'params.ftpMod exceeds normalized 1.0 baseline according to rank curve',
        failure_mode    = 'ftpMod unchanged at 1.0 or below expected rank curve',
    },
    wsc_modifier = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.modifier_deltas.wsc',
        validation_rule = 'params.<stat>_wsc increased by rank value',
        failure_mode    = 'stat WSC remained 0 despite invested rank',
    },
    damage_modifier = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.modifier_deltas.wsd_or_atk_or_matt',
        validation_rule = 'temporary WSD/MAB/atkVaries modifier applied during WS execution',
        failure_mode    = 'no offensive tempMod or atkVaries delta recorded',
    },
    hit_count_modifier = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.modifier_deltas.numHits',
        validation_rule = 'params.numHits or multiHitfTP increased per rank',
        failure_mode    = 'hit count remained 1 or multiHitfTP remained false',
    },
    critical_modifier = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.modifier_deltas.crit',
        validation_rule = 'params.critVaries or CRIT_DMG_INCREASE tempMod applied',
        failure_mode    = 'crit rate/damage modifiers absent',
    },
    def_ignore_modifier = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.modifier_deltas.ignoredDefense',
        validation_rule = 'params.ignoredDefense > 0',
        failure_mode    = 'ignoredDefense remained nil/0',
    },
    accuracy_modifier = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.modifier_deltas.acc_or_macc',
        validation_rule = 'accVaries, RACC, or MACC tempMod increased',
        failure_mode    = 'accuracy/magic accuracy modifier not applied',
    },
    tp_bonus = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.resource_deltas.effective_tp',
        validation_rule = 'effectiveTp increased above raw TP (capped at 3000)',
        failure_mode    = 'effectiveTp equaled raw TP without bonus',
    },
    tp_gain = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.resource_deltas.tp_refund_or_party_tp',
        validation_rule = 'attacker or party TP increased post-WS',
        failure_mode    = 'zero TP refund or party TP granted post-WS',
    },
    mp_gain = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.resource_deltas.mp_delta',
        validation_rule = 'attacker MP restored post-WS (unless at max MP)',
        failure_mode    = 'no MP recovery triggered when below max MP',
    },
    enmity_modifier = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.modifier_deltas.enmity',
        validation_rule = 'ENMITY tempMod applied with expected sign (positive tank / negative utility)',
        failure_mode    = 'ENMITY tempMod missing or wrong sign',
    },
    status_apply = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.applied_effects.status_buff',
        validation_rule = 'self or party status effect applied with duration > 0',
        failure_mode    = 'status buff not applied or blocked by role guardrail',
    },
    debuff_apply = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.applied_effects.target_debuff',
        validation_rule = 'target debuff or nativeDebuff context registered',
        failure_mode    = 'debuff not attempted or skipped',
    },
    dispel = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.applied_effects.dispel',
        validation_rule = 'dispel attempt recorded against target',
        failure_mode    = 'dispel handler not invoked',
    },
    heal_modifier = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.resource_deltas.hp_healed',
        validation_rule = 'HP recovery executed within role cap (never on pure DPS)',
        failure_mode    = 'heal not executed or violated role cap',
    },
    next_ws_primer = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.applied_effects.next_ws_primer',
        validation_rule = 'OX_NEXT_WS_* localVars set with future expiry',
        failure_mode    = 'OX_NEXT_WS_EXP not populated',
    },
    resource_build = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.resource_deltas.soul_resource',
        validation_rule = 'Soul localVar or Conduction gauge incremented up to cap',
        failure_mode    = 'Soul resource unchanged post-WS',
    },
    pet_interaction = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.resource_deltas.pet_hp_or_tp',
        validation_rule = 'active pet received HP/MP heal or TP gain',
        failure_mode    = 'pet present but received no heal/TP delta',
    },
    clone_interaction = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.resource_deltas.clone_sync',
        validation_rule = 'Kurogane clone sync counter/empowerment updated',
        failure_mode    = 'clone_sync state unchanged on Kurogane WS',
    },
    skillchain_modifier = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.modifier_deltas.sc_bonus_or_props',
        validation_rule = 'OX_WS_SC1..3 or pendingScBonus updated',
        failure_mode    = 'skillchain bonus/properties not applied',
    },
    stance_conditional = {
        phase           = 'pre_ws',
        trigger_event   = 'on_ws_pre',
        observable_via  = 'ws_talent_eval.status',
        validation_rule = 'activates when stance/jobSpec/petAlive condition holds; reports condition_not_met otherwise',
        failure_mode    = 'failed to activate when stance active, or activated when condition false',
    },
    elemental_followup = {
        phase           = 'post_ws',
        trigger_event   = 'on_ws_post',
        observable_via  = 'ws_talent_eval.applied_effects.elem_follow',
        validation_rule = 'elemental follow-up damage executed post-WS',
        failure_mode    = 'elemental follow-up did not fire on damaging WS',
    },
}

local function addEffect(list, effType, target, params)
    table.insert(list, {
        effect_type = effType,
        target      = target,
        params      = params or {},
    })
end

function C.extractEffects(node)
    local out = {}
    local eff = type(node.effect) == 'table' and node.effect or {}

    if (node.scTier or 0) > 0 then
        addEffect(out, 'skillchain_modifier', 'self', { sc_tier = node.scTier })
        return out
    end

    if node.ftpCurve ~= nil or eff.ftpCurve ~= nil or eff.ftpAdd ~= nil then
        addEffect(out, 'ftp_modifier', 'self', { has_curve = (node.ftpCurve ~= nil or eff.ftpCurve ~= nil), has_add = (eff.ftpAdd ~= nil) })
    end
    if type(eff.wsc) == 'table' then
        local stats = {}
        for k, _ in pairs(eff.wsc) do table.insert(stats, k) end
        table.sort(stats)
        addEffect(out, 'wsc_modifier', 'self', { stats = stats })
    end
    if eff.wsd or eff.atkPct or eff.matt or eff.potencyPct or eff.packWsdPerMob then
        addEffect(out, 'damage_modifier', 'target', {
            wsd = eff.wsd ~= nil, atkPct = eff.atkPct ~= nil, matt = eff.matt ~= nil, pack = eff.packWsdPerMob ~= nil,
        })
    end
    if eff.hits or eff.bonusHits or eff.multiHitfTPAt or eff.packBonusHitAt then
        addEffect(out, 'hit_count_modifier', 'target', {
            hits = eff.hits ~= nil, bonusHits = eff.bonusHits ~= nil, multiHitfTPAt = eff.multiHitfTPAt,
        })
    end
    if eff.crit or eff.critCurve or eff.critDmg then
        addEffect(out, 'critical_modifier', 'target', {
            crit = eff.crit ~= nil, critCurve = eff.critCurve ~= nil, critDmg = eff.critDmg ~= nil,
        })
    end
    if eff.defIgnore then
        addEffect(out, 'def_ignore_modifier', 'target', { has_def_ignore = true })
    end
    if eff.acc or eff.racc or eff.macc then
        addEffect(out, 'accuracy_modifier', 'self', {
            acc = eff.acc ~= nil, racc = eff.racc ~= nil, macc = eff.macc ~= nil,
        })
    end
    if eff.tpBonus then
        addEffect(out, 'tp_bonus', 'self', { has_tp_bonus = true })
    end
    if eff.tpRefund or eff.partyTp or eff.storeTp or eff.storeTpBuff or eff.packPartyTpPerMob then
        addEffect(out, 'tp_gain', eff.partyTp and 'party' or 'self', {
            tpRefund = eff.tpRefund ~= nil, partyTp = eff.partyTp ~= nil, storeTp = (eff.storeTp ~= nil or eff.storeTpBuff ~= nil),
        })
    end
    if eff.mpReturn or eff.mpDrain then
        addEffect(out, 'mp_gain', 'self', { mpReturn = eff.mpReturn ~= nil, mpDrain = eff.mpDrain ~= nil })
    end
    if eff.enmity or eff.subtleBlow or eff.packEnmityPerMob then
        addEffect(out, 'enmity_modifier', 'self', {
            enmity = eff.enmity ~= nil, subtleBlow = eff.subtleBlow ~= nil,
        })
    end
    if eff.statusBuffs or eff.partyBuffs or eff.timedMods or eff.cleanseSelf or eff.cleanseParty then
        addEffect(out, 'status_apply', (eff.partyBuffs or eff.cleanseParty) and 'party' or 'self', {
            selfBuffs = eff.statusBuffs ~= nil, partyBuffs = eff.partyBuffs ~= nil, timedMods = eff.timedMods ~= nil,
            cleanse = (eff.cleanseSelf ~= nil or eff.cleanseParty ~= nil),
        })
    end
    if eff.targetDebuffs or eff.nativeDebuff or eff.tpDrain then
        addEffect(out, 'debuff_apply', 'target', {
            targetDebuffs = eff.targetDebuffs ~= nil, nativeDebuff = eff.nativeDebuff ~= nil, tpDrain = eff.tpDrain ~= nil,
        })
    end
    if eff.dispel then
        addEffect(out, 'dispel', 'target', { has_dispel = true })
    end
    if eff.selfHeal or eff.selfMaxHpHealPct or eff.partyHealPct or eff.hpDrain or eff.mpToHpPct then
        addEffect(out, 'heal_modifier', eff.partyHealPct and 'party' or 'self', {
            partyHealPct = eff.partyHealPct ~= nil, hpDrain = eff.hpDrain ~= nil, selfHeal = (eff.selfHeal ~= nil or eff.selfMaxHpHealPct ~= nil),
        })
    end
    if eff.nextWs then
        addEffect(out, 'next_ws_primer', 'self', { dur = eff.nextWs.dur or 12 })
    end
    if eff.conductionAdd or (type(eff.soulHook) == 'table' and eff.soulHook.kind == 'resource_build') then
        addEffect(out, 'resource_build', 'self', {
            hook_id = type(eff.soulHook) == 'table' and eff.soulHook.id or 'run_conduction',
            local_var = type(eff.soulHook) == 'table' and eff.soulHook.localVar or 'OX_CONDUCTION',
        })
    end
    if eff.eosHeal or eff.petTp or (type(eff.soulHook) == 'table' and eff.soulHook.kind == 'pet_tp_heal') then
        addEffect(out, 'pet_interaction', 'pet', {
            eosHeal = eff.eosHeal ~= nil, petTp = eff.petTp ~= nil,
        })
    end
    if type(eff.soulHook) == 'table' and eff.soulHook.kind == 'clone_interaction' then
        addEffect(out, 'clone_interaction', 'clones', {
            hook_id = eff.soulHook.id, local_var = eff.soulHook.localVar,
        })
    elseif type(eff.soulHook) == 'table' then
        local hk = eff.soulHook.kind
        if hk == 'tp_refund' and not eff.tpRefund then
            addEffect(out, 'tp_gain', 'self', { hook_id = eff.soulHook.id })
        elseif hk == 'mp_siphon' and not eff.mpReturn then
            addEffect(out, 'mp_gain', 'self', { hook_id = eff.soulHook.id })
        elseif hk == 'party_pulse' and not eff.partyTp and not eff.partyHealPct then
            addEffect(out, 'tp_gain', 'party', { hook_id = eff.soulHook.id })
        elseif hk == 'next_ws_prime' and not eff.nextWs then
            addEffect(out, 'next_ws_primer', 'self', { hook_id = eff.soulHook.id })
        elseif hk == 'enmity_surge' and not eff.enmity then
            addEffect(out, 'enmity_modifier', 'self', { hook_id = eff.soulHook.id })
        elseif hk == 'debuff_extend' and not eff.targetDebuffs then
            addEffect(out, 'debuff_apply', 'target', { hook_id = eff.soulHook.id })
        elseif hk == 'stance_empower' and not eff.stance then
            addEffect(out, 'stance_conditional', 'self', { hook_id = eff.soulHook.id })
        end
    end
    if eff.scBonus then
        addEffect(out, 'skillchain_modifier', 'self', { scBonus = true })
    end
    if type(eff.stance) == 'table' then
        addEffect(out, 'stance_conditional', 'self', {
            jobSpec = eff.stance.jobSpec, schSpec = eff.stance.schSpec, petAlive = eff.stance.petAlive == true,
        })
    end
    if type(eff.elemFollow) == 'table' then
        addEffect(out, 'elemental_followup', 'target', { element = eff.elemFollow.ele })
    end

    -- Legacy H2H (#1..#15) nodes without node.effect table still have key-based mechanics
    if #out == 0 and node.key ~= nil then
        if node.key == 'ftp' then
            addEffect(out, 'ftp_modifier', 'self', { legacy = true })
        elseif string.sub(node.key, 1, 4) == 'wsc_' then
            addEffect(out, 'wsc_modifier', 'self', { stat = string.sub(node.key, 5) })
        else
            addEffect(out, 'damage_modifier', 'target', { legacy_key = node.key })
        end
    end

    return out
end

function C.compileNodeContract(ws, soulKey, node, rankReqFn)
    local normSoul = E.normalizeSoulKey(soulKey) or tostring(soulKey or 'generic')
    local eligEntry = E.getEntry(normSoul)
    local profile = M.getProfile(normSoul)
    local effects = C.extractEffects(node)

    local branch = node.branch or C.BRANCH_BY_COL[node.col or 1] or 'damage'
    if node.evolution then
        branch = 'evolution'
    end

    local reqLevel1 = rankReqFn and rankReqFn(node, 1) or (node.reqLevel or 1)
    local reqLevelMax = rankReqFn and rankReqFn(node, node.maxRank or 1) or reqLevel1

    local supportedLevels = {}
    for _, lvl in ipairs(C.CANONICAL_LEVELS) do
        if lvl >= reqLevel1 then
            table.insert(supportedLevels, lvl)
        end
    end

    local activationConditions = { 'ws_executed', 'soul_weapon_eligible' }
    local eff = type(node.effect) == 'table' and node.effect or {}
    if type(eff.stance) == 'table' then
        table.insert(activationConditions, 'stance_or_soul_active')
        if eff.stance.petAlive then
            table.insert(activationConditions, 'pet_alive')
        end
    end
    if eff.eosHeal or eff.petTp then
        table.insert(activationConditions, 'pet_alive')
    end
    if eff.packWsdPerMob or eff.packEnmityPerMob or eff.packBonusHitAt then
        table.insert(activationConditions, 'nearby_pack_mobs_gte_1')
    end

    local hasPre, hasPost = false, false
    local expectedEvents = { 'ws_talent_eval' }
    local expectedResourceDeltas = {}
    local expectedModifierChanges = {}
    local failureConditions = { 'talent_not_allocated', 'soul_weapon_ineligible' }

    for _, e in ipairs(effects) do
        local tax = C.EFFECT_TAXONOMY[e.effect_type]
        if tax then
            if tax.phase == 'pre_ws' then hasPre = true end
            if tax.phase == 'post_ws' then hasPost = true end
            if e.effect_type == 'tp_gain' or e.effect_type == 'tp_bonus' or e.effect_type == 'mp_gain' or e.effect_type == 'heal_modifier' or e.effect_type == 'resource_build' or e.effect_type == 'pet_interaction' or e.effect_type == 'clone_interaction' then
                table.insert(expectedResourceDeltas, tax.observable_via)
            else
                table.insert(expectedModifierChanges, tax.observable_via)
            end
            table.insert(failureConditions, tax.failure_mode)
        end
    end

    local triggerEvent = 'on_ws_pre'
    if hasPre and hasPost then
        triggerEvent = 'on_ws_pre_and_post'
    elseif hasPost then
        triggerEvent = 'on_ws_post'
    end

    return
    {
        talent_id                 = string.format('ws:%u:%s:%s', ws.id, normSoul, tostring(node.key)),
        schema_version            = C.CONTRACT_SCHEMA_VERSION,
        soul_key                  = normSoul,
        job                       = eligEntry and eligEntry.job or 'ANY',
        role                      = eligEntry and eligEntry.role or (profile and profile.role) or 'Damage',
        tier_role                 = eligEntry and eligEntry.tier or (profile and profile.tier) or 'Damage',
        ws_id                     = ws.id,
        ws_key                    = ws.key,
        ws_name                   = ws.name,
        weapon_family             = ws.skillName,
        skill_id                  = ws.skill,
        ws_type                   = ws.wsType,
        node_key                  = node.key,
        node_name                 = node.name,
        branch                    = branch,
        tier                      = node.tier or 1,
        col                       = node.col or 1,
        max_rank                  = node.maxRank or 1,
        point_cost                = 1,
        prerequisites             = {
            req_ws_points   = node.reqWsPoints or 0,
            req_level_rank1 = reqLevel1,
            req_level_max   = reqLevelMax,
            requires_node   = node.requires and node.requires.key or nil,
            requires_rank   = node.requires and node.requires.rank or 0,
        },
        exclusive_group           = node.exclusiveGroup or nil,
        activation_conditions     = activationConditions,
        trigger_event             = triggerEvent,
        effects                   = effects,
        expected_events           = expectedEvents,
        expected_resource_deltas  = expectedResourceDeltas,
        expected_modifier_changes = expectedModifierChanges,
        failure_conditions        = failureConditions,
        supported_levels          = supportedLevels,
        test_id                   = string.format('wst_%s_ws%u_%s', normSoul, ws.id, tostring(node.key)),
    }
end

return C
