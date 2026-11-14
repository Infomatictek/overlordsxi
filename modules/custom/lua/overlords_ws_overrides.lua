-----------------------------------
-- OverlordsXI Weaponskill Overrides
-- Normalizes base PC weaponskills to fTP 1.0 and 0 WSC, applies
-- per-weaponskill talent ranks dynamically, executes unique signature
-- and skillchain traits, and syncs Ashita UI on login/level.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_ws_catalog')
require('modules/custom/lua/overlords_ws_talents')
require('scripts/combat/skillchain')
require('scripts/globals/player')
require('scripts/globals/weaponskills')
-----------------------------------
local m = Module:new('overlords_ws_overrides')

local catalog = xi.overlords.wsCatalog
local talents = xi.overlords.wsTalents

local activeWsContext = {}
local pendingScBonus  = {}

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

local function applySkillchainVars(attacker, ws, ranks)
    if attacker == nil or ws == nil then
        return
    end

    local scRank = ranks and ranks.skillchain or 0
    local scData = scRank > 0 and talents.getSkillchainAtRank(ws, scRank) or nil
    if scData ~= nil then
        attacker:setLocalVar('OX_WS_SC1', scData.sc1 or 0)
        attacker:setLocalVar('OX_WS_SC2', scData.sc2 or 0)
        attacker:setLocalVar('OX_WS_SC3', scData.sc3 or 0)
        if scData.scBonus and scData.scBonus > 0 then
            pendingScBonus[attacker:getID()] = { pct = scData.scBonus, expiresAt = os.time() + 2 }
        else
            pendingScBonus[attacker:getID()] = nil
        end
    else
        attacker:setLocalVar('OX_WS_SC1', 0)
        attacker:setLocalVar('OX_WS_SC2', 0)
        attacker:setLocalVar('OX_WS_SC3', 0)
        pendingScBonus[attacker:getID()] = nil
    end
end

