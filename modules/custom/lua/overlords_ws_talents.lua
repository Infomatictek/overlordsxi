-----------------------------------
-- OverlordsXI Weaponskill Talent System
--
-- - All player weaponskills are unlocked at level 1 (via patch 0003).
-- - Base weaponskills for PCs are normalized to fTP = 1.0, WSC = 0,
--   numHits = 1, and ZERO skillchain properties (via patch 0005 + SQL).
-- - Players earn 3 talent points per main job level (225 pts at Lv 75),
--   allowing 4 fully maxed weaponskills (56 pts each -> 224 pts) at Lv 75.
-- - 4 Tiers gated by both WS points invested and job level:
--     Tier 1 (Lv 1+,  0+ WS pts) — Deep Foundation + Signature Identity (22 pts)
--     Tier 2 (Lv 20+, 10+ WS pts) — Specialization (12 pts)
--     Tier 3 (Lv 42+, 22+ WS pts) — Mastery (12 pts)
--     Tier 4 (Lv 62+, 35+ WS pts) — Capstone (10 pts)
-- - Every tier includes a player-selectable Skillchain Augment (Col 4)
--   so Lv 1 characters can enable Skillchains immediately, or leave
--   them off on Utility WSs to avoid interrupting party Skillchains.
-----------------------------------
require('modules/custom/lua/overlords_ws_catalog')
-----------------------------------
xi = xi or {}
xi.overlords = xi.overlords or {}
xi.overlords.wsTalents = xi.overlords.wsTalents or {}

local talents = xi.overlords.wsTalents
local catalog = xi.overlords.wsCatalog

local VAR_PREFIX    = 'OX_WST_'
local VAR2_PREFIX   = 'OX_WST2_'
local VAR_SC_PREFIX = 'OX_WSSC_'
local PROTO_TAG     = '[OXTAL]|'
local MAX_MSG       = 135

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
talents.STAT_ORDER = STAT_ORDER

talents.TIER_GATES =
{
    [1] = { reqWsPoints = 0,  reqLevel = 1  },
    [2] = { reqWsPoints = 10, reqLevel = 20 },
    [3] = { reqWsPoints = 22, reqLevel = 42 },
    [4] = { reqWsPoints = 35, reqLevel = 62 },
}

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
-- Skillchain Definitions & Choices
-----------------------------------
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

local SC_NAMES =
{
    [0]  = 'None',
    [1]  = 'Transfixion',
    [2]  = 'Compression',
    [3]  = 'Liquefaction',
    [4]  = 'Scission',
    [5]  = 'Reverberation',
    [6]  = 'Detonation',
    [7]  = 'Induration',
    [8]  = 'Impaction',
    [9]  = 'Gravitation',
    [10] = 'Distortion',
    [11] = 'Fusion',
    [12] = 'Fragmentation',
    [13] = 'Light',
    [14] = 'Darkness',
}

local SC_SHORT =
{
    [0]  = 'None',
    [1]  = 'Transfix',
    [2]  = 'Compress',
    [3]  = 'Liquefac',
    [4]  = 'Scission',
    [5]  = 'Reverb',
    [6]  = 'Detonat',
    [7]  = 'Indurat',
    [8]  = 'Impact',
    [9]  = 'Gravit',
    [10] = 'Distort',
    [11] = 'Fusion',
    [12] = 'Frag',
    [13] = 'Light',
    [14] = 'Darkness',
}

local SC_CHOICES =
{
    [1] = { 8, 3, 6, 4, 5, 7, 1, 2 }, -- Tier 1 (Lv 1+): All Level 1 properties
    [2] = { 3, 8, 4, 6, 7, 5, 2, 1 }, -- Tier 2 (Lv 20+): 2nd Level 1 property
    [3] = { 11, 12, 9, 10 },          -- Tier 3 (Lv 42+): Level 2 properties
    [4] = { 13, 14 },                 -- Tier 4 (Lv 62+): Level 3 properties
}

local SC_BONUS_BY_TIER =
{
    [1] = { 5, 10 },
    [2] = { 8, 15 },
    [3] = { 10, 20 },
    [4] = { 15, 28 },
}

local LV1_SC_SET = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true }
local LV2_SC_SET = { [9] = true, [10] = true, [11] = true, [12] = true }
local LV3_SC_SET = { [13] = true, [14] = true }

local DARK_SC_NAMES =
{
    COMPRESSION   = true,
    SCISSION      = true,
    REVERBERATION = true,
    INDURATION    = true,
    GRAVITATION   = true,
    DISTORTION    = true,
    DARKNESS      = true,
}

talents.SC_IDS     = SC_IDS
talents.SC_NAMES   = SC_NAMES
talents.SC_SHORT   = SC_SHORT
talents.SC_CHOICES = SC_CHOICES

local function isDarkAligned(ws)
    if ws == nil then
        return false
    end
    if ws.elementName == 'Dark' or ws.key == 'sanguine_blade' or ws.key == 'energy_steal' or ws.key == 'energy_drain' or ws.key == 'catastrophe' then
        return true
    end
    if ws.elementName == 'Earth' or ws.elementName == 'Water' or ws.elementName == 'Ice' then
        return true
    end
    local sc = (ws.orig and ws.orig.skillchain) or {}
    if #sc > 0 then
        return DARK_SC_NAMES[sc[1]] == true
    end
    return false
end

local function isValidChoiceForTier(scTier, scId)
    for _, v in ipairs(SC_CHOICES[scTier] or {}) do
        if v == scId then
            return true
        end
    end
    return false
end

local function getDefaultSCForWS(ws, scTier)
    local origSc = (ws and ws.orig and ws.orig.skillchain) or {}
    local dark = isDarkAligned(ws)

    if scTier == 1 then
        for _, name in ipairs(origSc) do
            local id = SC_IDS[name]
            if id and LV1_SC_SET[id] then
                return id
            end
        end
        return dark and SC_IDS.COMPRESSION or SC_IDS.IMPACTION
    elseif scTier == 2 then
        local t1 = getDefaultSCForWS(ws, 1)
        for _, name in ipairs(origSc) do
            local id = SC_IDS[name]
            if id and LV1_SC_SET[id] and id ~= t1 then
                return id
            end
        end
        return (t1 == SC_IDS.LIQUEFACTION) and SC_IDS.IMPACTION or (dark and SC_IDS.SCISSION or SC_IDS.LIQUEFACTION)
    elseif scTier == 3 then
        for _, name in ipairs(origSc) do
            local id = SC_IDS[name]
            if id and LV2_SC_SET[id] then
                return id
            end
        end
        return dark and SC_IDS.GRAVITATION or SC_IDS.FUSION
    elseif scTier == 4 then
        for _, name in ipairs(origSc) do
            local id = SC_IDS[name]
            if id and LV3_SC_SET[id] then
                return id
            end
        end
        return dark and SC_IDS.DARKNESS or SC_IDS.LIGHT
    end

    return 0
end

-----------------------------------
-- Persistence (3 bits/slot across OX_WST_ (1..10) & OX_WST2_ (11..20))
-- Skillchain tier picks packed 4 bits/tier in OX_WSSC_ (tiers 1..4)
-----------------------------------
function talents.getJobKey(jobId)
    return JOB_KEYS[jobId] or string.format('J%u', jobId or 0)
end

function talents.getVarPrefix(jobId)
    return VAR_PREFIX .. talents.getJobKey(jobId) .. '_'
end

function talents.getVar2Prefix(jobId)
    return VAR2_PREFIX .. talents.getJobKey(jobId) .. '_'
end

function talents.getScVarPrefix(jobId)
    return VAR_SC_PREFIX .. talents.getJobKey(jobId) .. '_'
end

function talents.getVarName(jobId, wsId)
    return string.format('%s%u', talents.getVarPrefix(jobId), wsId)
end

function talents.getVar2Name(jobId, wsId)
    return string.format('%s%u', talents.getVar2Prefix(jobId), wsId)
end

function talents.getScVarName(jobId, wsId)
    return string.format('%s%u', talents.getScVarPrefix(jobId), wsId)
end

local function unpack3(packed, idx)
    local shift = 8 ^ (idx - 1)
    return math.floor((packed or 0) / shift) % 8
end

local function pack3(packed, idx, val)
    local shift = 8 ^ (idx - 1)
    local oldVal = math.floor((packed or 0) / shift) % 8
    return (packed or 0) + (val - oldVal) * shift
end

local function unpack4(packed, idx)
    local shift = 16 ^ (idx - 1)
    return math.floor((packed or 0) / shift) % 16
end

local function pack4(packed, idx, val)
    local shift = 16 ^ (idx - 1)
    local oldVal = math.floor((packed or 0) / shift) % 16
    return (packed or 0) + (val - oldVal) * shift
end

local function readSlotRank(player, jobId, wsId, slot)
    if slot <= 10 then
        return unpack3(player:getCharVar(talents.getVarName(jobId, wsId)), slot)
    else
        return unpack3(player:getCharVar(talents.getVar2Name(jobId, wsId)), slot - 10)
    end
end

local function writeSlotRank(player, jobId, wsId, slot, rank)
    if slot <= 10 then
        local vn = talents.getVarName(jobId, wsId)
        player:setCharVar(vn, pack3(player:getCharVar(vn), slot, rank))
    else
        local vn = talents.getVar2Name(jobId, wsId)
        player:setCharVar(vn, pack3(player:getCharVar(vn), slot - 10, rank))
    end
end

function talents.getSCChoice(player, jobId, wsId, scTier)
    local ws = catalog.byId[wsId]
    if player ~= nil then
        local packed = player:getCharVar(talents.getScVarName(jobId, wsId))
        local raw = unpack4(packed, scTier)
        if isValidChoiceForTier(scTier, raw) then
            return raw
        end
    end
    return getDefaultSCForWS(ws, scTier)
end

function talents.setSCChoice(player, jobId, wsId, scTier, scId)
    if player == nil or not isValidChoiceForTier(scTier, scId) then
        return false, 'Invalid skillchain choice for this tier.'
    end
    local vn = talents.getScVarName(jobId, wsId)
    local packed = player:getCharVar(vn)
    player:setCharVar(vn, pack4(packed, scTier, scId))
    return true, scId
end

