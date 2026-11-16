-----------------------------------
-- OverlordsXI Bespoke WS Tree Helpers
-- Compact builders for 4-tier (56-pt) spec-filtered WS trees.
-- Supports explicit 5-spec trees (H.regSpec) and automatic 5-spec
-- 3x4 expansion (H.reg / H.regBaseline) with strict wsType stat guards.
-----------------------------------
local catalog = xi.overlords.wsCatalog
local talents = xi.overlords.wsTalents
local makeFtp = talents.makeCustomFtpNode
local makeNode = talents.makeSpecNode

local H = {}

local function pick(tbl, r)
    return tbl[r] or tbl[#tbl]
end

local function copyTable(src)
    if type(src) ~= 'table' then
        return src
    end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = copyTable(v)
    end
    return dst
end

function H.node(tier, col, key, name, maxRank, zeroDesc, rankDesc, effect, req)
    return makeNode(
    {
        tier     = tier,
        col      = col,
        key      = key,
        name     = name,
        maxRank  = maxRank,
        zeroDesc = zeroDesc,
        rankDesc = rankDesc,
        effect   = effect,
        requires = req,
    })
end

function H.ftp(curve, opts)
    opts = opts or {}
    return makeFtp(
    {
        key        = opts.key or 'ftp',
        name       = opts.name or 'TP Scaling',
        ftpCurve   = curve,
        zeroDesc   = opts.zeroDesc,
        zeroSuffix = opts.zeroSuffix,
        suffixFn   = opts.suffixFn,
        effect     = opts.effect,
    })
end

-----------------------------------
-- Strict Magic / Utility WS Stat Sanitizer
-- Ensures magic-only and utility/breath WSs NEVER have useless physical
-- atkPct, acc, racc, crit, critDmg, defIgnore, hits, bonusHits, or multiHitfTPAt.
-----------------------------------
local function isMagicOrUtilityWS(wsId, archetype)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    if ws ~= nil then
        if ws.wsType == 'magic' or ws.wsType == 'utility' then
            return true, ws.wsType
        end
    end
    if wsId == 39 or wsId == 45 then
        return true, 'utility'
    end
    if archetype == 'magic' then
        return true, 'magic'
    end
    return false, (ws and ws.wsType) or 'physical'
end

local function isMagicDamageWS(wsId)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    return ws ~= nil and ws.wsType == 'magic'
end

local function getDefaultElement(wsId)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    if ws and ws.elementName then
        return string.upper(ws.elementName), ws.elementName
    end
    local skill = ws and ws.skill or 0
    if skill == xi.skill.SCYTHE then
        return 'DARK', 'Dark'
    elseif skill == xi.skill.CLUB then
        return 'LIGHT', 'Light'
    elseif skill == xi.skill.GREAT_SWORD then
        return 'ICE', 'Ice'
    elseif skill == xi.skill.POLEARM or skill == xi.skill.AXE then
        return 'THUNDER', 'Thunder'
    elseif skill == xi.skill.DAGGER or skill == xi.skill.KATANA then
        return 'WIND', 'Wind'
    elseif skill == xi.skill.SWORD or skill == xi.skill.GREAT_KATANA then
        return 'FIRE', 'Fire'
    end
    return 'LIGHT', 'Light'
end

local function sanitizeNodeForNonPhysical(n, wsId, wsKind)
    if n == nil or type(n.effect) ~= 'table' then
        return n
    end
    local eff = n.effect
    local hadPhys = eff.atkPct or eff.acc or eff.racc or eff.crit or eff.critCurve
        or eff.critDmg or eff.defIgnore or eff.hits or eff.bonusHits or eff.multiHitfTPAt
        or (eff.stance and (eff.stance.atkPct or eff.stance.crit or eff.stance.critDmg or eff.stance.defIgnore))
    if not hadPhys then
        return n
    end

    local nodeCopy = copyTable(n)
    local ce = nodeCopy.effect
    local mr = nodeCopy.maxRank or 5

    local function seq(step)
        local t = {}
        for i = 1, mr do
            t[i] = i * step
        end
        return t
    end

    -- Convert physical stats into magic/utility equivalents
    if ce.atkPct then
        ce.matt = ce.matt or seq(8)
        ce.atkPct = nil
    end
    if ce.acc or ce.racc then
        ce.macc = ce.macc or seq(8)
        ce.acc  = nil
        ce.racc = nil
    end
    if ce.crit or ce.critCurve or ce.critDmg then
        ce.wsd     = ce.wsd or seq(6)
        ce.tpBonus = ce.tpBonus or seq(60)
        ce.crit      = nil
        ce.critCurve = nil
        ce.critDmg   = nil
    end
    if ce.defIgnore then
        ce.macc = ce.macc or seq(9)
        ce.matt = ce.matt or seq(9)
        ce.defIgnore = nil
    end
    if ce.hits or ce.bonusHits or ce.multiHitfTPAt then
        ce.ftpAdd = ce.ftpAdd or seq(0.35)
        ce.wsd    = ce.wsd or seq(7)
        ce.hits          = nil
        ce.bonusHits     = nil
        ce.multiHitfTPAt = nil
    end
    if ce.stance then
        if ce.stance.atkPct then
            ce.stance.matt = ce.stance.matt or seq(10)
            ce.stance.atkPct = nil
        end
        if ce.stance.crit or ce.stance.critDmg or ce.stance.defIgnore then
            ce.stance.macc = ce.stance.macc or seq(10)
            ce.stance.wsd  = ce.stance.wsd or seq(8)
            ce.stance.crit      = nil
            ce.stance.critDmg   = nil
            ce.stance.defIgnore = nil
        end
    end

    -- Refresh tooltip to reflect pure magic/utility stats
    local isUtil = (wsKind == 'utility')
    nodeCopy.describe = function(r)
        if r <= 0 then
            return isUtil and '+Potency, +MACC & +TP Scaling' or '+MAB, +MACC & +WSD Scaling'
        end
        local parts = {}
        if ce.wsd then table.insert(parts, string.format('+%d%% %s', pick(ce.wsd, r), isUtil and 'Potency' or 'WSD')) end
        if ce.matt and not isUtil then table.insert(parts, string.format('+%d MAB', pick(ce.matt, r))) end
        if ce.macc then table.insert(parts, string.format('+%d MACC', pick(ce.macc, r))) end
        if ce.tpBonus then table.insert(parts, string.format('+%d TP', pick(ce.tpBonus, r))) end
        if ce.ftpAdd then table.insert(parts, string.format('+%.2f fTP', pick(ce.ftpAdd, r))) end
        if #parts == 0 then
            return string.format('Rank %d/%d', r, mr)
        end
        return table.concat(parts, ', ')
    end

    return nodeCopy
end

-----------------------------------
-- Spec-Specific Column Builders (for automatic 3x4 spec trees)
-----------------------------------
local TANK_STANCE_EFFECTS =
{
    xi.effect.DEFENDER,
    xi.effect.SENTINEL,
    xi.effect.RAMPART,
    xi.effect.VALLATION,
    xi.effect.VALIANCE,
    xi.effect.SWORDPLAY,
    xi.effect.BATTUTA,
    xi.effect.COUNTERSTANCE,
    xi.effect.DODGE,
    xi.effect.BLOOD_RAGE,
}

local SPELLBLADE_STANCE_EFFECTS =
{
    xi.effect.SWORDPLAY,
    xi.effect.VALLATION,
    xi.effect.VALIANCE,
    xi.effect.IGNIS,
    xi.effect.GELUS,
    xi.effect.FLABRA,
    xi.effect.TELLUS,
    xi.effect.SULPOR,
    xi.effect.UNDA,
    xi.effect.LUX,
    xi.effect.TENEBRAE,
    xi.effect.DARK_ARTS,
    xi.effect.ADDENDUM_BLACK,
}

local HEALER_STANCE_EFFECTS =
{
    xi.effect.LIGHT_ARTS,
    xi.effect.ADDENDUM_WHITE,
    xi.effect.AFFLATUS_SOLACE,
    xi.effect.VALIANCE,
    xi.effect.VALLATION,
}

local COMMANDER_STANCE_EFFECTS =
{
    xi.effect.WARCRY,
    xi.effect.BERSERK,
    xi.effect.RESTRAINT,
    xi.effect.AGGRESSOR,
    xi.effect.RETALIATION,
}

local BERSERKER_STANCE_EFFECTS =
{
    xi.effect.BERSERK,
    xi.effect.BLOOD_RAGE,
    xi.effect.LAST_RESORT,
    xi.effect.SOULEATER,
    xi.effect.IMPETUS,
    xi.effect.FOCUS,
    xi.effect.RESTRAINT,
}

local function findGridNode(nodes, tier, col)
    for _, n in ipairs(nodes or {}) do
        if n.tier == tier and n.col == col then
            return copyTable(n)
        end
    end
    return nil
end

local function rekeyNode(n, tier, col, newKey)
    local c = copyTable(n)
    c.tier = tier
    c.col  = col
    if newKey then
        c.key = newKey
    end
    c.requires = nil -- finalizeTree auto-wires vertical same-col requires
    return c
end

local function makeScalingT1Col1(wsId, baseT1C1, isNonPhys)
    if baseT1C1 ~= nil then
        local c = rekeyNode(baseT1C1, 1, 1, 'ftp')
        return isNonPhys and sanitizeNodeForNonPhysical(c, wsId, 'magic') or c
    end
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local origFtp = (ws and ws.orig and ws.orig.ftp) or { 1.25, 2.00, 2.75 }
    local curve = {
        math.max(1.25, origFtp[1] or 1.25),
        math.max(1.85, origFtp[2] or 1.85),
        math.max(2.60, origFtp[3] or 2.60),
    }
    return H.ftp(curve)
end

local function makePrimaryWscNode(wsId, tier, col, key, isNonPhys, rolePrefStat)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local origWsc = (ws and ws.orig and ws.orig.wsc) or {}
    local stat = rolePrefStat
    if stat == nil then
        for _, s in ipairs({ 'str', 'dex', 'vit', 'agi', 'int', 'mnd', 'chr' }) do
            if (origWsc[s] or 0) > 0 then
                stat = s
                break
            end
        end
    end
    stat = stat or (isNonPhys and 'int' or 'str')
    local label = string.upper(stat)
    local wTbl = { 0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.85 }
    if isNonPhys then
        if isMagicDamageWS(wsId) then
            return H.node(tier, col, key, label .. ' & Arcane Focus', 7,
                string.format('%s +12..85%% WSC & +6..42 MACC', label),
                function(r) return string.format('%s +%d%% WSC, +%d MACC', label, math.floor(wTbl[r] * 100 + 0.5), r * 6) end,
                { wsc = { [stat] = wTbl }, macc = { 6, 12, 18, 24, 30, 36, 42 } })
        end
        return H.node(tier, col, key, label .. ' & Potency', 7,
            string.format('%s +12..85%% WSC & +45..315 TP Bonus', label),
            function(r) return string.format('%s +%d%% WSC, +%d TP', label, math.floor(wTbl[r] * 100 + 0.5), r * 45) end,
            { wsc = { [stat] = wTbl }, tpBonus = { 45, 90, 135, 180, 225, 270, 315 } })
    end
    return H.node(tier, col, key, label .. ' Precision', 7,
        string.format('%s +12..85%% WSC & +5..35 Acc', label),
        function(r) return string.format('%s +%d%% WSC, +%d Acc', label, math.floor(wTbl[r] * 100 + 0.5), r * 5) end,
        { wsc = { [stat] = wTbl }, acc = { 5, 10, 15, 20, 25, 30, 35 } })
end

-- Build 12-node (3x4) Tank tree for any WS
local function buildTankSpecNodes(wsId, archetype, baseNodes)
    local isNonPhys, wsKind = isMagicOrUtilityWS(wsId, archetype)
    local isMagDmg = isMagicDamageWS(wsId)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local skill = ws and ws.skill or 0
    local isSensei = (skill == xi.skill.STAFF or skill == xi.skill.HAND_TO_HAND or skill == xi.skill.KATANA or skill == xi.skill.DAGGER)
    local isGladiator = (skill == xi.skill.CLUB or skill == xi.skill.AXE or skill == xi.skill.GREAT_AXE)

    local t1c1 = makeScalingT1Col1(wsId, findGridNode(baseNodes, 1, 1), isNonPhys)
    local t1c3 = makePrimaryWscNode(wsId, 1, 3, 'tk_t1_c3', isNonPhys, isSensei and 'vit' or 'vit')

    local c1_t1, c1_t2, c1_t3, c1_t4
    if isSensei then
        c1_t1 = H.node(1, 2, 'tk_t1_c2', 'Sensei Provoke', 7, '+7..49 Enmity & +2..14% Counter (15s)',
            function(r) return string.format('+%d Enmity, +%d%% Counter (15s)', r * 7, r * 2) end,
            { enmity = { 7,14,21,28,35,42,49 }, postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 15, mods = {{ mod = xi.mod.COUNTER, val = { 2,4,6,8,10,12,14 } }} } })
        c1_t2 = H.node(2, 2, 'tk_t2_c2', 'Evasive Poise', 5, 'Heal 3..15% Max HP & +5..25 EVA (20s)',
            function(r) return string.format('Heal %d%% Max HP, +%d EVA (20s)', r * 3, r * 5) end,
            { selfMaxHpHealPct = { 3,6,9,12,15 }, postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 20, mods = {{ mod = xi.mod.EVA, val = { 5,10,15,20,25 } }} } })
        c1_t3 = H.node(3, 2, 'tk_t3_c2', 'Sweeping Parry', 5, '+3..15% Parry (20s) & Stoneskin 120..360',
            function(r) return string.format('+%d%% Parry, Stoneskin %d', r * 3, 60 + r * 60) end,
            { postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 20, mods = {{ mod = xi.mod.INQUARTATA, val = { 3,6,9,12,15 } }} },
              statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 120,180,240,300,360 }, duration = 45, tier = 3 }} })
        c1_t4 = H.node(4, 2, 'tk_t4_c2', 'Grandmaster Guard', 3, 'Phalanx 20..40 (30s) & +12..36% WSD',
            function(r) return string.format('Phalanx %d (30s), +%d%% WSD', 10 + r * 10, r * 12) end,
            { wsd = { 12,24,36 }, statusBuffs = {{ effect = xi.effect.PHALANX, power = { 20,30,40 }, duration = 30 }} })
    elseif isGladiator then
        c1_t1 = H.node(1, 2, 'tk_t1_c2', 'Bloodthirsty Taunt', 7, '+7..49 Enmity & Heal 2..14% Max HP',
            function(r) return string.format('+%d Enmity, Heal %d%% Max HP', r * 7, r * 2) end,
            { enmity = { 7,14,21,28,35,42,49 }, selfMaxHpHealPct = { 2,4,6,8,10,12,14 } })
        c1_t2 = H.node(2, 2, 'tk_t2_c2', 'Crimson Shield', 5, '+4..20% Shield Block (20s) & Stoneskin 120..360',
            function(r) return string.format('+%d%% Block, Stoneskin %d', r * 4, 60 + r * 60) end,
            { postBuff = { effect = xi.effect.SHIELD_BREAK, duration = 20, mods = {{ mod = xi.mod.PALISADE_BLOCK_BONUS, val = { 4,8,12,16,20 } }} },
              statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 120,180,240,300,360 }, duration = 45, tier = 3 }} })
        c1_t3 = H.node(3, 2, 'tk_t3_c2', 'Sanguine Leech', 5, 'Drains 12..40% WS dmg as HP & +8..40% WSD',
            function(r) return string.format('%d%% HP Drain, +%d%% WSD', 4 + r * 8, r * 8) end,
            { hpDrain = { 12,19,26,33,40 }, wsd = { 8,16,24,32,40 } })
        c1_t4 = H.node(4, 2, 'tk_t4_c2', 'Immortal Gladiator', 3, 'Phalanx 20..40 (30s) & Heal 6..18% Max HP',
            function(r) return string.format('Phalanx %d (30s), Heal %d%% HP', 10 + r * 10, r * 6) end,
            { selfMaxHpHealPct = { 6,12,18 }, statusBuffs = {{ effect = xi.effect.PHALANX, power = { 20,30,40 }, duration = 30 }} })
    else
        c1_t1 = H.node(1, 2, 'tk_t1_c2', 'Inquisitor Challenge', 7, '+7..49 Enmity & Stoneskin 90..330 (45s)',
            function(r) return string.format('+%d Enmity, Stoneskin %d', r * 7, 50 + r * 40) end,
            { enmity = { 7,14,21,28,35,42,49 }, statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 90,130,170,210,250,290,330 }, duration = 45, tier = 3 }} })
        c1_t2 = H.node(2, 2, 'tk_t2_c2', 'Order Ward', 5, 'Heal 3..15% Max HP & +3..15% Parry (20s)',
            function(r) return string.format('Heal %d%% Max HP, +%d%% Parry', r * 3, r * 3) end,
            { selfMaxHpHealPct = { 3,6,9,12,15 }, postBuff = { effect = xi.effect.SUBTLE_BLOW_PLUS, duration = 20, mods = {{ mod = xi.mod.INQUARTATA, val = { 3,6,9,12,15 } }} } })
        c1_t3 = H.node(3, 2, 'tk_t3_c2', 'Sanctified Phalanx', 5, 'Phalanx 16..36 (30s) & +6..30 Enmity',
            function(r) return string.format('Phalanx %d (30s), +%d Enmity', 11 + r * 5, r * 6) end,
            { enmity = { 6,12,18,24,30 }, statusBuffs = {{ effect = xi.effect.PHALANX, power = { 16,21,26,31,36 }, duration = 30 }} })
        c1_t4 = H.node(4, 2, 'tk_t4_c2', 'Unbreakable Aegis', 3, 'Stoneskin 250..500 & Heal 6..18% Max HP',
            function(r) return string.format('Stoneskin %d, Heal %d%% HP', 125 + r * 125, r * 6) end,
            { selfMaxHpHealPct = { 6,12,18 }, statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 250,375,500 }, duration = 45, tier = 3 }} })
    end

    local c2_t2 = H.node(2, 1, 'tk_t2_c1', 'Suppressing Blow', 5, 'Target -5..25% Atk & -8..40 Acc (45s)',
        function(r) return string.format('Target -%d%% Atk, -%d Acc', r * 5, r * 8) end,
        { targetDebuffs = {
            { effect = xi.effect.ATTACK_DOWN, power = { 5,10,15,20,25 }, duration = 45 },
            { effect = xi.effect.ACCURACY_DOWN, power = { 8,16,24,32,40 }, duration = 45 },
        } })
    local c2_t3 = H.node(3, 1, 'tk_t3_c1', 'Spellbreaker Guard', 5, 'Target -6..30 M.Atk & Drains 60..300 Target TP',
        function(r) return string.format('Target -%d M.Atk, -%d TP', r * 6, r * 60) end,
        { tpDrain = { 60,120,180,240,300 }, targetDebuffs = {{ effect = xi.effect.MAGIC_ATK_DOWN, power = { 6,12,18,24,30 }, duration = 45 }} })
    local c2_t4 = H.node(4, 1, 'tk_t4_c1', 'Bastion Judgment', 3, 'Dispel 1-2, Target Slow 15..25% & +14..42% WSD',
        function(r) return string.format('Dispel %d, Slow %d%%, +%d%% WSD', r >= 2 and 2 or 1, 10 + r * 5, r * 14) end,
        { dispel = { 1,2,2 }, wsd = { 14,28,42 }, targetDebuffs = {{ effect = xi.effect.SLOW, power = { 1500,2000,2500 }, duration = 45 }} })

    local c3_t2 = H.stanceNode(2, 3, 'tk_t2_c3', 'Tank Stance Synergy', 5, 'Tank Stance', TANK_STANCE_EFFECTS,
        isMagDmg and { wsd = { 8,16,24,32,40 }, matt = { 8,16,24,32,40 }, zeroDesc = 'Tank Stance: +8..40% WSD & +8..40 MAB' }
            or (isNonPhys and { wsd = { 8,16,24,32,40 }, enmity = { 6,12,18,24,30 }, zeroDesc = 'Tank Stance: +8..40% WSD & +6..30 Enmity' }
                or { wsd = { 8,16,24,32,40 }, atkPct = { 8,16,24,32,40 }, zeroDesc = 'Tank Stance: +8..40% WSD & +8..40% Atk' }))
    local c3_t3 = isMagDmg
        and H.node(3, 3, 'tk_t3_c3', 'Runic Focus', 5, '+9..45 MAB, +9..45 MACC & +60..300 TP Bonus',
            function(r) return string.format('+%d MAB/MACC, +%d TP', r * 9, r * 60) end,
            { matt = { 9,18,27,36,45 }, macc = { 9,18,27,36,45 }, tpBonus = { 60,120,180,240,300 } })
        or (isNonPhys
            and H.node(3, 3, 'tk_t3_c3', 'Bastion Focus', 5, '+6..30% WSD, +6..30 Enmity & +60..300 TP Bonus',
                function(r) return string.format('+%d%% WSD, +%d Enmity, +%d TP', r * 6, r * 6, r * 60) end,
                { wsd = { 6,12,18,24,30 }, enmity = { 6,12,18,24,30 }, tpBonus = { 60,120,180,240,300 } })
            or H.node(3, 3, 'tk_t3_c3', 'Vanguard Force', 5, '+1 Bonus Hit, +8..40% Atk & +8..40 Acc',
                function(r) return string.format('+1 Hit, +%d%% Atk, +%d Acc', r * 8, r * 8) end,
                { bonusHits = { 1,1,1,1,1 }, atkPct = { 8,16,24,32,40 }, acc = { 8,16,24,32,40 } }))
    local c3_t4 = isMagDmg
        and H.node(4, 3, 'tk_t4_c3', 'Vanguard Mastery', 5, '+7..35% WSD, +8..40 MAB & +6..30 Enmity',
            function(r) return string.format('+%d%% WSD, +%d MAB, +%d Enmity', r * 7, r * 8, r * 6) end,
            { wsd = { 7,14,21,28,35 }, matt = { 8,16,24,32,40 }, enmity = { 6,12,18,24,30 } })
        or (isNonPhys
            and H.node(4, 3, 'tk_t4_c3', 'Vanguard Mastery', 5, '+8..40% WSD, +8..40 Enmity & Heal 3..15% HP',
                function(r) return string.format('+%d%% WSD, +%d Enmity, Heal %d%%', r * 8, r * 8, r * 3) end,
                { wsd = { 8,16,24,32,40 }, enmity = { 8,16,24,32,40 }, selfMaxHpHealPct = { 3,6,9,12,15 } })
            or H.node(4, 3, 'tk_t4_c3', 'Vanguard Mastery', 5, 'fTP ALL Hits, +6..30% WSD & +6..30 Enmity',
                function(r) return string.format('fTP ALL, +%d%% WSD, +%d Enmity', r * 6, r * 6) end,
                { multiHitfTPAt = 1, wsd = { 6,12,18,24,30 }, enmity = { 6,12,18,24,30 } }))

    return { t1c1, c1_t1, t1c3, c2_t2, c1_t2, c3_t2, c2_t3, c1_t3, c3_t3, c2_t4, c1_t4, c3_t4 }
