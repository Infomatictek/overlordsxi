-----------------------------------
-- OverlordsXI Weaponskill Overrides
-- Normalizes base PC weaponskills to fTP 1.0, 0 WSC, numHits = 1,
-- and ZERO skillchain properties; applies per-WS 4-tier talent ranks,
-- pickable skillchain overrides, H2H signature mechanics, and syncs
-- the Ashita v4 UI on login/level.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_ws_catalog')
require('modules/custom/lua/overlords_ws_talents')
require('scripts/combat/skillchain')
require('scripts/globals/job_utils/monk')
require('scripts/globals/player')
require('scripts/globals/weaponskills')
-----------------------------------
local m = Module:new('overlords_ws_overrides')

local catalog = xi.overlords.wsCatalog
local talents = xi.overlords.wsTalents

local activeWsContext = {}
local pendingScBonus  = {}
local spinPackCache   = {}

local DEBUFF_POWER_CAPS =
{
    [xi.effect.DEFENSE_DOWN]          = 50,
    [xi.effect.ATTACK_DOWN]           = 50,
    [xi.effect.EVASION_DOWN]          = 80,
    [xi.effect.ACCURACY_DOWN]         = 80,
    [xi.effect.MAGIC_DEF_DOWN]        = 40,
    [xi.effect.MAGIC_ATK_DOWN]        = 40,
    [xi.effect.MAGIC_EVASION_DOWN]    = 40,
    [xi.effect.PARALYSIS]             = 50,
    [xi.effect.SLOW]                  = 4500,
    [xi.effect.WEIGHT]                = 60,
    [xi.effect.BLINDNESS]             = 60,
    [xi.effect.PLAGUE]                = 12,
    [xi.effect.POISON]                = 30,
    [xi.effect.INT_DOWN]              = 35,
    [xi.effect.CHOKE]                 = 25,
    [xi.effect.CRIT_HIT_EVASION_DOWN] = 20,
}

local MP_DRAIN_BASE_RATIO =
{
    [109] = 0.20, -- Entropy
    [171] = 1.00, -- Mystic Boon
    [183] = 1.00, -- Spirit Taker
}

local function copyParams(src)
    local dst = {}
    for k, v in pairs(src or {}) do
        if type(v) == 'table' then
            local sub = {}
            for sk, sv in pairs(v) do
                sub[sk] = sv
            end
            dst[k] = sub
        else
            dst[k] = v
        end
    end
    return dst
end

local function addToTriple(tbl, addVal, defaultBase)
    local out = tbl or { defaultBase, defaultBase, defaultBase }
    for i = 1, 3 do
        out[i] = out[i] + addVal
    end
    return out
end

local function countSpinningPackExtras(attacker, target, primaryMsg)
    if attacker == nil then
        return 0
    end
    local actorId = attacker:getID()
    local now = os.time()
    local cached = spinPackCache[actorId]
    if not primaryMsg and cached ~= nil and (now - cached.at) <= 1 then
        return cached.extra
    end

    local count = 0
    if attacker.getNearbyEntities then
        local nearby = attacker:getNearbyEntities(8)
        if type(nearby) == 'table' then
            for _, ent in pairs(nearby) do
                if ent ~= nil and ent:isMob() and ent:isAlive() and ent:checkDistance(attacker) <= 7.5 then
                    count = count + 1
                end
            end
        end
    end
    if count == 0 and target ~= nil then
        count = 1
    end
    local extra = math.max(0, math.min(5, count - 1))
    spinPackCache[actorId] = { at = now, extra = extra }
    return extra
end

local function applyTimedBuffMods(player, effectId, durationSec, modPairs)
    if player == nil then
        return
    end
    player:delStatusEffectSilent(effectId)
    player:addStatusEffect(effectId, { power = 1, duration = durationSec, origin = player, silent = true })
    local eff = player:getStatusEffect(effectId)
    if eff ~= nil then
        for _, pair in ipairs(modPairs) do
            if pair[2] ~= 0 then
                eff:addMod(pair[1], pair[2])
            end
        end
    end
end

local function applyCustomFtpCurve(curve, rank, maxRank)
    local out = { 1.0, 1.0, 1.0 }
    if rank <= 0 then
        return out
    end
    local t = math.min(rank, maxRank) / maxRank
    for i = 1, 3 do
        out[i] = math.floor((1.0 + (curve[i] - 1.0) * t) * 100 + 0.5) / 100
    end
    return out
end

local function applySkillchainVars(attacker, ws, ranks, extraScBonus)
    if attacker == nil or ws == nil then
        return
    end

    local jobId = attacker:getMainJob()
    local scData = talents.getActiveSkillchains(attacker, jobId, ws.id, ranks)
    local totalScBonus = (scData.scBonus or 0) + (extraScBonus or 0)

    attacker:setLocalVar('OX_WS_SC_SET', 1)
    attacker:setLocalVar('OX_WS_SC1', scData.sc1 or 0)
    attacker:setLocalVar('OX_WS_SC2', scData.sc2 or 0)
    attacker:setLocalVar('OX_WS_SC3', scData.sc3 or 0)

    if totalScBonus > 0 then
        pendingScBonus[attacker:getID()] = { pct = totalScBonus, expiresAt = os.time() + 2 }
    else
        pendingScBonus[attacker:getID()] = nil
    end
end