function talents.cycleSCChoice(player, jobId, wsId, scTier, dir)
    local list = SC_CHOICES[scTier]
    if list == nil or #list == 0 then
        return false, 'No skillchain choices for this tier.'
    end
    local cur = talents.getSCChoice(player, jobId, wsId, scTier)
    local curIdx = 1
    for i, id in ipairs(list) do
        if id == cur then
            curIdx = i
            break
        end
    end
    local step = (dir and dir < 0) and -1 or 1
    local nxtIdx = ((curIdx - 1 + step) % #list) + 1
    return talents.setSCChoice(player, jobId, wsId, scTier, list[nxtIdx])
end

function talents.getActiveSkillchains(player, jobId, wsId, ranksOverride)
    local ranks = ranksOverride
    if ranks == nil then
        ranks = talents.getWSRanks(player, jobId, wsId)
    end

    local chosen = {}
    local seen = {}
    local bonus = 0

    -- Collect active properties: prioritize highest unlocked tiers (4 -> 3 -> 1 -> 2)
    -- so Lv 3 + Lv 2 + primary Lv 1 are preserved if all 4 tiers are invested.
    local order = { 4, 3, 1, 2 }
    for _, tier in ipairs(order) do
        local r = ranks['sc_t' .. tier] or 0
        if r > 0 then
            local bTbl = SC_BONUS_BY_TIER[tier]
            bonus = bonus + (bTbl and bTbl[math.min(r, 2)] or 0)
            local scId = talents.getSCChoice(player, jobId, wsId, tier)
            if scId > 0 and not seen[scId] and #chosen < 3 then
                seen[scId] = true
                table.insert(chosen, scId)
            end
        end
    end

    return
    {
        sc1     = chosen[1] or 0,
        sc2     = chosen[2] or 0,
        sc3     = chosen[3] or 0,
        scBonus = bonus,
        ids     = chosen,
    }
end

-----------------------------------
-- Scaling Helpers
-----------------------------------
function talents.calcFtpAtRank(origFtp, rank, maxRank)
    local mr = maxRank or 5
    local out = { 1.0, 1.0, 1.0 }
    if rank <= 0 then
        return out
    end

    local t = math.min(rank, mr) / mr
    local bonusMax = (rank >= mr) and 1.12 or 1.0
    for i = 1, 3 do
        local origVal = (origFtp and origFtp[i]) or 1.0
        if origVal > 1.0 then
            out[i] = round2(1.0 + (origVal - 1.0) * t * bonusMax)
        else
            local add = (0.60 + (i - 1) * 0.35) * t
            out[i] = round2(1.0 + add)
        end
    end

    return out
end

function talents.calcWscAtRank(origWeight, rank, maxRank)
    local mr = maxRank or 5
    if rank <= 0 then
        return 0
    end

    local maxWsc = math.max((origWeight or 0) * 1.15, 0.45)
    return round2(maxWsc * (math.min(rank, mr) / mr))
end

function talents.calcScaledTable(origTbl, rank, maxTotalFloor, maxRank)
    if rank <= 0 then
        return nil
    end

    local mr = maxRank or 5
    local t = math.min(rank, mr) / mr
    local mFactor = t * 1.15
    local out = {}
    for i = 1, 3 do
        local baseVal = (origTbl and origTbl[i]) or 0
        local minFloor = maxTotalFloor and (maxTotalFloor[i] * t) or 0
        out[i] = round2(math.max(baseVal * mFactor, minFloor))
    end

    return out
end

function talents.calcAtkScaleAtRank(origAtk, rank, maxRank)
    if rank <= 0 then
        return nil
    end

    local mr = maxRank or 5
    local t = math.min(rank, mr) / mr
    local mFactor = t * 1.25
    local out = {}
    for i = 1, 3 do
        local origBonus = math.max(0, ((origAtk and origAtk[i]) or 1.0) - 1.0)
        local bonus = math.max(origBonus * mFactor, 0.50 * t)
        out[i] = round2(bonus)
    end

    return out
end

-----------------------------------
-- Node Builders (Skillchain Col 4 in every Tier)
-----------------------------------
local function makeSCTierNode(ws, scTier, col)
    local gate = talents.TIER_GATES[scTier]
    local tierLabels = { 'SC T1 (Lv1)', 'SC T2 (Lv1)', 'SC T3 (Lv2)', 'SC T4 (Lv3)' }
    local bonuses = SC_BONUS_BY_TIER[scTier]

    return
    {
        key         = 'sc_t' .. scTier,
        name        = tierLabels[scTier] or ('SC T' .. scTier),
        tier        = scTier,
        col         = col or 4,
        reqWsPoints = gate.reqWsPoints,
        reqLevel    = gate.reqLevel,
        maxRank     = 2,
        scTier      = scTier,
        describe    = function(rank, wsArg, player, jobId)
            local pickedId = talents.getSCChoice(player, jobId, ws.id, scTier)
            local pickedName = SC_NAMES[pickedId] or 'None'
            if rank == 0 then
                return string.format('Pick: [%s] | Enables %s SC (+%d/%d%% SC Dmg)', pickedName, scTier <= 2 and 'Lv1' or (scTier == 3 and 'Lv2' or 'Lv3'), bonuses[1], bonuses[2])
            elseif rank == 1 then
                return string.format('[%s] ACTIVE (+%d%% SC Dmg) | Next: +%d%%', pickedName, bonuses[1], bonuses[2])
            end
            return string.format('[%s] ACTIVE (+%d%% SC Dmg) (MAX)', pickedName, bonuses[2])
        end,
    }
end

local function makeCurveNode(opts)
    local gate = talents.TIER_GATES[opts.tier]
    return
    {
        key         = opts.key,
        name        = opts.name,
        tier        = opts.tier,
        col         = opts.col,
        reqWsPoints = opts.reqWsPoints ~= nil and opts.reqWsPoints or gate.reqWsPoints,
        reqLevel    = opts.reqLevel ~= nil and opts.reqLevel or gate.reqLevel,
        requires    = opts.requires,
        maxRank     = opts.maxRank,
        describe    = function(rank)
            if rank == 0 then
                return opts.zeroDesc
            end
            return opts.rankDesc(rank)
        end,
    }
end

-----------------------------------
-- Hand-to-Hand (#1 - #15) Bespoke 4-Tier Trees (56 pts each -> 4 maxed @ Lv 75)
-- T1 (Lv 1+,  0+ pts): 6 + 7 + 7 + 2 (SC) = 22 pts (Deep + Signature Identity from R1!)
-- T2 (Lv 20+, 10+ pts): 5 + 5 + 2 (SC)     = 12 pts
-- T3 (Lv 42+, 22+ pts): 5 + 5 + 2 (SC)     = 12 pts
-- T4 (Lv 62+, 35+ pts): 3 + 5 + 2 (SC)     = 10 pts
-----------------------------------
local CUSTOM_TREES = {}

local function registerCustomH2H(wsId, spec)
    CUSTOM_TREES[wsId] = spec
end

local function h2hFtpCurveNode(ftpCurve, maxRank, customName, extraZeroDesc)
    return
    {
        key      = 'ftp',
        name     = customName or 'TP Scaling',
        tier     = 1,
        col      = 1,
        maxRank  = maxRank or 6,
        ftpCurve = ftpCurve,
        describe = function(rank)
            local mr = maxRank or 6
            if rank <= 0 then
                return string.format('Base fTP 1.00 -> Scales up to %.2f/%.2f/%.2f%s', ftpCurve[1], ftpCurve[2], ftpCurve[3], extraZeroDesc or '')
            end
            local t = rank / mr
            local a = round2(1.0 + (ftpCurve[1] - 1.0) * t)
            local b = round2(1.0 + (ftpCurve[2] - 1.0) * t)
            local c = round2(1.0 + (ftpCurve[3] - 1.0) * t)
            return string.format('fTP: %.2f / %.2f / %.2f%s', a, b, c, rank >= mr and ' (MAX)' or '')
        end,
    }
end

-- #1 Combo (Utility Speed Opener & Next-WS Primer, 56 pts)
registerCustomH2H(1,
{
    archetype = 'utility',
    nodes =
    {
        h2hFtpCurveNode({ 1.00, 1.65, 2.25 }, 6),
        makeCurveNode({ key = 'combo_tempo', name = 'Tempo & Haste', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'R1: 1->2h & +3% JA Haste (12s) -> R7: 1->3h, +15% WSD & +15% JA Haste',
            rankDesc = function(r)
                local h = r >= 4 and 3 or 2
                local ja = ({ 3, 5, 7, 9, 11, 13, 15 })[r]
                local wsd = ({ 0, 3, 6, 9, 11, 13, 15 })[r]
                return string.format('Hits: 1->%d, +%d%% JA Haste (12s), +%d%% WSD', h, ja, wsd)
            end }),
        makeCurveNode({ key = 'combo_edge', name = 'Opening Edge & WSC', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'Next WS deals +4->25% extra dmg (10s) & STR/DEX +5->35% WSC',
            rankDesc = function(r)
                local nxt = ({ 4, 8, 12, 16, 19, 22, 25 })[r]
                local w = r * 5
                return string.format('Next WS +%d%% Dmg (10s), STR/DEX +%d%% WSC', nxt, w)
            end }),
        makeCurveNode({ key = 'combo_sb', name = 'Subtle Rhythm', tier = 2, col = 1, maxRank = 5,
            zeroDesc = 'Post-WS +6/12/18/24/30 Subtle Blow (12s) & +10..50 WS Acc',
            rankDesc = function(r) return string.format('Subtle Blow +%d (12s), +%d Acc', r * 6, r * 10) end }),
        makeCurveNode({ key = 'combo_prec', name = 'Combo Precision', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+8/16/24/32/40% WS Atk & +6/12/18/24/30 Acc',
            rankDesc = function(r) return string.format('+%d%% WS Atk, +%d Acc', r * 8, r * 6) end }),
        makeCurveNode({ key = 'combo_da', name = 'Double Tempo', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'Grants +8/16/24/32/40% Double Attack for 12s after WS',
            rankDesc = function(r) return string.format('Post-WS Double Attack +%d%% (12s)', r * 8) end }),
        makeCurveNode({ key = 'combo_flow', name = 'Momentum Flow', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+4/8/12/16/20% WSD & +60/120/180/240/300 Next-WS TP Bonus',
            rankDesc = function(r) return string.format('+%d%% WSD, +%d Next-WS TP', r * 4, r * 60) end }),
        makeCurveNode({ key = 'capstone', name = 'Blitz Tempo', tier = 4, col = 1, maxRank = 3, requires = { key = 'combo_da', rank = 1 },
            zeroDesc = 'Capstone: +8/14/20% Triple Attack (12s) & +10/20/30% WSD',
            rankDesc = function(r) return string.format('Post-WS +%d%% TA (12s), +%d%% WSD', ({ 8, 14, 20 })[r], r * 10) end }),
        makeCurveNode({ key = 'combo_mast', name = 'Speed Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+6/12/18/24/30% WS Atk & +10/20/30/40/50 Acc',
            rankDesc = function(r) return string.format('+%d%% WS Atk, +%d Acc', r * 6, r * 10) end }),
    },
})

-- #2 Shoulder Tackle (Interrupt, Debuff & Chi Blast Primer, 56 pts)
registerCustomH2H(2,
{
    archetype = 'utility',
    nodes =
    {
        {
            key = 'debuff', name = 'Concussive Stun & fTP', tier = 1, col = 1, maxRank = 6,
            ftpCurve = { 1.00, 1.25, 1.50 },
            describe = function(r)
                if r <= 0 then
                    return 'fTP 1.00->1.50 + +18..110 Stun MACC & +1..3s Stun Duration'
                end
                local t = r / 6
                local b = round2(1.0 + 0.25 * t)
                local c = round2(1.0 + 0.50 * t)
                local macc = ({ 18, 36, 54, 72, 90, 110 })[r]
                local dur = ({ 1, 1, 2, 2, 3, 3 })[r]
                return string.format('fTP 1/%.2f/%.2f, +%d Stun MACC, +%ds Dur', b, c, macc, dur)
            end,
        },
        makeCurveNode({ key = 'chi_setup', name = 'Focused Chi & Hits', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'R1: 1->2h & Chi Blast +12% Dmg/-6s CD -> R7: +65% Dmg/-30s CD, +35 Acc',
            rankDesc = function(r)
                local dmg = ({ 12, 22, 32, 42, 50, 58, 65 })[r]
                local cd = ({ 6, 10, 14, 18, 22, 26, 30 })[r]
                return string.format('Hits: 1->2, +%d Acc, Chi +%d%%/-%ds CD', r * 5, dmg, cd)
            end }),
        makeCurveNode({ key = 'tackle_break', name = 'Shoulder Break & VIT', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'VIT +12->75% WSC & Inflicts Atk Down (-5->-20%, 45s)',
            rankDesc = function(r)
                local vit = ({ 12, 24, 36, 48, 58, 66, 75 })[r]
                local atk = ({ 5, 8, 11, 13, 15, 18, 20 })[r]
                return string.format('VIT +%d%% WSC, Atk Down -%d%% (45s)', vit, atk)
            end }),
        makeCurveNode({ key = 'tackle_drain', name = 'TP Drain Break', tier = 2, col = 1, maxRank = 5,
            zeroDesc = 'Drains 80/150/220/290/360 TP & extra -2/4/6/8/10% Atk Down',
            rankDesc = function(r) return string.format('Drain %d TP, -%d%% extra Atk Down', ({ 80, 150, 220, 290, 360 })[r], r * 2) end }),
        makeCurveNode({ key = 'tackle_force', name = 'Disruptive Force', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+12/24/36/48/60 Acc & +8/16/24/32/40% WS Atk',
            rankDesc = function(r) return string.format('+%d Acc, +%d%% WS Atk', r * 12, r * 8) end }),
        makeCurveNode({ key = 'tackle_dispel', name = 'Chi Dispel', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'Dispels 1/1/2/2/3 buffs & inflicts Acc/Eva Down -10..50',
            rankDesc = function(r) local d = r >= 5 and 3 or (r >= 3 and 2 or 1); return string.format('Dispel %d Buff(s), Acc/Eva -%d', d, r * 10) end }),
        makeCurveNode({ key = 'tackle_macc', name = 'Resonant Chi', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+15/30/45/60/75 MACC & -5/10/15/20/25% Enmity',
            rankDesc = function(r) return string.format('+%d MACC, -%d%% Enmity', r * 15, r * 5) end }),
        makeCurveNode({ key = 'capstone', name = 'Grand Breaker', tier = 4, col = 1, maxRank = 3, requires = { key = 'tackle_drain', rank = 1 },
            zeroDesc = 'Capstone: Inflicts Slow+Para & +20/35/50% extra Chi Blast Dmg',
            rankDesc = function(r) return string.format('Inflicts Slow+Para, +%d%% extra Chi Blast', ({ 20, 35, 50 })[r]) end }),
        makeCurveNode({ key = 'tackle_mast', name = 'Disruptor Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+12/24/36/48/60 WS MACC & +8/16/24/32/40% Enmity Control',
            rankDesc = function(r) return string.format('+%d MACC, +%d%% Enmity Control', r * 12, r * 8) end }),
    },
})

-- #3 One Inch Punch (Armor Shatter, Stoneskin & Chi Amplifier, 56 pts)
registerCustomH2H(3,
{
    archetype = 'utility',
    nodes =
    {
        {
            key = 'def_ignore', name = 'Penetrating fTP', tier = 1, col = 1, maxRank = 6,
            ftpCurve = { 1.00, 1.35, 1.75 },
            describe = function(r)
                if r <= 0 then
                    return 'fTP 1.00->1.75 & Ignores 10->55% Target Defense'
                end
                local t = r / 6
                local b = round2(1.0 + 0.35 * t)
                local c = round2(1.0 + 0.75 * t)
                local ign = ({ 10, 18, 27, 36, 45, 55 })[r]
                return string.format('fTP 1/%.2f/%.2f, Ignores %d%% DEF', b, c, ign)
            end,
        },
        makeCurveNode({ key = 'inch_shatter', name = 'Shatter Inch & Hits', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'R1: 1->2h & Inflicts DEF Down -8% -> R7: DEF -30% (60s), +40 Acc, +25% Atk',
            rankDesc = function(r)
                local defdn = ({ 8, 12, 16, 20, 24, 27, 30 })[r]
                local acc = ({ 6, 12, 18, 24, 30, 35, 40 })[r]
                local atk = ({ 0, 4, 8, 12, 16, 20, 25 })[r]
                return string.format('Hits: 1->2, DEF -%d%%, +%d Acc, +%d%% Atk', defdn, acc, atk)
            end }),
        makeCurveNode({ key = 'inch_vit_chi', name = 'VIT & Chi Flow', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'VIT +12->80% WSC & Next Chi Blast +12->75% Dmg',
            rankDesc = function(r)
                local vit = ({ 12, 24, 36, 48, 60, 70, 80 })[r]
                local chi = ({ 12, 22, 32, 42, 54, 65, 75 })[r]
                return string.format('VIT %d%% WSC, Chi Blast +%d%% Dmg', vit, chi)
            end }),
        makeCurveNode({ key = 'inch_skin', name = 'Iron Shell', tier = 2, col = 1, maxRank = 5,
            zeroDesc = 'Grants self Stoneskin barrier (100/200/300/400/520 HP)',
            rankDesc = function(r) return string.format('Grants Stoneskin (%d HP)', ({ 100, 200, 300, 400, 520 })[r]) end }),
        makeCurveNode({ key = 'inch_cd', name = 'Focused Chi Flow', tier = 2, col = 2, maxRank = 5,
            zeroDesc = 'Trims -8/16/24/32/40s Chi Blast CD & +10/20/30/40/50 MACC',
            rankDesc = function(r) return string.format('-%ds Chi Blast CD, +%d MACC', r * 8, r * 10) end }),
        makeCurveNode({ key = 'inch_plague', name = 'Internal Rupture', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'Inflicts Plague (-2/4/6/8/10 TP/t) + Light Chi hit (8..40%)',
            rankDesc = function(r) return string.format('Plague -%d TP/t + %d%% Light Chi hit', r * 2, r * 8) end }),
        makeCurveNode({ key = 'inch_focus', name = 'Crushing Focus', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+12/24/36/48/60% WS Atk & +10/20/30/40/50 Acc',
            rankDesc = function(r) return string.format('+%d%% WS Atk, +%d Acc', r * 12, r * 10) end }),
        makeCurveNode({ key = 'capstone', name = 'True Inch', tier = 4, col = 1, maxRank = 3, requires = { key = 'inch_skin', rank = 1 },
            zeroDesc = 'Capstone: 75/90/100% DEF Ign & Inflicts MDEF Down -10/15/20%',
            rankDesc = function(r) return string.format('%d%% DEF Ign, MDEF -%d%% (60s)', ({ 75, 90, 100 })[r], ({ 10, 15, 20 })[r]) end }),
        makeCurveNode({ key = 'inch_mast', name = 'Chi Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+8/16/24/32/40% Chi Blast Dmg & +12/24/36/48/60 MACC',
            rankDesc = function(r) return string.format('Chi Blast +%d%%, +%d MACC', r * 8, r * 12) end }),
    },
})

-- #4 Backhand Blow (Crit-Primer, En-Aero & Evasion Down, 56 pts)
registerCustomH2H(4,
{
    archetype = 'utility',
    nodes =
    {
        {
            key = 'crit', name = 'Vicious Arc & fTP', tier = 1, col = 1, maxRank = 6,
            ftpCurve = { 1.00, 1.45, 1.90 },
            describe = function(r)
                if r <= 0 then
                    return 'fTP 1.00->1.90, WS Crit +10->60% & +4->20% Crit Dmg'
                end
                local t = r / 6
                local b = round2(1.0 + 0.45 * t)
                local c = round2(1.0 + 0.90 * t)
                local cd = ({ 4, 7, 10, 14, 17, 20 })[r]
                return string.format('fTP 1/%.2f/%.2f, Crit +%d%%/+%d%%Dmg', b, c, r * 10, cd)
            end,
        },
        makeCurveNode({ key = 'bh_gale', name = 'Keen Gale & Hits', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'R1: 1->2h & Post-WS +4% Crit -> R7: +20% Melee Crit (12s), +30 Acc, +20% Atk',
            rankDesc = function(r)
                local pc = ({ 4, 7, 10, 13, 15, 18, 20 })[r]
                local acc = ({ 5, 10, 15, 20, 24, 27, 30 })[r]
                local atk = ({ 0, 3, 6, 10, 13, 16, 20 })[r]
                return string.format('1->2h, Post +%d%% Crit, +%d Acc, +%d%% Atk', pc, acc, atk)
            end }),
        makeCurveNode({ key = 'bh_feint', name = 'Wind Feint & WSC', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'STR/DEX +10->65% WSC & Inflicts Evasion Down -8->-40 (45s)',
            rankDesc = function(r)
                local w = ({ 10, 20, 30, 40, 50, 58, 65 })[r]
                local eva = ({ 8, 14, 20, 26, 31, 36, 40 })[r]
                return string.format('STR/DEX +%d%% WSC, Eva Down -%d', w, eva)
            end }),
        makeCurveNode({ key = 'bh_enaero', name = 'Gale En-Aero', tier = 2, col = 1, maxRank = 5,
            zeroDesc = 'Grants En-Aero +10/20/30/40/50 (12s) & +8/16/24/32/40% WS Atk',
            rankDesc = function(r) return string.format('En-Aero +%d (12s), +%d%% WS Atk', r * 10, r * 8) end }),
        makeCurveNode({ key = 'bh_prec', name = 'Aero Precision', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+12/24/36/48/60 Acc & -4/8/12/16/20 extra Evasion Down',
            rankDesc = function(r) return string.format('+%d Acc, -%d extra Eva Down', r * 12, r * 4) end }),
        makeCurveNode({ key = 'bh_rhythm', name = 'Tempest Rhythm', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'Post-WS +4/8/12/16/20% Crit Dmg (12s) & +5/10/15/20/25% WSD',
            rankDesc = function(r) return string.format('Post-WS +%d%% Crit Dmg, +%d%% WSD', r * 4, r * 5) end }),
        makeCurveNode({ key = 'bh_wind', name = 'Razor Gale', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+8/16/24/32/40 MACC & +10/20/30/40/50% Wind Follow-up',
            rankDesc = function(r) return string.format('+%d MACC, +%d%% Wind Follow-up', r * 8, r * 10) end }),
        makeCurveNode({ key = 'capstone', name = 'Tempest Eye', tier = 4, col = 1, maxRank = 3, requires = { key = 'bh_rhythm', rank = 1 },
            zeroDesc = 'Capstone: Post-WS +8/15/22% extra Crit Dmg (12s) & +10/18/26% WSD',
            rankDesc = function(r) return string.format('Post +%d%% extra Crit Dmg, +%d%% WSD', ({ 8, 15, 22 })[r], ({ 10, 18, 26 })[r]) end }),
        makeCurveNode({ key = 'bh_mast', name = 'Precision Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+10/20/30/40/50 Acc & +8/16/24/32/40 MACC',
            rankDesc = function(r) return string.format('+%d Acc, +%d MACC', r * 10, r * 8) end }),
    },
})

-- #5 Raging Fists (Pure 5-Hit Multi-Hit Finisher — leaves DA/TA headroom below 8 cap, 56 pts)
registerCustomH2H(5,
{
    archetype = 'multihit',
    nodes =
    {
        h2hFtpCurveNode({ 1.00, 1.55, 2.20 }, 6),
        makeCurveNode({ key = 'rf_hits1', name = 'Flurry Hits', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'Rebuild flurry 1->4h (+1 offhand) & +4->28% WS Atk',
            rankDesc = function(r)
                local h = r >= 5 and 4 or (r >= 3 and 3 or 2)
                return string.format('Hits: 1->%d, +%d%% WS Atk', h, r * 4)
            end }),
        makeCurveNode({ key = 'rf_stance', name = 'Focus/Impetus & WSC', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'STR/DEX +7->45% WSC & +6->36% WSD w/ Focus or Impetus',
            rankDesc = function(r)
                local w = ({ 7, 13, 19, 25, 32, 38, 45 })[r]
                local st = ({ 6, 11, 16, 21, 26, 31, 36 })[r]
                return string.format('STR/DEX +%d%% WSC, +%d%% Stance WSD', w, st)
            end }),
        makeCurveNode({ key = 'rf_hits2', name = 'Relentless Strike', tier = 2, col = 1, maxRank = 5,
            zeroDesc = 'R1: 4->5 Hits | R2-5: +12..48 Acc & +8..32% Atk',
            rankDesc = function(r) return string.format('+1 Hit (up to 5h), +%d Acc, +%d%% Atk', (r - 1) * 12, (r - 1) * 8) end }),
        makeCurveNode({ key = 'rf_force', name = 'Pummel Force', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+9/18/27/36/45% WS Attack & +6/12/18/24/30 Acc',
            rankDesc = function(r) return string.format('+%d%% WS Atk, +%d Acc', r * 9, r * 6) end }),
        makeCurveNode({ key = 'rf_mftp', name = 'Raging fTP', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'R1-4: +6/12/18/24% WSD | R5: fTP applies to ALL Hits!',
            rankDesc = function(r) return r >= 5 and 'fTP ALL HITS + +24% WSD (MAX)' or string.format('+%d%% WSD (R5: fTP all hits)', r * 6) end }),
        makeCurveNode({ key = 'rf_savage', name = 'Savage Impact', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+5/10/15/20/25% WSD & +6/12/18/24/30% Crit Dmg',
            rankDesc = function(r) return string.format('+%d%% WSD, +%d%% Crit Dmg', r * 5, r * 6) end }),
        makeCurveNode({ key = 'capstone', name = 'Raging Barrage', tier = 4, col = 1, maxRank = 3, requires = { key = 'rf_mftp', rank = 1 },
            zeroDesc = 'Capstone: +10/20/30% WSD & +10/20/30% WS Atk',
            rankDesc = function(r) return string.format('+%d%% WSD, +%d%% WS Atk', r * 10, r * 10) end }),
        makeCurveNode({ key = 'rf_mast', name = 'Brawler Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+4/8/12/15/18% Crit Rate & +5/10/15/20/25% Crit Dmg',
            rankDesc = function(r) return string.format('+%d%% Crit Rate, +%d%% Crit Dmg', ({ 4, 8, 12, 15, 18 })[r], r * 5) end }),
    },
})

-- #6 Spinning Attack (Pure Mob-Count Scaling AoE Pack Blender, 56 pts)
registerCustomH2H(6,
{
    archetype = 'multihit',
    nodes =
    {
        h2hFtpCurveNode({ 1.00, 1.30, 1.60 }, 6),
        makeCurveNode({ key = 'spin_hits', name = 'Whirlwind Hits', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'Rebuild 1->3 Hits & +4->28% Atk, +3->21 Acc in AoE',
            rankDesc = function(r) local h = r >= 5 and 3 or 2; return string.format('Hits: 1->%d, +%d%% Atk, +%d Acc', h, r * 4, r * 3) end }),
        makeCurveNode({ key = 'spin_pack', name = 'Pack Momentum & STR', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'STR +15->100% WSC & +5->35% WSD per extra enemy (max 5)',
            rankDesc = function(r)
                local str = ({ 15, 30, 45, 60, 75, 88, 100 })[r]
                return string.format('STR +%d%%, +%d%% Dmg per extra mob', str, r * 5)
            end }),
        makeCurveNode({ key = 'spin_force', name = 'Cyclone Force', tier = 2, col = 1, maxRank = 5,
            zeroDesc = '+9/18/27/36/45% AoE Attack & +9/18/27/36/45 Acc',
            rankDesc = function(r) return string.format('+%d%% Atk, +%d Acc', r * 9, r * 9) end }),
        makeCurveNode({ key = 'spin_swarm', name = 'Swarm Pressure', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+3/6/9/12/15% extra Dmg per nearby mob (up to +250% total in 5+ packs)',
            rankDesc = function(r) return string.format('+%d%% extra Dmg/mob, +%d%% WSD', r * 3, r * 4) end }),
        makeCurveNode({ key = 'spin_fire', name = 'Firestorm Spin', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'Adds Fire follow-up splash scaling with mob count (16..80%)',
            rankDesc = function(r) return string.format('Fire AoE Splash %d%% (+mob scale)', r * 16) end }),
        makeCurveNode({ key = 'spin_mftp', name = 'Sweep fTP', tier = 3, col = 2, maxRank = 5,
            zeroDesc = 'R1-4: +4/8/12/16% WSD | R5: fTP applies to ALL Hits!',
            rankDesc = function(r) return r >= 5 and 'fTP ALL HITS + +16% WSD (MAX)' or string.format('+%d%% WSD (R5: fTP all hits)', r * 4) end }),
        makeCurveNode({ key = 'capstone', name = 'Maelstrom', tier = 4, col = 1, maxRank = 3, requires = { key = 'spin_swarm', rank = 1 },
            zeroDesc = 'Capstone: +10/20/30% AoE WSD & +1 Hit when >=2 enemies nearby',
            rankDesc = function(r) return string.format('+%d%% AoE WSD, +1 Hit in packs', r * 10) end }),
        makeCurveNode({ key = 'spin_mast', name = 'Pack Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+6/12/18/24/30% Crit Rate & +5/10/15/20/25% Crit Dmg',
            rankDesc = function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 6, r * 5) end }),
    },
})

-- #7 Howling Fist (Pure Heavy High-TP / High-DEF Buster, 56 pts)
registerCustomH2H(7,
{
    archetype = 'heavy',
    nodes =
    {
        h2hFtpCurveNode({ 2.25, 3.60, 5.20 }, 6),
        makeCurveNode({ key = 'hf_pierce', name = 'Heavy Twin & Pierce', tier = 1, col = 2, maxRank = 7,
            zeroDesc = '1->2h, Ignores 4->28% DEF & +4->28% WS Atk right from Lv 1',
            rankDesc = function(r) return string.format('1->2h, %d%% DEF Ign, +%d%% Atk', r * 4, r * 4) end }),
        makeCurveNode({ key = 'hf_tp_wsc', name = 'TP Overflow & WSC', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'STR +5->30% / VIT +10->60% WSC & +75->500 TP Bonus at Lv 1',
            rankDesc = function(r)
                local s = math.floor(r * 30 / 7 + 0.5)
                local v = math.floor(r * 60 / 7 + 0.5)
                local tp = ({ 75, 140, 210, 280, 350, 425, 500 })[r]
                return string.format('STR +%d%%/VIT +%d%%, +%d TP Bonus', s, v, tp)
            end }),
        makeCurveNode({ key = 'hf_atk', name = 'Crushing Howl', tier = 2, col = 1, maxRank = 5,
            zeroDesc = '+13/26/39/52/65% WS Attack',
            rankDesc = function(r) return string.format('+%d%% WS Attack', r * 13) end }),
        makeCurveNode({ key = 'hf_prec', name = 'Heavy Precision', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+10/20/30/40/50 Acc & +4/8/12/16/20% WSD',
            rankDesc = function(r) return string.format('+%d Acc, +%d%% WSD', r * 10, r * 4) end }),
        makeCurveNode({ key = 'hf_sonic', name = 'Sonic Breath', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'Adds Wind Sonic follow-up hit (8/16/24/32/40% WS dmg)',
            rankDesc = function(r) return string.format('Sonic Breath +%d%% follow-up hit', r * 8) end }),
        makeCurveNode({ key = 'hf_res', name = 'Resonant Howl', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+5/10/15/20/25% Crit Rate & +5/10/15/20/25% Crit Dmg',
            rankDesc = function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 5, r * 5) end }),
        makeCurveNode({ key = 'capstone', name = 'Howling Execution', tier = 4, col = 1, maxRank = 3, requires = { key = 'hf_atk', rank = 1 },
            zeroDesc = 'Capstone: fTP ALL HITS + +8/16/25% WSD',
            rankDesc = function(r) return string.format('fTP ALL HITS + +%d%% WSD', ({ 8, 16, 25 })[r]) end }),
        makeCurveNode({ key = 'hf_mast', name = 'Heavy Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+10/20/30/40/50 Acc & +5/10/15/20/25% Crit Rate',
            rankDesc = function(r) return string.format('+%d Acc, +%d%% Crit Rate', r * 10, r * 5) end }),
    },
})

