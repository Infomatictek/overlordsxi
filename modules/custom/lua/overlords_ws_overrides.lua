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

    -- Tier 1: fTP Scaling (supports combined Tier 1 fTP + utility nodes on #2/#3/#4)
    local ftpRank = ranks.ftp or 0
    local ftpNode = tree and tree.byKey and tree.byKey.ftp
    if ftpNode == nil and tree and tree.nodes then
        for _, n in ipairs(tree.nodes) do
            if n.ftpCurve ~= nil then
                ftpNode = n
                ftpRank = ranks[n.key] or 0
                break
            end
        end
    end
    if ftpRank > 0 then
        if ftpNode and ftpNode.ftpCurve then
            params.ftpMod = applyCustomFtpCurve(ftpNode.ftpCurve, ftpRank, ftpNode.maxRank or 6)
        else
            params.ftpMod = talents.calcFtpAtRank(orig.ftp, ftpRank, (ftpNode and ftpNode.maxRank) or 6)
        end
    end

    -- Generic Fallback Stat WSC / Curves (for weapon #16-#207 until curated)
    for _, stat in ipairs(talents.STAT_ORDER) do
        local r = ranks['wsc_' .. stat] or 0
        if r > 0 and orig.wsc[stat] then
            local node = tree and tree.byKey and tree.byKey['wsc_' .. stat]
            params[stat .. '_wsc'] = talents.calcWscAtRank(orig.wsc[stat], r, (node and node.maxRank) or 7)
        end
    end

    local hitsT1 = ranks.hits_t1 or 0
    if hitsT1 > 0 and orig.numHits >= 2 then
        local hitsNode = tree and tree.byKey and tree.byKey.hits_t1
        local mr = (hitsNode and hitsNode.maxRank) or 7
        local targetHits = orig.numHits
        params.numHits = 1 + math.min(targetHits - 1, math.ceil((targetHits - 1) * (hitsT1 / mr)))
        params.accVaries = addToTriple(params.accVaries, hitsT1 * 5, 0)
        params.atkVaries = addToTriple(params.atkVaries, hitsT1 * 0.03, 1.0)
    end

    local mhRank = ranks.multihit or 0
    if mhRank > 0 then
        params.accVaries = addToTriple(params.accVaries, 10 * mhRank, 0)
        params.atkVaries = addToTriple(params.atkVaries, 0.07 * mhRank, 1.0)
        if mhRank >= 4 then
            params.multiHitfTP = true
        end
        if mhRank >= 5 then
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
        if wsID == 4 then -- Backhand Blow (Tier 1 Col 1 combined fTP + Crit)
            params.critVaries = addToTriple(params.critVaries, critRank * 0.10, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, ({ 4, 7, 10, 14, 17, 20 })[critRank] or 20)
        elseif wsID == 11 then -- Ascetics Fury
            local curves = { { 0.08, 0.12, 0.18 }, { 0.12, 0.18, 0.26 }, { 0.16, 0.25, 0.36 }, { 0.20, 0.32, 0.46 }, { 0.25, 0.40, 0.55 } }
            params.critVaries = curves[critRank] or curves[5]
        elseif wsID == 12 then -- Stringing Pummel
            local curves = { { 0.06, 0.09, 0.12 }, { 0.09, 0.14, 0.18 }, { 0.12, 0.18, 0.25 }, { 0.14, 0.22, 0.32 }, { 0.16, 0.26, 0.38 } }
            params.critVaries = curves[critRank] or curves[5]
        elseif wsID == 14 then -- Victory Smite
            local curves = { { 0.08, 0.12, 0.15 }, { 0.11, 0.16, 0.22 }, { 0.14, 0.21, 0.30 }, { 0.17, 0.27, 0.38 }, { 0.20, 0.32, 0.45 } }
            params.critVaries = curves[critRank] or curves[5]
        else
            local critNode = tree and tree.byKey and tree.byKey.crit
            local mr = (critNode and critNode.maxRank) or 5
            local floorTbl = (mr >= 7) and { 0.20, 0.32, 0.45 } or { 0.16, 0.28, 0.40 }
            params.critVaries = talents.calcScaledTable(orig.critVaries, critRank, floorTbl, mr)
            local critDmgMod = (ws.wsType == 'ranged') and xi.mod.RANGED_CRIT_DMG_INCREASE or xi.mod.CRIT_DMG_INCREASE
            addTempMod(critDmgMod, critRank * (mr >= 7 and 3 or 4))
        end
    end

    local defIgnRank = ranks.def_ignore or 0
    if defIgnRank > 0 then
        if wsID == 3 then -- One Inch Punch (Tier 1 Col 1 combined fTP + DEF Ign)
            local pct = ({ 0.10, 0.18, 0.27, 0.36, 0.45, 0.55 })[defIgnRank] or 0.55
            params.ignoredDefense = { pct, pct, pct }
        elseif wsID == 10 then -- Final Heaven
            local pct = defIgnRank * 0.07
            params.ignoredDefense = { pct, pct, pct }
        else
            local defNode = tree and tree.byKey and tree.byKey.def_ignore
            local mr = (defNode and defNode.maxRank) or 5
            local floorTbl = (mr >= 7) and { 0.25, 0.35, 0.45 } or { 0.20, 0.30, 0.40 }
            params.ignoredDefense = talents.calcScaledTable(orig.ignoredDefense, defIgnRank, floorTbl, mr)
        end
    end

    local atkRank = ranks.atk_mult or 0
    if atkRank > 0 then
        local atkNode = tree and tree.byKey and tree.byKey.atk_mult
        local bonuses = talents.calcAtkScaleAtRank(orig.atkVaries, atkRank, (atkNode and atkNode.maxRank) or 5)
        params.atkVaries = params.atkVaries or { 1.0, 1.0, 1.0 }
        for i = 1, 3 do
            params.atkVaries[i] = params.atkVaries[i] + bonuses[i]
        end
    end

    local accRank = ranks.acc_mult or 0
    if accRank > 0 then
        if wsID == 9 then -- Asuran Fists (Tier 1 Col 3 WSC + True Acc)
            local v = ({ 0.04, 0.08, 0.12, 0.16, 0.19, 0.22, 0.25 })[accRank] or 0.25
            params.str_wsc, params.vit_wsc = v, v
            local curve = { accRank * 9, accRank * 14, accRank * 20 }
            params.accVaries = params.accVaries or { 0, 0, 0 }
            for i = 1, 3 do
                params.accVaries[i] = params.accVaries[i] + curve[i]
            end
        else
            local accNode = tree and tree.byKey and tree.byKey.acc_mult
            local accAdd = talents.calcScaledTable(orig.accVaries, accRank, { 40, 60, 85 }, (accNode and accNode.maxRank) or 5)
            params.accVaries = params.accVaries or { 0, 0, 0 }
            for i = 1, 3 do
                params.accVaries[i] = params.accVaries[i] + accAdd[i]
            end
        end
    end

    local echoRank = ranks.aftermath_echo or 0
    if echoRank > 0 then
        addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, echoRank * 5)
        effectiveTp = math.min(3000, effectiveTp + echoRank * 60)
    end

    local elemRank = ranks.elemental or 0
    if elemRank > 0 then
        addTempMod(xi.mod.MATT, elemRank * 12)
        addTempMod(xi.mod.MACC, elemRank * 12)
    end

    local t1EdgeRank = ranks.t1_edge or 0
    if t1EdgeRank > 0 then
        local arch = tree and tree.archetype or 'heavy'
        if arch == 'magic' then
            addTempMod(xi.mod.MATT, t1EdgeRank * 5)
            addTempMod(xi.mod.MACC, t1EdgeRank * 6)
        elseif arch == 'utility' then
            params.atkVaries = addToTriple(params.atkVaries, t1EdgeRank * 0.05, 1.0)
            params.accVaries = addToTriple(params.accVaries, t1EdgeRank * 5, 0)
            addTempMod(xi.mod.SUBTLE_BLOW, t1EdgeRank * 3)
        else
            params.atkVaries = addToTriple(params.atkVaries, t1EdgeRank * 0.06, 1.0)
            params.accVaries = addToTriple(params.accVaries, t1EdgeRank * 6, 0)
        end
    end

    local keenRank = ranks.keen_instinct or 0
    if keenRank > 0 then
        addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, keenRank * 4)
        params.critVaries = addToTriple(params.critVaries, keenRank * 0.04, 0)
    end

    local focRank = ranks.focused or 0
    if focRank > 0 then
        params.atkVaries = addToTriple(params.atkVaries, focRank * 0.10, 1.0)
        params.accVaries = addToTriple(params.accVaries, focRank * 12, 0)
    end

    local mfRank = ranks.master_force or 0
    if mfRank > 0 then
        addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, mfRank * 5)
        params.atkVaries = addToTriple(params.atkVaries, mfRank * 0.08, 1.0)
    end

    local mpRank = ranks.master_prec or 0
    if mpRank > 0 then
        params.accVaries = addToTriple(params.accVaries, mpRank * 14, 0)
        params.critVaries = addToTriple(params.critVaries, mpRank * 0.05, 0)
    end

    local wsmRank = ranks.ws_mastery or 0
    if wsmRank > 0 then
        addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, wsmRank * 5)
        params.accVaries = addToTriple(params.accVaries, wsmRank * 10, 0)
    end

    -----------------------------------
    -- Hand-to-Hand (#1 - #15) Specific Combat Mechanics
    -----------------------------------
    local hasFootwork = attacker:hasStatusEffect(xi.effect.FOOTWORK)
    local hasFocus    = attacker:hasStatusEffect(xi.effect.FOCUS)
    local hasImpetus  = attacker:hasStatusEffect(xi.effect.IMPETUS)
    local hasDodge    = attacker:hasStatusEffect(xi.effect.DODGE)

    if wsID == 1 then -- Combo
        local rTempo = ranks.combo_tempo or 0
        if rTempo > 0 then
            params.numHits = rTempo >= 4 and 3 or 2
            local wsd = ({ 0, 3, 6, 9, 11, 13, 15 })[rTempo] or 15
            if wsd > 0 then
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, wsd)
            end
        end
        local rEdge = ranks.combo_edge or 0
        if rEdge > 0 then
            local v = rEdge * 0.05
            params.str_wsc, params.dex_wsc = v, v
        end
        local rSb = ranks.combo_sb or 0
        if rSb > 0 then
            params.accVaries = addToTriple(params.accVaries, rSb * 10, 0)
        end
        local rPrec = ranks.combo_prec or 0
        if rPrec > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rPrec * 0.08, 1.0)
            params.accVaries = addToTriple(params.accVaries, rPrec * 6, 0)
        end
        local rFlow = ranks.combo_flow or 0
        if rFlow > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rFlow * 4)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 10)
        end
        local rMast = ranks.combo_mast or 0
        if rMast > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rMast * 0.06, 1.0)
            params.accVaries = addToTriple(params.accVaries, rMast * 10, 0)
        end

    elseif wsID == 2 then -- Shoulder Tackle
        local rChi = ranks.chi_setup or 0
        if rChi > 0 then
            params.numHits = 2
            params.accVaries = addToTriple(params.accVaries, rChi * 5, 0)
        end
        local rBreak = ranks.tackle_break or 0
        if rBreak > 0 then
            params.vit_wsc = ({ 0.12, 0.24, 0.36, 0.48, 0.58, 0.66, 0.75 })[rBreak] or 0.75
        end
        local rForce = ranks.tackle_force or 0
        if rForce > 0 then
            params.accVaries = addToTriple(params.accVaries, rForce * 12, 0)
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.08, 1.0)
        end
        local rMacc = ranks.tackle_macc or 0
        if rMacc > 0 then
            addTempMod(xi.mod.MACC, rMacc * 15)
            addTempMod(xi.mod.ENMITY, -(rMacc * 5))
        end
        local rMast = ranks.tackle_mast or 0
        if rMast > 0 then
            addTempMod(xi.mod.MACC, rMast * 12)
            addTempMod(xi.mod.ENMITY, -(rMast * 8))
        end

    elseif wsID == 3 then -- One Inch Punch
        local rShatter = ranks.inch_shatter or 0
        if rShatter > 0 then
            params.numHits = 2
            params.accVaries = addToTriple(params.accVaries, ({ 6, 12, 18, 24, 30, 35, 40 })[rShatter] or 40, 0)
            local atk = ({ 0, 0.04, 0.08, 0.12, 0.16, 0.20, 0.25 })[rShatter] or 0.25
            if atk > 0 then
                params.atkVaries = addToTriple(params.atkVaries, atk, 1.0)
            end
        end
        local rVit = ranks.inch_vit_chi or 0
        if rVit > 0 then
            params.vit_wsc = ({ 0.12, 0.24, 0.36, 0.48, 0.60, 0.70, 0.80 })[rVit] or 0.80
        end
        local rCd = ranks.inch_cd or 0
        if rCd > 0 then
            addTempMod(xi.mod.MACC, rCd * 10)
        end
        local rFoc = ranks.inch_focus or 0
        if rFoc > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rFoc * 0.12, 1.0)
            params.accVaries = addToTriple(params.accVaries, rFoc * 10, 0)
        end
        local rMast = ranks.inch_mast or 0
        if rMast > 0 then
            addTempMod(xi.mod.MACC, rMast * 12)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            local pct = ({ 0.75, 0.90, 1.00 })[rCap] or 1.00
            params.ignoredDefense = { pct, pct, pct }
        end

    elseif wsID == 4 then -- Backhand Blow
        local rGale = ranks.bh_gale or 0
        if rGale > 0 then
            params.numHits = 2
            params.accVaries = addToTriple(params.accVaries, ({ 5, 10, 15, 20, 24, 27, 30 })[rGale] or 30, 0)
            local atk = ({ 0, 0.03, 0.06, 0.10, 0.13, 0.16, 0.20 })[rGale] or 0.20
            if atk > 0 then
                params.atkVaries = addToTriple(params.atkVaries, atk, 1.0)
            end
        end
        local rFeint = ranks.bh_feint or 0
        if rFeint > 0 then
            local v = ({ 0.10, 0.20, 0.30, 0.40, 0.50, 0.58, 0.65 })[rFeint] or 0.65
            params.str_wsc, params.dex_wsc = v, v
        end
        local rAero = ranks.bh_enaero or 0
        if rAero > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rAero * 0.08, 1.0)
        end
        local rPrec = ranks.bh_prec or 0
        if rPrec > 0 then
            params.accVaries = addToTriple(params.accVaries, rPrec * 12, 0)
        end
        local rRhythm = ranks.bh_rhythm or 0
        if rRhythm > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rRhythm * 5)
        end
        local rWind = ranks.bh_wind or 0
        if rWind > 0 then
            addTempMod(xi.mod.MACC, rWind * 8)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, ({ 10, 18, 26 })[rCap] or 26)
        end
        local rMast = ranks.bh_mast or 0
        if rMast > 0 then
            params.accVaries = addToTriple(params.accVaries, rMast * 10, 0)
            addTempMod(xi.mod.MACC, rMast * 8)
        end

    elseif wsID == 5 then -- Raging Fists
        local rH1 = ranks.rf_hits1 or 0
        local rH2 = ranks.rf_hits2 or 0
        local baseH = rH1 == 0 and 1 or (rH1 >= 5 and 4 or (rH1 >= 3 and 3 or 2))
        params.numHits = math.min(5, baseH + (rH2 >= 1 and 1 or 0))
        if rH1 > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rH1 * 0.04, 1.0)
        end
        if rH2 > 1 then
            params.accVaries = addToTriple(params.accVaries, (rH2 - 1) * 12, 0)
            params.atkVaries = addToTriple(params.atkVaries, (rH2 - 1) * 0.08, 1.0)
        end
        local rStance = ranks.rf_stance or 0
        if rStance > 0 then
            local v = ({ 0.07, 0.13, 0.19, 0.25, 0.32, 0.38, 0.45 })[rStance] or 0.45
            params.str_wsc, params.dex_wsc = v, v
            if hasFocus or hasImpetus then
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, ({ 6, 11, 16, 21, 26, 31, 36 })[rStance] or 36)
            end
        end
        local rForce = ranks.rf_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.09, 1.0)
            params.accVaries = addToTriple(params.accVaries, rForce * 6, 0)
        end
        local rMftp = ranks.rf_mftp or 0
        if rMftp > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, math.min(rMftp, 4) * 6)
            if rMftp >= 5 then
                params.multiHitfTP = true
            end
        end
        local rSav = ranks.rf_savage or 0
        if rSav > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rSav * 5)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rSav * 6)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 10)
            params.atkVaries = addToTriple(params.atkVaries, rCap * 0.10, 1.0)
        end
        local rMast = ranks.rf_mast or 0
        if rMast > 0 then
            params.critVaries = addToTriple(params.critVaries, ({ 0.04, 0.08, 0.12, 0.15, 0.18 })[rMast] or 0.18, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rMast * 5)
        end

    elseif wsID == 6 then -- Spinning Attack
        local rHits = ranks.spin_hits or 0
        if rHits > 0 then
            params.numHits = rHits >= 5 and 3 or 2
            params.atkVaries = addToTriple(params.atkVaries, rHits * 0.04, 1.0)
            params.accVaries = addToTriple(params.accVaries, rHits * 3, 0)
        end
        local packExtras = countSpinningPackExtras(attacker, target, primaryMsg)
        extraCtx.packExtras = packExtras
        local rPack = ranks.spin_pack or 0
        if rPack > 0 then
            params.str_wsc = ({ 0.15, 0.30, 0.45, 0.60, 0.75, 0.88, 1.00 })[rPack] or 1.00
            if packExtras > 0 then
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rPack * 5 * packExtras)
            end
        end
        local rForce = ranks.spin_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.09, 1.0)
            params.accVaries = addToTriple(params.accVaries, rForce * 9, 0)
        end
        local rSwarm = ranks.spin_swarm or 0
        if rSwarm > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rSwarm * 4 + (rSwarm * 3 * packExtras))
        end
        local rMftp = ranks.spin_mftp or 0
        if rMftp > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, math.min(rMftp, 4) * 4)
            if rMftp >= 5 then
                params.multiHitfTP = true
            end
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 10)
            if packExtras >= 1 then
                params.numHits = (params.numHits or 1) + 1
            end
        end
        local rMast = ranks.spin_mast or 0
        if rMast > 0 then
            params.critVaries = addToTriple(params.critVaries, rMast * 0.06, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rMast * 5)
        end

    elseif wsID == 7 then -- Howling Fist
        local rPierce = ranks.hf_pierce or 0
        if rPierce > 0 then
            params.numHits = 2
            params.ignoredDefense = addToTriple(params.ignoredDefense, rPierce * 0.04, 0)
            params.atkVaries = addToTriple(params.atkVaries, rPierce * 0.04, 1.0)
        end
        local rTpWsc = ranks.hf_tp_wsc or 0
        if rTpWsc > 0 then
            params.str_wsc = math.floor(rTpWsc * 30 / 7 + 0.5) / 100
            params.vit_wsc = math.floor(rTpWsc * 60 / 7 + 0.5) / 100
            effectiveTp = math.min(3000, effectiveTp + (({ 75, 140, 210, 280, 350, 425, 500 })[rTpWsc] or 500))
        end
        local rAtk = ranks.hf_atk or 0
        if rAtk > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rAtk * 0.13, 1.0)
        end
        local rPrec = ranks.hf_prec or 0
        if rPrec > 0 then
            params.accVaries = addToTriple(params.accVaries, rPrec * 10, 0)
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rPrec * 4)
        end
        local rRes = ranks.hf_res or 0
        if rRes > 0 then
            params.critVaries = addToTriple(params.critVaries, rRes * 0.05, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rRes * 5)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, ({ 8, 16, 25 })[rCap] or 25)
        end
        local rMast = ranks.hf_mast or 0
        if rMast > 0 then
            params.accVaries = addToTriple(params.accVaries, rMast * 10, 0)
            params.critVaries = addToTriple(params.critVaries, rMast * 0.05, 0)
        end

    elseif wsID == 8 then -- Dragon Kick
        local rHits = ranks.dk_hits or 0
        if rHits > 0 then
            params.numHits = 2
            local v = ({ 0.10, 0.18, 0.26, 0.35, 0.44, 0.52, 0.60 })[rHits] or 0.60
            params.str_wsc, params.vit_wsc = v, v
            params.accVaries = addToTriple(params.accVaries, rHits * 5, 0)
        end
        local rFw = ranks.dk_fw or 0
        if rFw > 0 and hasFootwork then
            params.ftpMod = addToTriple(params.ftpMod, rFw * 0.10, 1.0)
            params.atkVaries = addToTriple(params.atkVaries, rFw * 0.06, 1.0)
        end
        local rForce = ranks.dk_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.10, 1.0)
            params.accVaries = addToTriple(params.accVaries, rForce * 6, 0)
        end
        local rCrit = ranks.dk_crit or 0
        if rCrit > 0 then
            params.critVaries = addToTriple(params.critVaries, rCrit * 0.07, 0)
            params.accVaries = addToTriple(params.accVaries, rCrit * 8, 0)
        end
        local rMom = ranks.dk_mom or 0
        if rMom > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rMom * 5)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rMom * 6)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            if hasFootwork then
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 10)
            end
        end
        local rMast = ranks.dk_mast or 0
        if rMast > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rMast * 5)
            if hasFootwork then
                effectiveTp = math.min(3000, effectiveTp + rMast * 100)
            end
        end

    elseif wsID == 9 then -- Asuran Fists
        local rH1 = ranks.af_hits1 or 0
        local rH2 = ranks.af_hits2 or 0
        local h1 = rH1 == 0 and 1 or (({ 2, 2, 3, 3, 4, 4, 5 })[rH1] or 5)
        local h2Add = math.min(rH2, 3)
        params.numHits = math.min(8, h1 + h2Add) -- 1 -> 8h
        if rH1 > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rH1 * 0.03, 1.0)
        end
        if rH2 > 3 then
            params.atkVaries = addToTriple(params.atkVaries, (rH2 - 3) * 0.10, 1.0)
        end
        local rBar = ranks.af_barrage or 0
        if rBar > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rBar * 0.06, 1.0)
            params.accVaries = addToTriple(params.accVaries, rBar * 10, 0)
        end
        local rMftp = ranks.af_mftp or 0
        if rMftp > 0 then
            params.atkVaries = addToTriple(params.atkVaries, math.min(rMftp, 4) * 0.06, 1.0)
            if rMftp >= 5 then
                params.multiHitfTP = true
            end
        end
        local rFoc = ranks.af_focus or 0
        if rFoc > 0 then
            if hasFocus then
                params.critVaries = addToTriple(params.critVaries, rFoc * 0.06, 0)
            end
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rFoc * 5)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.ftpMod = addToTriple(params.ftpMod, ({ 0.05, 0.10, 0.16 })[rCap] or 0.16, 1.0)
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 8)
        end
        local rMast = ranks.af_mast or 0
        if rMast > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rMast * 0.05, 1.0)
            params.accVaries = addToTriple(params.accVaries, rMast * 12, 0)
        end

    elseif wsID == 10 then -- Final Heaven
        local rHits = ranks.fh_hits or 0
        if rHits > 0 then
            params.numHits = 2
            params.vit_wsc = ({ 0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.85 })[rHits] or 0.85
            params.accVaries = addToTriple(params.accVaries, rHits * 5, 0)
        end
        local rSb = ranks.fh_sb or 0
        if rSb > 0 then
            addTempMod(xi.mod.SUBTLE_BLOW, ({ 6, 12, 18, 24, 30, 35, 40 })[rSb] or 40)
            addTempMod(xi.mod.ENMITY, -(({ 9, 18, 27, 36, 44, 52, 60 })[rSb] or 60))
        end
        local rSanc = ranks.fh_sanc or 0
        if rSanc > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rSanc * 0.08, 1.0)
            params.accVaries = addToTriple(params.accVaries, rSanc * 10, 0)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, ({ 10, 18, 26 })[rCap] or 26)
            extraCtx.extraScBonus = extraCtx.extraScBonus + rCap * 8
        end
        local rMast = ranks.fh_mast or 0
        if rMast > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rMast * 0.09, 1.0)
            params.accVaries = addToTriple(params.accVaries, rMast * 10, 0)
        end

    elseif wsID == 11 then -- Ascetics Fury
        local rHits = ranks.afury_hits or 0
        if rHits > 0 then
            params.numHits = 2
            local v = ({ 0.10, 0.20, 0.30, 0.40, 0.50, 0.58, 0.65 })[rHits] or 0.65
            params.str_wsc, params.vit_wsc = v, v
            params.accVaries = addToTriple(params.accVaries, rHits * 5, 0)
        end
        local rAtk = ranks.afury_atk or 0
        if rAtk > 0 then
            params.atkVaries = addToTriple(params.atkVaries, ({ 0.20, 0.40, 0.62, 0.85, 1.08, 1.30, 1.50 })[rAtk] or 1.50, 1.0)
            params.critVaries = addToTriple(params.critVaries, ({ 0.03, 0.06, 0.09, 0.12, 0.15, 0.18, 0.20 })[rAtk] or 0.20, 0)
        end
        local rPierce = ranks.afury_pierce or 0
        if rPierce > 0 then
            params.ignoredDefense = addToTriple(params.ignoredDefense, rPierce * 0.06, 0)
            params.accVaries = addToTriple(params.accVaries, rPierce * 10, 0)
        end
        local rCdmg = ranks.afury_critdmg or 0
        if rCdmg > 0 then
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rCdmg * 7)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            params.critVaries = addToTriple(params.critVaries, 0.15, 0)
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 8)
        end
        local rMast = ranks.afury_mast or 0
        if rMast > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rMast * 0.10, 1.0)
            params.accVaries = addToTriple(params.accVaries, rMast * 12, 0)
        end

    elseif wsID == 12 then -- Stringing Pummel
        local rH1 = ranks.sp_hits1 or 0
        local rH2 = ranks.sp_hits2 or 0
        local h1 = rH1 == 0 and 1 or (rH1 >= 5 and 4 or (rH1 >= 3 and 3 or 2))
        params.numHits = math.min(6, h1 + math.min(rH2, 2)) -- 1 -> 6h
        if rH1 > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rH1 * 0.03, 1.0)
        end
        if rH2 > 2 then
            params.atkVaries = addToTriple(params.atkVaries, (rH2 - 2) * 0.10, 1.0)
        end
        local rCritWsc = ranks.sp_crit_wsc or 0
        if rCritWsc > 0 then
            local v = ({ 0.06, 0.12, 0.18, 0.24, 0.30, 0.35, 0.40 })[rCritWsc] or 0.40
            params.str_wsc, params.vit_wsc = v, v
            params.critVaries = addToTriple(params.critVaries, ({ 0.03, 0.05, 0.08, 0.10, 0.13, 0.15, 0.18 })[rCritWsc] or 0.18, 0)
        end
        local rCdmg = ranks.sp_critdmg or 0
        if rCdmg > 0 then
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rCdmg * 7)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, ({ 8, 15, 22 })[rCap] or 22)
        end
        local rMast = ranks.sp_mast or 0
        if rMast > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rMast * 0.08, 1.0)
            params.accVaries = addToTriple(params.accVaries, rMast * 10, 0)
        end

    elseif wsID == 13 then -- Tornado Kick
        local rHits = ranks.tk_hits or 0
        if rHits > 0 then
            params.numHits = rHits >= 5 and 3 or 2
            local v = ({ 0.08, 0.15, 0.22, 0.29, 0.36, 0.43, 0.50 })[rHits] or 0.50
            params.str_wsc, params.vit_wsc = v, v
            params.accVaries = addToTriple(params.accVaries, rHits * 4, 0)
        end
        local rFw = ranks.tk_fw or 0
        if rFw > 0 and hasFootwork then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, ({ 7, 14, 21, 28, 35, 42, 50 })[rFw] or 50)
            params.atkVaries = addToTriple(params.atkVaries, rFw * 0.06, 1.0)
        end
        local rForce = ranks.tk_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.09, 1.0)
            params.accVaries = addToTriple(params.accVaries, rForce * 9, 0)
        end
        local rEdge = ranks.tk_edge or 0
        if rEdge > 0 then
            params.critVaries = addToTriple(params.critVaries, rEdge * 0.05, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rEdge * 5)
        end
        local rTp = ranks.tk_tp or 0
        if rTp > 0 and (hasFootwork or hasDodge) then
            effectiveTp = math.min(3000, effectiveTp + rTp * 90)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 8)
        end
        local rMast = ranks.tk_mast or 0
        if rMast > 0 then
            params.critVaries = addToTriple(params.critVaries, rMast * 0.06, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rMast * 5)
        end

    elseif wsID == 14 then -- Victory Smite
        local rHits = ranks.vs_hits or 0
        if rHits > 0 then
            params.numHits = rHits >= 5 and 4 or (rHits >= 3 and 3 or 2)
            params.atkVaries = addToTriple(params.atkVaries, rHits * 0.04, 1.0)
        end
        local rStrCrit = ranks.vs_str_crit or 0
        if rStrCrit > 0 then
            params.str_wsc = ({ 0.15, 0.28, 0.42, 0.55, 0.68, 0.80, 0.90 })[rStrCrit] or 0.90
            params.critVaries = addToTriple(params.critVaries, ({ 0.03, 0.05, 0.08, 0.10, 0.13, 0.15, 0.18 })[rStrCrit] or 0.18, 0)
        end
        local rForce = ranks.vs_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.09, 1.0)
            params.accVaries = addToTriple(params.accVaries, rForce * 9, 0)
        end
        local rCdmg = ranks.vs_critdmg or 0
        if rCdmg > 0 then
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rCdmg * 7)
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            params.multiHitfTP = true
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, ({ 8, 15, 22 })[rCap] or 22)
        end
        local rMast = ranks.vs_mast or 0
        if rMast > 0 then
            if hasImpetus or hasFocus then
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rMast * 8)
            end
            params.accVaries = addToTriple(params.accVaries, rMast * 12, 0)
        end

    elseif wsID == 15 then -- Shijin Spiral
        local rHits = ranks.ss_hits or 0
        if rHits > 0 then
            params.numHits = ({ 2, 2, 3, 3, 4, 4, 5 })[rHits] or 5
            params.atkVaries = addToTriple(params.atkVaries, rHits * 0.04, 1.0)
        end
        local rDexPrec = ranks.ss_dex_prec or 0
        if rDexPrec > 0 then
            params.dex_wsc = ({ 0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.85 })[rDexPrec] or 0.85
            params.accVaries = addToTriple(params.accVaries, ({ 12, 24, 36, 48, 60, 72, 85 })[rDexPrec] or 85, 0)
        end
        local rForce = ranks.ss_force or 0
        if rForce > 0 then
            params.atkVaries = addToTriple(params.atkVaries, rForce * 0.08, 1.0)
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rForce * 4)
        end
        local rStance = ranks.ss_stance or 0
        if rStance > 0 and (hasImpetus or hasFocus) then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rStance * 6)
        end
        local rMftp = ranks.ss_mftp or 0
        if rMftp > 0 then
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, math.min(rMftp, 4) * 6)
            if rMftp >= 5 then
                params.multiHitfTP = true
            end
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            extraCtx.extraScBonus = extraCtx.extraScBonus + rCap * 10
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, rCap * 8)
        end
        local rMast = ranks.ss_mast or 0
        if rMast > 0 then
            params.critVaries = addToTriple(params.critVaries, rMast * 0.06, 0)
            addTempMod(xi.mod.CRIT_DMG_INCREASE, rMast * 5)
        end

    else
        -- Generic 4-Tier Capstone (#16-#207 fallback, 3 ranks)
        local capRank = ranks.capstone or 0
        if capRank > 0 then
            local r = math.min(capRank, 3)
            local arch = tree and tree.archetype or 'heavy'
            if arch == 'magic' then
                local m = ({ 20, 35, 50 })[r]
                addTempMod(xi.mod.MATT, m)
                addTempMod(xi.mod.MACC, m)
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, r * 10)
            elseif arch == 'crit' then
                params.critVaries = addToTriple(params.critVaries, ({ 0.08, 0.14, 0.20 })[r], 0)
                local critDmgMod = (ws.wsType == 'ranged') and xi.mod.RANGED_CRIT_DMG_INCREASE or xi.mod.CRIT_DMG_INCREASE
                addTempMod(critDmgMod, ({ 10, 18, 26 })[r])
                params.ftpMod = addToTriple(params.ftpMod, ({ 0.3, 0.7, 1.0 })[r], 1.0)
            elseif arch == 'multihit' then
                params.multiHitfTP = true
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, ({ 10, 18, 28 })[r])
            elseif arch == 'utility' then
                addTempMod(xi.mod.SUBTLE_BLOW, r * 10)
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, r * 12)
            else
                params.atkVaries = addToTriple(params.atkVaries, r * 0.15, 1.0)
                params.ignoredDefense = addToTriple(params.ignoredDefense, ({ 0.10, 0.18, 0.25 })[r], 0)
                addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, r * 8)
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
        local rTempo = ranks.combo_tempo or 0
        if rTempo > 0 then
            local jaHaste = ({ 300, 500, 700, 900, 1100, 1300, 1500 })[rTempo] or 1500
            table.insert(mods, { xi.mod.HASTE_ABILITY, jaHaste })
        end
        local rSb = ranks.combo_sb or 0
        if rSb > 0 then
            table.insert(mods, { xi.mod.SUBTLE_BLOW, rSb * 6 })
        end
        local rDa = ranks.combo_da or 0
        if rDa > 0 then
            table.insert(mods, { xi.mod.DOUBLE_ATTACK, rDa * 8 })
        end
        local rCap = ranks.capstone or 0
        if rCap > 0 then
            table.insert(mods, { xi.mod.TRIPLE_ATTACK, ({ 8, 14, 20 })[rCap] or 20 })
        end
        if #mods > 0 then
            applyTimedBuffMods(attacker, xi.effect.SUBTLE_BLOW_PLUS, 12, mods)
        end
        local rEdge = ranks.combo_edge or 0
        local rFlow = ranks.combo_flow or 0
        if rEdge > 0 or rFlow > 0 then
            if rEdge > 0 then
                attacker:setLocalVar('OX_NEXT_WS_WSD', ({ 4, 8, 12, 16, 19, 22, 25 })[rEdge] or 25)
            end
            if rFlow > 0 then
                attacker:setLocalVar('OX_NEXT_WS_TP', rFlow * 60)
            end
            attacker:setLocalVar('OX_NEXT_WS_EXP', os.time() + 10)
        end

    elseif wsID == 2 then -- Shoulder Tackle
        local rChi = ranks.chi_setup or 0
        local rCap = ranks.capstone or 0
        local chiFromT1 = rChi > 0 and (({ 12, 22, 32, 42, 50, 58, 65 })[rChi] or 65) or 0
        local chiFromCap = rCap > 0 and (({ 20, 35, 50 })[rCap] or 50) or 0
        local chiPct = chiFromT1 + chiFromCap
        if chiPct > 0 then
            attacker:setLocalVar('OX_CHIBLAST_PCT', chiPct)
        end
        if rChi > 0 then
            attacker:setLocalVar('OX_CHIBLAST_CD_TRIM', ({ 6, 10, 14, 18, 22, 26, 30 })[rChi] or 30)
        end
        if totalDmg > 0 and target ~= nil and target:isAlive() then
            local rBreak = ranks.tackle_break or 0
            local rDrain = ranks.tackle_drain or 0
            local atkDnBase = rBreak > 0 and (({ 5, 8, 11, 13, 15, 18, 20 })[rBreak] or 20) or 0
            local atkDnTotal = atkDnBase + (rDrain * 2)
            if atkDnTotal > 0 then
                target:delStatusEffectSilent(xi.effect.ATTACK_DOWN)
                target:addStatusEffect(xi.effect.ATTACK_DOWN, { power = atkDnTotal, duration = 45, origin = attacker })
            end
            if rDrain > 0 then
                target:delTP(({ 80, 150, 220, 290, 360 })[rDrain] or 360)
            end
            local rDispel = ranks.tackle_dispel or 0
            if rDispel > 0 then
                local count = rDispel >= 5 and 3 or (rDispel >= 3 and 2 or 1)
                for _ = 1, count do
                    target:dispelStatusEffect()
                end
                local deb = rDispel * 10
                target:delStatusEffectSilent(xi.effect.ACCURACY_DOWN)
                target:addStatusEffect(xi.effect.ACCURACY_DOWN, { power = deb, duration = 45, origin = attacker })
                target:delStatusEffectSilent(xi.effect.EVASION_DOWN)
                target:addStatusEffect(xi.effect.EVASION_DOWN, { power = deb, duration = 45, origin = attacker })
            end
            if rCap > 0 then
                target:delStatusEffectSilent(xi.effect.SLOW)
                target:addStatusEffect(xi.effect.SLOW, { power = ({ 1500, 2000, 2500 })[rCap] or 2500, duration = 45, origin = attacker })
                target:delStatusEffectSilent(xi.effect.PARALYSIS)
                target:addStatusEffect(xi.effect.PARALYSIS, { power = ({ 15, 20, 25 })[rCap] or 25, duration = 45, origin = attacker })
            end
        end

    elseif wsID == 3 then -- One Inch Punch
        local rChi  = ranks.inch_vit_chi or 0
        local rMast = ranks.inch_mast or 0
        local chiFromT1 = rChi > 0 and (({ 12, 22, 32, 42, 54, 65, 75 })[rChi] or 75) or 0
        local chiPct = chiFromT1 + (rMast * 8)
        if chiPct > 0 then
            attacker:setLocalVar('OX_CHIBLAST_PCT', chiPct)
        end
        local rCd = ranks.inch_cd or 0
        if rCd > 0 then
            attacker:setLocalVar('OX_CHIBLAST_CD_TRIM', rCd * 8)
        end
        local rSkin = ranks.inch_skin or 0
        if rSkin > 0 then
            attacker:delStatusEffectSilent(xi.effect.STONESKIN)
            attacker:addStatusEffect(xi.effect.STONESKIN, { power = ({ 100, 200, 300, 400, 520 })[rSkin] or 520, duration = 120, origin = attacker, tier = 3 })
        end
        if totalDmg > 0 and target ~= nil and target:isAlive() then
            local rShatter = ranks.inch_shatter or 0
            if rShatter > 0 then
                target:delStatusEffectSilent(xi.effect.DEFENSE_DOWN)
                target:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = ({ 8, 12, 16, 20, 24, 27, 30 })[rShatter] or 30, duration = 60, origin = attacker })
            end
            local rPlague = ranks.inch_plague or 0
            if rPlague > 0 then
                target:delStatusEffectSilent(xi.effect.PLAGUE)
                target:addStatusEffect(xi.effect.PLAGUE, { power = rPlague * 2, duration = 45, origin = attacker })
                totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * rPlague * 0.08, xi.damageType.LIGHT)
            end
            local rCap = ranks.capstone or 0
            if rCap > 0 then
                target:delStatusEffectSilent(xi.effect.MAGIC_DEF_DOWN)
                target:addStatusEffect(xi.effect.MAGIC_DEF_DOWN, { power = ({ 10, 15, 20 })[rCap] or 20, duration = 60, origin = attacker })
            end
        end

    elseif wsID == 4 then -- Backhand Blow
        local critMods = {}
        local rGale = ranks.bh_gale or 0
        if rGale > 0 then
            table.insert(critMods, { xi.mod.CRITHITRATE, ({ 4, 7, 10, 13, 15, 18, 20 })[rGale] or 20 })
        end
        local rRhythm = ranks.bh_rhythm or 0
        local rCap = ranks.capstone or 0
        local extraCritDmg = (rRhythm * 4) + (rCap > 0 and (({ 8, 15, 22 })[rCap] or 22) or 0)
        if extraCritDmg > 0 then
            table.insert(critMods, { xi.mod.CRIT_DMG_INCREASE, extraCritDmg })
        end
        if #critMods > 0 then
            applyTimedBuffMods(attacker, xi.effect.POTENCY, 12, critMods)
        end
        local rAero = ranks.bh_enaero or 0
        if rAero > 0 then
            attacker:delStatusEffectSilent(xi.effect.ENAERO)
            attacker:addStatusEffect(xi.effect.ENAERO, { power = rAero * 10, duration = 12, origin = attacker })
        end
        if totalDmg > 0 and target ~= nil and target:isAlive() then
            local rFeint = ranks.bh_feint or 0
            local rPrec  = ranks.bh_prec or 0
            local evaDn  = (rFeint > 0 and (({ 8, 14, 20, 26, 31, 36, 40 })[rFeint] or 40) or 0) + (rPrec * 4)
            if evaDn > 0 then
                target:delStatusEffectSilent(xi.effect.EVASION_DOWN)
                target:addStatusEffect(xi.effect.EVASION_DOWN, { power = evaDn, duration = 45, origin = attacker })
            end
            local rWind = ranks.bh_wind or 0
            if rWind > 0 then
                totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * rWind * 0.10, xi.damageType.WIND)
            end
        end
    end

    -----------------------------------
    -- Elemental Follow-Up Hits on Damage H2H WSs (Zero Buffs/Debuffs)
    -----------------------------------
    if totalDmg > 0 and target ~= nil and target:isAlive() then
        if wsID == 6 and (ranks.spin_fire or 0) > 0 then
            local mult = (ranks.spin_fire * 0.16) * (1 + 0.25 * (extraCtx and extraCtx.packExtras or 0))
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * mult, xi.damageType.FIRE)
        elseif wsID == 7 and (ranks.hf_sonic or 0) > 0 then
            local mult = ranks.hf_sonic * 0.08
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * mult, xi.damageType.WIND)
        elseif wsID == 8 and (ranks.dk_flame or 0) > 0 then
            local mult = ranks.dk_flame * 0.07
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * mult, xi.damageType.FIRE)
        elseif wsID == 10 and (ranks.fh_light or 0) > 0 then
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * ranks.fh_light * 0.08, xi.damageType.LIGHT)
        elseif wsID == 13 and (ranks.tk_wind or 0) > 0 then
            local mult = ({ 0.07, 0.14, 0.21, 0.28, 0.36 })[ranks.tk_wind] or 0.36
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * mult, xi.damageType.WIND)
        elseif wsID == 15 and (ranks.ss_wind or 0) > 0 then
            totalDmg = totalDmg + dealFollowUpElementalHit(attacker, target, totalDmg * ranks.ss_wind * 0.06, xi.damageType.WIND)
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

    local r = math.min(ctx.debuffRank, 7)
    local durMult = 1 + (({ 0.15, 0.30, 0.45, 0.65, 0.85, 1.10, 1.35 })[r] or 0)
    local maccAdd = ({ 18, 36, 54, 72, 90, 110, 125 })[r] or 0
    local newDur  = math.floor((duration or 0) * durMult)
    local newPwr  = power

    if not ctx.isBinary and type(power) == 'number' and power > 0 then
        local potMult = 1 + (({ 0.12, 0.25, 0.40, 0.55, 0.70, 0.85, 1.00 })[r] or 0)
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
    local wsdBonus = capRank * 10

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
        local bonusDmg = math.floor(dmg * ftpRank * 0.10)
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

    local mult = 1.0 + (ftpRank * 0.10) + (potRank * 0.15) + (capRank * 0.18)
    return mult, ranks
end

m:addOverride('xi.actions.weaponskills.spirits_within.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    local mult, ranks = getUtilityScale(player, wsID)
    applySkillchainVars(player, catalog.byId[wsID], ranks, 0)

    local ftpCurve = talents.calcFtpAtRank({ 1.0, 4.0, 8.0 }, ranks.ftp or 0, 6)
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
    local wscWeight = talents.calcWscAtRank(1.0, wscRank, 7)
    local wsc = player:getStat(xi.mod.MND) * wscWeight
    local mult = baseMult + (ftpRank * 0.22) + (capRank * 0.30)
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