end

-- Build 12-node (3x4) Spellblade / Sage / Necromancer tree for any WS
local function buildSpellbladeSpecNodes(wsId, archetype, baseNodes)
    local isNonPhys = isMagicOrUtilityWS(wsId, archetype)
    local isMagDmg = isMagicDamageWS(wsId)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local skill = ws and ws.skill or 0
    local isRanged = (ws and ws.wsType == 'ranged')
    local accKey = isRanged and 'racc' or 'acc'
    local accLabel = isRanged and 'RAcc' or 'Acc'
    local eleUpper, eleName = getDefaultElement(wsId)
    local isNecro = (skill == xi.skill.SCYTHE)
    local isSage  = (skill == xi.skill.CLUB or skill == xi.skill.STAFF or skill == xi.skill.DAGGER)

    local t1c1 = makeScalingT1Col1(wsId, findGridNode(baseNodes, 1, 1), isNonPhys)
    local t1c3 = makePrimaryWscNode(wsId, 1, 3, 'sb_t1_c3', isNonPhys, 'int')

    local c1_t1, c1_t2, c1_t3, c1_t4
    if isNecro then
        c1_t1 = isMagDmg
            and H.node(1, 2, 'sb_t1_c2', 'Harbinger Pact', 7, 'Heals Undead Pet 10..70% HP/MP & +8..56 MAB',
                function(r) return string.format('Pet Heal %d%%, +%d MAB', r * 10, r * 8) end,
                { eosHeal = { 10,20,30,40,50,60,70 }, matt = { 8,16,24,32,40,48,56 } })
            or H.node(1, 2, 'sb_t1_c2', 'Harbinger Pact', 7, 'Heals Undead Pet 10..70% HP/MP & +4..28% WSD',
                function(r) return string.format('Pet Heal %d%%, +%d%% WSD', r * 10, r * 4) end,
                { eosHeal = { 10,20,30,40,50,60,70 }, wsd = { 4,8,12,16,20,24,28 } })
        c1_t2 = H.node(2, 2, 'sb_t2_c2', 'Soul Siphon', 5, 'HP Drain 8..40% & MP Drain 5..25% of WS dmg',
            function(r) return string.format('%d%% HP Drain, %d%% MP Drain', r * 8, r * 5) end,
            { hpDrain = { 8,16,24,32,40 }, mpDrain = { 5,10,15,20,25 } })
        c1_t3 = H.elemFollow(3, 2, 'sb_t3_c2', 'Necrotic Burst', 'DARK', 'Dark', 12, false)
        c1_t4 = isMagDmg
            and H.node(4, 2, 'sb_t4_c2', 'Lich Sovereign', 3, 'Pet Heal 30..90%, +15..45% WSD & +15..45 MAB',
                function(r) return string.format('Pet +%d%%, +%d%% WSD, +%d MAB', r * 30, r * 15, r * 15) end,
                { eosHeal = { 30,60,90 }, wsd = { 15,30,45 }, matt = { 15,30,45 } })
            or (isNonPhys
                and H.node(4, 2, 'sb_t4_c2', 'Lich Sovereign', 3, 'Pet Heal 30..90%, +15..45% WSD & +0.4..1.2 fTP',
                    function(r) return string.format('Pet +%d%%, +%d%% WSD, +%.1f fTP', r * 30, r * 15, r * 0.4) end,
                    { eosHeal = { 30,60,90 }, wsd = { 15,30,45 }, ftpAdd = { 0.4,0.8,1.2 } })
                or H.node(4, 2, 'sb_t4_c2', 'Lich Sovereign', 3, 'Pet Heal 30..90%, +15..45% WSD & 10..30% DEF Ign',
                    function(r) return string.format('Pet +%d%%, +%d%% WSD, %d%% DEF Ign', r * 30, r * 15, r * 10) end,
                    { eosHeal = { 30,60,90 }, wsd = { 15,30,45 }, defIgnore = { .10,.20,.30 } }))
    elseif isSage then
        c1_t1 = isMagDmg
            and H.node(1, 2, 'sb_t1_c2', 'Titania Covenant', 7, 'Heals Titania/Pet 10..70% & +8..56 MAB',
                function(r) return string.format('Pet Heal %d%%, +%d MAB', r * 10, r * 8) end,
                { eosHeal = { 10,20,30,40,50,60,70 }, matt = { 8,16,24,32,40,48,56 } })
            or H.node(1, 2, 'sb_t1_c2', 'Titania Covenant', 7, 'Heals Titania/Pet 10..70% & +4..28% WSD',
                function(r) return string.format('Pet Heal %d%%, +%d%% WSD', r * 10, r * 4) end,
                { eosHeal = { 10,20,30,40,50,60,70 }, wsd = { 4,8,12,16,20,24,28 } })
        c1_t2 = isMagDmg
            and H.node(2, 2, 'sb_t2_c2', 'Dark Arts Helix', 5, 'MP Drain 6..30% & +9..45 MACC',
                function(r) return string.format('MP Drain %d%%, +%d MACC', r * 6, r * 9) end,
                { mpDrain = { 6,12,18,24,30 }, macc = { 9,18,27,36,45 } })
            or H.node(2, 2, 'sb_t2_c2', 'Dark Arts Helix', 5, 'MP Drain 6..30% & +5..25% WSD',
                function(r) return string.format('MP Drain %d%%, +%d%% WSD', r * 6, r * 5) end,
                { mpDrain = { 6,12,18,24,30 }, wsd = { 5,10,15,20,25 } })
        c1_t3 = H.elemFollow(3, 2, 'sb_t3_c2', eleName .. ' Helix Burst', eleUpper, eleName, 12, false)
        c1_t4 = isMagDmg
            and H.node(4, 2, 'sb_t4_c2', 'Sage Overcharge', 3, '+16..48% WSD, +18..54 MAB & -15..45 Target MEVA',
                function(r) return string.format('+%d%% WSD, +%d MAB, -%d MEVA', r * 16, r * 18, r * 15) end,
                { wsd = { 16,32,48 }, matt = { 18,36,54 }, targetDebuffs = {{ effect = xi.effect.MAGIC_EVASION_DOWN, power = { 15,30,45 }, duration = 60 }} })
            or (isNonPhys
                and H.node(4, 2, 'sb_t4_c2', 'Sage Overcharge', 3, '+16..48% WSD, +0.4..1.2 fTP & -15..45 Target MEVA',
                    function(r) return string.format('+%d%% WSD, +%.1f fTP, -%d MEVA', r * 16, r * 0.4, r * 15) end,
                    { wsd = { 16,32,48 }, ftpAdd = { 0.4,0.8,1.2 }, targetDebuffs = {{ effect = xi.effect.MAGIC_EVASION_DOWN, power = { 15,30,45 }, duration = 60 }} })
                or H.node(4, 2, 'sb_t4_c2', 'Sage Overcharge', 3, '+16..48% WSD, 10..30% DEF Ign & -15..45 Target MEVA',
                    function(r) return string.format('+%d%% WSD, %d%% DEF Ign, -%d MEVA', r * 16, r * 10, r * 15) end,
                    { wsd = { 16,32,48 }, defIgnore = { .10,.20,.30 }, targetDebuffs = {{ effect = xi.effect.MAGIC_EVASION_DOWN, power = { 15,30,45 }, duration = 60 }} }))
    else
        c1_t1 = isMagDmg
            and H.node(1, 2, 'sb_t1_c2', 'Conduction Edge', 7, 'Grants +1..2 Conduction & +8..56 MAB',
                function(r) return string.format('+%d Conduction, +%d MAB', r >= 5 and 2 or 1, r * 8) end,
                { conductionAdd = { 1,1,1,1,2,2,2 }, matt = { 8,16,24,32,40,48,56 } })
            or H.node(1, 2, 'sb_t1_c2', 'Conduction Edge', 7, 'Grants +1..2 Conduction & +4..28% WSD',
                function(r) return string.format('+%d Conduction, +%d%% WSD', r >= 5 and 2 or 1, r * 4) end,
                { conductionAdd = { 1,1,1,1,2,2,2 }, wsd = { 4,8,12,16,20,24,28 } })
        c1_t2 = isMagDmg
            and H.node(2, 2, 'sb_t2_c2', 'Runic Siphon', 5, 'MP Drain 6..30% & +9..45 MACC',
                function(r) return string.format('MP Drain %d%%, +%d MACC', r * 6, r * 9) end,
                { mpDrain = { 6,12,18,24,30 }, macc = { 9,18,27,36,45 } })
            or H.node(2, 2, 'sb_t2_c2', 'Runic Siphon', 5, 'MP Drain 6..30% & +5..25% WSD',
                function(r) return string.format('MP Drain %d%%, +%d%% WSD', r * 6, r * 5) end,
                { mpDrain = { 6,12,18,24,30 }, wsd = { 5,10,15,20,25 } })
        c1_t3 = H.elemFollow(3, 2, 'sb_t3_c2', eleName .. ' Edgeflare', eleUpper, eleName, 12, false)
        c1_t4 = isMagDmg
            and H.node(4, 2, 'sb_t4_c2', 'Ascendant Spellblade', 3, '+2..3 Conduction, +15..45% WSD & +15..45 MAB',
                function(r) return string.format('+%d Conduction, +%d%% WSD, +%d MAB', r >= 2 and 3 or 2, r * 15, r * 15) end,
                { conductionAdd = { 2,3,3 }, wsd = { 15,30,45 }, matt = { 15,30,45 } })
            or H.node(4, 2, 'sb_t4_c2', 'Ascendant Spellblade', 3, '+2..3 Conduction, +15..45% WSD & +0.4..1.2 fTP',
                function(r) return string.format('+%d Conduction, +%d%% WSD, +%.1f fTP', r >= 2 and 3 or 2, r * 15, r * 0.4) end,
                { conductionAdd = { 2,3,3 }, wsd = { 15,30,45 }, ftpAdd = { 0.4,0.8,1.2 } })
    end

    local c2_t2 = H.node(2, 1, 'sb_t2_c1', 'Arcane Breach', 5, 'Target -6..30 M.Def & -8..40 M.Eva (45s)',
        function(r) return string.format('Target -%d M.Def, -%d M.Eva', r * 6, r * 8) end,
        { targetDebuffs = {
            { effect = xi.effect.MAGIC_DEF_DOWN, power = { 6,12,18,24,30 }, duration = 45 },
            { effect = xi.effect.MAGIC_EVASION_DOWN, power = { 8,16,24,32,40 }, duration = 45 },
        } })
    local c2_t3 = isMagDmg
        and H.stanceNode(3, 1, 'sb_t3_c1', 'Runic Resonance', 5, 'Runes/DarkArts', SPELLBLADE_STANCE_EFFECTS,
            { wsd = { 9,18,27,36,45 }, matt = { 10,20,30,40,50 }, zeroDesc = 'Runes/DarkArts: +9..45% WSD & +10..50 MAB' })
        or H.stanceNode(3, 1, 'sb_t3_c1', 'Runic Resonance', 5, 'Runes/DarkArts', SPELLBLADE_STANCE_EFFECTS,
            { wsd = { 9,18,27,36,45 }, tpBonus = { 60,120,180,240,300 }, zeroDesc = 'Runes/DarkArts: +9..45% WSD & +60..300 TP Bonus' })
    local c2_t4 = H.node(4, 1, 'sb_t4_c1', 'Elemental Convergence', 3, '+15..45% SC Dmg & +0.5..1.5 fTP',
        function(r) return string.format('+%d%% SC Dmg, +%.1f fTP', r * 15, r * 0.5) end,
        { scBonus = { 15,30,45 }, ftpAdd = { 0.5,1.0,1.5 } })

    local c3_t2 = H.node(2, 3, 'sb_t2_c3', 'Spellweaver Tempo', 5, '+70..350 TP Bonus & +6..30% WSD',
        function(r) return string.format('+%d TP Bonus, +%d%% WSD', r * 70, r * 6) end,
        { tpBonus = { 70,140,210,280,350 }, wsd = { 6,12,18,24,30 } })
    local c3_t3 = isMagDmg
        and H.node(3, 3, 'sb_t3_c3', 'Arcane Amplifier', 5, '+10..50 MAB, +10..50 MACC & +5..25% WSD',
            function(r) return string.format('+%d MAB/MACC, +%d%% WSD', r * 10, r * 5) end,
            { matt = { 10,20,30,40,50 }, macc = { 10,20,30,40,50 }, wsd = { 5,10,15,20,25 } })
        or (isNonPhys
            and H.node(3, 3, 'sb_t3_c3', 'Runic Amplifier', 5, '+7..35% WSD & +60..300 TP Bonus',
                function(r) return string.format('+%d%% WSD, +%d TP Bonus', r * 7, r * 60) end,
                { wsd = { 7,14,21,28,35 }, tpBonus = { 60,120,180,240,300 } })
            or H.node(3, 3, 'sb_t3_c3', 'Enchanted Flurry', 5, '+1 Bonus Hit, +5..25% WSD & +8..40 ' .. accLabel,
                function(r) return string.format('+1 Hit, +%d%% WSD, +%d %s', r * 5, r * 8, accLabel) end,
                { bonusHits = { 1,1,1,1,1 }, wsd = { 5,10,15,20,25 }, [accKey] = { 8,16,24,32,40 } }))
    local c3_t4 = isMagDmg
        and H.node(4, 3, 'sb_t4_c3', 'Spellblade Mastery', 5, '+7..35% WSD, +10..50 MAB & +8..40% SC Dmg',
            function(r) return string.format('+%d%% WSD, +%d MAB, +%d%% SC', r * 7, r * 10, r * 8) end,
            { wsd = { 7,14,21,28,35 }, matt = { 10,20,30,40,50 }, scBonus = { 8,16,24,32,40 } })
        or H.node(4, 3, 'sb_t4_c3', 'Spellblade Mastery', 5, '+7..35% WSD, +60..300 TP Bonus & +8..40% SC Dmg',
            function(r) return string.format('+%d%% WSD, +%d TP, +%d%% SC', r * 7, r * 60, r * 8) end,
            { wsd = { 7,14,21,28,35 }, tpBonus = { 60,120,180,240,300 }, scBonus = { 8,16,24,32,40 } })

    return { t1c1, c1_t1, t1c3, c2_t2, c1_t2, c3_t2, c2_t3, c1_t3, c3_t3, c2_t4, c1_t4, c3_t4 }
