-----------------------------------
-- OverlordsXI Weaponskill Talent System
--
-- - All player weaponskills are unlocked at level 1 (via patch 0003).
-- - Base weaponskills for PCs are normalized to fTP 1.0 and 0 WSC.
-- - Players earn 1 talent point per main job level (starting at 1 at Lv 1).
-- - Each weaponskill has a tailored talent tree based on what that WS originally was.
-----------------------------------
require('modules/custom/lua/overlords_ws_catalog')
-----------------------------------
xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.wsTalents = xi.overlords.wsTalents or {}

local talents = xi.overlords.wsTalents
local catalog = xi.overlords.wsCatalog

local VAR_PREFIX = 'OX_WST_'
local PROTO_TAG  = '[OXTAL]|'
local MAX_MSG    = 135

local JOB_KEYS =
{
    [xi.job.WAR] = 'WAR',
    [xi.job.MNK] = 'MNK',
    [xi.job.WHM] = 'WHM',
    [xi.job.BLM] = 'BLM',
    [xi.job.RDM] = 'RDM',
    [xi.job.THF] = 'THF',
    [xi.job.PLD] = 'PLD',
    [xi.job.DRK] = 'DRK',
    [xi.job.BST] = 'BST',
    [xi.job.BRD] = 'BRD',
    [xi.job.RNG] = 'RNG',
    [xi.job.SAM] = 'SAM',
    [xi.job.NIN] = 'NIN',
    [xi.job.DRG] = 'DRG',
    [xi.job.SMN] = 'SMN',
    [xi.job.BLU] = 'BLU',
    [xi.job.COR] = 'COR',
    [xi.job.PUP] = 'PUP',
    [xi.job.DNC] = 'DNC',
    [xi.job.SCH] = 'SCH',
    [xi.job.GEO] = 'GEO',
    [xi.job.RUN] = 'RUN',
}

local STAT_LABELS =
{
    str = 'STR',
    dex = 'DEX',
    vit = 'VIT',
    agi = 'AGI',
    int = 'INT',
    mnd = 'MND',
    chr = 'CHR',
}

local STAT_ORDER = { 'str', 'dex', 'vit', 'agi', 'int', 'mnd', 'chr' }

local function round2(v)
    return math.floor(v * 100 + 0.5) / 100
end

local function fmtPct(v)
    return string.format('%d%%', math.floor(v * 100 + 0.5))
end

local function sanitizeField(text)
    local s = tostring(text or '')
    s = string.gsub(s, '|', '/')
    s = string.gsub(s, '[\r\n]', ' ')
    return s
end

local function sendProto(player, payload)
    if player == nil then
        return
    end

    player:printToPlayer(PROTO_TAG .. payload, xi.msg.channel.SYSTEM_3, '')
end

-----------------------------------
-- Persistence (3 bits per slot, up to 10 slots / 30 bits per WS)
-----------------------------------
function talents.getJobKey(jobId)
    return JOB_KEYS[jobId] or string.format('J%u', jobId or 0)
end

function talents.getVarPrefix(jobId)
    return VAR_PREFIX .. talents.getJobKey(jobId) .. '_'
end

function talents.getVarName(jobId, wsId)
    return string.format('%s%u', talents.getVarPrefix(jobId), wsId)
end

local function unpackSlot(packed, slot)
    local shift = 8 ^ (slot - 1)
    return math.floor((packed or 0) / shift) % 8
end

local function packSlot(packed, slot, rank)
    local shift = 8 ^ (slot - 1)
    local oldRank = math.floor((packed or 0) / shift) % 8
    return (packed or 0) + (rank - oldRank) * shift
end

-----------------------------------
-- Dynamic Per-WS Tree Generation
-----------------------------------
local treeCache = {}

talents.STAT_ORDER = STAT_ORDER

function talents.calcFtpAtRank(origFtp, rank)
    local out = { 1.0, 1.0, 1.0 }
    if rank <= 0 then
        return out
    end

    for i = 1, 3 do
        local origVal = (origFtp and origFtp[i]) or 1.0
        if origVal > 1.0 then
            local scale = rank * 0.20 + (rank == 5 and 0.15 or 0)
            out[i] = round2(1.0 + (origVal - 1.0) * scale)
        else
            local step = 0.15 + (i - 1) * 0.10
            out[i] = round2(1.0 + rank * step)
        end
    end

    return out
end

function talents.calcWscAtRank(origWeight, rank)
    if rank <= 0 then
        return 0
    end

    local maxWsc = math.max((origWeight or 0) * 1.25, 0.50)
    return round2(maxWsc * (rank / 5))
end