local function applyWSNormalizationAndTalents(attacker, target, wsID, wsParams, tp, primaryMsg)
    local ws = catalog.byId[wsID]
    local params = copyParams(wsParams)

    -- Always normalize base WS to fTP 1.0, 0 WSC, 1 base hit, and strip curve mods
    params.ftpMod  = { 1.0, 1.0, 1.0 }
    params.numHits = 1
    params.str_wsc = 0
    params.dex_wsc = 0
    params.vit_wsc = 0
    params.agi_wsc = 0
    params.int_wsc = 0
    params.mnd_wsc = 0
    params.chr_wsc = 0

    params.critVaries     = nil
    params.accVaries      = nil
    params.atkVaries      = nil
    params.ignoredDefense = nil
    params.multiHitfTP    = nil

    if ws == nil then
        attacker:setLocalVar('OX_WS_SC_SET', 1)
        attacker:setLocalVar('OX_WS_SC1', 0)
        attacker:setLocalVar('OX_WS_SC2', 0)
        attacker:setLocalVar('OX_WS_SC3', 0)
        pendingScBonus[attacker:getID()] = nil
        return params, {}, nil, tp, {}
    end

    local tempMods = {}
    local function addTempMod(modId, amount)
        if modId ~= nil and amount ~= 0 then
            table.insert(tempMods, { mod = modId, amount = amount })
            attacker:addMod(modId, amount)
        end
    end

    local jobId = attacker:getMainJob()
    local tree  = talents.getTreeForWS(wsID)
    local ranks = talents.getWSRanks(attacker, jobId, wsID)
    local orig  = ws.orig
    local extraCtx = { extraScBonus = 0, packExtras = 0 }
    local effectiveTp = tp

    -- Consume Combo's "Opening Edge" / "Blitz Tempo" Next-WS buffs if active
    local nextWsd = attacker:getLocalVar('OX_NEXT_WS_WSD')
    local nextExp = attacker:getLocalVar('OX_NEXT_WS_EXP')
    if nextWsd > 0 and os.time() <= nextExp then
        addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, nextWsd)
    end
    local nextTpBonus = attacker:getLocalVar('OX_NEXT_WS_TP')
    if nextTpBonus > 0 and os.time() <= nextExp then
        effectiveTp = math.min(3000, effectiveTp + nextTpBonus)
    end
    if nextExp > 0 then
        attacker:setLocalVar('OX_NEXT_WS_WSD', 0)
        attacker:setLocalVar('OX_NEXT_WS_TP', 0)
        attacker:setLocalVar('OX_NEXT_WS_EXP', 0)
    end

    -- Tier 1: fTP Scaling
    local ftpRank = ranks.ftp or 0
    if ftpRank > 0 then
        local ftpNode = tree and tree.byKey and tree.byKey.ftp
        if ftpNode and ftpNode.ftpCurve then
            params.ftpMod = applyCustomFtpCurve(ftpNode.ftpCurve, ftpRank, ftpNode.maxRank or 4)
        else
            params.ftpMod = talents.calcFtpAtRank(orig.ftp, ftpRank, (ftpNode and ftpNode.maxRank) or 4)
        end
    end

    -- Generic Fallback Stat WSC / Curves (for weapon #16-#207 until curated)
    for _, stat in ipairs(talents.STAT_ORDER) do
        local r = ranks['wsc_' .. stat] or 0
        if r > 0 and orig.wsc[stat] then
            local node = tree and tree.byKey and tree.byKey['wsc_' .. stat]
            params[stat .. '_wsc'] = talents.calcWscAtRank(orig.wsc[stat], r, (node and node.maxRank) or 3)
        end
    end

    local hitsT1 = ranks.hits_t1 or 0
    if hitsT1 > 0 and orig.numHits >= 2 then
        local targetHits = orig.numHits
        params.numHits = 1 + math.min(targetHits - 1, math.ceil((targetHits - 1) * (hitsT1 / 3)))
        params.accVaries = addToTriple(params.accVaries, hitsT1 * 10, 0)
    end

    local mhRank = ranks.multihit or 0
    if mhRank > 0 then
        params.accVaries = addToTriple(params.accVaries, 12 * mhRank, 0)
        params.atkVaries = addToTriple(params.atkVaries, 0.08 * mhRank, 1.0)
        if mhRank >= 3 then
            params.multiHitfTP = true
        end
        if mhRank >= 4 then
            params.numHits = (params.numHits or 1) + 1
        end
    end

    local debRank = ranks.debuff or 0
    if debRank > 0 then
        activeWsContext[attacker:getID()] =
        {
            wsID = wsID,
            debuffRank = debRank,
            isBinary = orig.debuff and orig.debuff.binary or false,
            expiresAt = os.time() + 2,
        }
    else
        activeWsContext[attacker:getID()] = nil
    end

    local critRank = ranks.crit or 0
    if critRank > 0 then
        if wsID == 4 then -- Backhand Blow
            params.critVaries = addToTriple(params.critVaries, critRank * 0.15, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, critRank * 5)
        elseif wsID == 11 then -- Ascetics Fury
            local curves = { { 0.10, 0.15, 0.25 }, { 0.18, 0.28, 0.40 }, { 0.25, 0.40, 0.55 } }
            params.critVaries = curves[critRank] or curves[3]
        elseif wsID == 12 then -- Stringing Pummel
            local curves = { { 0.08, 0.12, 0.18 }, { 0.12, 0.18, 0.28 }, { 0.16, 0.26, 0.38 } }
            params.critVaries = curves[critRank] or curves[3]
        elseif wsID == 14 then -- Victory Smite
            local curves = { { 0.08, 0.12, 0.15 }, { 0.12, 0.18, 0.25 }, { 0.16, 0.26, 0.35 }, { 0.20, 0.32, 0.45 } }
            params.critVaries = curves[critRank] or curves[4]
        else
            params.critVaries = talents.calcScaledTable(orig.critVaries, critRank, { 0.10, 0.15, 0.20 })
            local critDmgMod = (ws.wsType == 'ranged') and xi.mod.RANGED_CRIT_DMG_INCREASE or xi.mod.CRIT_DMG_INCREASE
            addTempMod(critDmgMod, critRank * 5)
        end
    end

    local defIgnRank = ranks.def_ignore or 0
    if defIgnRank > 0 then
        if wsID == 3 then -- One Inch Punch
            local pct = ({ 0.15, 0.30, 0.50 })[defIgnRank] or 0.50
            params.ignoredDefense = { pct, pct, pct }
        elseif wsID == 7 then -- Howling Fist
            local pct = ({ 0.10, 0.18, 0.28 })[defIgnRank] or 0.28
            params.ignoredDefense = { pct, pct, pct }
        elseif wsID == 10 then -- Final Heaven
            local pct = ({ 0.12, 0.24, 0.35 })[defIgnRank] or 0.35
            params.ignoredDefense = { pct, pct, pct }
        else
            params.ignoredDefense = talents.calcScaledTable(orig.ignoredDefense, defIgnRank, { 0.08, 0.12, 0.16 })
        end
    end

    local atkRank = ranks.atk_mult or 0
    if atkRank > 0 then
        local bonuses = talents.calcAtkScaleAtRank(orig.atkVaries, atkRank)
        params.atkVaries = params.atkVaries or { 1.0, 1.0, 1.0 }
        for i = 1, 3 do
            params.atkVaries[i] = params.atkVaries[i] + bonuses[i]
        end
    end

    local accRank = ranks.acc_mult or 0
    if accRank > 0 then
        if wsID == 9 then -- Asuran Fists
            local curve = ({ { 20, 30, 45 }, { 40, 60, 90 }, { 60, 90, 140 } })[accRank] or { 60, 90, 140 }
            params.accVaries = params.accVaries or { 0, 0, 0 }
            for i = 1, 3 do
                params.accVaries[i] = params.accVaries[i] + curve[i]
            end
        else
            local accAdd = talents.calcScaledTable(orig.accVaries, accRank, { 20, 25, 30 })
            params.accVaries = params.accVaries or { 0, 0, 0 }
            for i = 1, 3 do
                params.accVaries[i] = params.accVaries[i] + accAdd[i]
            end
        end
    end

    local echoRank = ranks.aftermath_echo or 0
    if echoRank > 0 then
        local wsdAdd = ({ 8, 16, 25 })[echoRank] or 0
        local tpAdd  = echoRank * 100
        addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, wsdAdd)
        effectiveTp = math.min(3000, effectiveTp + tpAdd)
    end

    local elemRank = ranks.elemental or 0
    if elemRank > 0 then
        addTempMod(xi.mod.MATT, elemRank * 18)
        addTempMod(xi.mod.MACC, elemRank * 18)
    end

    local focRank = ranks.focused or 0
    if focRank > 0 then
        params.atkVaries = addToTriple(params.atkVaries, focRank * 0.15, 1.0)
        params.accVaries = addToTriple(params.accVaries, focRank * 15, 0)
    end

    local mfRank = ranks.master_force or 0
    if mfRank > 0 then
        addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, mfRank * 7)
        params.atkVaries = addToTriple(params.atkVaries, mfRank * 0.10, 1.0)
    end

    local mpRank = ranks.master_prec or 0
    if mpRank > 0 then
        params.accVaries = addToTriple(params.accVaries, mpRank * 20, 0)
        params.critVaries = addToTriple(params.critVaries, mpRank * 0.06, 0)
    end

    local wsmRank = ranks.ws_mastery or 0
    if wsmRank > 0 then
        addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, wsmRank * 8)
        params.accVaries = addToTriple(params.accVaries, wsmRank * 15, 0)
    end

    -----------------------------------
    -- Hand-to-Hand (#1 - #15) Specific Combat Mechanics
    -----------------------------------
    local hasFootwork = attacker:hasStatusEffect(xi.effect.FOOTWORK)
    local hasFocus    = attacker:hasStatusEffect(xi.effect.FOCUS)
    local hasImpetus  = attacker:hasStatusEffect(xi.effect.IMPETUS)
    local hasDodge    = attacker:hasStatusEffect(xi.effect.DODGE)

    if wsID == 1 then -- Combo
        local rHits = ranks.combo_hits or 0
        if rHits >= 1 then
            params.numHits = rHits >= 3 and 3 or 2
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rHits * 5)
        end
        local rWsc = ranks.combo_wsc or 0
        if rWsc > 0 then
            local v = ({ 0.12, 0.24, 0.35 })[rWsc] or 0.35
            params.str_wsc, params.dex_wsc = v, v
        end
        local rSb = ranks.combo_sb or 0
        if rSb > 0 then
            params.accVaries = addToTriple(params.accVaries, rSb * 15, 0)
        end
        local rMast = ranks.combo_mast or 0
        if rMast > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rMast * 0.10, 1.0)
            params.accVaries = addToTriple(params.accVaries, rMast * 15, 0)
        end

    elseif wsID == 2 then -- Shoulder Tackle
        local rHits = ranks.tackle_hits or 0
        if rHits > 0 then
            params.numHits = 2
            params.accVaries = addToTriple(params.accVaries, ({ 10, 20, 35 })[rHits] or 35, 0)
        end
        local rWsc = ranks.tackle_wsc or 0
        if rWsc > 0 then
            params.vit_wsc = rWsc * 0.25
        end
        local rMast = ranks.tackle_mast or 0
        if rMast > 0 then
            addTempMod(xi.mod.MACC, rMast * 20)
            addTempMod(xi.mod.ENMITY, -(({ 15, 30, 50 })[rMast] or 50))
        end

    elseif wsID == 3 then -- One Inch Punch
        local rHits = ranks.inch_hits or 0
        if rHits > 0 then
            params.numHits = 2
            params.accVaries = addToTriple(params.accVaries, rHits == 1 and 10 or (rHits - 1) * 20, 0)
            if rHits > 1 then
                params.atkVaries = addToTriple(params.atkVaries, (rHits - 1) * 0.10, 1.0)
            end
        end
        local rVit = ranks.inch_vit_chi or 0
        if rVit > 0 then
            params.vit_wsc = rVit * 0.20
        end
        local rMast = ranks.inch_mast or 0
        if rMast > 0 then
            addTempMod(xi.mod.MACC, rMast * 20)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            local pct = rCap >= 2 and 1.00 or 0.80
            params.ignoredDefense = { pct, pct, pct }
        end

    elseif wsID == 4 then -- Backhand Blow
        local rHits = ranks.bh_hits or 0
        if rHits > 0 then
            params.numHits = 2
            params.accVaries = addToTriple(params.accVaries, (rHits - 1) * 15, 0)
            params.atkVaries = addToTriple(params.atkVaries, (rHits - 1) * 0.10, 1.0)
        end
        local rWsc = ranks.bh_wsc or 0
        if rWsc > 0 then
            local v = ({ 0.25, 0.45, 0.65 })[rWsc] or 0.65
            params.str_wsc, params.dex_wsc = v, v
        end
        local rAero = ranks.bh_enaero or 0
        if rAero > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rAero * 0.10, 1.0)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap >= 2 and 25 or 15)
        end
        local rMast = ranks.bh_mast or 0
        if rMast > 0 then
            params.accVaries = addToTriple(params.accVaries, ({ 15, 30, 50 })[rMast] or 50, 0)
            addTempMod(xi.mod.MACC, ({ 10, 20, 35 })[rMast] or 35)
        end

    elseif wsID == 5 then -- Raging Fists
        local rH1 = ranks.rf_hits1 or 0
        local rH2 = ranks.rf_hits2 or 0
        params.numHits = 1 + rH1 + (rH2 >= 1 and 1 or 0) -- 1 -> 5h
        if rH2 > 1 then
            params.accVaries = addToTriple(params.accVaries, (rH2 - 1) * 15, 0)
            params.atkVaries = addToTriple(params.atkVaries, (rH2 - 1) * 0.10, 1.0)
        end
        local rWsc = ranks.rf_wsc or 0
        if rWsc > 0 then
            local v = rWsc * 0.15
            params.str_wsc, params.dex_wsc = v, v
        end
        local rForce = ranks.rf_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.15, 1.0)
            params.accVaries = addToTriple(params.accVaries, rForce * 10, 0)
        end
        local rMftp = ranks.rf_mftp or 0
        if rMftp > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, math.min(rMftp, 3) * 8)
            if rMftp >= 4 then
                params.multiHitfTP = true
            end
        end
        local rStance = ranks.rf_stance or 0
        if rStance > 0 and (hasFocus or hasImpetus) then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rStance * 12)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap >= 2 and 28 or 15)
            params.atkVaries = addToTriple(params.atkVaries, rCap * 0.15, 1.0)
        end
        local rMast = ranks.rf_mast or 0
        if rMast > 0 then
            params.critVaries = addToTriple(params.critVaries, rMast * 0.05, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, ({ 8, 16, 25 })[rMast] or 25)
        end

    elseif wsID == 6 then -- Spinning Attack
        local rHits = ranks.spin_hits or 0
        if rHits > 0 then
            params.numHits = rHits >= 3 and 3 or 2
            params.accVaries = addToTriple(params.accVaries, rHits >= 2 and 15 or 5, 0)
        end
        local rWsc = ranks.spin_wsc or 0
        if rWsc > 0 then
            params.str_wsc = ({ 0.35, 0.65, 1.00 })[rWsc] or 1.00
        end
        local packExtras = countSpinningPackExtras(attacker, target, primaryMsg)
        extraCtx.packExtras = packExtras
        local rPack = ranks.spin_pack or 0
        if rPack > 0 and packExtras > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rPack * 10 * packExtras)
        end
        local rForce = ranks.spin_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.15, 1.0)
            params.accVaries = addToTriple(params.accVaries, rForce * 15, 0)
        end
        local rMftp = ranks.spin_mftp or 0
        if rMftp > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, math.min(rMftp, 2) * 8)
            if rMftp >= 3 then
                params.multiHitfTP = true
            end
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 15)
            if packExtras >= 1 then
                params.numHits = (params.numHits or 1) + 1
            end
        end
        local rMast = ranks.spin_mast or 0
        if rMast > 0 then
            params.critVaries = addToTriple(params.critVaries, rMast * 0.10, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, ({ 8, 16, 25 })[rMast] or 25)
        end

    elseif wsID == 7 then -- Howling Fist
        local rHits = ranks.hf_hits or 0
        if rHits > 0 then
            params.numHits = 2
            params.accVaries = addToTriple(params.accVaries, (rHits - 1) * 15, 0)
            params.atkVaries = addToTriple(params.atkVaries, (rHits - 1) * 0.10, 1.0)
        end
        local rWsc = ranks.hf_wsc or 0
        if rWsc > 0 then
            params.str_wsc = rWsc * 0.10
            params.vit_wsc = rWsc * 0.20
        end
        local rAtk = ranks.hf_atk or 0
        if rAtk > 0 then
            params.atkVaries = addToTriple(params.atkVaries, ({ 0.15, 0.30, 0.45, 0.65 })[rAtk] or 0.65, 1.0)
        end
        local rTp = ranks.hf_tp or 0
        if rTp > 0 then
            effectiveTp = math.min(3000, effectiveTp + rTp * 125)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 12)
        end
        local rMast = ranks.hf_mast or 0
        if rMast > 0 then
            params.accVaries = addToTriple(params.accVaries, ({ 15, 30, 50 })[rMast] or 50, 0)
            params.critVaries = addToTriple(params.critVaries, ({ 0.08, 0.16, 0.25 })[rMast] or 0.25, 0)
        end

    elseif wsID == 8 then -- Dragon Kick
        local rHits = ranks.dk_hits or 0
        if rHits > 0 then
            params.numHits = 2
            params.accVaries = addToTriple(params.accVaries, (rHits - 1) * 15, 0)
            params.atkVaries = addToTriple(params.atkVaries, (rHits - 1) * 0.10, 1.0)
        end
        local rWsc = ranks.dk_wsc or 0
        if rWsc > 0 then
            local v = rWsc * 0.20
            params.str_wsc, params.vit_wsc = v, v
        end
        local rFw = ranks.dk_fw or 0
        if rFw > 0 and hasFootwork then
            local ftpAdd = ({ 0.20, 0.35, 0.50, 0.70 })[rFw] or 0.70
            params.ftpMod = addToTriple(params.ftpMod, ftpAdd, 1.0)
            params.atkVaries = addToTriple(params.atkVaries, rFw * 0.10, 1.0)
        end
        local rForce = ranks.dk_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.15, 1.0)
        end
        local rCrit = ranks.dk_crit or 0
        if rCrit > 0 then
            params.critVaries = addToTriple(params.critVaries, rCrit * 0.08, 0)
            params.accVaries = addToTriple(params.accVaries, ({ 10, 20, 30, 45 })[rCrit] or 45, 0)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            if hasFootwork then
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 15)
            end
        end
        local rMast = ranks.dk_mast or 0
        if rMast > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, ({ 8, 16, 25 })[rMast] or 25)
            if hasFootwork then
                effectiveTp = math.min(3000, effectiveTp + rMast * 150)
            end
        end

    elseif wsID == 9 then -- Asuran Fists
        local rH1 = ranks.af_hits1 or 0
        local rH2 = ranks.af_hits2 or 0
        local h1Add = ({ 1, 2, 4 })[rH1] or 0
        local h2Add = math.min(rH2, 3)
        params.numHits = math.min(8, 1 + h1Add + h2Add) -- 1 -> 8h
        if rH2 >= 4 then
            params.atkVaries = addToTriple(params.atkVaries, 0.15, 1.0)
        end
        local rWsc = ranks.af_wsc or 0
        if rWsc > 0 then
            local v = ({ 0.10, 0.18, 0.25 })[rWsc] or 0.25
            params.str_wsc, params.vit_wsc = v, v
        end
        local rMftp = ranks.af_mftp or 0
        if rMftp > 0 then
            params.atkVaries = addToTriple(params.atkVaries, math.min(rMftp, 3) * 0.08, 1.0)
            if rMftp >= 4 then
                params.multiHitfTP = true
            end
        end
        local rFoc = ranks.af_focus or 0
        if rFoc > 0 and hasFocus then
            params.critVaries = addToTriple(params.critVaries, rFoc * 0.10, 0)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.ftpMod = addToTriple(params.ftpMod, rCap >= 2 and 0.15 or 0.08, 1.0)
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 10)
        end
        local rMast = ranks.af_mast or 0
        if rMast > 0 then
            params.atkVaries = addToTriple(params.atkVaries, ({ 0.08, 0.16, 0.25 })[rMast] or 0.25, 1.0)
            params.accVaries = addToTriple(params.accVaries, rMast * 20, 0)
        end

    elseif wsID == 10 then -- Final Heaven
        local rHits = ranks.fh_hits or 0
        if rHits > 0 then
            params.numHits = 2
            params.accVaries = addToTriple(params.accVaries, (rHits - 1) * 15, 0)
            params.atkVaries = addToTriple(params.atkVaries, (rHits - 1) * 0.10, 1.0)
        end
        local rWsc = ranks.fh_wsc or 0
        if rWsc > 0 then
            params.vit_wsc = ({ 0.30, 0.55, 0.85 })[rWsc] or 0.85
        end
        local rSb = ranks.fh_sb or 0
        if rSb > 0 then
            addTempMod(xi.mod.SUBTLE_BLOW, rSb * 10)
            addTempMod(xi.mod.ENMITY, -(rSb * 15))
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap >= 2 and 25 or 15)
            extraCtx.extraScBonus = extraCtx.extraScBonus + rCap * 10
        end
        local rMast = ranks.fh_mast or 0
        if rMast > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rMast * 0.15, 1.0)
            params.accVaries = addToTriple(params.accVaries, ({ 15, 30, 50 })[rMast] or 50, 0)
        end

    elseif wsID == 11 then -- Ascetics Fury
        local rHits = ranks.afury_hits or 0
        if rHits > 0 then
            params.numHits = 2
            params.accVaries = addToTriple(params.accVaries, (rHits - 1) * 15, 0)
            params.atkVaries = addToTriple(params.atkVaries, (rHits - 1) * 0.10, 1.0)
        end
        local rWsc = ranks.afury_wsc or 0
        if rWsc > 0 then
            local v = ({ 0.25, 0.45, 0.65 })[rWsc] or 0.65
            params.str_wsc, params.vit_wsc = v, v
        end
        local rAtk = ranks.afury_atk or 0
        if rAtk > 0 then
            params.atkVaries = addToTriple(params.atkVaries, ({ 0.35, 0.70, 1.10, 1.50 })[rAtk] or 1.50, 1.0)
        end
        local rCdmg = ranks.afury_critdmg or 0
        if rCdmg > 0 then
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rCdmg * 8)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            params.critVaries = addToTriple(params.critVaries, 0.15, 0)
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap >= 2 and 22 or 10)
        end
        local rMast = ranks.afury_mast or 0
        if rMast > 0 then
            local pct = rMast * 0.10
            params.ignoredDefense = addToTriple(params.ignoredDefense, pct, 0)
            params.accVaries = addToTriple(params.accVaries, rMast * 20, 0)
        end

    elseif wsID == 12 then -- Stringing Pummel
        local rH1 = ranks.sp_hits1 or 0
        local rH2 = ranks.sp_hits2 or 0
        params.numHits = 1 + rH1 + math.min(rH2, 2) -- 1 -> 6h
        if rH2 > 2 then
            params.atkVaries = addToTriple(params.atkVaries, (rH2 - 2) * 0.12, 1.0)
        end
        local rWsc = ranks.sp_wsc or 0
        if rWsc > 0 then
            local v = ({ 0.15, 0.28, 0.40 })[rWsc] or 0.40
            params.str_wsc, params.vit_wsc = v, v
        end
        local rCdmg = ranks.sp_critdmg or 0
        if rCdmg > 0 then
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rCdmg * 8)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 10)
        end
        local rMast = ranks.sp_mast or 0
        if rMast > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rMast * 0.12, 1.0)
            params.accVaries = addToTriple(params.accVaries, ({ 15, 30, 50 })[rMast] or 50, 0)
        end

    elseif wsID == 13 then -- Tornado Kick
        local rHits = ranks.tk_hits or 0
        if rHits > 0 then
            params.numHits = rHits >= 3 and 3 or 2
            params.accVaries = addToTriple(params.accVaries, rHits >= 2 and 15 or 5, 0)
        end
        local rWsc = ranks.tk_wsc or 0
        if rWsc > 0 then
            local v = ({ 0.20, 0.35, 0.50 })[rWsc] or 0.50
            params.str_wsc, params.vit_wsc = v, v
        end
        local rFw = ranks.tk_fw or 0
        if rFw > 0 and hasFootwork then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rFw * 12)
            params.atkVaries = addToTriple(params.atkVaries, rFw * 0.10, 1.0)
        end
        local rForce = ranks.tk_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.15, 1.0)
            params.accVaries = addToTriple(params.accVaries, rForce * 15, 0)
        end
        local rTp = ranks.tk_tp or 0
        if rTp > 0 and (hasFootwork or hasDodge) then
            effectiveTp = math.min(3000, effectiveTp + rTp * 150)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap >= 2 and 22 or 12)
        end
        local rMast = ranks.tk_mast or 0
        if rMast > 0 then
            params.critVaries = addToTriple(params.critVaries, rMast * 0.10, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, ({ 8, 16, 25 })[rMast] or 25)
        end

    elseif wsID == 14 then -- Victory Smite
        local rHits = ranks.vs_hits or 0
        params.numHits = 1 + rHits -- 1 -> 4h
        local rWsc = ranks.vs_wsc or 0
        if rWsc > 0 then
            params.str_wsc = ({ 0.35, 0.65, 0.90 })[rWsc] or 0.90
        end
        local rForce = ranks.vs_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.15, 1.0)
            params.accVaries = addToTriple(params.accVaries, rForce * 15, 0)
        end
        local rCdmg = ranks.vs_critdmg or 0
        if rCdmg > 0 then
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rCdmg * 8)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 10)
        end
        local rMast = ranks.vs_mast or 0
        if rMast > 0 then
            if hasImpetus or hasFocus then
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, ({ 12, 24, 40 })[rMast] or 40)
            end
            params.accVaries = addToTriple(params.accVaries, rMast * 20, 0)
        end

    elseif wsID == 15 then -- Shijin Spiral
        local rHits = ranks.ss_hits or 0
        params.numHits = 1 + (({ 1, 2, 4 })[rHits] or 0) -- 1 -> 5h
        local rWsc = ranks.ss_wsc or 0
        if rWsc > 0 then
            params.dex_wsc = ({ 0.30, 0.55, 0.85 })[rWsc] or 0.85
        end
        local rAcc = ranks.ss_acc or 0
        if rAcc > 0 then
            params.accVaries = addToTriple(params.accVaries, ({ 20, 40, 60, 85 })[rAcc] or 85, 0)
            params.atkVaries = addToTriple(params.atkVaries, rAcc * 0.08, 1.0)
        end
        local rForce = ranks.ss_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, ({ 0.12, 0.24, 0.38 })[rForce] or 0.38, 1.0)
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rForce * 5)
        end
        local rMftp = ranks.ss_mftp or 0
        if rMftp > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, math.min(rMftp, 3) * 8)
            if rMftp >= 4 then
                params.multiHitfTP = true
            end
        end
        local rWind = ranks.ss_wind or 0
        if rWind > 0 and (hasImpetus or hasFocus) then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rWind * 10)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            extraCtx.extraScBonus = extraCtx.extraScBonus + rCap * 15
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 12)
        end
        local rMast = ranks.ss_mast or 0
        if rMast > 0 then
            params.critVaries = addToTriple(params.critVaries, rMast * 0.10, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, ({ 8, 16, 25 })[rMast] or 25)
        end

    else
        -- Generic 4-Tier Capstone (#16-#207 fallback)
        local capRank = ranks.capstone or 0
        if capRank > 0 then
            local arch = tree and tree.archetype or 'heavy'
            if arch == 'magic' then
                addTempMod(xi.mod.MATT, capRank >= 2 and 50 or 30)
                addTempMod(xi.mod.MACC, capRank >= 2 and 50 or 30)
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, capRank >= 2 and 28 or 15)
            elseif arch == 'crit' then
                params.critVaries = addToTriple(params.critVaries, capRank >= 2 and 0.18 or 0.10, 0)
                local critDmgMod = (ws.wsType == 'ranged') and xi.mod.RANGED_CRIT_DMG_INCREASE or xi.mod.CRIT_DMG_INCREASE
                addTempMod(critDmgMod, capRank * 12)
                params.ftpMod = addToTriple(params.ftpMod, capRank * 0.5, 1.0)
            elseif arch == 'multihit' then
                params.multiHitfTP = true
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, capRank >= 2 and 28 or 15)
            elseif arch == 'utility' then
                addTempMod(xi.mod.SUBTLE_BLOW, capRank * 15)
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, capRank * 15)
            else
                params.atkVaries = addToTriple(params.atkVaries, capRank >= 2 and 0.45 or 0.25, 1.0)
                params.ignoredDefense = addToTriple(params.ignoredDefense, capRank >= 2 and 0.25 or 0.15, 0)
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, capRank * 12)
            end
        end
    end

    applySkillchainVars(attacker, ws, ranks, extraCtx.extraScBonus)
    return params, tempMods, ranks, effectiveTp, extraCtx