end

-- Build 12-node (3x4) Healer / Lifebinder / Medic tree for any WS
local function buildHealerSpecNodes(wsId, archetype, baseNodes)
    local isNonPhys = isMagicOrUtilityWS(wsId, archetype)
    local isMagDmg = isMagicDamageWS(wsId)
    local t1c1 = makeScalingT1Col1(wsId, findGridNode(baseNodes, 1, 1), isNonPhys)
    local t1c3 = makePrimaryWscNode(wsId, 1, 3, 'hl_t1_c3', isNonPhys, 'mnd')

    local c1_t1 = H.node(1, 2, 'hl_t1_c2', 'Vivacious Mending', 7, 'Party Heal 3..21% Max HP & Eos/Pet Heal 10..70%',
        function(r) return string.format('Party Heal %d%%, Pet Heal %d%%', r * 3, r * 10) end,
        { partyHealPct = { 3,6,9,12,15,18,21 }, eosHeal = { 10,20,30,40,50,60,70 } })
    local c1_t2 = H.node(2, 2, 'hl_t2_c2', 'Sanctuary Regen', 5, 'Party Regen 12..32/tick (30s) & +6..30% WSD',
        function(r) return string.format('Party Regen %d/t, +%d%% WSD', 7 + r * 5, r * 6) end,
        { wsd = { 6,12,18,24,30 }, partyBuffs = {{ effect = xi.effect.REGEN, power = { 12,17,22,27,32 }, duration = 30 }} })
    local c1_t3 = H.node(3, 2, 'hl_t3_c2', 'Runic Lifetap', 5, 'MP Drain 8..40% of WS dmg & Party Refresh 3..15/t',
        function(r) return string.format('MP Drain %d%%, Party Refresh %d/t', r * 8, r * 3) end,
        { mpDrain = { 8,16,24,32,40 }, partyBuffs = {{ effect = xi.effect.REFRESH, power = { 3,6,9,12,15 }, duration = 30 }} })
    local c1_t4 = H.node(4, 2, 'hl_t4_c2', 'Lifebinder Benediction', 3, 'Party Heal 10..30% Max HP & +15..45% WSD',
        function(r) return string.format('Party Heal %d%%, +%d%% WSD', r * 10, r * 15) end,
        { partyHealPct = { 10,20,30 }, wsd = { 15,30,45 } })

    local c2_t2 = H.node(2, 1, 'hl_t2_c1', 'Pacifying Strike', 5, '+5..25 Subtle Blow & Target -5..25% Atk (45s)',
        function(r) return string.format('+%d Subtle Blow, Target -%d%% Atk', r * 5, r * 5) end,
        { subtleBlow = { 5,10,15,20,25 }, targetDebuffs = {{ effect = xi.effect.ATTACK_DOWN, power = { 5,10,15,20,25 }, duration = 45 }} })
    local c2_t3 = isMagDmg
        and H.stanceNode(3, 1, 'hl_t3_c1', 'Solace Harmony', 5, 'LightArts/Valiance', HEALER_STANCE_EFFECTS,
            { wsd = { 9,18,27,36,45 }, matt = { 10,20,30,40,50 }, zeroDesc = 'LightArts/Valiance: +9..45% WSD & +10..50 MAB' })
        or H.stanceNode(3, 1, 'hl_t3_c1', 'Solace Harmony', 5, 'LightArts/Valiance', HEALER_STANCE_EFFECTS,
            { wsd = { 9,18,27,36,45 }, tpBonus = { 60,120,180,240,300 }, zeroDesc = 'LightArts/Valiance: +9..45% WSD & +60..300 TP Bonus' })
    local c2_t4 = H.node(4, 1, 'hl_t4_c1', 'Sanctified Ward', 3, 'Stoneskin 250..500 & Party +80..240 TP',
        function(r) return string.format('Stoneskin %d, Party +%d TP', 125 + r * 125, r * 80) end,
        { partyTp = { 80,160,240 }, statusBuffs = {{ effect = xi.effect.STONESKIN, power = { 250,375,500 }, duration = 45, tier = 3 }} })

    local c3_t2 = H.elemFollow(2, 3, 'hl_t2_c3', 'Luminous Pulse', 'LIGHT', 'Light', 11, false)
    local c3_t3 = H.node(3, 3, 'hl_t3_c3', 'Mending Tempo', 5, '+70..350 TP Bonus & Target -6..30 M.Atk (45s)',
        function(r) return string.format('+%d TP Bonus, Target -%d M.Atk', r * 70, r * 6) end,
        { tpBonus = { 70,140,210,280,350 }, targetDebuffs = {{ effect = xi.effect.MAGIC_ATK_DOWN, power = { 6,12,18,24,30 }, duration = 45 }} })
    local c3_t4 = isMagDmg
        and H.node(4, 3, 'hl_t4_c3', 'Healer Mastery', 5, '+7..35% WSD, +8..40 MACC & -4..20 Enmity',
            function(r) return string.format('+%d%% WSD, +%d MACC, -%d Enmity', r * 7, r * 8, r * 4) end,
            { wsd = { 7,14,21,28,35 }, macc = { 8,16,24,32,40 }, enmity = { -4,-8,-12,-16,-20 } })
        or H.node(4, 3, 'hl_t4_c3', 'Healer Mastery', 5, '+7..35% WSD, Party Heal 2..10% & -4..20 Enmity',
            function(r) return string.format('+%d%% WSD, Party Heal %d%%, -%d Enmity', r * 7, r * 2, r * 4) end,
            { wsd = { 7,14,21,28,35 }, partyHealPct = { 2,4,6,8,10 }, enmity = { -4,-8,-12,-16,-20 } })

    return { t1c1, c1_t1, t1c3, c2_t2, c1_t2, c3_t2, c2_t3, c1_t3, c3_t3, c2_t4, c1_t4, c3_t4 }