function talents.calcScaledTable(origTbl, rank, minPerRank)
    if rank <= 0 then
        return nil
    end

    local mults = { 0.34, 0.67, 1.20 }
    local mFactor = mults[rank] or 0
    local out = {}
    for i = 1, 3 do
        local baseVal = (origTbl and origTbl[i]) or 0
        local minFloor = minPerRank and (minPerRank[i] * rank) or 0
        out[i] = round2(math.max(baseVal * mFactor, minFloor))
    end

    return out
end

function talents.calcAtkScaleAtRank(origAtk, rank)
    if rank <= 0 then
        return 0
    end

    local mults = { 0.34, 0.67, 1.20 }
    local mFactor = mults[rank] or 0
    local out = {}
    for i = 1, 3 do
        local origBonus = math.max(0, ((origAtk and origAtk[i]) or 1.0) - 1.0)
        local bonus = math.max(origBonus * mFactor, 0.10 * rank)
        out[i] = round2(bonus)
    end

    return out
end

local calcFtpAtRank = talents.calcFtpAtRank
local calcWscAtRank = talents.calcWscAtRank
local calcScaledTable = talents.calcScaledTable
local calcAtkScaleAtRank = talents.calcAtkScaleAtRank

local SC_IDS =
{
    NONE          = 0,
    TRANSFIXION   = 1,
    COMPRESSION   = 2,
    LIQUEFACTION  = 3,
    SCISSION      = 4,
    REVERBERATION = 5,
    DETONATION    = 6,
    INDURATION    = 7,
    IMPACTION     = 8,
    GRAVITATION   = 9,
    DISTORTION    = 10,
    FUSION        = 11,
    FRAGMENTATION = 12,
    LIGHT         = 13,
    DARKNESS      = 14,
}

local SC_SHORT =
{
    TRANSFIXION   = 'Transfix',
    COMPRESSION   = 'Compress',
    LIQUEFACTION  = 'Liquefac',
    SCISSION      = 'Scission',
    REVERBERATION = 'Reverb',
    DETONATION    = 'Detonat',
    INDURATION    = 'Indurat',
    IMPACTION     = 'Impact',
    GRAVITATION   = 'Gravit',
    DISTORTION    = 'Distort',
    FUSION        = 'Fusion',
    FRAGMENTATION = 'Frag',
    LIGHT         = 'Light',
    DARKNESS      = 'Dark',
}

local DARK_SC_SET =
{
    COMPRESSION   = true,
    SCISSION      = true,
    REVERBERATION = true,
    INDURATION    = true,
    GRAVITATION   = true,
    DISTORTION    = true,
    DARKNESS      = true,
}

local function hasSc(list, name)
    for _, v in ipairs(list or {}) do
        if v == name then
            return true
        end
    end
    return false
end

local function isDarkAligned(ws)
    if ws.elementName == 'Dark' or ws.key == 'sanguine_blade' or ws.key == 'energy_steal' or ws.key == 'energy_drain' or ws.key == 'catastrophe' then
        return true
    end
    if ws.elementName == 'Earth' or ws.elementName == 'Water' or ws.elementName == 'Ice' then
        return true
    end
    local sc = (ws.orig and ws.orig.skillchain) or {}
    if #sc > 0 then
        return DARK_SC_SET[sc[1]] == true
    end
    return false
end

local function formatScNames(names)
    local parts = {}
    for _, n in ipairs(names or {}) do
        table.insert(parts, SC_SHORT[n] or n)
    end
    return #parts > 0 and table.concat(parts, '/') or 'None'
end

local scPlanCache = {}

function talents.getSkillchainPlan(ws)
    if ws == nil then
        return nil
    end
    if ws.orig and ws.orig.restoreMp then
        return nil
    end
    if scPlanCache[ws.id] ~= nil then
        return scPlanCache[ws.id]
    end

    local origSc = (ws.orig and ws.orig.skillchain) or {}
    local dark = isDarkAligned(ws)

    local r1, r2, r3
    if #origSc == 0 then
        if dark then
            r1 = { 'COMPRESSION' }
            r2 = { 'COMPRESSION', 'GRAVITATION' }
            r3 = { 'COMPRESSION', 'GRAVITATION', 'DARKNESS' }
        else
            r1 = { 'TRANSFIXION' }
            r2 = { 'TRANSFIXION', 'FUSION' }
            r3 = { 'TRANSFIXION', 'FUSION', 'LIGHT' }
        end
    else
        local lv2
        if dark then
            lv2 = not hasSc(origSc, 'GRAVITATION') and 'GRAVITATION' or 'DISTORTION'
        else
            lv2 = not hasSc(origSc, 'FUSION') and 'FUSION' or 'FRAGMENTATION'
        end

        local lv3
        if dark then
            lv3 = not hasSc(origSc, 'DARKNESS') and 'DARKNESS' or 'LIGHT'
        else
            lv3 = not hasSc(origSc, 'LIGHT') and 'LIGHT' or 'DARKNESS'
        end

        if #origSc == 1 then
            r1 = { origSc[1], lv2 }
            r2 = { origSc[1], lv2, lv3 }
            r3 = { origSc[1], lv2, lv3 }
        elseif #origSc == 2 then
            r1 = { origSc[1], origSc[2], lv2 }
            r2 = { origSc[1], origSc[2], lv3 }
            r3 = { origSc[1], lv2, lv3 }
        else
            r1 = { origSc[1], origSc[2], lv2 }
            r2 = { origSc[1], origSc[2], lv3 }
            r3 = { origSc[1], lv2, lv3 }
        end
    end

    local plan =
    {
        base = origSc,
        ranks = { r1, r2, r3 },
        bonusPct = { 10, 20, 35 },
    }
    scPlanCache[ws.id] = plan
    return plan