end

local function cleanupTempMods(attacker, tempMods)
    for i = #tempMods, 1, -1 do
        attacker:delMod(tempMods[i].mod, tempMods[i].amount)
    end
end

local function dealFollowUpElementalHit(attacker, target, pct, elementDmgType)
    if attacker == nil or target == nil or not target:isAlive() or (pct or 0) <= 0 then
        return 0
    end
    local extra = math.floor(pct)
    if extra > 0 then
        target:takeDamage(extra, attacker, xi.attackType.BREATH, elementDmgType or xi.damageType.ELEMENTAL)
    end
    return extra
end

local function applyPostDamageTraits(attacker, target, wsID, ranks, dmg, extraCtx)
    if attacker == nil or ranks == nil then
        return dmg
    end

    local totalDmg = dmg or 0

    -----------------------------------
    -- Utility Self-Buffs / Debuffs / Chi Blast Setup (#1 - #4)
    -----------------------------------
    if wsID == 1 then -- Combo
        local mods = {}
        local rHaste = ranks.combo_haste or 0
        if rHaste > 0 then
            table.insert(mods, { xi.mod.HASTE_ABILITY, ({ 400, 800, 1200, 1500 })[rHaste] or 1500 })
        end
        local rSb = ranks.combo_sb or 0
        if rSb > 0 then
            table.insert(mods, { xi.mod.SUBTLE_BLOW, ({ 8, 16, 25 })[rSb] or 25 })
        end
        local rDa = ranks.combo_da or 0
        if rDa > 0 then
            table.insert(mods, { xi.mod.DOUBLE_ATTACK, rDa * 10 })
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            table.insert(mods, { xi.mod.TRIPLE_ATTACK, rCap >= 2 and 18 or 10 })
            attacker:setLocalVar('OX_NEXT_WS_TP', rCap >= 2 and 250 or 120)
            attacker:setLocalVar('OX_NEXT_WS_EXP', os.time() + 10)
        end
        if #mods > 0 then
            applyTimedBuffMods(attacker, xi.effect.SUBTLE_BLOW_PLUS, 12, mods)
        end
        local rSetup = ranks.combo_setup or 0
        if rSetup > 0 then
            attacker:setLocalVar('OX_NEXT_WS_WSD', ({ 8, 16, 25 })[rSetup] or 25)
            attacker:setLocalVar('OX_NEXT_WS_EXP', os.time() + 10)
        end

    elseif wsID == 2 then -- Shoulder Tackle
        local rChi = ranks.chi_setup or 0
        local rCap = ranks.capstone or 0
        local chiPct = rChi * 20 + (rCap > 0 and (rCap >= 2 and 50 or 30) or 0)
        if chiPct > 0 then
            attacker:setLocalVar('OX_CHIBLAST_PCT', chiPct)
        end
        if rChi > 0 then
            attacker:setLocalVar('OX_CHIBLAST_CD_TRIM', rChi * 10)
        end
        if totalDmg > 0 and target ~= nil and target:isAlive() then
            local rAtkDn = ranks.tackle_atkdn or 0
            if rAtkDn > 0 then
                target:delStatusEffectSilent(xi.effect.ATTACK_DOWN)
                target:addStatusEffect(xi.effect.ATTACK_DOWN, { power = ({ 10, 16, 22, 28 })[rAtkDn] or 28, duration = 45, origin = attacker })
                target:delTP(({ 100, 180, 260, 350 })[rAtkDn] or 350)
            end
            local rDispel = ranks.tackle_dispel or 0
            if rDispel > 0 then
                local count = rDispel >= 3 and 2 or 1
                for _ = 1, count do
                    target:dispelStatusEffect()
                end
                local deb = rDispel * 15
                target:delStatusEffectSilent(xi.effect.ACCURACY_DOWN)
                target:addStatusEffect(xi.effect.ACCURACY_DOWN, { power = deb, duration = 45, origin = attacker })
                target:delStatusEffectSilent(xi.effect.EVASION_DOWN)
                target:addStatusEffect(xi.effect.EVASION_DOWN, { power = deb, duration = 45, origin = attacker })
            end
            if rCap > 0 then
                target:delStatusEffectSilent(xi.effect.SLOW)
                target:addStatusEffect(xi.effect.SLOW, { power = rCap >= 2 and 2500 or 1500, duration = 45, origin = attacker })
                target:delStatusEffectSilent(xi.effect.PARALYSIS)
                target:addStatusEffect(xi.effect.PARALYSIS, { power = rCap >= 2 and 25 or 15, duration = 45, origin = attacker })
            end
        end

    elseif wsID == 3 then -- One Inch Punch
        local rChi  = ranks.inch_vit_chi or 0
        local rMast = ranks.inch_mast or 0
        local rCap  = ranks.capstone or 0
        local chiPct = (rChi > 0 and ({ 20, 40, 60, 75 })[rChi] or 0) + (rMast * 10)
        if chiPct > 0 then
            attacker:setLocalVar('OX_CHIBLAST_PCT', chiPct)
        end
        if rCap > 0 then
            attacker:setLocalVar('OX_CHIBLAST_CD_TRIM', rCap >= 2 and 45 or 25)
        end
        local rSkin = ranks.inch_skin or 0
        if rSkin > 0 then
            attacker:delStatusEffectSilent(xi.effect.STONESKIN)
            attacker:addStatusEffect(xi.effect.STONESKIN, { power = ({ 120, 240, 360, 500 })[rSkin] or 500, duration = 120, origin = attacker, tier = 3 })
        end
        if totalDmg > 0 and target ~= nil and target:isAlive() then
            local rDefDn = ranks.inch_defdn or 0
            if rDefDn > 0 then
                target:delStatusEffectSilent(xi.effect.DEFENSE_DOWN)
                target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = ({ 15, 22, 30 })[rDefDn] or 30, duration = 60, origin = attacker })
            end
            local rPlague = ranks.inch_plague or 0
            if rPlague > 0 then
                target:delStatusEffectSilent(xi.effect.PLAGUE)
                target:addStatusEffect(xi.effect.PLAGUE, { power = ({ 3, 5, 8 })[rPlague] or 8, duration = 45, origin = attacker })
                totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * rPlague * 0.10, xi.damageType.LIGHT)
            end
            if rCap > 0 then
                target:delStatusEffectSilent(xi.effect.MAGIC_DEF_DOWN)
                target:addStatusEffect(xi.effect.MAGIC_DEF_DOWN, { power = 20, duration = 60, origin = attacker })
            end
        end

    elseif wsID == 4 then -- Backhand Blow
        local critMods = {}
        local rPost = ranks.bh_postcrit or 0
        if rPost > 0 then
            table.insert(critMods, { xi.mod.CRITHITRATE, ({ 8, 14, 20 })[rPost] or 20 })
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            table.insert(critMods, { xi.mod.CRIT_DMG_INCREASE, rCap >= 2 and 22 or 12 })
        end
        if #critMods > 0 then
            applyTimedBuffMods(attacker, xi.effect.POTENCY, 12, critMods)
        end
        local rAero = ranks.bh_enaero or 0
        if rAero > 0 then
            attacker:delStatusEffectSilent(xi.effect.ENAERO)
            attacker:addStatusEffect(xi.effect.ENAERO, { power = ({ 12, 22, 32, 45 })[rAero] or 45, duration = 12, origin = attacker })
        end
        if totalDmg > 0 and target ~= nil and target:isAlive() then
            local rEva = ranks.bh_evadn or 0
            if rEva > 0 then
                target:delStatusEffectSilent(xi.effect.EVASION_DOWN)
                target:addStatusEffect(xi.effect.EVASION_DOWN, { power = ({ 20, 35, 50 })[rEva] or 50, duration = 45, origin = attacker })
            end
        end
    end

    -----------------------------------
    -- Elemental Follow-Up Hits on Damage H2H WSs (Zero Buffs/Debuffs)
    -----------------------------------
    if totalDmg > 0 and target ~= nil and target:isAlive() then
        if wsID == 6 and (ranks.spin_fire or 0) > 0 then
            local mult = (ranks.spin_fire * 0.20) * (1 + 0.25 * (extraCtx and extraCtx.packExtras or 0))
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * mult, xi.damageType.FIRE)
        elseif wsID == 7 and (ranks.hf_sonic or 0) > 0 then
            local mult = ({ 0.12, 0.24, 0.38 })[ranks.hf_sonic] or 0.38
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * mult, xi.damageType.WIND)
        elseif wsID == 8 and (ranks.dk_flame or 0) > 0 then
            local mult = ({ 0.10, 0.20, 0.32 })[ranks.dk_flame] or 0.32
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * mult, xi.damageType.FIRE)
        elseif wsID == 10 and (ranks.fh_light or 0) > 0 then
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * ranks.fh_light * 0.10, xi.damageType.LIGHT)
        elseif wsID == 13 and (ranks.tk_wind or 0) > 0 then
            local mult = ({ 0.08, 0.16, 0.24, 0.35 })[ranks.tk_wind] or 0.35
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * mult, xi.damageType.WIND)
        elseif wsID == 15 and (ranks.ss_wind or 0) > 0 then
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * ranks.ss_wind * 0.10, xi.damageType.WIND)
        end
    end

    -----------------------------------
    -- Generic Drain/Leech Traits (Non-H2H Fallback)
    -----------------------------------
    if totalDmg > 0 then
        local siphonRank = ranks.siphon or 0
        if siphonRank > 0 and (target == nil or not target:isUndead()) then
            local pct = ({ 0.15, 0.30, 0.50 })[siphonRank] or 0
            attacker:addHP(math.floor(totalDmg * pct))
            attacker:addMP(math.floor(totalDmg * pct))
        end

        local manaRank = ranks.mana_leech or 0
        local baseMpRatio = MP_DRAIN_BASE_RATIO[wsID]
        if manaRank > 0 and baseMpRatio ~= nil then
            local mpBoost = ({ 0.25, 0.50, 1.00 })[manaRank] or 0
            local hpShare = ({ 0.25, 0.50, 0.75 })[manaRank] or 0
            local extraMp = math.floor(totalDmg * baseMpRatio * mpBoost)
            local totalMp = math.floor(totalDmg * baseMpRatio * (1 + mpBoost))
            if extraMp > 0 then
                attacker:addMP(extraMp)
            end
            local hpHeal = math.floor(totalMp * hpShare)
            if hpHeal > 0 then
                attacker:addHP(hpHeal)
            end
        end
    end

    return totalDmg