-- #8 Dragon Kick (Pure Footwork Kick Finisher, 56 pts)
registerCustomH2H(8,
{
    archetype = 'heavy',
    nodes =
    {
        h2hFtpCurveNode({ 1.50, 2.50, 3.80 }, 6),
        makeCurveNode({ key = 'dk_hits', name = 'Twin Kick & WSC', tier = 1, col = 2, maxRank = 7,
            zeroDesc = '1->2h, STR/VIT +10->60% WSC & +5->35 Acc',
            rankDesc = function(r)
                local w = ({ 10, 18, 26, 35, 44, 52, 60 })[r]
                return string.format('1->2h, STR/VIT +%d%%, +%d Acc', w, r * 5)
            end }),
        makeCurveNode({ key = 'dk_fw', name = 'Footwork Stance', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'Under Footwork: +0.10->0.70 fTP & +6->42% Atk right from Lv 1',
            rankDesc = function(r)
                local f = ({ 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70 })[r]
                return string.format('Footwork: +%.2f fTP, +%d%% Atk', f, r * 6)
            end }),
        makeCurveNode({ key = 'dk_force', name = 'Dragon Force', tier = 2, col = 1, maxRank = 5,
            zeroDesc = '+10/20/30/40/50% WS Attack & +6/12/18/24/30 Acc',
            rankDesc = function(r) return string.format('+%d%% WS Attack, +%d Acc', r * 10, r * 6) end }),
        makeCurveNode({ key = 'dk_crit', name = 'Shatter Kick', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+7/14/21/28/35% Crit Rate & +8/16/24/32/40 Acc',
            rankDesc = function(r) return string.format('+%d%% Crit, +%d Acc', r * 7, r * 8) end }),
        makeCurveNode({ key = 'dk_flame', name = 'Wyrm Flame', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'Adds Fire kick follow-up hit (7/14/21/28/35% WS dmg)',
            rankDesc = function(r) return string.format('Wyrm Flame +%d%% follow-up hit', r * 7) end }),
        makeCurveNode({ key = 'dk_mom', name = 'Dragon Momentum', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+5/10/15/20/25% WSD & +6/12/18/24/30% Crit Dmg',
            rankDesc = function(r) return string.format('+%d%% WSD, +%d%% Crit Dmg', r * 5, r * 6) end }),
        makeCurveNode({ key = 'capstone', name = 'True Dragon Kick', tier = 4, col = 1, maxRank = 3, requires = { key = 'dk_force', rank = 1 },
            zeroDesc = 'Capstone: fTP ALL HITS + +10/20/30% extra Footwork WSD',
            rankDesc = function(r) return string.format('fTP ALL HITS + +%d%% Footwork WSD', r * 10) end }),
        makeCurveNode({ key = 'dk_mast', name = 'Kick Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+5/10/15/20/25% WSD & +100/200/300/400/500 Footwork TP Bonus',
            rankDesc = function(r) return string.format('+%d%% WSD, +%d Footwork TP Bonus', r * 5, r * 100) end }),
    },
})