local function applyWSNormalizationAndTalents(attacker, wsID, wsParams)
    local ws = catalog.byId[wsID]
    local params = copyParams(wsParams)

    -- Always normalize base WS to fTP 1.0 and 0 WSC for PCs
    params.ftpMod = { 1.0, 1.0, 1.0 }
    params.str_wsc = 0
    params.dex_wsc = 0
    params.vit_wsc = 0
    params.agi_wsc = 0
    params.int_wsc = 0
    params.mnd_wsc = 0
    params.chr_wsc = 0

    -- Strip original TP-scaling bonus curves unless earned via WS talents
    params.critVaries = nil
    params.accVaries = nil
    params.atkVaries = nil
    params.ignoredDefense = nil
    params.multiHitfTP = nil

    if ws == nil then
        attacker:setLocalVar('OX_WS_SC1', 0)
        attacker:setLocalVar('OX_WS_SC2', 0)
        attacker:setLocalVar('OX_WS_SC3', 0)
        pendingScBonus[attacker:getID()] = nil
        return params, {}, nil
    end

    local tempMods = {}
    local function addTempMod(modId, amount)
        if amount ~= 0 then
            table.insert(tempMods, { mod = modId, amount = amount })
            attacker:addMod(modId, amount)
        end
    end

    local tree = talents.getTreeForWS(wsID)
    local ranks = talents.getWSRanks(attacker, attacker:getMainJob(), wsID)
    local orig = ws.orig

    -- Tier 1: fTP Scaling
    local ftpRank = ranks.ftp or 0
    if ftpRank > 0 then
        params.ftpMod = talents.calcFtpAtRank(orig.ftp, ftpRank)
    end

    -- Tier 1: Stat WSC
    for _, stat in ipairs(talents.STAT_ORDER) do
        local r = ranks['wsc_' .. stat] or 0
        if r > 0 and orig.wsc[stat] then
            params[stat .. '_wsc'] = talents.calcWscAtRank(orig.wsc[stat], r)
        end
    end

    -- Tier 2: Unique Signature Traits
    local debRank = ranks.debuff or 0
    if debRank > 0 then
        if orig.debuff and orig.debuff.binary then
            local atkAdd = ({ 0.10, 0.20, 0.35 })[debRank] or 0
            params.atkVaries = addToTriple(params.atkVaries, atkAdd, 1.0)
        end
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

    local aoeRank = ranks.aoe_cleave or 0
    if aoeRank > 0 then
        local atkAdd = ({ 0.10, 0.20, 0.35 })[aoeRank] or 0
        local accAdd = ({ 15, 30, 50 })[aoeRank] or 0
        local wsdAdd = ({ 8, 16, 25 })[aoeRank] or 0
        params.atkVaries = addToTriple(params.atkVaries, atkAdd, 1.0)
        params.accVaries = addToTriple(params.accVaries, accAdd, 0)
        addTempMod(xi.mod.MACC, accAdd)
        addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, wsdAdd)
    end

    local enmRank = ranks.enmity_ctrl or 0
    if enmRank > 0 then
        if orig.enmity == 'low' then
            local enmRed = ({ 30, 60, 90 })[enmRank] or 0
            local wsdAdd = ({ 10, 20, 35 })[enmRank] or 0
            addTempMod(xi.mod.ENMITY, -enmRed)
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, wsdAdd)
        elseif orig.enmity == 'high' then
            local enmMult = ({ 0.50, 1.00, 1.75 })[enmRank] or 0
            params.enmityMult = (params.enmityMult or 1) + enmMult
        end
    end

    local echoRank = ranks.aftermath_echo or 0
    if echoRank > 0 then
        local wsdAdd = ({ 8, 16, 25 })[echoRank] or 0
        local tpAdd  = ({ 50, 100, 175 })[echoRank] or 0
        addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, wsdAdd)
        params.bonusTP = (params.bonusTP or 0) + tpAdd
    end

    -- Tier 2: Combat Curves
    local mhRank = ranks.multihit or 0
    if mhRank > 0 then
        params.accVaries = addToTriple(params.accVaries, 15 * mhRank, 0)
        params.atkVaries = addToTriple(params.atkVaries, 0.10 * mhRank, 1.0)
        if mhRank >= 2 then
            params.multiHitfTP = true
        end
        if mhRank >= 3 then
            params.numHits = (params.numHits or 1) + 1
        end
    end

    local critRank = ranks.crit or 0
    if critRank > 0 then
        params.critVaries = talents.calcScaledTable(orig.critVaries, critRank, { 0.10, 0.15, 0.20 })
        local critDmgMod = (ws.wsType == 'ranged') and xi.mod.RANGED_CRIT_DMG_INCREASE or xi.mod.CRIT_DMG_INCREASE
        addTempMod(critDmgMod, critRank * 5)
    end

    local defIgnRank = ranks.def_ignore or 0
    if defIgnRank > 0 then
        params.ignoredDefense = talents.calcScaledTable(orig.ignoredDefense, defIgnRank, { 0.08, 0.12, 0.16 })
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
        local accAdd = talents.calcScaledTable(orig.accVaries, accRank, { 20, 25, 30 })
        params.accVaries = params.accVaries or { 0, 0, 0 }
        for i = 1, 3 do
            params.accVaries[i] = params.accVaries[i] + accAdd[i]
        end
    end

    local elemRank = ranks.elemental or 0
    if elemRank > 0 then
        local elemBonus = elemRank == 3 and 50 or (elemRank * 15)
        addTempMod(xi.mod.MATT, elemBonus)
        addTempMod(xi.mod.MACC, elemBonus)
    end

    local focRank = ranks.focused or 0
    if focRank > 0 then
        local atkPct = focRank == 3 and 0.40 or (focRank * 0.12)
        local accVal = focRank == 3 and 50 or (focRank * 15)
        params.atkVaries = addToTriple(params.atkVaries, atkPct, 1.0)
        params.accVaries = addToTriple(params.accVaries, accVal, 0)
    end

    -- Tier 3: TP Momentum & Skillchain Traits
    local tpRank = ranks.tp_refund or 0
    if tpRank > 0 then
        local refund = tpRank == 3 and 350 or (tpRank * 100)
        params.bonusTP = (params.bonusTP or 0) + refund
    end

    applySkillchainVars(attacker, ws, ranks)

    -- Tier 3: Archetype Capstone
    if (ranks.capstone or 0) > 0 then
        local arch = tree and tree.archetype or 'heavy'
        if arch == 'magic' then
            addTempMod(xi.mod.MATT, 30)
            addTempMod(xi.mod.MACC, 30)
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, 25)
        elseif arch == 'crit' then
            params.critVaries = addToTriple(params.critVaries, 0.15, 0)
            local critDmgMod = (ws.wsType == 'ranged') and xi.mod.RANGED_CRIT_DMG_INCREASE or xi.mod.CRIT_DMG_INCREASE
            addTempMod(critDmgMod, 20)
            params.ftpMod = addToTriple(params.ftpMod, 1.0, 1.0)
        elseif arch == 'multihit' then
            params.multiHitfTP = true
            params.numHits = (params.numHits or 1) + 1
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, 10)
        else
            params.atkVaries = addToTriple(params.atkVaries, 0.35, 1.0)
            params.ignoredDefense = addToTriple(params.ignoredDefense, 0.25, 0)
            addTempMod(xi.mod.ALL_WSDMG_ALL_HITS, 15)
        end
    end

    return params, tempMods, ranks