end

-- Build 12-node (3x4) Commander tree for any WS
local function buildCommanderSpecNodes(wsId, archetype, baseNodes)
    local isNonPhys = isMagicOrUtilityWS(wsId, archetype)
    local t1c1 = makeScalingT1Col1(wsId, findGridNode(baseNodes, 1, 1), isNonPhys)
    local t1c3 = makePrimaryWscNode(wsId, 1, 3, 'cm_t1_c3', isNonPhys, nil)

    local c1_t1 = H.node(1, 2, 'cm_t1_c2', 'Rallying Cadence', 7, 'Party +35..245 TP & NextWS +4..28% WSD (15s)',
        function(r) return string.format('Party +%d TP, NextWS +%d%% WSD', r * 35, r * 4) end,
        { partyTp = { 35,70,105,140,175,210,245 }, nextWs = { wsd = { 4,8,12,16,20,24,28 }, dur = 15 } })
    local c1_t2 = H.node(2, 2, 'cm_t2_c2', 'Banner of War', 5, 'Party Warcry (+6..30% Atk, 25s) & +5..25% WSD',
        function(r) return string.format('Party +%d%% Atk (25s), +%d%% WSD', r * 6, r * 5) end,
        { wsd = { 5,10,15,20,25 }, partyBuffs = {{ effect = xi.effect.WARCRY, power = { 6,12,18,24,30 }, duration = 25 }} })
    local c1_t3 = H.node(3, 2, 'cm_t3_c2', 'Tactical Haste', 5, 'Party Haste +4..20% (25s) & +60..300 TP Bonus',
        function(r) return string.format('Party Haste +%d%% (25s), +%d TP', r * 4, r * 60) end,
        { tpBonus = { 60,120,180,240,300 }, partyBuffs = {{ effect = xi.effect.HASTE, power = { 400,800,1200,1600,2000 }, duration = 25 }} })
    local c1_t4 = H.node(4, 2, 'cm_t4_c2', 'Supreme Commander', 3, 'Party +100..300 TP, +15..45% WSD & +12..36% SC Dmg',
        function(r) return string.format('Party +%d TP, +%d%% WSD, +%d%% SC', r * 100, r * 15, r * 12) end,
        { partyTp = { 100,200,300 }, wsd = { 15,30,45 }, scBonus = { 12,24,36 } })

    local c2_t2 = H.node(2, 1, 'cm_t2_c1', 'Sunder Formation', 5, 'Target -5..25% DEF & -6..30 M.Def (45s)',
        function(r) return string.format('Target -%d%% DEF, -%d M.Def', r * 5, r * 6) end,
        { targetDebuffs = {
            { effect = xi.effect.DEFENSE_DOWN, power = { 5,10,15,20,25 }, duration = 45 },
            { effect = xi.effect.MAGIC_DEF_DOWN, power = { 6,12,18,24,30 }, duration = 45 },
        } })
    local isMagDmg = isMagicDamageWS(wsId)
    local c2_t3 = H.stanceNode(3, 1, 'cm_t3_c1', 'Command Presence', 5, 'Warcry/Berserk/Restraint', COMMANDER_STANCE_EFFECTS,
        isMagDmg and { wsd = { 9,18,27,36,45 }, matt = { 10,20,30,40,50 }, zeroDesc = 'Command Stance: +9..45% WSD & +10..50 MAB' }
            or (isNonPhys and { wsd = { 9,18,27,36,45 }, tpBonus = { 60,120,180,240,300 }, zeroDesc = 'Command Stance: +9..45% WSD & +60..300 TP' }
                or { wsd = { 9,18,27,36,45 }, atkPct = { 8,16,24,32,40 }, zeroDesc = 'Command Stance: +9..45% WSD & +8..40% Atk' }))
    local c2_t4 = H.node(4, 1, 'cm_t4_c1', 'Exposed Flank', 3, 'Target -15..45 EVA/MEVA & NextWS +120..360 TP',
        function(r) return string.format('Target -%d EVA/MEVA, NextWS +%d TP', r * 15, r * 120) end,
        { nextWs = { tp = { 120,240,360 }, dur = 15 }, targetDebuffs = {
            { effect = xi.effect.EVASION_DOWN, power = { 15,30,45 }, duration = 45 },
            { effect = xi.effect.MAGIC_EVASION_DOWN, power = { 15,30,45 }, duration = 45 },
        } })

    local c3_t2 = isMagDmg
        and H.node(2, 3, 'cm_t2_c3', 'Arcane Volley', 5, '+9..45 MAB & +9..45 MACC',
            function(r) return string.format('+%d MAB, +%d MACC', r * 9, r * 9) end,
            { matt = { 9,18,27,36,45 }, macc = { 9,18,27,36,45 } })
        or (isNonPhys
            and H.node(2, 3, 'cm_t2_c3', 'Tactical Volley', 5, '+6..30% WSD & Party +40..200 TP',
                function(r) return string.format('+%d%% WSD, Party +%d TP', r * 6, r * 40) end,
                { wsd = { 6,12,18,24,30 }, partyTp = { 40,80,120,160,200 } })
            or H.node(2, 3, 'cm_t2_c3', 'Vanguard Strike', 5, '+9..45% WS Atk & +9..45 Acc',
                function(r) return string.format('+%d%% WS Atk, +%d Acc', r * 9, r * 9) end,
                { atkPct = { 9,18,27,36,45 }, acc = { 9,18,27,36,45 } }))
    local c3_t3 = isNonPhys
        and H.node(3, 3, 'cm_t3_c3', 'Resonant Chain', 5, '+8..40% SC Dmg & +0.25..1.25 fTP',
            function(r) return string.format('+%d%% SC Dmg, +%.2f fTP', r * 8, r * 0.25) end,
            { scBonus = { 8,16,24,32,40 }, ftpAdd = { 0.25,0.50,0.75,1.00,1.25 } })
        or H.node(3, 3, 'cm_t3_c3', 'Coordinated Assault', 5, '+1 Bonus Hit & +8..40% SC Dmg',
            function(r) return string.format('+1 Hit, +%d%% SC Dmg', r * 8) end,
            { bonusHits = { 1,1,1,1,1 }, scBonus = { 8,16,24,32,40 } })
    local c3_t4 = H.node(4, 3, 'cm_t4_c3', 'Commander Mastery', 5, '+7..35% WSD & Party +5..25% Crit (20s)',
        function(r) return string.format('+%d%% WSD, Party +%d%% Crit (20s)', r * 7, r * 5) end,
        { wsd = { 7,14,21,28,35 }, partyBuffs = {{ effect = xi.effect.POTENCY, power = { 5,10,15,20,25 }, duration = 20 }} })

    return { t1c1, c1_t1, t1c3, c2_t2, c1_t2, c3_t2, c2_t3, c1_t3, c3_t3, c2_t4, c1_t4, c3_t4 }