-- #9 Asuran Fists (8-Hit 1000-TP / Anti-Evasion Specialist, 56 pts)
registerCustomH2H(9,
{
    archetype = 'multihit',
    nodes =
    {
        h2hFtpCurveNode({ 0.85, 1.00, 1.15 }, 6),
        makeCurveNode({ key = 'af_hits1', name = 'Asuran Rush I', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'Rebuild flurry 1->5h (+1 offhand) & +3->21% Atk',
            rankDesc = function(r)
                local h = ({ 2, 2, 3, 3, 4, 4, 5 })[r]
                return string.format('Hits: 1->%d, +%d%% Atk', h, r * 3)
            end }),
        makeCurveNode({ key = 'acc_mult', name = 'True Accuracy & WSC', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'STR/VIT +4->25% WSC & TP-scaled WS Acc up to +140 Acc at Lv 1',
            rankDesc = function(r)
                local w = ({ 4, 8, 12, 16, 19, 22, 25 })[r]
                return string.format('STR/VIT +%d%%, +%d/%d/%d Acc', w, r * 9, r * 14, r * 20)
            end }),
        makeCurveNode({ key = 'af_hits2', name = 'Asuran Rush II', tier = 2, col = 1, maxRank = 5,
            zeroDesc = 'R1-3: +1/+2/+3 Hits (5->8h!) | R4-5: +10/20% Atk',
            rankDesc = function(r) local add = math.min(r, 3); return string.format('+%d Hits (up to 8h), +%d%% Atk', add, math.max(0, r - 3) * 10) end }),
        makeCurveNode({ key = 'af_barrage', name = 'Iron Barrage', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+6/12/18/24/30% WS Atk & +10/20/30/40/50 Acc',
            rankDesc = function(r) return string.format('+%d%% WS Atk, +%d Acc', r * 6, r * 10) end }),
        makeCurveNode({ key = 'af_mftp', name = 'Hundred-Hand fTP', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'R1-4: +6/12/18/24% Atk | R5: fTP applies to ALL Hits!',
            rankDesc = function(r) return r >= 5 and 'fTP ALL HITS + +24% Atk (MAX)' or string.format('+%d%% Atk (R5: fTP all hits)', r * 6) end }),
        makeCurveNode({ key = 'af_focus', name = 'Focus Resonance', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+6/12/18/24/30% Crit Rate w/ Focus & +5/10/15/20/25% Crit Dmg',
            rankDesc = function(r) return string.format('+%d%% Focus Crit, +%d%% Crit Dmg', r * 6, r * 5) end }),
        makeCurveNode({ key = 'capstone', name = 'Asuran Zenith', tier = 4, col = 1, maxRank = 3, requires = { key = 'af_mftp', rank = 1 },
            zeroDesc = 'Capstone: +0.05/0.10/0.16 flat fTP & +8/16/24% WSD',
            rankDesc = function(r) return string.format('+%.2f flat fTP & +%d%% WSD', ({ 0.05, 0.10, 0.16 })[r], r * 8) end }),
        makeCurveNode({ key = 'af_mast', name = 'Relentless Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+5/10/15/20/25% Atk & +12/24/36/48/60 WS Acc',
            rankDesc = function(r) return string.format('+%d%% Atk, +%d Acc', r * 5, r * 12) end }),
    },
})