end

local function cleanupTempMods(attacker, tempMods)
    for i = #tempMods, 1, -1 do
        attacker:delMod(tempMods[i].mod, tempMods[i].amount)
    end
end

local function applyPostDamageTraits(attacker, target, wsID, ranks, dmg)
    if attacker == nil or ranks == nil or (dmg or 0) <= 0 then
        return
    end

    local siphonRank = ranks.siphon or 0
    if siphonRank > 0 and (target == nil or not target:isUndead()) then
        local pct = ({ 0.15, 0.30, 0.50 })[siphonRank] or 0
        local extraHp = math.floor(dmg * pct)
        local drainedMp = math.floor(dmg * pct)
        if extraHp > 0 then
            attacker:addHP(extraHp)
        end
        if drainedMp > 0 then
            attacker:addMP(drainedMp)
        end
    end

    local manaRank = ranks.mana_leech or 0
    local baseMpRatio = MP_DRAIN_BASE_RATIO[wsID]
    if manaRank > 0 and baseMpRatio ~= nil then
        local mpBoost = ({ 0.25, 0.50, 1.00 })[manaRank] or 0
        local hpShare = ({ 0.25, 0.50, 0.75 })[manaRank] or 0
        local extraMp = math.floor(dmg * baseMpRatio * mpBoost)
        local totalMp = math.floor(dmg * baseMpRatio * (1 + mpBoost))
        if extraMp > 0 then
            attacker:addMP(extraMp)
        end
        local hpHeal = math.floor(totalMp * hpShare)
        if hpHeal > 0 then
            attacker:addHP(hpHeal)
        end
    end

    local ws = catalog.byId[wsID]
    local enmRank = ranks.enmity_ctrl or 0
    if enmRank > 0 and ws ~= nil and ws.orig.enmity == 'high' then
        local healPct = ({ 0.15, 0.30, 0.50 })[enmRank] or 0
        local hpHeal = math.floor(dmg * healPct)
        if hpHeal > 0 then
            attacker:addHP(hpHeal)
        end
    end
end

local function invokeWithNormalizedParams(superFn, attacker, target, wsID, wsParams, tp, action, primaryMsg, taChar)
    if attacker == nil or not attacker:isPC() then
        return superFn(attacker, target, wsID, wsParams, tp, action, primaryMsg, taChar)
    end

    local modParams, tempMods, ranks = applyWSNormalizationAndTalents(attacker, wsID, wsParams)
    local ok, r1, r2, r3, r4, r5 = pcall(superFn, attacker, target, wsID, modParams, tp, action, primaryMsg, taChar)
    cleanupTempMods(attacker, tempMods)

    if not ok then
        error(r1)
    end

    applyPostDamageTraits(attacker, target, wsID, ranks, r1)
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