end

-- Build 12-node (3x4) Berserker / DPS tree for any WS (preserving bespoke DPS nodes and filling missing Col 3 slots)
local function buildBerserkerSpecNodes(wsId, archetype, baseNodes)
    local isNonPhys, wsKind = isMagicOrUtilityWS(wsId, archetype)
    local isMagDmg = isMagicDamageWS(wsId)
    local out = {}
    local grid = { {}, {}, {}, {} }

    for _, raw in ipairs(baseNodes or {}) do
        local n = copyTable(raw)
        if isNonPhys then
            n = sanitizeNodeForNonPhysical(n, wsId, wsKind)
        end
        if grid[n.tier] and grid[n.tier][n.col] == nil then
            grid[n.tier][n.col] = n
            table.insert(out, n)
        end
    end

    -- Ensure all 12 positions (Tier 1..4 x Col 1..3) are populated
    if grid[1][1] == nil then
        grid[1][1] = makeScalingT1Col1(wsId, nil, isNonPhys)
        table.insert(out, grid[1][1])
    end
    if grid[1][2] == nil then
        grid[1][2] = isMagDmg
            and H.node(1, 2, 'zk_t1_c2', 'Arcane Surge', 7, '+8..56 MAB & +7..49 MACC',
                function(r) return string.format('+%d MAB, +%d MACC', r * 8, r * 7) end,
                { matt = { 8,16,24,32,40,48,56 }, macc = { 7,14,21,28,35,42,49 } })
            or (isNonPhys
                and H.node(1, 2, 'zk_t1_c2', 'Resonant Surge', 7, '+5..35% WSD & +45..315 TP Bonus',
                    function(r) return string.format('+%d%% WSD, +%d TP', r * 5, r * 45) end,
                    { wsd = { 5,10,15,20,25,30,35 }, tpBonus = { 45,90,135,180,225,270,315 } })
                or H.node(1, 2, 'zk_t1_c2', 'Fury Opener', 7, '+7..49% WS Atk & +4..28% WSD',
                    function(r) return string.format('+%d%% Atk, +%d%% WSD', r * 7, r * 4) end,
                    { atkPct = { 7,14,21,28,35,42,49 }, wsd = { 4,8,12,16,20,24,28 } }))
        table.insert(out, grid[1][2])
    end
    if grid[1][3] == nil then
        grid[1][3] = makePrimaryWscNode(wsId, 1, 3, 'zk_t1_c3', isNonPhys, nil)
        table.insert(out, grid[1][3])
    end

    if grid[2][3] == nil then
        grid[2][3] = isMagDmg
            and H.node(2, 3, 'zk_t2_c3', 'Overwhelming Arcana', 5, '+9..45 MAB, +5..25% WSD & +50..250 TP Bonus',
                function(r) return string.format('+%d MAB, +%d%% WSD, +%d TP', r * 9, r * 5, r * 50) end,
                { matt = { 9,18,27,36,45 }, wsd = { 5,10,15,20,25 }, tpBonus = { 50,100,150,200,250 } })
            or (isNonPhys
                and H.node(2, 3, 'zk_t2_c3', 'Overwhelming Force', 5, '+7..35% WSD & +60..300 TP Bonus',
                    function(r) return string.format('+%d%% WSD, +%d TP', r * 7, r * 60) end,
                    { wsd = { 7,14,21,28,35 }, tpBonus = { 60,120,180,240,300 } })
                or H.node(2, 3, 'zk_t2_c3', 'Armor Sundering', 5, 'Ignores 6..30% DEF & +5..25% WSD',
                    function(r) return string.format('Ignores %d%% DEF, +%d%% WSD', r * 6, r * 5) end,
                    { defIgnore = { 0.06,0.12,0.18,0.24,0.30 }, wsd = { 5,10,15,20,25 } }))
        table.insert(out, grid[2][3])
    end

    if grid[3][3] == nil then
        local eleUpper, eleName = getDefaultElement(wsId)
        grid[3][3] = isNonPhys
            and H.elemFollow(3, 3, 'zk_t3_c3', eleName .. ' Detonation', eleUpper, eleName, 12, false)
            or H.node(3, 3, 'zk_t3_c3', 'Bloodbath Momentum', 5, '+5..25% Crit, +6..30% Crit Dmg & 5..25% HP Drain',
                function(r) return string.format('+%d%% Crit, +%d%% CrDmg, %d%% Drain', r * 5, r * 6, r * 5) end,
                { crit = { 5,10,15,20,25 }, critDmg = { 6,12,18,24,30 }, hpDrain = { 5,10,15,20,25 } })
        table.insert(out, grid[3][3])
    end

    if grid[4][3] == nil then
        grid[4][3] = isNonPhys
            and H.node(4, 3, 'zk_t4_c3', 'Cataclysmic Apex', 5, '+0.3..1.5 fTP, +7..35% WSD & +8..40% SC Dmg',
                function(r) return string.format('+%.1f fTP, +%d%% WSD, +%d%% SC', r * 0.3, r * 7, r * 8) end,
                { ftpAdd = { 0.3,0.6,0.9,1.2,1.5 }, wsd = { 7,14,21,28,35 }, scBonus = { 8,16,24,32,40 } })
            or H.node(4, 3, 'zk_t4_c3', 'Berserker Apex', 5, '+1 Bonus Hit, fTP ALL Hits & +6..30% WSD',
                function(r) return string.format('+1 Hit, fTP ALL, +%d%% WSD', r * 6) end,
                { bonusHits = { 1,1,1,1,1 }, multiHitfTPAt = 1, wsd = { 6,12,18,24,30 } })
        table.insert(out, grid[4][3])
    end

    return out