end

function talents.getSkillchainAtRank(ws, rank)
    local plan = talents.getSkillchainPlan(ws)
    if plan == nil or (rank or 0) <= 0 then
        return nil
    end

    local props = plan.ranks[math.min(rank, 3)]
    local bonus = plan.bonusPct[math.min(rank, 3)] or 0
    local function toId(name)
        if name == nil then
            return 0
        end
        if xi and xi.skillchainType and xi.skillchainType[name] then
            return xi.skillchainType[name]
        end
        return SC_IDS[name] or 0
    end

    return
    {
        names = props,
        sc1 = toId(props[1]),
        sc2 = toId(props[2]),
        sc3 = toId(props[3]),
        scBonus = bonus,
    }
end

local function determineArchetype(ws)
    local orig = ws.orig
    if ws.wsType == 'utility' then
        return 'utility'
    elseif ws.wsType == 'magic' or ws.wsType == 'hybrid' or ws.element ~= nil or orig.drainHp then
        return 'magic'
    elseif orig.critVaries ~= nil then
        return 'crit'
    elseif orig.numHits >= 2 then
        return 'multihit'
    end

    return 'heavy'
end

local T2_SLOTS = { 5, 6, 9 }

local function buildTreeForWS(ws)
    local orig = ws.orig
    local nodes = {}
    local archetype = determineArchetype(ws)

    -- Tier 1, Col 1 (Slot 1): fTP Scaling
    table.insert(nodes,
    {
        slot = 1,
        key = 'ftp',
        name = 'TP Scaling',
        tier = 1,
        col = 1,
        reqWsPoints = 0,
        maxRank = 5,
        describe = function(rank)
            local f = calcFtpAtRank(orig.ftp, rank)
            local nxt = rank < 5 and calcFtpAtRank(orig.ftp, rank + 1) or nil
            local curStr = string.format('fTP: %.2f/%.2f/%.2f', f[1], f[2], f[3])
            if nxt then
                return string.format('%s | Next: %.2f/%.2f', curStr, nxt[1], nxt[3])
            end
            return curStr .. ' (MAX)'
        end,
    })

    -- Tier 1, Col 2..4 (Slots 2..4): Original Stat WSC (or Utility Potency)
    local nextCol = 2
    local wscSlot = 2
    local hasWsc = false
    for _, stat in ipairs(STAT_ORDER) do
        local weight = orig.wsc[stat]
        if weight ~= nil and weight > 0 and wscSlot <= 4 then
            hasWsc = true
            local statUpper = STAT_LABELS[stat]
            local capturedStat = stat
            local capturedWeight = weight
            table.insert(nodes,
            {
                slot = wscSlot,
                key = 'wsc_' .. capturedStat,
                stat = capturedStat,
                origWeight = capturedWeight,
                name = statUpper .. ' WSC',
                tier = 1,
                col = nextCol,
                reqWsPoints = 0,
                maxRank = 5,
                describe = function(rank)
                    local cur = calcWscAtRank(capturedWeight, rank)
                    local nxt = rank < 5 and calcWscAtRank(capturedWeight, rank + 1) or nil
                    if nxt then
                        return string.format('%s WSC %s (orig %s) | Next: %s', statUpper, fmtPct(cur), fmtPct(capturedWeight), fmtPct(nxt))
                    end
                    return string.format('%s WSC %s (MAX)', statUpper, fmtPct(cur))
                end,
            })
            wscSlot = wscSlot + 1
            nextCol = nextCol + 1
        end
    end

    if not hasWsc then
        table.insert(nodes,
        {
            slot = 2,
            key = 'potency',
            name = 'Potency Scaling',
            tier = 1,
            col = 2,
            reqWsPoints = 0,
            maxRank = 5,
            describe = function(rank)
                local cur = rank * 20
                if rank < 5 then
                    return string.format('+%d%% HP/MP potency | Next: +%d%%', cur, (rank + 1) * 20)
                end
                return string.format('+%d%% HP/MP potency (MAX)', cur)
            end,
        })
    end

    -- Tier 2 (Slots 5, 6, 9, requires >= 3 pts in this WS, prereq ftp >= 1)
    local t2Idx = 1

    local function addT2Node(node)
        if t2Idx > #T2_SLOTS then
            return
        end
        node.slot = T2_SLOTS[t2Idx]
        node.tier = 2
        node.col = t2Idx
        node.reqWsPoints = 3
        node.requires = { key = 'ftp', rank = 1 }
        table.insert(nodes, node)
        t2Idx = t2Idx + 1
    end

    -- Priority 1: Unique WS signature traits based on what the WS originally did
    if orig.drainHp then
        addT2Node(
        {
            key = 'siphon',
            name = ws.key == 'sanguine_blade' and 'Crimson Siphon' or 'Soul Siphon',
            maxRank = 3,
            describe = function(rank)
                local pcts = { 15, 30, 50 }
                if rank == 0 then
                    return '+15/30/50% HP Drain & drains dmg as MP'
                end
                local p = pcts[rank] or 50
                return string.format('+%d%% HP Drain & drains %d%% dmg as MP', p, p)
            end,
        })
    end

    if orig.drainMp or orig.restoreMp then
        addT2Node(
        {
            key = 'mana_leech',
            name = orig.restoreMp and 'Font of Aether' or 'Aether Siphon',
            maxRank = 3,
            describe = function(rank)
                local mps = { 25, 50, 100 }
                local hps = { 25, 50, 75 }
                if rank == 0 then
                    return '+25/50/100% MP & heals 25/50/75% MP as HP'
                end
                return string.format('+%d%% MP gained & +%d%% MP healed as HP', mps[rank] or 100, hps[rank] or 75)
            end,
        })
    end

    if orig.debuff ~= nil then
        local deb = orig.debuff
        addT2Node(
        {
            key = 'debuff',
            name = deb.label .. ' +',
            maxRank = 3,
            describe = function(rank)
                local durs = { 35, 70, 120 }
                local maccs = { 25, 50, 80 }
                if deb.binary then
                    local atks = { 10, 20, 35 }
                    if rank == 0 then
                        return '+35/70/120% Dur, +25-80 MACC, +10-35% Atk'
                    end
                    return string.format('+%d%% Dur, +%d MACC, +%d%% WS Atk', durs[rank], maccs[rank], atks[rank])
                else
                    local pots = { 20, 40, 65 }
                    if rank == 0 then
                        return '+20/40/65% Pot, +35-120% Dur, +25-80 MACC'
                    end
                    return string.format('+%d%% Potency, +%d%% Dur, +%d MACC', pots[rank], durs[rank], maccs[rank])
                end
            end,
        })
    end

    if orig.aoe then
        addT2Node(
        {
            key = 'aoe_cleave',
            name = 'Tempest Cleave',
            maxRank = 3,
            describe = function(rank)
                local atks = { 10, 20, 35 }
                local accs = { 15, 30, 50 }
                local wsds = { 8, 16, 25 }
                if rank == 0 then
                    return '+10-35% Atk, +15-50 Acc, +8-25% AoE WSD'
                end
                return string.format('+%d%% Atk, +%d Acc, +%d%% AoE WSD', atks[rank], accs[rank], wsds[rank])
            end,
        })
    end

    if orig.enmity == 'high' then
        addT2Node(
        {
            key = 'enmity_ctrl',
            name = 'Vanguard Oath',
            maxRank = 3,
            describe = function(rank)
                local enms = { 50, 100, 175 }
                local heals = { 15, 30, 50 }
                if rank == 0 then
                    return '+50/100/175% Enmity & 15/30/50% HP drain'
                end
                return string.format('+%d%% Enmity & +%d%% dmg self-heal', enms[rank], heals[rank])
            end,
        })
    elseif orig.enmity == 'low' then
        addT2Node(
        {
            key = 'enmity_ctrl',
            name = 'Phantom Shot',
            maxRank = 3,
            describe = function(rank)
                local enms = { 30, 60, 90 }
                local wsds = { 10, 20, 35 }
                if rank == 0 then
                    return '-30/60/90 Enmity & +10/20/35% WS Damage'
                end
                return string.format('-%d Enmity & +%d%% WS Damage', enms[rank], wsds[rank])
            end,
        })
    end

    -- Priority 2: Combat curve traits matching original WS math
    if orig.numHits >= 2 then
        addT2Node(
        {
            key = 'multihit',
            name = 'Flurry Strikes',
            maxRank = 3,
            describe = function(rank)
                if rank == 0 then
                    return 'R1:+Acc/Atk R2:fTP all hits R3:+1 Hit'
                elseif rank == 1 then
                    return '+15 Acc/+10% Atk | Next: fTP all hits'
                elseif rank == 2 then
                    return '+30 Acc/+20% Atk, fTP all | Next: +1 Hit'
                end
                return '+45 Acc/+30% Atk, fTP all, +1 Hit (MAX)'
            end,
        })
    end

    if orig.critVaries ~= nil then
        addT2Node(
        {
            key = 'crit',
            name = 'Critical Edge',
            maxRank = 3,
            describe = function(rank)
                if rank == 0 then
                    return 'TP crit scaling (+10-30% crit, +5-15% dmg)'
                end
                local c = calcScaledTable(orig.critVaries, rank, { 0.10, 0.15, 0.20 })
                return string.format('Crit %s/%s/%s, +%d%% Crit Dmg', fmtPct(c[1]), fmtPct(c[2]), fmtPct(c[3]), rank * 5)
            end,
        })
    end

    if orig.ignoredDefense ~= nil then
        addT2Node(
        {
            key = 'def_ignore',
            name = 'Armor Piercer',
            maxRank = 3,
            describe = function(rank)
                if rank == 0 then
                    return 'Restores & boosts Defense Ignore (up to 120%)'
                end
                local d = calcScaledTable(orig.ignoredDefense, rank, { 0.08, 0.12, 0.16 })
                return string.format('Ignores %s/%s/%s DEF', fmtPct(d[1]), fmtPct(d[2]), fmtPct(d[3]))
            end,
        })
    end

    if orig.atkVaries ~= nil then
        addT2Node(
        {
            key = 'atk_mult',
            name = 'Crushing Force',
            maxRank = 3,
            describe = function(rank)
                if rank == 0 then
                    return 'Restores & boosts WS Attack multiplier'
                end
                local a = calcAtkScaleAtRank(orig.atkVaries, rank)
                return string.format('WS Atk +%s/+%s/+%s', fmtPct(a[1]), fmtPct(a[2]), fmtPct(a[3]))
            end,
        })
    end

    if orig.accVaries ~= nil then
        addT2Node(
        {
            key = 'acc_mult',
            name = 'True Strike',
            maxRank = 3,
            describe = function(rank)
                if rank == 0 then
                    return 'Restores & boosts TP-varying Accuracy'
                end
                local ac = calcScaledTable(orig.accVaries, rank, { 20, 25, 30 })
                return string.format('WS Acc +%d/+%d/+%d', math.floor(ac[1]), math.floor(ac[2]), math.floor(ac[3]))
            end,
        })
    end

    if ws.wsType == 'magic' or ws.wsType == 'hybrid' or ws.element ~= nil or orig.drainHp then
        local elemText = ws.elementName or (ws.key == 'sanguine_blade' and 'Dark' or 'Elemental')
        addT2Node(
        {
            key = 'elemental',
            name = elemText .. ' Surge',
            maxRank = 3,
            describe = function(rank)
                if rank == 0 then
                    return string.format('+15/+30/+50 MAB & MACC for %s WS', elemText)
                end
                local val = rank == 3 and 50 or (rank * 15)
                return string.format('+%d MAB and +%d MACC on WS', val, val)
            end,
        })
    end

    if orig.aftermath ~= nil then
        local amNames = { relic = 'Relic Echo', mythic = 'Mythic Echo', empyrean = 'Empyrean Echo' }
        addT2Node(
        {
            key = 'aftermath_echo',
            name = amNames[orig.aftermath] or 'RMEA Echo',
            maxRank = 3,
            describe = function(rank)
                local wsds = { 8, 16, 25 }
                local tps = { 50, 100, 175 }
                if rank == 0 then
                    return '+8/16/25% WSD & +50/100/175 TP Bonus'
                end
                return string.format('+%d%% WS Dmg & +%d TP Bonus', wsds[rank], tps[rank])
            end,
        })
    end

    if t2Idx == 1 then
        addT2Node(
        {
            key = 'focused',
            name = 'Focused Power',
            maxRank = 3,
            describe = function(rank)
                if rank == 0 then
                    return '+12/24/40% WS Atk & +15/30/50 WS Acc'
                end
                local atkPct = rank == 3 and 40 or (rank * 12)
                local accVal = rank == 3 and 50 or (rank * 15)
                return string.format('+%d%% WS Atk, +%d WS Acc', atkPct, accVal)
            end,
        })
    end

    -- Tier 3 (Slots 7, 10, 8, requires >= 6 pts in this WS)
    local firstT2Key = 'ftp'
    for _, n in ipairs(nodes) do
        if n.tier == 2 then
            firstT2Key = n.key
            break
        end
    end

    table.insert(nodes,
    {
        slot = 7,
        key = 'tp_refund',
        name = 'TP Momentum',
        tier = 3,
        col = 1,
        reqWsPoints = 6,
        requires = { key = 'ftp', rank = 3 },
        maxRank = 3,
        describe = function(rank)
            local refund = rank == 3 and 350 or (rank * 100)
            if rank == 0 then
                return 'Refunds 100/200/350 TP after using WS'
            end
            return string.format('Refunds +%d TP after using WS', refund)
        end,
    })

    local scPlan = talents.getSkillchainPlan(ws)
    if scPlan ~= nil then
        table.insert(nodes,
        {
            slot = 10,
            key = 'skillchain',
            name = 'Skillchain Trait',
            tier = 3,
            col = 2,
            reqWsPoints = 6,
            requires = { key = 'ftp', rank = 2 },
            maxRank = 3,
            describe = function(rank)
                if rank == 0 then
                    local nextProps = formatScNames(scPlan.ranks[1])
                    return string.format('R1: %s (+10%% SC) | R3: %s', nextProps, formatScNames(scPlan.ranks[3]))
                end
                local cur = talents.getSkillchainAtRank(ws, rank)
                return string.format('SC: %s (+%d%% SC Dmg)', formatScNames(cur.names), cur.scBonus)
            end,
        })
    else
        table.insert(nodes,
        {
            slot = 10,
            key = 'aether_pulse',
            name = 'Aether Pulse',
            tier = 3,
            col = 2,
            reqWsPoints = 6,
            requires = { key = 'ftp', rank = 2 },
            maxRank = 3,
            describe = function(rank)
                local hps = { 10, 20, 35 }
                local refs = { 3, 5, 8 }
                if rank == 0 then
                    return 'Restores 10/20/35% Max HP & grants Refresh'
                end
                return string.format('+%d%% Max HP heal & Refresh %d MP/t', hps[rank], refs[rank])
            end,
        })
    end

    local capstoneSpecs =
    {
        magic =
        {
            name = 'Arcane Overcharge',
            desc = '+30 MAB, +30 MACC, +25% WS Damage',
        },
        crit =
        {
            name = 'Fatal Execution',
            desc = '+15% Crit Rate, +20% Crit DMG, +1.0 fTP',
        },
        multihit =
        {
            name = 'Relentless Flurry',
            desc = 'fTP on all hits, +1 Hit, +10% WS Damage',
        },
        heavy =
        {
            name = 'Brutal Impact',
            desc = '+35% WS Atk, 25% DEF Ign, +15% WS Dmg',
        },
        utility =
        {
            name = 'Masters Efficiency',
            desc = '+50% WS Potency and +200 TP Refund',
        },
    }

    local capInfo = capstoneSpecs[archetype] or capstoneSpecs.heavy
    table.insert(nodes,
    {
        slot = 8,
        key = 'capstone',
        name = capInfo.name,
        archetype = archetype,
        tier = 3,
        col = 3,
        reqWsPoints = 6,
        requires = { key = firstT2Key, rank = 1 },
        maxRank = 1,
        describe = function(rank)
            if rank > 0 then
                return capInfo.desc .. ' (ACTIVE)'
            end
            return capInfo.desc
        end,
    })

    local byKey = {}
    for _, node in ipairs(nodes) do
        byKey[node.key] = node
    end

    return
    {
        ws = ws,
        archetype = archetype,
        nodes = nodes,
        byKey = byKey,
    }
