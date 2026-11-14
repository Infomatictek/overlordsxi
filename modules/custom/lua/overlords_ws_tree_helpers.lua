-----------------------------------
-- OverlordsXI Bespoke WS Tree Helpers
-- Compact builders for 4-tier (56-pt) bespoke WS trees.
-----------------------------------
local talents = xi.overlords.wsTalents
local makeFtp = talents.makeCustomFtpNode
local makeNode = talents.makeSpecNode

local H = {}

local function pick(tbl, r)
    return tbl[r] or tbl[#tbl]
end

function H.reg(wsId, archetype, nodes)
    talents.registerCustomWS(wsId,
    {
        archetype = archetype,
        nodes     = nodes,
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
            if di  then table.insert(parts, string.format('-%d%% DEF', pick(di, r))) end
            if tp  then table.insert(parts, string.format('+%d TP', pick(tp, r))) end
            return string.format('%s: %s', stanceLabel, table.concat(parts, ', '))
        end,
        {
            stance =
            {
                effects   = effects,
                schSpec   = schSpec,
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
return H