end

local function invokeWithNormalizedParams(superFn, attacker, target, wsID, wsParams, tp, action, primaryMsg, taChar)
    if attacker == nil or not attacker:isPC() then
        return superFn(attacker, target, wsID, wsParams, tp, action, primaryMsg, taChar)
    end

    local modParams, tempMods, ranks, effTp, extraCtx = applyWSNormalizationAndTalents(attacker, target, wsID, wsParams, tp, primaryMsg)
    local ok, r1, r2, r3, r4, r5 = pcall(superFn, attacker, target, wsID, modParams, effTp, action, primaryMsg, taChar)
    cleanupTempMods(attacker, tempMods)

    if not ok then
        error(r1)
    end

    r1 = applyPostDamageTraits(attacker, target, wsID, ranks, r1, extraCtx)
    return r1, r2, r3, r4, r5
end

m:addOverride('xi.weaponskills.doPhysicalWeaponskill', function(attacker, target, wsID, wsParams, tp, action, primaryMsg, taChar)
    return invokeWithNormalizedParams(super, attacker, target, wsID, wsParams, tp, action, primaryMsg, taChar)
end)

m:addOverride('xi.weaponskills.doRangedWeaponskill', function(attacker, target, wsID, wsParams, tp, action, primaryMsg)
    return invokeWithNormalizedParams(super, attacker, target, wsID, wsParams, tp, action, primaryMsg, nil)
end)