end

function talents.getTreeForWS(wsId)
    if treeCache[wsId] ~= nil then
        return treeCache[wsId]
    end

    local ws = catalog.byId[wsId]
    if ws == nil then
        return nil
    end

    treeCache[wsId] = buildTreeForWS(ws)
    return treeCache[wsId]
end

-----------------------------------
-- Queries & Mutations
-----------------------------------
function talents.getEarnedPoints(player, jobId)
    if player == nil then
        return 0
    end

    local jid = jobId or player:getMainJob()
    return math.max(1, player:getJobLevel(jid))
end

function talents.getWSRanks(player, jobId, wsId)
    local tree = talents.getTreeForWS(wsId)
    if tree == nil then
        return {}, 0
    end

    local packed = player:getCharVar(talents.getVarName(jobId, wsId))
    local ranks = {}
    local spent = 0
    for _, node in ipairs(tree.nodes) do
        local r = math.min(node.maxRank, unpackSlot(packed, node.slot))
        ranks[node.key] = r
        spent = spent + r
    end

    return ranks, spent
end

function talents.getWSSpent(player, jobId, wsId)
    local _, spent = talents.getWSRanks(player, jobId, wsId)
    return spent
end

function talents.getTotalSpent(player, jobId)
    if player == nil then
        return 0, {}
    end

    local jid = jobId or player:getMainJob()
    local prefix = talents.getVarPrefix(jid)
    local vars = player:getCharVarsWithPrefix(prefix)
    local total = 0
    local perWs = {}

    for varName, packed in pairs(vars) do
        if packed > 0 then
            local wsId = tonumber(string.sub(varName, #prefix + 1))
            if wsId ~= nil and catalog.byId[wsId] ~= nil then
                local _, wsSpent = talents.getWSRanks(player, jid, wsId)
                if wsSpent > 0 then
                    perWs[wsId] = wsSpent
                    total = total + wsSpent
                end
            end
        end
    end

    return total, perWs
end

function talents.getAvailablePoints(player, jobId)
    local jid = jobId or player:getMainJob()
    local earned = talents.getEarnedPoints(player, jid)
    local spent = talents.getTotalSpent(player, jid)
    return math.max(0, earned - spent), earned, spent
end

function talents.canInvest(player, jobId, wsId, nodeKey)
    local tree = talents.getTreeForWS(wsId)
    if tree == nil then
        return false, 'Unknown weaponskill.'
    end

    local node = tree.byKey[nodeKey]
    if node == nil then
        return false, 'Unknown talent node for this weaponskill.'
    end

    local avail = talents.getAvailablePoints(player, jobId)
    if avail <= 0 then
        return false, 'No available talent points for this job.'
    end

    local ranks, wsSpent = talents.getWSRanks(player, jobId, wsId)
    local curRank = ranks[nodeKey] or 0
    if curRank >= node.maxRank then
        return false, 'Talent is already at max rank.'
    end

    if wsSpent < (node.reqWsPoints or 0) then
        return false, string.format('Requires %d points invested in %s.', node.reqWsPoints, tree.ws.name)
    end

    if node.requires ~= nil then
        local reqRank = ranks[node.requires.key] or 0
        if reqRank < node.requires.rank then
            local reqNode = tree.byKey[node.requires.key]
            local reqName = reqNode and reqNode.name or node.requires.key
            return false, string.format('Requires %s (Rank %d).', reqName, node.requires.rank)
        end
    end

    return true, nil
end

function talents.invest(player, jobId, wsId, nodeKey)
    local ok, err = talents.canInvest(player, jobId, wsId, nodeKey)
    if not ok then
        return false, err
    end

    local tree = talents.getTreeForWS(wsId)
    local node = tree.byKey[nodeKey]
    local varName = talents.getVarName(jobId, wsId)
    local packed = player:getCharVar(varName)
    local curRank = unpackSlot(packed, node.slot)
    local newRank = curRank + 1

    player:setCharVar(varName, packSlot(packed, node.slot, newRank))
    return true, newRank
end

function talents.refundNode(player, jobId, wsId, nodeKey)
    local tree = talents.getTreeForWS(wsId)
    if tree == nil then
        return false, 'Unknown weaponskill.'
    end

    local node = tree.byKey[nodeKey]
    if node == nil then
        return false, 'Unknown talent node.'
    end

    local ranks, wsSpent = talents.getWSRanks(player, jobId, wsId)
    local curRank = ranks[nodeKey] or 0
    if curRank <= 0 then
        return false, 'Talent rank is already 0.'
    end

    -- Verify removing 1 point does not invalidate higher tiers or dependents
    local newRanks = {}
    for k, v in pairs(ranks) do
        newRanks[k] = v
    end
    newRanks[nodeKey] = curRank - 1
    local newWsSpent = wsSpent - 1

    for _, other in ipairs(tree.nodes) do
        local r = newRanks[other.key] or 0
        if r > 0 then
            if other.key ~= nodeKey and newWsSpent < (other.reqWsPoints or 0) then
                return false, string.format('Cannot refund: %s requires %d pts in this WS.', other.name, other.reqWsPoints)
            end
            if other.requires ~= nil and (newRanks[other.requires.key] or 0) < other.requires.rank then
                return false, string.format('Cannot refund: %s depends on %s.', other.name, node.name)
            end
        end
    end

    local varName = talents.getVarName(jobId, wsId)
    local packed = player:getCharVar(varName)
    player:setCharVar(varName, packSlot(packed, node.slot, curRank - 1))
    return true, curRank - 1
end

function talents.resetWS(player, jobId, wsId)
    if catalog.byId[wsId] == nil then
        return false
    end

    player:setCharVar(talents.getVarName(jobId, wsId), 0)
    return true
end

function talents.resetAll(player, jobId)
    local jid = jobId or player:getMainJob()
    local prefix = talents.getVarPrefix(jid)
    local vars = player:getCharVarsWithPrefix(prefix)
    local count = 0

    for varName, val in pairs(vars) do
        if val ~= 0 then
            player:setCharVar(varName, 0)
            count = count + 1
        end
    end

    return count
end

-----------------------------------
-- Ashita Protocol Sync Helpers
-----------------------------------
function talents.formatOrigSummary(ws)
    local orig = ws.orig
    local ftpStr = string.format('fTP %.2g/%.2g/%.2g', orig.ftp[1], orig.ftp[2], orig.ftp[3])
    local wscParts = {}
    for _, stat in ipairs(STAT_ORDER) do
        if orig.wsc[stat] and orig.wsc[stat] > 0 then
            table.insert(wscParts, string.format('%s %d%%', STAT_LABELS[stat], math.floor(orig.wsc[stat] * 100 + 0.5)))
        end
    end
    local wscStr = #wscParts > 0 and table.concat(wscParts, ' ') or 'None'
    local extraParts = {}
    if orig.numHits > 1 then
        table.insert(extraParts, string.format('%dh', orig.numHits))
    end
    if orig.drainHp then
        table.insert(extraParts, 'DrainHP')
    end
    if orig.drainMp or orig.restoreMp then
        table.insert(extraParts, orig.restoreMp and 'RestMP' or 'DrainMP')
    end
    if orig.debuff then
        table.insert(extraParts, orig.debuff.label)
    end
    if orig.aoe then
        table.insert(extraParts, 'AoE')
    end
    if orig.critVaries then
        table.insert(extraParts, 'Crit')
    end
    if orig.ignoredDefense then
        table.insert(extraParts, 'DefIgn')
    end
    if ws.elementName then
        table.insert(extraParts, ws.elementName)
    end
    local scStr = formatScNames(orig.skillchain)
    table.insert(extraParts, 'SC:' .. scStr)
    local summary = string.format('%s | %s | %s', ftpStr, wscStr, table.concat(extraParts, ','))
    if #summary > 86 then
        summary = string.sub(summary, 1, 83) .. '...'
    end
    return summary
end

local function sendChunked(player, tag, items)
    if #items == 0 then
        return
    end

    local buf = tag
    for _, item in ipairs(items) do
        local sep = (buf == tag) and '' or ','
        if #PROTO_TAG + #buf + #sep + #item > MAX_MSG then
            sendProto(player, buf)
            buf = tag .. item
        else
            buf = buf .. sep .. item
        end
    end

    if buf ~= tag then
        sendProto(player, buf)
    end
end

function talents.sendMetaAndSpent(player)
    if player == nil then
        return
    end

    local jobId = player:getMainJob()
    local jobKey = talents.getJobKey(jobId)
    local jobLvl = math.max(1, player:getJobLevel(jobId))
    local avail, earned, spent = talents.getAvailablePoints(player, jobId)
    local _, perWs = talents.getTotalSpent(player, jobId)
    local mainSkill = player:getWeaponSkillType(xi.slot.MAIN) or 0
    local rangedSkill = player:getWeaponSkillType(xi.slot.RANGED) or 0

    sendProto(player, string.format('META|%s|%u|%u|%u|%u|%u|%u', jobKey, jobLvl, avail, spent, earned, mainSkill, rangedSkill))

    local spentItems = {}
    for wsId, wsSpent in pairs(perWs) do
        table.insert(spentItems, string.format('%u:%u', wsId, wsSpent))
    end
    table.sort(spentItems)
    sendProto(player, 'SPENT_BEGIN')
    sendChunked(player, 'SPENT|', spentItems)
    sendProto(player, 'SPENT_END')
end

function talents.sendCatalogSync(player)
    if player == nil then
        return
    end

    talents.sendMetaAndSpent(player)

    local wsItems = {}
    for _, wsId in ipairs(catalog.orderedIds) do
        local ws = catalog.byId[wsId]
        table.insert(wsItems, string.format('%u:%u:%s:%s', ws.id, ws.skill, sanitizeField(ws.name), ws.wsType))
    end
    sendProto(player, 'CAT_BEGIN')
    sendChunked(player, 'CAT|', wsItems)
    sendProto(player, 'CAT_END')
end

function talents.sendWSDetail(player, wsId)
    if player == nil then
        return
    end

    local tree = talents.getTreeForWS(wsId)
    if tree == nil then
        return
    end

    local jobId = player:getMainJob()
    local ws = tree.ws
    local ranks, wsSpent = talents.getWSRanks(player, jobId, wsId)
    local avail = talents.getAvailablePoints(player, jobId)

    sendProto(player, string.format('WS|%u|%s|%s|%s|%u|%s', ws.id, sanitizeField(ws.name), sanitizeField(ws.skillName), ws.wsType, wsSpent, sanitizeField(talents.formatOrigSummary(ws))))

    for _, node in ipairs(tree.nodes) do
        local r = ranks[node.key] or 0
        local canLearn = talents.canInvest(player, jobId, wsId, node.key)
        local reqKey = node.requires and node.requires.key or ''
        local reqRank = node.requires and node.requires.rank or 0
        local desc = sanitizeField(node.describe(r, ws))
        if #desc > 58 then
            desc = string.sub(desc, 1, 55) .. '...'
        end

        sendProto(player, string.format('NODE|%u|%s|%u|%u|%u|%u|%u|%u|%s|%u|%s|%s',
            ws.id,
            node.key,
            node.tier,
            node.col,
            r,
            node.maxRank,
            canLearn and 1 or 0,
            node.reqWsPoints or 0,
            reqKey,
            reqRank,
            sanitizeField(node.name),
            desc
        ))
    end

    sendProto(player, string.format('WS_END|%u|%u', ws.id, avail))
end

return talents