-- #10 Final Heaven (Relic High-Subtle-Blow Light Finisher, 56 pts)
registerCustomH2H(10,
{
    archetype = 'heavy',
    nodes =
    {
        h2hFtpCurveNode({ 1.80, 2.25, 2.75 }, 6),
        makeCurveNode({ key = 'fh_hits', name = 'Twin Heaven & VIT', tier = 1, col = 2, maxRank = 7,
            zeroDesc = '1->2h, VIT +12->85% WSC & +5->35 Acc right at Lv 1',
            rankDesc = function(r)
                local v = ({ 12, 24, 36, 48, 60, 72, 85 })[r]
                return string.format('1->2h, VIT +%d%% WSC, +%d Acc', v, r * 5)
            end }),
        makeCurveNode({ key = 'fh_sb', name = 'Subtle Soul & Enmity-', tier = 1, col = 3, maxRank = 7,
            zeroDesc = '+6->40 Subtle Blow & -9->-60 Enmity on WS right at Lv 1',
            rankDesc = function(r)
                local sb = ({ 6, 12, 18, 24, 30, 35, 40 })[r]
                local en = ({ 9, 18, 27, 36, 44, 52, 60 })[r]
                return string.format('+%d Subtle Blow, -%d Enmity', sb, en)
            end }),
        makeCurveNode({ key = 'def_ignore', name = 'Heavenly Pierce', tier = 2, col = 1, maxRank = 5,
            zeroDesc = 'Ignores 7/14/21/28/35% Target Defense',
            rankDesc = function(r) return string.format('Ignores %d%% Target DEF', r * 7) end }),
        makeCurveNode({ key = 'fh_sanc', name = 'Sanctuary Force', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+8/16/24/32/40% WS Atk & +10/20/30/40/50 Acc',
            rankDesc = function(r) return string.format('+%d%% WS Atk, +%d Acc', r * 8, r * 10) end }),
        makeCurveNode({ key = 'fh_light', name = 'Heavenly Radiance', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'Adds Light elemental follow-up hit (8/16/24/32/40% Dmg)',
            rankDesc = function(r) return string.format('Light Breath +%d%% follow-up hit', r * 8) end }),
        makeCurveNode({ key = 'aftermath_echo', name = 'Relic Echo', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+5/10/15/20/25% WSD & +60/120/180/240/300 TP Bonus',
            rankDesc = function(r) return string.format('+%d%% WSD, +%d TP Bonus', r * 5, r * 60) end }),
        makeCurveNode({ key = 'capstone', name = 'Final Ascension', tier = 4, col = 1, maxRank = 3, requires = { key = 'fh_light', rank = 1 },
            zeroDesc = 'Capstone: fTP ALL HITS + +10/18/26% WSD & +8/16/24% SC Dmg',
            rankDesc = function(r) return string.format('fTP ALL HITS, +%d%% WSD, +%d%% SC', ({ 10, 18, 26 })[r], r * 8) end }),
        makeCurveNode({ key = 'fh_mast', name = 'Relic Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+9/18/27/36/45% WS Atk & +10/20/30/40/50 Acc',
            rankDesc = function(r) return string.format('+%d%% Atk, +%d Acc', r * 9, r * 10) end }),
    },
})

-- #11 Ascetics Fury (Mythic High-DEF / Crit Executioner, 56 pts)
registerCustomH2H(11,
{
    archetype = 'crit',
    nodes =
    {
        h2hFtpCurveNode({ 1.10, 1.50, 2.00 }, 6),
        makeCurveNode({ key = 'afury_hits', name = 'Twin Fury & WSC', tier = 1, col = 2, maxRank = 7,
            zeroDesc = '1->2h, STR/VIT +10->65% WSC & +5->35 Acc right at Lv 1',
            rankDesc = function(r)
                local w = ({ 10, 20, 30, 40, 50, 58, 65 })[r]
                return string.format('1->2h, STR/VIT +%d%%, +%d Acc', w, r * 5)
            end }),
        makeCurveNode({ key = 'afury_atk', name = 'Ascetic Attack & Crit', tier = 1, col = 3, maxRank = 7,
            zeroDesc = '+20->150% WS Attack & +3->20% early Crit Rate right at Lv 1',
            rankDesc = function(r)
                local atk = ({ 20, 40, 62, 85, 108, 130, 150 })[r]
                local cr = ({ 3, 6, 9, 12, 15, 18, 20 })[r]
                return string.format('+%d%% WS Atk, +%d%% Crit', atk, cr)
            end }),
        makeCurveNode({ key = 'crit', name = 'Merciless Crit', tier = 2, col = 1, maxRank = 5,
            zeroDesc = 'TP-varying Crit Rate: up to +15/25/35/45/55% max TP crit scaling',
            rankDesc = function(r)
                local t = ({ { 8, 12, 18 }, { 12, 18, 26 }, { 16, 25, 36 }, { 20, 32, 46 }, { 25, 40, 55 } })[r]
                return string.format('Crit +%d/%d/%d%%', t[1], t[2], t[3])
            end }),
        makeCurveNode({ key = 'afury_pierce', name = 'Fury Pierce', tier = 2, col = 2, maxRank = 5,
            zeroDesc = 'Ignores 6/12/18/24/30% Target DEF & +10..50 Acc',
            rankDesc = function(r) return string.format('%d%% DEF Ign, +%d Acc', r * 6, r * 10) end }),
        makeCurveNode({ key = 'afury_critdmg', name = 'Lethal Edge', tier = 3, col = 1, maxRank = 5,
            zeroDesc = '+7/14/21/28/35% Critical Hit Damage on WS',
            rankDesc = function(r) return string.format('+%d%% WS Crit Damage', r * 7) end }),
        makeCurveNode({ key = 'aftermath_echo', name = 'Mythic Echo', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+5/10/15/20/25% WSD & +60/120/180/240/300 TP Bonus',
            rankDesc = function(r) return string.format('+%d%% WSD, +%d TP Bonus', r * 5, r * 60) end }),
        makeCurveNode({ key = 'capstone', name = 'Ascetics Zenith', tier = 4, col = 1, maxRank = 3, requires = { key = 'crit', rank = 1 },
            zeroDesc = 'Capstone: fTP ALL HITS + +15% Crit & +8/16/24% WSD',
            rankDesc = function(r) return string.format('fTP ALL HITS, +15%% Crit, +%d%% WSD', r * 8) end }),
        makeCurveNode({ key = 'afury_mast', name = 'Fury Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+10/20/30/40/50% WS Atk & +12/24/36/48/60 Acc',
            rankDesc = function(r) return string.format('+%d%% WS Atk, +%d Acc', r * 10, r * 12) end }),
    },
})