m:addOverride('xi.weaponskills.doMagicWeaponskill', function(attacker, target, wsID, wsParams, tp, action, primaryMsg)
    return invokeWithNormalizedParams(super, attacker, target, wsID, wsParams, tp, action, primaryMsg, nil)
end)

-----------------------------------
-- Chi Blast Augmentation Hooks (from Shoulder Tackle & One Inch Punch)
-----------------------------------
m:addOverride('xi.actions.abilities.chi_blast.onAbilityCheck', function(player, target, ability)
    local rc, p = super(player, target, ability)
    if player ~= nil and player:isPC() and ability ~= nil then
        local trim = player:getLocalVar('OX_CHIBLAST_CD_TRIM')
        if trim > 0 then
            ability:setRecast(math.max(0, ability:getRecast() - trim))
            player:setLocalVar('OX_CHIBLAST_CD_TRIM', 0)
        end
    end
    return rc, p
end)

m:addOverride('xi.job_utils.monk.useChiBlast', function(player, target, ability)
    local dmg = super(player, target, ability)
    if player ~= nil and player:isPC() and dmg and dmg > 0 then
        local pct = player:getLocalVar('OX_CHIBLAST_PCT')
        if pct > 0 then
            player:setLocalVar('OX_CHIBLAST_PCT', 0)
            local bonus = math.floor(dmg * (pct / 100))
            if bonus > 0 and target ~= nil and target:isAlive() then
                target:takeDamage(bonus, player, xi.attackType.BREATH, xi.damageType.ELEMENTAL)
                dmg = dmg + bonus
            end
        end
    end
    return dmg
end)