m:addOverride('xi.weaponskills.handleWeaponskillEffect', function(actor, target, effectId, actionElement, damage, power, duration)
    if actor == nil or not actor:isPC() then
        return super(actor, target, effectId, actionElement, damage, power, duration)
    end

    local ctx = activeWsContext[actor:getID()]
    if ctx == nil or os.time() > ctx.expiresAt or (ctx.debuffRank or 0) <= 0 then
        return super(actor, target, effectId, actionElement, damage, power, duration)
    end

    local r = ctx.debuffRank
    local durMult = 1 + (({ 0.35, 0.70, 1.20 })[r] or 0)
    local maccAdd = ({ 25, 50, 80 })[r] or 0
    local newDur  = math.floor((duration or 0) * durMult)
    local newPwr  = power

    if not ctx.isBinary and type(power) == 'number' and power > 0 then
        local potMult = 1 + (({ 0.20, 0.40, 0.65 })[r] or 0)
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
-- Special / Utility Weaponskill Overrides
-----------------------------------
m:addOverride('xi.actions.weaponskills.atonement.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    local ws = catalog.byId[wsID]
    local ranks = talents.getWSRanks(player, player:getMainJob(), wsID)
    applySkillchainVars(player, ws, ranks)

    local enmRank = ranks.enmity_ctrl or 0
    local tpRank = ranks.tp_refund or 0
    local capRank = ranks.capstone or 0
    local ftpRank = ranks.ftp or 0
    local enmBonus = enmRank > 0 and (({ 50, 100, 175 })[enmRank] or 0) or 0
    local wsdBonus = capRank > 0 and 15 or 0

    if enmBonus > 0 then
        player:addMod(xi.mod.ENMITY, enmBonus)
    end
    if wsdBonus > 0 then
        player:addMod(xi.mod.ALL_WSDMG_ALL_HITS, wsdBonus)
    end

    local ok, tpHits, extraHits, crit, dmg = pcall(super, player, target, wsID, tp, primary, action, taChar)

    if wsdBonus > 0 then
        player:delMod(xi.mod.ALL_WSDMG_ALL_HITS, wsdBonus)
    end
    if enmBonus > 0 then
        player:delMod(xi.mod.ENMITY, enmBonus)
    end

    if not ok then
        error(tpHits)
    end

    if dmg and dmg > 0 then
        if ftpRank > 0 and target:getObjType() == xi.objType.MOB then
            local bonusDmg = math.floor(dmg * ftpRank * 0.15)
            if bonusDmg > 0 then
                target:takeDamage(bonusDmg, player, xi.attackType.BREATH, xi.damageType.ELEMENTAL)
                dmg = dmg + bonusDmg
            end
        end
        if enmRank > 0 then
            local healPct = ({ 0.15, 0.30, 0.50 })[enmRank] or 0
            player:addHP(math.floor(dmg * healPct))
        end
    end

    local refund = (tpRank == 3 and 350 or tpRank * 100)
    if refund > 0 then
        player:addTP(refund)
    end

    return tpHits, extraHits, crit, dmg
end)

local function getUtilityScale(player, wsID)
    local ranks = talents.getWSRanks(player, player:getMainJob(), wsID)
    local ftpRank = ranks.ftp or 0
    local potRank = ranks.potency or 0
    local capRank = ranks.capstone or 0
    local tpRank = ranks.tp_refund or 0

    local mult = 1.0 + (ftpRank * 0.15) + (potRank * 0.20) + (capRank * 0.50)
    local refund = (tpRank == 3 and 350 or tpRank * 100) + (capRank * 200)
    return mult, refund, ranks
end

local function applySelfUtilityTraits(player, ranks, baseMp)
    local mp = baseMp
    local manaRank = ranks.mana_leech or 0
    if manaRank > 0 then
        local mpMult = 1 + (({ 0.25, 0.50, 1.00 })[manaRank] or 0)
        local hpShare = ({ 0.25, 0.50, 0.75 })[manaRank] or 0
        mp = math.floor(mp * mpMult)
        local hpHeal = math.floor(mp * hpShare)
        if hpHeal > 0 then
            player:addHP(hpHeal)
        end
    end

    local pulseRank = ranks.aether_pulse or 0
    if pulseRank > 0 then
        local hpPct = ({ 0.10, 0.20, 0.35 })[pulseRank] or 0
        local refPwr = ({ 3, 5, 8 })[pulseRank] or 3
        local refDur = ({ 15, 30, 45 })[pulseRank] or 15
        player:addHP(math.floor(player:getMaxHP() * hpPct))
        player:addStatusEffect(xi.effect.REFRESH, { power = refPwr, duration = refDur, origin = player })
    end

    return mp
end

m:addOverride('xi.actions.weaponskills.spirits_within.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    local mult, refund, ranks = getUtilityScale(player, wsID)
    applySkillchainVars(player, catalog.byId[wsID], ranks)

    local ftpCurve = talents.calcFtpAtRank({ 1.0, 4.0, 8.0 }, ranks.ftp or 0)
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
        ['type'] = xi.attackType.BREATH,
        ['slot'] = xi.slot.MAIN,
        ['weaponType'] = player:getWeaponSkillType(xi.slot.MAIN),
        ['damageType'] = xi.damageType.ELEMENTAL,
    }
    local calcParams =
    {
        wsID = wsID,
        criticalHit = false,
        hitsLanded = 1,
        tpHitsLanded = dmg > 0 and (player:getOffhandDmg() > 0 and 2 or 1) or 0,
        extraHitsLanded = 0,
        shadowsAbsorbed = 0,
        bonusTP = refund,
        finalDmg = dmg,
    }

    dmg = xi.weaponskills.takeWeaponskillDamage(target, player, {}, primary, attack, calcParams, action)
    return calcParams.tpHitsLanded, calcParams.extraHitsLanded, calcParams.criticalHit, dmg
end)