-- #12 Stringing Pummel (Mythic 6-Hit Crit Barrage, 56 pts)
registerCustomH2H(12,
{
    archetype = 'crit',
    nodes =
    {
        h2hFtpCurveNode({ 1.00, 1.15, 1.35 }, 6),
        makeCurveNode({ key = 'sp_hits1', name = 'Pummel Rush I', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'Rebuild 1->4 Hits (+1 offhand) & +3->21% Atk',
            rankDesc = function(r) local h = r >= 5 and 4 or (r >= 3 and 3 or 2); return string.format('Hits: 1->%d, +%d%% Atk', h, r * 3) end }),
        makeCurveNode({ key = 'sp_crit_wsc', name = 'Pummel Crit & WSC', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'STR/VIT +6->40% WSC & +3->18% early Crit Rate right at Lv 1',
            rankDesc = function(r)
                local w = ({ 6, 12, 18, 24, 30, 35, 40 })[r]
                local c = ({ 3, 5, 8, 10, 13, 15, 18 })[r]
                return string.format('STR/VIT +%d%%, +%d%% Crit', w, c)
            end }),
        makeCurveNode({ key = 'sp_hits2', name = 'Pummel Rush II', tier = 2, col = 1, maxRank = 5,
            zeroDesc = 'R1-2: 4->6 Hits! | R3-5: +10/20/30% Atk',
            rankDesc = function(r) local h = math.min(r, 2); return string.format('+%d Hits (up to 6h), +%d%% Atk', h, math.max(0, r - 2) * 10) end }),
        makeCurveNode({ key = 'crit', name = 'Barrage Crit', tier = 2, col = 2, maxRank = 5,
            zeroDesc = 'TP Crit Rate: up to +12/18/24/32/38% max TP crit scaling',
            rankDesc = function(r)
                local t = ({ { 6, 9, 12 }, { 9, 14, 18 }, { 12, 18, 25 }, { 14, 22, 32 }, { 16, 26, 38 } })[r]
                return string.format('Crit +%d/%d/%d%%', t[1], t[2], t[3])
            end }),
        makeCurveNode({ key = 'sp_critdmg', name = 'Barrage Crit Dmg', tier = 3, col = 1, maxRank = 5,
            zeroDesc = '+7/14/21/28/35% Critical Hit Damage on WS',
            rankDesc = function(r) return string.format('+%d%% WS Crit Damage', r * 7) end }),
        makeCurveNode({ key = 'aftermath_echo', name = 'Mythic Echo', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+5/10/15/20/25% WSD & +60/120/180/240/300 TP Bonus',
            rankDesc = function(r) return string.format('+%d%% WSD, +%d TP Bonus', r * 5, r * 60) end }),
        makeCurveNode({ key = 'capstone', name = 'Grand Pummel', tier = 4, col = 1, maxRank = 3, requires = { key = 'crit', rank = 1 },
            zeroDesc = 'Capstone: fTP ALL HITS + +8/15/22% WSD',
            rankDesc = function(r) return string.format('fTP ALL HITS + +%d%% WSD', ({ 8, 15, 22 })[r]) end }),
        makeCurveNode({ key = 'sp_mast', name = 'Barrage Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+8/16/24/32/40% WS Atk & +10/20/30/40/50 Acc',
            rankDesc = function(r) return string.format('+%d%% Atk, +%d Acc', r * 8, r * 10) end }),
    },
})

-- #13 Tornado Kick (Multi-Kick Footwork / Wind Specialist, 56 pts)
registerCustomH2H(13,
{
    archetype = 'multihit',
    nodes =
    {
        h2hFtpCurveNode({ 1.15, 1.75, 2.65 }, 6),
        makeCurveNode({ key = 'tk_hits', name = 'Gale Kicks & WSC', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'Rebuild 1->3 Hits & STR/VIT +8->50% WSC, +4->28 Acc',
            rankDesc = function(r)
                local h = r >= 5 and 3 or 2
                local w = ({ 8, 15, 22, 29, 36, 43, 50 })[r]
                return string.format('Hits: 1->%d, STR/VIT +%d%%, +%d Acc', h, w, r * 4)
            end }),
        makeCurveNode({ key = 'tk_fw', name = 'Cyclone Footwork', tier = 1, col = 3, maxRank = 7,
            zeroDesc = '+7->50% WSD & +6->42% Atk under Footwork right at Lv 1',
            rankDesc = function(r)
                local wsd = ({ 7, 14, 21, 28, 35, 42, 50 })[r]
                return string.format('Footwork: +%d%% WSD, +%d%% Atk', wsd, r * 6)
            end }),
        makeCurveNode({ key = 'tk_force', name = 'Gale Force', tier = 2, col = 1, maxRank = 5,
            zeroDesc = '+9/18/27/36/45% WS Atk & +9/18/27/36/45 Acc',
            rankDesc = function(r) return string.format('+%d%% Atk, +%d Acc', r * 9, r * 9) end }),
        makeCurveNode({ key = 'tk_edge', name = 'Cyclone Edge', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+5/10/15/20/25% Crit Rate & +5/10/15/20/25% Crit Dmg',
            rankDesc = function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 5, r * 5) end }),
        makeCurveNode({ key = 'tk_wind', name = 'Tempest Splash', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'Adds Wind elemental kick follow-up hit (7/14/21/28/36% Dmg)',
            rankDesc = function(r) return string.format('Wind Kick +%d%% follow-up hit', ({ 7, 14, 21, 28, 36 })[r]) end }),
        makeCurveNode({ key = 'tk_tp', name = 'Cyclone Stance TP', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+90/180/270/360/450 TP Bonus w/ Footwork or Dodge',
            rankDesc = function(r) return string.format('+%d TP Bonus w/ Footwork/Dodge', r * 90) end }),
        makeCurveNode({ key = 'capstone', name = 'Eye of Tornado', tier = 4, col = 1, maxRank = 3, requires = { key = 'tk_force', rank = 1 },
            zeroDesc = 'Capstone: fTP ALL HITS + +8/16/24% WSD',
            rankDesc = function(r) return string.format('fTP ALL HITS + +%d%% WSD', r * 8) end }),
        makeCurveNode({ key = 'tk_mast', name = 'Gale Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+6/12/18/24/30% Crit Rate & +5/10/15/20/25% Crit Dmg',
            rankDesc = function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 6, r * 5) end }),
    },
})

-- #14 Victory Smite (Empyrean 4-Hit Pure STR Crit Finisher, 56 pts)
registerCustomH2H(14,
{
    archetype = 'crit',
    nodes =
    {
        h2hFtpCurveNode({ 1.15, 1.35, 1.60 }, 6),
        makeCurveNode({ key = 'vs_hits', name = 'Smite Flurry', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'Rebuild 1->4 Hits (+1 offhand) & +4->28% WS Atk',
            rankDesc = function(r) local h = r >= 5 and 4 or (r >= 3 and 3 or 2); return string.format('Hits: 1->%d, +%d%% Atk', h, r * 4) end }),
        makeCurveNode({ key = 'vs_str_crit', name = 'STR Force & Crit', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'STR +15->90% WSC & +3->18% early Crit Rate right at Lv 1',
            rankDesc = function(r)
                local s = ({ 15, 28, 42, 55, 68, 80, 90 })[r]
                local c = ({ 3, 5, 8, 10, 13, 15, 18 })[r]
                return string.format('STR +%d%% WSC, +%d%% Crit', s, c)
            end }),
        makeCurveNode({ key = 'crit', name = 'Smite Crit', tier = 2, col = 1, maxRank = 5,
            zeroDesc = 'TP Crit Rate: up to +15/22/30/38/45% max TP crit scaling',
            rankDesc = function(r)
                local t = ({ { 8, 12, 15 }, { 11, 16, 22 }, { 14, 21, 30 }, { 17, 27, 38 }, { 20, 32, 45 } })[r]
                return string.format('Crit +%d/%d/%d%%', t[1], t[2], t[3])
            end }),
        makeCurveNode({ key = 'vs_force', name = 'Empyrean Force', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+9/18/27/36/45% WS Atk & +9/18/27/36/45 Acc',
            rankDesc = function(r) return string.format('+%d%% Atk, +%d Acc', r * 9, r * 9) end }),
        makeCurveNode({ key = 'vs_critdmg', name = 'Keen Smite', tier = 3, col = 1, maxRank = 5,
            zeroDesc = '+7/14/21/28/35% Critical Hit Damage on WS',
            rankDesc = function(r) return string.format('+%d%% WS Crit Damage', r * 7) end }),
        makeCurveNode({ key = 'aftermath_echo', name = 'Empyrean Echo', tier = 3, col = 2, maxRank = 5,
            zeroDesc = '+5/10/15/20/25% WSD & +60/120/180/240/300 TP Bonus',
            rankDesc = function(r) return string.format('+%d%% WSD, +%d TP Bonus', r * 5, r * 60) end }),
        makeCurveNode({ key = 'capstone', name = 'Triumphant Smite', tier = 4, col = 1, maxRank = 3, requires = { key = 'crit', rank = 1 },
            zeroDesc = 'Capstone: fTP ALL HITS + +8/15/22% WSD',
            rankDesc = function(r) return string.format('fTP ALL HITS + +%d%% WSD', ({ 8, 15, 22 })[r]) end }),
        makeCurveNode({ key = 'vs_mast', name = 'Victor Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+8/16/24/32/40% WSD w/ Impetus or Focus & +12..60 Acc',
            rankDesc = function(r) return string.format('+%d%% Impetus/Focus WSD, +%d Acc', r * 8, r * 12) end }),
    },
})