-----------------------------------
-- Debuff & Skillchain Overrides
-----------------------------------
m:addOverride('xi.weaponskills.handleWeaponskillEffect', function(actor, target, effectId, actionElement, damage, power, duration)
    if actor == nil or not actor:isPC() then
        return super(actor, target, effectId, actionElement, damage, power, duration)
    end

    local ctx = activeWsContext[actor:getID()]
    if ctx == nil or os.time() > ctx.expiresAt or (ctx.debuffRank or 0) <= 0 then
        return super(actor, target, effectId, actionElement, damage, power, duration)
    end

    local r = ctx.debuffRank
    local durMult = 1 + (({ 0.35, 0.70, 1.00, 1.35 })[r] or 0)
    local maccAdd = ({ 25, 50, 75, 100 })[r] or 0
    local newDur  = math.floor((duration or 0) * durMult)
    local newPwr  = power

    if not ctx.isBinary and type(power) == 'number' and power > 0 then
        local potMult = 1 + (({ 0.20, 0.40, 0.65, 0.90 })[r] or 0)
        newPwr = math.floor(power * potMult + 0.5)
        local cap = DEBUFF_POWER_CAPS[effectId]
        if cap ~= nil then
            newPwr = math.min(newPwr, cap)
        end
    end

    actor:addMod(xi.mod.MACC, maccAdd)
    local ok, err = pcall(super, actor, target, effectId, actionElement, damage, newPwr, newDur)
    actor:delMod(xi.mod.MACC, maccAdd)
    if not ok then
        error(err)
    end
end)