m:addOverride('xi.actions.weaponskills.myrkr.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    local tpHits, extraHits, crit, mp = super(player, target, wsID, tp, primary, action, taChar)
    if player ~= nil and player:isPC() then
        local mult, refund, ranks = getUtilityScale(player, wsID)
        mp = applySelfUtilityTraits(player, ranks, math.floor(player:getMaxMP() * 0.20 * mult))
        if refund > 0 then
            player:addTP(refund)
        end
    end
    return tpHits, extraHits, crit, mp
end)

m:addOverride('xi.actions.weaponskills.dagan.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    xi.aftermath.addStatusEffect(player, tp, xi.slot.MAIN, xi.aftermath.type.EMPYREAN)
    local mult, refund, ranks = getUtilityScale(player, wsID)
    player:addHP(math.floor(player:getMaxHP() * 0.22 * mult))
    local mp = applySelfUtilityTraits(player, ranks, math.floor(player:getMaxMP() * 0.15 * mult))
    if refund > 0 then
        player:addTP(refund)
    end
    return 0, 0, false, mp
end)

m:addOverride('xi.actions.weaponskills.starlight.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    local mult, refund, ranks = getUtilityScale(player, wsID)
    local lvl = math.max(10, player:getSkillLevel(xi.skill.CLUB))
    local mp = applySelfUtilityTraits(player, ranks, math.floor(math.max(10, lvl * 0.11) * 2.0 * mult * xi.settings.main.WEAPON_SKILL_POWER))
    if refund > 0 then
        player:addTP(refund)
    end
    return 1, 0, false, mp
end)

m:addOverride('xi.actions.weaponskills.moonlight.onUseWeaponSkill', function(player, target, wsID, tp, primary, action, taChar)
    if player == nil or not player:isPC() then
        return super(player, target, wsID, tp, primary, action, taChar)
    end

    local mult, refund, ranks = getUtilityScale(player, wsID)
    local lvl = math.max(10, player:getSkillLevel(xi.skill.CLUB))
    local aoeBoost = 1 + ((ranks.aoe_cleave or 0) * 0.15)
    local mp = applySelfUtilityTraits(player, ranks, math.floor(math.max(10, lvl * 0.11) * 2.25 * mult * aoeBoost * xi.settings.main.WEAPON_SKILL_POWER))
    if refund > 0 then
        player:addTP(refund)
    end
    return 1, 0, false, mp
end)

local function overrideEnergyDrainOrSteal(player, target, wsID, action, baseMult)
    local ws = catalog.byId[wsID]
    local ranks = talents.getWSRanks(player, player:getMainJob(), wsID)
    applySkillchainVars(player, ws, ranks)

    local ftpRank = ranks.ftp or 0
    local wscRank = ranks.wsc_mnd or 0
    local capRank = ranks.capstone or 0
    local tpRank = ranks.tp_refund or 0
    local manaRank = ranks.mana_leech or 0

    local skill = math.max(10, player:getSkillLevel(xi.skill.DAGGER))
    local wscWeight = talents.calcWscAtRank(1.0, wscRank)
    local wsc = player:getStat(xi.mod.MND) * wscWeight
    local manaMult = 1 + (manaRank > 0 and (({ 0.25, 0.50, 1.00 })[manaRank] or 0) or 0)
    local mult = (baseMult + (ftpRank * 0.35) + (capRank * 0.75)) * manaMult
    local mpRestored = math.floor((math.floor(skill * 0.11) + wsc) * mult)

    if target:isUndead() then
        mpRestored = 0
    else
        mpRestored = target:delMP(mpRestored)
        mpRestored = player:addMP(mpRestored)
        if manaRank > 0 and mpRestored > 0 then
            local hpShare = ({ 0.25, 0.50, 0.75 })[manaRank] or 0
            player:addHP(math.floor(mpRestored * hpShare))
        end
    end

    local refund = (tpRank == 3 and 350 or tpRank * 100) + (capRank * 200)
    if refund > 0 then
        player:addTP(refund)
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