-- #15 Shijin Spiral (Merit 5-Hit Pure DEX Fusion Finisher, 56 pts)
registerCustomH2H(15,
{
    archetype = 'multihit',
    nodes =
    {
        h2hFtpCurveNode({ 1.05, 1.35, 1.65 }, 6),
        makeCurveNode({ key = 'ss_hits', name = 'Spiral Flurry', tier = 1, col = 2, maxRank = 7,
            zeroDesc = 'Rebuild 1->5 Hits (+1 offhand) & +4->28% WS Atk',
            rankDesc = function(r) local h = ({ 2, 2, 3, 3, 4, 4, 5 })[r]; return string.format('Hits: 1->%d, +%d%% Atk', h, r * 4) end }),
        makeCurveNode({ key = 'ss_dex_prec', name = 'Spiral Precision & DEX', tier = 1, col = 3, maxRank = 7,
            zeroDesc = 'DEX +12->85% WSC & +12->85 WS Accuracy right at Lv 1',
            rankDesc = function(r)
                local d = ({ 12, 24, 36, 48, 60, 72, 85 })[r]
                local a = ({ 12, 24, 36, 48, 60, 72, 85 })[r]
                return string.format('DEX +%d%% WSC, +%d WS Acc', d, a)
            end }),
        makeCurveNode({ key = 'ss_force', name = 'Four-Gods Force', tier = 2, col = 1, maxRank = 5,
            zeroDesc = '+8/16/24/32/40% WS Attack & +4/8/12/16/20% WSD',
            rankDesc = function(r) return string.format('+%d%% Atk, +%d%% WSD', r * 8, r * 4) end }),
        makeCurveNode({ key = 'ss_stance', name = 'Stance Flow', tier = 2, col = 2, maxRank = 5,
            zeroDesc = '+6/12/18/24/30% WSD while Impetus or Focus is active',
            rankDesc = function(r) return string.format('+%d%% Stance WSD', r * 6) end }),
        makeCurveNode({ key = 'ss_mftp', name = 'Spiral fTP', tier = 3, col = 1, maxRank = 5,
            zeroDesc = 'R1-4: +6/12/18/24% WSD | R5: fTP applies to ALL Hits!',
            rankDesc = function(r) return r >= 5 and 'fTP ALL HITS + +24% WSD (MAX)' or string.format('+%d%% WSD (R5: fTP all hits)', r * 6) end }),
        makeCurveNode({ key = 'ss_wind', name = 'Wind Spiral', tier = 3, col = 2, maxRank = 5,
            zeroDesc = 'Adds Wind elemental burst hit (6/12/18/24/30% WS dmg)',
            rankDesc = function(r) return string.format('Wind +%d%% follow-up hit', r * 6) end }),
        makeCurveNode({ key = 'capstone', name = 'Shijin Zenith', tier = 4, col = 1, maxRank = 3, requires = { key = 'ss_mftp', rank = 1 },
            zeroDesc = 'Capstone: +10/20/30% SC Damage & +8/16/24% WSD',
            rankDesc = function(r) return string.format('+%d%% SC Dmg, +%d%% WSD', r * 10, r * 8) end }),
        makeCurveNode({ key = 'ss_mast', name = 'Spiral Mastery', tier = 4, col = 2, maxRank = 5,
            zeroDesc = '+6/12/18/24/30% Crit Rate & +5/10/15/20/25% Crit Dmg',
            rankDesc = function(r) return string.format('+%d%% Crit, +%d%% Crit Dmg', r * 6, r * 5) end }),
    },
})