m:addOverride('xi.combat.skillchain.calculateSkillchainDamage', function(actor, target, baseDamage)
    if actor == nil or not actor:isPC() then
        return super(actor, target, baseDamage)
    end

    local actorId = actor:getID()
    local pending = pendingScBonus[actorId]
    pendingScBonus[actorId] = nil

    if pending ~= nil and os.time() <= pending.expiresAt and (pending.pct or 0) > 0 then
        actor:addMod(xi.mod.SKILLCHAINBONUS, pending.pct)
        local ok, dmg = pcall(super, actor, target, baseDamage)
        actor:delMod(xi.mod.SKILLCHAINBONUS, pending.pct)
        if not ok then
            error(dmg)
        end
        return dmg
    end

    return super(actor, target, baseDamage)
end)

-----------------------------------
-- Special / Utility Weaponskill Overrides (No default TP refund)
-----------------------------------
m:addOverride('xi.actions.weaponskills.atonement.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    local ws = catalog.byId[wsID]
    local ranks = talents.getWSRanks(player, player:getMainJob(), wsID)
    applySkillchainVars(player, ws, ranks, 0)

    local capRank = ranks.capstone or 0
    local ftpRank = ranks.ftp or 0
    local wsdBonus = capRank * 12

    if wsdBonus > 0 then
        player:addMod(xi.mod.ALL_WSDMG_ALL_HITS, wsdBonus)
    end

    local ok, tpHits, extraHits, crit, dmg = pcall(super, player, target, wsID, tp, primary, action, taChar)

    if wsdBonus > 0 then
        player:delMod(xi.mod.ALL_WSDMG_ALL_HITS, wsdBonus)
    end

    if not ok then
        error(tpHits)
    end

    if dmg and dmg > 0 and ftpRank > 0 and target:getObjType() == xi.objType.MOB then
        local bonusDmg = math.floor(dmg * ftpRank * 0.15)
        if bonusDmg > 0 then
            target:takeDamage(bonusDmg, player, xi.attackType.BREATH, xi.damageType.ELEMENTAL)
            dmg = dmg + bonusDmg
        end
    end

    return tpHits, extraHits, crit, dmg
end)