end

function H.regSpec(wsId, archetype, specNodes, opts)
    opts = opts or {}
    local isNonPhys, wsKind = isMagicOrUtilityWS(wsId, archetype)
    local cleaned = {}
    for specCat, list in pairs(specNodes or {}) do
        cleaned[specCat] = {}
        for _, n in ipairs(list or {}) do
            table.insert(cleaned[specCat], isNonPhys and sanitizeNodeForNonPhysical(n, wsId, wsKind) or n)
        end
    end
    talents.registerCustomWS(wsId,
    {
        archetype   = archetype,
        useBaseline = opts.useBaseline == true,
        specNodes   = cleaned,
        nodes       = cleaned.berserker or cleaned.tank or {},
    })
end

function H.reg(wsId, archetype, nodes)
    local specNodes =
    {
        berserker  = buildBerserkerSpecNodes(wsId, archetype, nodes),
        commander  = buildCommanderSpecNodes(wsId, archetype, nodes),
        tank       = buildTankSpecNodes(wsId, archetype, nodes),
        spellblade = buildSpellbladeSpecNodes(wsId, archetype, nodes),
        healer     = buildHealerSpecNodes(wsId, archetype, nodes),
    }
    H.regSpec(wsId, archetype, specNodes, { useBaseline = false })
end