-----------------------------------
-- Dynamic Tree Builder (Custom + Generic 4-Tier Fallback for #16+)
-----------------------------------
local treeCache = {}

local function finalizeTree(ws, archetype, rawNodes)
    local nodes = {}
    local colUsed = { {}, {}, {}, {} }

    for _, n in ipairs(rawNodes) do
        colUsed[n.tier][n.col] = true
        table.insert(nodes, n)
    end

    -- Add Skillchain Augment selector node on Col 4 in EVERY tier (1..4)
    for scTier = 1, 4 do
        table.insert(nodes, makeSCTierNode(ws, scTier, 4))
    end

    -- Sort cleanly by tier, then col, and assign deterministic storage slots (1..20)
    table.sort(nodes, function(a, b)
        if a.tier ~= b.tier then
            return a.tier < b.tier
        end
        return a.col < b.col
    end)

    local byKey = {}
    for idx, node in ipairs(nodes) do
        node.slot = idx
        local gate = talents.TIER_GATES[node.tier] or talents.TIER_GATES[1]
        node.reqWsPoints = node.reqWsPoints ~= nil and node.reqWsPoints or gate.reqWsPoints
        node.reqLevel    = node.reqLevel ~= nil and node.reqLevel or gate.reqLevel
        byKey[node.key]  = node
    end

    return
    {
        ws        = ws,
        archetype = archetype,
        nodes     = nodes,
        byKey     = byKey,
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

local function buildGenericTreeForWS(ws)
    local orig = ws.orig
    local nodes = {}
    local usedKeys = {}
    local archetype = determineArchetype(ws)

    local function addNode(node)
        usedKeys[node.key] = true
        table.insert(nodes, node)
    end

    -- Tier 1 (Lv 1+, 0+ WS pts): 6 + 7 + 7 + 2 (SC) = 22 pts
    addNode(
    {
        key = 'ftp',
        name = 'TP Scaling',
        tier = 1,
        col = 1,
        maxRank = 6,
        describe = function(rank)
            local f = talents.calcFtpAtRank(orig.ftp, rank, 6)
            return string.format('fTP: %.2f/%.2f/%.2f%s', f[1], f[2], f[3], rank >= 6 and ' (MAX)' or '')
        end,
    })

    local wscList = {}
    for _, stat in ipairs(STAT_ORDER) do
        local weight = orig.wsc[stat]
        if weight ~= nil and weight > 0 then
            table.insert(wscList, { stat = stat, weight = weight, upper = STAT_LABELS[stat] })
        end
    end

    if #wscList >= 1 then
        local w1 = wscList[1]
        addNode(
        {
            key = 'wsc_' .. w1.stat,
            stat = w1.stat,
            origWeight = w1.weight,
            name = w1.upper .. ' WSC',
            tier = 1,
            col = 2,
            maxRank = 7,
            describe = function(rank)
                local cur = talents.calcWscAtRank(w1.weight, rank, 7)
                return string.format('%s WSC %s (orig %s)%s', w1.upper, fmtPct(cur), fmtPct(w1.weight), rank >= 7 and ' (MAX)' or '')
            end,
        })
    else
        addNode(
        {
            key = 'potency',
            name = 'Potency Scaling',
            tier = 1,
            col = 2,
            maxRank = 7,
            describe = function(rank)
                return string.format('+%d%% HP/MP/Utility potency', rank * 15)
            end,
        })
    end

    -- Tier 1 Col 3 (7 pts): Signature early trait (Hits, Debuff, Crit, DEF Ign, 2nd WSC, or Combat Edge)
    local deferredWsc2 = nil
    if orig.numHits >= 2 then
        local targetHits = orig.numHits
        addNode(
        {
            key = 'hits_t1',
            name = 'Strike Rhythm',
            tier = 1,
            col = 3,
            maxRank = 7,
            describe = function(rank)
                local h = 1 + math.min(targetHits - 1, math.ceil((targetHits - 1) * (rank / 7)))
                return rank == 0 and string.format('Earn back hits (1->%dh) & Acc/Atk', targetHits)
                    or string.format('Hits: 1->%d, +%d Acc, +%d%% Atk', h, rank * 5, rank * 3)
            end,
        })
        if #wscList >= 2 then
            deferredWsc2 = wscList[2]
        end
    elseif orig.debuff ~= nil then
        local deb = orig.debuff
        addNode(
        {
            key = 'debuff',
            name = deb.label .. ' +',
            tier = 1,
            col = 3,
            maxRank = 7,
            describe = function(rank)
                if rank == 0 then
                    return '+15..135% Dur, +18..125 MACC & Potency'
                end
                local dur = ({ 15, 30, 45, 65, 85, 110, 135 })[rank]
                local macc = ({ 18, 36, 54, 72, 90, 110, 125 })[rank]
                return string.format('+%d%% Dur, +%d MACC', dur, macc)
            end,
        })
        if #wscList >= 2 then
            deferredWsc2 = wscList[2]
        end
    elseif orig.critVaries ~= nil then
        addNode(
        {
            key = 'crit',
            name = 'Critical Edge',
            tier = 1,
            col = 3,
            maxRank = 7,
            describe = function(rank)
                if rank == 0 then
                    return 'TP Crit scaling (+up to 45% crit & +21% dmg)'
                end
                local c = talents.calcScaledTable(orig.critVaries, rank, { 0.20, 0.32, 0.45 }, 7)
                return string.format('Crit %s/%s/%s, +%d%% Crit Dmg', fmtPct(c[1]), fmtPct(c[2]), fmtPct(c[3]), rank * 3)
            end,
        })
        if #wscList >= 2 then
            deferredWsc2 = wscList[2]
        end
    elseif orig.ignoredDefense ~= nil then
        addNode(
        {
            key = 'def_ignore',
            name = 'Armor Piercer',
            tier = 1,
            col = 3,
            maxRank = 7,
            describe = function(rank)
                if rank == 0 then
                    return 'Restores & boosts Defense Ignore (up to 45%)'
                end
                local d = talents.calcScaledTable(orig.ignoredDefense, rank, { 0.25, 0.35, 0.45 }, 7)
                return string.format('Ignores %s/%s/%s DEF', fmtPct(d[1]), fmtPct(d[2]), fmtPct(d[3]))
            end,
        })
        if #wscList >= 2 then
            deferredWsc2 = wscList[2]
        end
    elseif #wscList >= 2 then
        local w2 = wscList[2]
        addNode(
        {
            key = 'wsc_' .. w2.stat,
            stat = w2.stat,
            origWeight = w2.weight,
            name = w2.upper .. ' WSC',
            tier = 1,
            col = 3,
            maxRank = 7,
            describe = function(rank)
                local cur = talents.calcWscAtRank(w2.weight, rank, 7)
                return string.format('%s WSC %s (orig %s)%s', w2.upper, fmtPct(cur), fmtPct(w2.weight), rank >= 7 and ' (MAX)' or '')
            end,
        })
    else
        addNode(
        {
            key = 't1_edge',
            name = archetype == 'magic' and 'Arcane Focus' or (archetype == 'utility' and 'Tactical Edge' or 'Opening Edge'),
            tier = 1,
            col = 3,
            maxRank = 7,
            describe = function(rank)
                if archetype == 'magic' then
                    return string.format('+%d MAB, +%d MACC on WS', rank * 5, rank * 6)
                elseif archetype == 'utility' then
                    return string.format('+%d%% Atk, +%d Acc, +%d Subtle Blow', rank * 5, rank * 5, rank * 3)
                end
                return string.format('+%d%% WS Atk, +%d Acc', rank * 6, rank * 6)
            end,
        })
    end

    -- Tier 2 (Lv 20+, 10+ WS pts): 5 + 5 + 2 (SC) = 12 pts
    local t2Col = 1
    local function addT2(node)
        if t2Col > 2 or usedKeys[node.key] then
            return
        end
        node.tier = 2
        node.col = t2Col
        node.maxRank = 5
        node.requires = node.requires or { key = 'ftp', rank = 1 }
        addNode(node)
        t2Col = t2Col + 1
    end

    if orig.numHits >= 2 then
        addT2(
        {
            key = 'multihit',
            name = 'Flurry Strikes',
            describe = function(rank)
                if rank == 0 then
                    return 'R1-3:+Acc/Atk | R4:fTP ALL Hits | R5:+1 Hit'
                end
                return string.format('+%d Acc, +%d%% Atk%s%s', rank * 10, rank * 7, rank >= 4 and ', fTP ALL' or '', rank >= 5 and ', +1 Hit' or '')
            end,
        })
    end

    if deferredWsc2 ~= nil then
        local w2 = deferredWsc2
        addT2(
        {
            key = 'wsc_' .. w2.stat,
            stat = w2.stat,
            origWeight = w2.weight,
            name = w2.upper .. ' WSC',
            describe = function(rank)
                local cur = talents.calcWscAtRank(w2.weight, rank, 5)
                return string.format('%s WSC %s (orig %s)%s', w2.upper, fmtPct(cur), fmtPct(w2.weight), rank >= 5 and ' (MAX)' or '')
            end,
        })
    end

    if orig.debuff ~= nil then
        local deb = orig.debuff
        addT2(
        {
            key = 'debuff',
            name = deb.label .. ' +',
            describe = function(rank)
                if rank == 0 then
                    return '+15..85% Dur, +18..90 MACC & Potency'
                end
                local dur = ({ 15, 30, 45, 65, 85 })[rank]
                local macc = ({ 18, 36, 54, 72, 90 })[rank]
                return string.format('+%d%% Dur, +%d MACC', dur, macc)
            end,
        })
    end

    if orig.critVaries ~= nil then
        addT2(
        {
            key = 'crit',
            name = 'Critical Edge',
            describe = function(rank)
                if rank == 0 then
                    return 'TP crit scaling (+up to 40% crit, +20% dmg)'
                end
                local c = talents.calcScaledTable(orig.critVaries, rank, { 0.16, 0.28, 0.40 }, 5)
                return string.format('Crit %s/%s/%s, +%d%% Crit Dmg', fmtPct(c[1]), fmtPct(c[2]), fmtPct(c[3]), rank * 4)
            end,
        })
    end

    if orig.ignoredDefense ~= nil then
        addT2(
        {
            key = 'def_ignore',
            name = 'Armor Piercer',
            describe = function(rank)
                if rank == 0 then
                    return 'Restores & boosts Defense Ignore'
                end
                local d = talents.calcScaledTable(orig.ignoredDefense, rank, { 0.20, 0.30, 0.40 }, 5)
                return string.format('Ignores %s/%s/%s DEF', fmtPct(d[1]), fmtPct(d[2]), fmtPct(d[3]))
            end,
        })
    end

    if t2Col <= 2 then
        addT2(
        {
            key = 'focused',
            name = 'Focused Power',
            describe = function(rank)
                return string.format('+%d%% WS Atk, +%d Acc', rank * 10, rank * 12)
            end,
        })
    end
    if t2Col <= 2 then
        addT2(
        {
            key = 'keen_instinct',
            name = 'Keen Instinct',
            describe = function(rank)
                return string.format('+%d%% WSD, +%d%% Crit Rate', rank * 4, rank * 4)
            end,
        })
    end

    -- Tier 3 (Lv 42+, 22+ WS pts): 5 + 5 + 2 (SC) = 12 pts
    local t3Col = 1
    local function addT3(node)
        if t3Col > 2 or usedKeys[node.key] then
            return
        end
        node.tier = 3
        node.col = t3Col
        node.maxRank = 5
        addNode(node)
        t3Col = t3Col + 1
    end

    if orig.atkVaries ~= nil then
        addT3(
        {
            key = 'atk_mult',
            name = 'Crushing Force',
            describe = function(rank)
                if rank == 0 then
                    return 'TP-varying WS Attack multiplier'
                end
                local a = talents.calcAtkScaleAtRank(orig.atkVaries, rank, 5)
                return string.format('WS Atk +%s/+%s/+%s', fmtPct(a[1]), fmtPct(a[2]), fmtPct(a[3]))
            end,
        })
    end

    if orig.aftermath ~= nil then
        local amNames = { relic = 'Relic Echo', mythic = 'Mythic Echo', empyrean = 'Empyrean Echo' }
        addT3(
        {
            key = 'aftermath_echo',
            name = amNames[orig.aftermath] or 'RMEA Echo',
            describe = function(rank)
                return string.format('+%d%% WS Dmg, +%d TP Bonus', rank * 5, rank * 60)
            end,
        })
    end

    if ws.wsType == 'magic' or ws.wsType == 'hybrid' or ws.element ~= nil or orig.drainHp then
        addT3(
        {
            key = 'elemental',
            name = (ws.elementName or 'Elemental') .. ' Surge',
            describe = function(rank)
                return string.format('+%d MAB and +%d MACC on WS', rank * 12, rank * 12)
            end,
        })
    end

    if t3Col <= 2 then
        addT3(
        {
            key = 'master_force',
            name = 'Heavy Force',
            describe = function(rank)
                return string.format('+%d%% WSD, +%d%% WS Atk', rank * 5, rank * 8)
            end,
        })
    end
    if t3Col <= 2 then
        addT3(
        {
            key = 'master_prec',
            name = 'Precision Instinct',
            describe = function(rank)
                return string.format('+%d Acc, +%d%% Crit Rate', rank * 14, rank * 5)
            end,
        })
    end

    -- Tier 4 (Lv 62+, 35+ WS pts): 3 + 5 + 2 (SC) = 10 pts
    local capstoneSpecs =
    {
        magic    = { name = 'Arcane Overcharge', desc = '+20/35/50 MAB, +20/35/50 MACC, +10/20/30% WSD' },
        crit     = { name = 'Fatal Execution',   desc = '+8/14/20% Crit, +10/18/26% Crit DMG, +0.3/0.7/1.0 fTP' },
        multihit = { name = 'Relentless Flurry', desc = 'fTP ALL Hits, +10/18/28% WSD' },
        heavy    = { name = 'Brutal Impact',     desc = '+15/30/45% WS Atk, 10/18/25% DEF Ign, +8/16/24% WSD' },
        utility  = { name = 'Masters Utility',   desc = '+20/38/55% WS Potency, +10/20/30% Subtle Blow' },
    }
    local capInfo = capstoneSpecs[archetype] or capstoneSpecs.heavy
    addNode(
    {
        key = 'capstone',
        name = capInfo.name,
        archetype = archetype,
        tier = 4,
        col = 1,
        requires = { key = 'ftp', rank = 2 },
        maxRank = 3,
        describe = function(rank)
            return rank > 0 and (capInfo.desc .. (rank >= 3 and ' (MAX)' or (' (R' .. rank .. ')'))) or capInfo.desc
        end,
    })

    addNode(
    {
        key = 'ws_mastery',
        name = 'Combat Mastery',
        tier = 4,
        col = 2,
        maxRank = 5,
        describe = function(rank)
            return string.format('+%d%% WSD, +%d Acc', rank * 5, rank * 10)
        end,
    })

    return finalizeTree(ws, archetype, nodes)
end

local function buildTreeForWS(ws)
    local custom = CUSTOM_TREES[ws.id]
    if custom ~= nil then
        local copied = {}
        for _, n in ipairs(custom.nodes) do
            table.insert(copied, n)
        end
        return finalizeTree(ws, custom.archetype, copied)
    end
    return buildGenericTreeForWS(ws)
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
    return math.max(1, player:getJobLevel(jid)) * 3
end

function talents.getWSRanks(player, jobId, wsId)
    local tree = talents.getTreeForWS(wsId)
    if tree == nil then
        return {}, 0
    end

    local ranks = {}
    local spent = 0
    for _, node in ipairs(tree.nodes) do
        local r = math.min(node.maxRank, readSlotRank(player, jobId, wsId, node.slot))
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
    local total = 0
    local perWs = {}
    local seenWs = {}

    local function scanPrefix(prefix)
        local vars = player:getCharVarsWithPrefix(prefix)
        for varName, packed in pairs(vars) do
            if packed > 0 then
                local wsId = tonumber(string.sub(varName, #prefix + 1))
                if wsId ~= nil and not seenWs[wsId] and catalog.byId[wsId] ~= nil then
                    seenWs[wsId] = true
                    local _, wsSpent = talents.getWSRanks(player, jid, wsId)
                    if wsSpent > 0 then
                        perWs[wsId] = wsSpent
                        total = total + wsSpent
                    end
                end
            end
        end
    end

    scanPrefix(talents.getVarPrefix(jid))
    scanPrefix(talents.getVar2Prefix(jid))

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

    local reqLevel = node.reqLevel or 1
    local jobLvl = math.max(1, player:getJobLevel(jobId or player:getMainJob()))
    if jobLvl < reqLevel then
        return false, string.format('Requires Level %d %s (currently %d).', reqLevel, talents.getJobKey(jobId or player:getMainJob()), jobLvl)
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
    local curRank = readSlotRank(player, jobId, wsId, node.slot)
    local newRank = curRank + 1

    writeSlotRank(player, jobId, wsId, node.slot, newRank)
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

    writeSlotRank(player, jobId, wsId, node.slot, curRank - 1)
    return true, curRank - 1
end

function talents.resetWS(player, jobId, wsId)
    if catalog.byId[wsId] == nil then
        return false
    end

    player:setCharVar(talents.getVarName(jobId, wsId), 0)
    player:setCharVar(talents.getVar2Name(jobId, wsId), 0)
    player:setCharVar(talents.getScVarName(jobId, wsId), 0)
    return true
end

function talents.resetAll(player, jobId)
    local jid = jobId or player:getMainJob()
    local count = 0

    local function clearPrefix(prefix)
        local vars = player:getCharVarsWithPrefix(prefix)
        for varName, val in pairs(vars) do
            if val ~= 0 then
                player:setCharVar(varName, 0)
                count = count + 1
            end
        end
    end

    clearPrefix(talents.getVarPrefix(jid))
    clearPrefix(talents.getVar2Prefix(jid))
    clearPrefix(talents.getScVarPrefix(jid))

    return count
end

-----------------------------------
-- Ashita Protocol Sync Helpers
-----------------------------------
function talents.formatActiveSummary(player, jobId, ws, ranks)
    local scData = talents.getActiveSkillchains(player, jobId, ws.id, ranks)
    local scParts = {}
    for _, scId in ipairs(scData.ids) do
        table.insert(scParts, SC_SHORT[scId] or SC_NAMES[scId] or tostring(scId))
    end
    local scText = #scParts > 0 and table.concat(scParts, '/') or 'NONE'
    local tree = talents.getTreeForWS(ws.id)
    local maxPts = 0
    for _, n in ipairs(tree and tree.nodes or {}) do
        maxPts = maxPts + n.maxRank
    end
    return string.format('Base: 1h fTP 1.0 | Active SC: %s (+%d%%) | Max: %d pts', scText, scData.scBonus, maxPts)
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
    local summary = talents.formatActiveSummary(player, jobId, ws, ranks)

    sendProto(player, string.format('WS|%u|%s|%s|%s|%u|%s', ws.id, sanitizeField(ws.name), sanitizeField(ws.skillName), ws.wsType, wsSpent, sanitizeField(summary)))

    for _, node in ipairs(tree.nodes) do
        local r = ranks[node.key] or 0
        local canLearn = talents.canInvest(player, jobId, wsId, node.key)
        local reqKey = node.requires and node.requires.key or ''
        local reqRank = node.requires and node.requires.rank or 0
        local desc = sanitizeField(node.describe(r, ws, player, jobId))
        if #desc > 60 then
            desc = string.sub(desc, 1, 57) .. '...'
        end
        local scTier = node.scTier or 0
        local scId = scTier > 0 and talents.getSCChoice(player, jobId, ws.id, scTier) or 0
        local scName = scId > 0 and (SC_SHORT[scId] or SC_NAMES[scId] or '') or ''

        sendProto(player, string.format('NODE|%u|%s|%u|%u|%u|%u|%u|%u|%s|%u|%s|%s|%u|%u|%u|%s',
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
            desc,
            node.reqLevel or 1,
            scTier,
            scId,
            scName
        ))
    end

    sendProto(player, string.format('WS_END|%u|%u', ws.id, avail))
end

return talents