local function getUtilityScale(player, wsID)
    local ranks = talents.getWSRanks(player, player:getMainJob(), wsID)
    local ftpRank = ranks.ftp or 0
    local potRank = ranks.potency or 0
    local capRank = ranks.capstone or 0

    local mult = 1.0 + (ftpRank * 0.15) + (potRank * 0.25) + (capRank * 0.30)
    return mult, ranks
end

m:addOverride('xi.actions.weaponskills.spirits_within.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    local mult, ranks = getUtilityScale(player, wsID)
    applySkillchainVars(player, catalog.byId[wsID], ranks, 0)

    local ftpCurve = talents.calcFtpAtRank({ 1.0, 4.0, 8.0 }, ranks.ftp or 0, 4)
    local tpRatio = xi.weaponskills.fTP(tp, ftpCurve)
    local dmg = math.floor(player:getHP() * 0.125 * tpRatio * mult)

    dmg = math.floor(dmg * xi.combat.damage.calculateDamageAdjustment(target, false, false, false, true))
    dmg = math.floor(dmg * xi.spells.damage.calculateAbsorption(target, xi.element.NONE, false, false, false, true))
    dmg = math.floor(dmg * xi.spells.damage.calculateNullification(target, xi.element.NONE, false, false, false, true))
    dmg = math.floor(target:handleSevereDamage(dmg, false))

    if player:getMod(xi.mod.WEAPONSKILL_DAMAGE_BASE + wsID) > 0 then
        dmg = dmg * (100 + player:getMod(xi.mod.WEAPONSKILL_DAMAGE_BASE + wsID)) / 100
    end

    dmg = math.floor(dmg * xi.settings.main.WEAPON_SKILL_POWER)

    local attack =
    {
        ['type']       = xi.attackType.BREATH,
        ['slot']       = xi.slot.MAIN,
        ['weaponType'] = player:getWeaponSkillType(xi.slot.MAIN),
        ['damageType'] = xi.damageType.ELEMENTAL,
    }
    local calcParams =
    {
        wsID            = wsID,
        criticalHit     = false,
        hitsLanded      = 1,
        tpHitsLanded    = dmg > 0 and (player:getOffhandDmg() > 0 and 2 or 1) or 0,
        extraHitsLanded = 0,
        shadowsAbsorbed = 0,
        bonusTP         = 0,
        finalDmg        = dmg,
    }

    dmg = xi.weaponskills.takeWeaponskillDamage(target, player, {}, primary, attack, calcParams, action)
    return calcParams.tpHitsLanded, calcParams.extraHitsLanded, calcParams.criticalHit, dmg
end)

m:addOverride('xi.actions.weaponskills.myrkr.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    local tpHits, extraHits, crit, mp = super(player, target, wsID, tp, primary, action, taChar)
    if player ~= nil and player:isPC() then
        local mult = getUtilityScale(player, wsID)
        mp = math.floor(player:getMaxMP() * 0.20 * mult)
    end
    return tpHits, extraHits, crit, mp
end)

m:addOverride('xi.actions.weaponskills.dagan.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    xi.aftermath.addStatusEffect(player, tp, xi.slot.MAIN, xi.aftermath.type.EMPYREAN)
    local mult = getUtilityScale(player, wsID)
    player:addHP(math.floor(player:getMaxHP() * 0.22 * mult))
    local mp = math.floor(player:getMaxMP() * 0.15 * mult)
    return 0, 0, false, mp
end)

m:addOverride('xi.actions.weaponskills.starlight.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    local mult = getUtilityScale(player, wsID)
    local lvl = math.max(10, player:getSkillLevel(xi.skill.CLUB))
    local mp = math.floor(math.max(10, lvl * 0.11) * 2.0 * mult * xi.settings.main.WEAPON_SKILL_POWER)
    return 1, 0, false, mp
end)

m:addOverride('xi.actions.weaponskills.moonlight.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    local mult = getUtilityScale(player, wsID)
    local lvl = math.max(10, player:getSkillLevel(xi.skill.CLUB))
    local mp = math.floor(math.max(10, lvl * 0.11) * 2.25 * mult * xi.settings.main.WEAPON_SKILL_POWER)
    return 1, 0, false, mp
end)

local function overrideEnergyDrainOrSteal(player, target, wsID, action, baseMult)
    local ws = catalog.byId[wsID]
    local ranks = talents.getWSRanks(player, player:getMainJob(), wsID)
    applySkillchainVars(player, ws, ranks, 0)

    local ftpRank = ranks.ftp or 0
    local wscRank = ranks.wsc_mnd or 0
    local capRank = ranks.capstone or 0

    local skill = math.max(10, player:getSkillLevel(xi.skill.DAGGER))
    local wscWeight = talents.calcWscAtRank(1.0, wscRank, 3)
    local wsc = player:getStat(xi.mod.MND) * wscWeight
    local mult = baseMult + (ftpRank * 0.35) + (capRank * 0.45)
    local mpRestored = math.floor((math.floor(skill * 0.11) + wsc) * mult)

    if target:isUndead() then
        mpRestored = 0
    else
        mpRestored = target:delMP(mpRestored)
        mpRestored = player:addMP(mpRestored)
    end

    action:messageID(target:getID(), xi.msg.basic.SKILL_DRAIN_MP)
    action:param(target:getID(), mpRestored)
    return 1, 0, false, mpRestored
end

m:addOverride('xi.actions.weaponskills.energy_steal.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end
    return overrideEnergyDrainOrSteal(player, target, wsID, action, 1.0)
end)

m:addOverride('xi.actions.weaponskills.energy_drain.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end
    return overrideEnergyDrainOrSteal(player, target, wsID, action, 1.25)
end)

-----------------------------------
-- Player Lifecycle Auto-Sync for Ashita UI
-----------------------------------
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player ~= nil and player:isPC() then
        player:timer(1500, function(playerArg)
            if playerArg ~= nil then
                talents.sendMetaAndSpent(playerArg)
            end
        end)
    end
end)

m:addOverride('xi.player.onPlayerLevelUp', function(player)
    super(player)
    if player ~= nil and player:isPC() then
        talents.sendMetaAndSpent(player)
    end
end)

m:addOverride('xi.player.onPlayerLevelDown', function(player)
    super(player)
    if player ~= nil and player:isPC() then
        talents.sendMetaAndSpent(player)
    end
end)

return m