function H.regBaseline(wsId, archetype, nodes)
    local ws = catalog and catalog.byId and catalog.byId[wsId]
    local skill = ws and ws.skill or 0

    -- Throwing (#241-#252) is Dancer Bladewheel's dedicated 3x4 tree
    if skill == xi.skill.THROWING then
        local isNonPhys, wsKind = isMagicOrUtilityWS(wsId, archetype)
        local cleaned = {}
        for _, n in ipairs(nodes or {}) do
            table.insert(cleaned, isNonPhys and sanitizeNodeForNonPhysical(n, wsId, wsKind) or n)
        end
        talents.registerCustomWS(wsId,
        {
            archetype   = archetype,
            useBaseline = true,
            nodes       = cleaned,
        })
        return
    end

    -- Club & Staff: Col 1 is bespoke Tank (Gladiator/Sensei), Col 2 is bespoke Scholar, Col 3 is bespoke WAR/DPS
    local tankNodes = buildTankSpecNodes(wsId, archetype, nodes)
    local healNodes = buildHealerSpecNodes(wsId, archetype, nodes)
    local sbNodes   = buildSpellbladeSpecNodes(wsId, archetype, nodes)
    local cmdNodes  = buildCommanderSpecNodes(wsId, archetype, nodes)
    local zerkNodes = buildBerserkerSpecNodes(wsId, archetype, nodes)

    -- Preserve the bespoke Club/Staff Col 1/2/3 nodes in their respective spec trees' Col 1!
    local function injectColumn1FromBespoke(targetList, bespokeCol)
        for tier = 1, 4 do
            local bNode = findGridNode(nodes, tier, bespokeCol)
            if bNode ~= nil then
                for idx, tn in ipairs(targetList) do
                    if tn.tier == tier and tn.col == 1 then
                        targetList[idx] = rekeyNode(bNode, tier, 1, bNode.key)
                        break
                    end
                end
            end
        end
    end

    injectColumn1FromBespoke(tankNodes, 1)
    injectColumn1FromBespoke(healNodes, 2)
    injectColumn1FromBespoke(sbNodes,   2)
    injectColumn1FromBespoke(cmdNodes,  3)

    H.regSpec(wsId, archetype,
    {
        tank       = tankNodes,
        healer     = healNodes,
        spellblade = sbNodes,
        commander  = cmdNodes,
        berserker  = zerkNodes,
    }, { useBaseline = true })
end

-- Upgrade H2H (#1-#15) trees registered in overlords_ws_talents.lua to full 5-spec 3x4 trees
function H.upgradeExistingCustomRange(minWsId, maxWsId)
    local customMap = talents._customTrees or {}
    for wsId = minWsId, maxWsId do
        local cur = customMap[wsId]
        if cur ~= nil and cur.specNodes == nil and cur.nodes ~= nil then
            H.reg(wsId, cur.archetype or 'heavy', cur.nodes)
        end
    end
end

-- Common bespoke building blocks with exact data-driven tooltips + effects
function H.echo(key, name, wsdStep, tpStep)
    local wStep = wsdStep or 5
    local tStep = tpStep or 60
    local wTbl = { wStep, wStep * 2, wStep * 3, wStep * 4, wStep * 5 }
    local tTbl = { tStep, tStep * 2, tStep * 3, tStep * 4, tStep * 5 }
    return H.node(3, 2, key or 'aftermath_echo', name or 'Relic Echo', 5,
        string.format('+%d..%d%% WSD & +%d..%d TP Bonus', wStep, wStep * 5, tStep, tStep * 5),
        function(r) return string.format('+%d%% WSD, +%d TP Bonus', r * wStep, r * tStep) end,
        { wsd = wTbl, tpBonus = tTbl })
end

function H.atkAcc(tier, col, key, name, atkStep, accStep, req)
    local aTbl, cTbl = {}, {}
    for i = 1, 5 do
        aTbl[i] = i * atkStep
        cTbl[i] = i * accStep
    end
    return H.node(tier, col, key, name, 5,
        string.format('+%d..%d%% WS Atk & +%d..%d Acc', atkStep, atkStep * 5, accStep, accStep * 5),
        function(r) return string.format('+%d%% WS Atk, +%d Acc', r * atkStep, r * accStep) end,
        { atkPct = aTbl, acc = cTbl }, req)
end

function H.wsdAcc(tier, col, key, name, wsdStep, accStep, req)
    local wTbl, cTbl = {}, {}
    for i = 1, 5 do
        wTbl[i] = i * wsdStep
        cTbl[i] = i * accStep
    end
    return H.node(tier, col, key, name, 5,
        string.format('+%d..%d%% WSD & +%d..%d Acc', wsdStep, wsdStep * 5, accStep, accStep * 5),
        function(r) return string.format('+%d%% WSD, +%d Acc', r * wsdStep, r * accStep) end,
        { wsd = wTbl, acc = cTbl }, req)
end

function H.critMast(tier, col, key, name, crStep, cdStep)
    local crTbl, cdTbl = {}, {}
    for i = 1, 5 do
        crTbl[i] = i * crStep
        cdTbl[i] = i * cdStep
    end
    return H.node(tier, col, key, name, 5,
        string.format('+%d..%d%% Crit & +%d..%d%% Crit Dmg', crStep, crStep * 5, cdStep, cdStep * 5),
        function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * crStep, r * cdStep) end,
        { crit = crTbl, critDmg = cdTbl })
end

function H.mabMacc(tier, col, key, name, mabStep, maccStep, wsdStep)
    local mTbl, aTbl, wTbl = {}, {}, wsdStep and {} or nil
    for i = 1, 5 do
        mTbl[i] = i * mabStep
        aTbl[i] = i * maccStep
        if wTbl then
            wTbl[i] = i * wsdStep
        end
    end
    local zero = wTbl and string.format('+%d..%d MAB/MACC & +%d..%d%% WSD', mabStep, mabStep * 5, wsdStep, wsdStep * 5)
        or string.format('+%d..%d MAB & +%d..%d MACC', mabStep, mabStep * 5, maccStep, maccStep * 5)
    return H.node(tier, col, key, name, 5, zero,
        function(r)
            if wTbl then
                return string.format('+%d MAB, +%d MACC, +%d%% WSD', r * mabStep, r * maccStep, r * wsdStep)
            end
            return string.format('+%d MAB, +%d MACC', r * mabStep, r * maccStep)
        end,
        { matt = mTbl, macc = aTbl, wsd = wTbl })
end

function H.rangedAtkAcc(tier, col, key, name, atkStep, raccStep)
    local aTbl, rTbl = {}, {}
    for i = 1, 5 do
        aTbl[i] = i * atkStep
        rTbl[i] = i * raccStep
    end
    return H.node(tier, col, key, name, 5,
        string.format('+%d..%d%% R.Atk & +%d..%d R.Acc', atkStep, atkStep * 5, raccStep, raccStep * 5),
        function(r) return string.format('+%d%% R.Atk, +%d R.Acc', r * atkStep, r * raccStep) end,
        { atkPct = aTbl, racc = rTbl })
end

function H.multiFtp(tier, col, key, name, wsdStep, atkStep)
    local wTbl = wsdStep and {} or nil
    local aTbl = atkStep and {} or nil
    for i = 1, 4 do
        if wTbl then wTbl[i] = i * wsdStep end
        if aTbl then aTbl[i] = i * atkStep end
    end
    if wTbl then wTbl[5] = 4 * wsdStep end
    if aTbl then aTbl[5] = 4 * atkStep end
    local label = wTbl and string.format('+%d%% WSD', wsdStep * 4) or string.format('+%d%% Atk', atkStep * 4)
    return H.node(tier, col, key, name, 5,
        string.format('R1-4:%s | R5:fTP ALL Hits!', label),
        function(r)
            if r >= 5 then
                return string.format('fTP ALL HITS + %s (MAX)', label)
            end
            return wTbl and string.format('+%d%% WSD (R5:fTP all hits)', r * wsdStep)
                or string.format('+%d%% Atk (R5:fTP all hits)', r * atkStep)
        end,
        { wsd = wTbl, atkPct = aTbl, multiHitfTPAt = 5 })
end

function H.elemFollow(tier, col, key, name, ele, dmgName, pctStep, packScale)
    local pTbl = {}
    for i = 1, 5 do pTbl[i] = i * pctStep end
    return H.node(tier, col, key, name, 5,
        string.format('%s follow-up (%d..%d%%%s)', dmgName, pctStep, pctStep * 5, packScale and ' +pack' or ''),
        function(r)
            return string.format('%s +%d%% follow-up%s', dmgName, r * pctStep, packScale and ' (+pack)' or '')
        end,
        { elemFollow = { ele = ele, pct = pTbl, scaleWithPack = packScale } })
end

function H.stanceNode(tier, col, key, name, maxRank, stanceLabel, effects, opts)
    opts = opts or {}
    local wsd = opts.wsd
    local atk = opts.atkPct
    local cr  = opts.crit
    local cd  = opts.critDmg
    local tp  = opts.tpBonus
    local mab = opts.matt
    local mac = opts.macc
    local di  = opts.defIgnore
    local schSpec = opts.schSpec
    return H.node(tier, col, key, name, maxRank,
        opts.zeroDesc or string.format('%s: +%s', stanceLabel, opts.summary or 'Stance bonus'),
        opts.rankDesc or function(r)
            local parts = {}
            if wsd then table.insert(parts, string.format('+%d%% WSD', pick(wsd, r))) end
            if atk then table.insert(parts, string.format('+%d%% Atk', pick(atk, r))) end
            if cr  then table.insert(parts, string.format('+%d%% Crit', pick(cr, r))) end
            if cd  then table.insert(parts, string.format('+%d%% CrDmg', pick(cd, r))) end
            if mab then table.insert(parts, string.format('+%d MAB', pick(mab, r))) end
            if mac then table.insert(parts, string.format('+%d MACC', pick(mac, r))) end
            if di  then table.insert(parts, string.format('-%d%% DEF', math.floor(pick(di, r) * 100 + 0.5))) end
            if tp  then table.insert(parts, string.format('+%d TP', pick(tp, r))) end
            return string.format('%s: %s', stanceLabel, table.concat(parts, ', '))
        end,
        {
            stance =
            {
                effects   = effects,
                schSpec   = schSpec,
                jobSpec   = opts.jobSpec,
                petAlive  = opts.petAlive,
                wsd       = wsd,
                atkPct    = atk,
                crit      = cr,
                tpBonus   = tp,
                matt      = mab,
                macc      = mac,
                critDmg   = cd,
                defIgnore = di,
                ftpAdd    = opts.ftpAdd,
            },
        }, opts.requires)
end

function H.hits(tier, col, key, name, hitSeq, atkStep, accStep, zeroDesc)
    local mr = #hitSeq
    local aTbl = atkStep and {} or nil
    local cTbl = accStep and {} or nil
    for i = 1, mr do
        if aTbl then aTbl[i] = i * atkStep end
        if cTbl then cTbl[i] = i * accStep end
    end
    local targetH = hitSeq[mr]
    local zd = zeroDesc or string.format('Rebuild 1->%d Hits%s%s', targetH,
        atkStep and string.format(' & +%d..%d%% Atk', atkStep, atkStep * mr) or '',
        accStep and string.format(' & +%d..%d Acc', accStep, accStep * mr) or '')
    return H.node(tier, col, key, name, mr, zd,
        function(r)
            local h = hitSeq[r] or targetH
            local p = { string.format('Hits: 1->%d', h) }
            if aTbl then table.insert(p, string.format('+%d%% Atk', aTbl[r])) end
            if cTbl then table.insert(p, string.format('+%d Acc', cTbl[r])) end
            return table.concat(p, ', ')
        end,
        { hits = hitSeq, atkPct = aTbl, acc = cTbl })
end

function H.cap(key, name, zeroDesc, rankDesc, effect, req)
    return H.node(4, 1, key or 'capstone', name, 3, zeroDesc, rankDesc, effect, req or { key = 'ftp', rank = 2 })
end

function H.mast(key, name, maxRank, zeroDesc, rankDesc, effect)
    if type(maxRank) == 'string' then
        return H.node(4, 2, key, name, 5, maxRank, zeroDesc, rankDesc)
    end
    return H.node(4, 2, key, name, maxRank or 5, zeroDesc, rankDesc, effect)
end

function H.utilFtp(name, zeroDesc, rankDesc, effect)
    return H.node(1, 1, 'ftp', name, 6, zeroDesc, rankDesc, effect)
end

H.pick = pick
H.buildTankSpecNodes       = buildTankSpecNodes
H.buildSpellbladeSpecNodes = buildSpellbladeSpecNodes
H.buildHealerSpecNodes     = buildHealerSpecNodes
H.buildCommanderSpecNodes  = buildCommanderSpecNodes
H.buildBerserkerSpecNodes  = buildBerserkerSpecNodes

return H
