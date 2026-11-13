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
-- Persistence (3 bits per slot, up to 8 slots per WS)
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

local function determineArchetype(ws)
    local orig = ws.orig
    if ws.wsType == 'utility' then
        return 'utility'
    elseif ws.wsType == 'magic' or ws.wsType == 'hybrid' or ws.element ~= nil then
        return 'magic'
    elseif orig.critVaries ~= nil then
        return 'crit'
    elseif orig.numHits >= 2 then
        return 'multihit'
    end

    return 'heavy'
end

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
                return string.format('%s | Next: %.2f/%.2f/%.2f', curStr, nxt[1], nxt[2], nxt[3])
            end
            return curStr .. ' (MAX)'
        end,
    })

    -- Tier 1, Col 2..3 (Slots 2..4): Original Stat WSC (or Utility Potency)
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
                    return string.format('+%d%% HP/MP/Breath potency | Next: +%d%%', cur, (rank + 1) * 20)
                end
                return string.format('+%d%% HP/MP/Breath potency (MAX)', cur)
            end,
        })
    end

    -- Tier 2 (Slots 5..6, requires >= 3 pts in this WS, prereq ftp >= 1)
    local t2Col = 1
    local t2Slot = 5

    local function addT2Node(node)
        if t2Slot > 6 then
            return
        end
        node.slot = t2Slot
        node.tier = 2
        node.col = t2Col
        node.reqWsPoints = 3
        node.requires = { key = 'ftp', rank = 1 }
        table.insert(nodes, node)
        t2Slot = t2Slot + 1
        t2Col = t2Col + 1
    end

    if orig.numHits >= 2 then
        addT2Node(
        {
            key = 'multihit',
            name = 'Flurry Strikes',
            maxRank = 3,
            describe = function(rank)
                if rank == 0 then
                    return 'R1: +15 Acc/+10% Atk | R2: fTP all hits | R3: +1 Hit'
                elseif rank == 1 then
                    return '+15 Acc/+10% Atk | Next: fTP carries to all hits'
                elseif rank == 2 then
                    return '+30 Acc/+20% Atk, fTP all hits | Next: +1 Extra Hit'
                end
                return '+45 Acc/+30% Atk, fTP all hits, +1 Hit (MAX)'
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
                    return 'Restores TP crit scaling (+10-30% crit, +5-15% crit dmg)'
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
                    return 'Restores & boosts Defense Ignore (up to 120% orig)'
                end
                local d = calcScaledTable(orig.ignoredDefense, rank, { 0.08, 0.12, 0.16 })
                return string.format('Ignores %s/%s/%s target DEF', fmtPct(d[1]), fmtPct(d[2]), fmtPct(d[3]))
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
                    return 'Restores & boosts WS Attack multiplier with TP'
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
                    return 'Restores & boosts TP-varying WS Accuracy'
                end
                local ac = calcScaledTable(orig.accVaries, rank, { 20, 25, 30 })
                return string.format('WS Acc +%d/+%d/+%d', math.floor(ac[1]), math.floor(ac[2]), math.floor(ac[3]))
            end,
        })
    end

    if ws.wsType == 'magic' or ws.wsType == 'hybrid' or ws.element ~= nil then
        local elemText = ws.elementName or 'Elemental'
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
                return string.format('+%d MAB and +%d MACC on this WS', val, val)
            end,
        })
    end

    if t2Slot == 5 then
        addT2Node(
        {
            key = 'focused',
            name = 'Focused Power',
            maxRank = 3,
            describe = function(rank)
                if rank == 0 then
                    return '+12/24/40% WS Attack & +15/30/50 WS Accuracy'
                end
                local atkPct = rank == 3 and 40 or (rank * 12)
                local accVal = rank == 3 and 50 or (rank * 15)
                return string.format('+%d%% WS Attack, +%d WS Accuracy', atkPct, accVal)
            end,
        })
    end

    -- Tier 3 (Slots 7..8, requires >= 6 pts in this WS)
    local t3PrereqKey = nodes[#nodes] and nodes[#nodes].key or 'ftp'

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
                return 'Refunds 100/200/350 TP after using this WS'
            end
            return string.format('Refunds +%d TP after using this WS', refund)
        end,
    })

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
            desc = '+35% WS Attack, 25% DEF Ignore, +15% WS Damage',
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
        col = 2,
        reqWsPoints = 6,
        requires = { key = t3PrereqKey, rank = 1 },
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
        table.insert(extraParts, string.format('%d-hit', orig.numHits))
    end
    if orig.critVaries then
        table.insert(extraParts, 'Crit')
    end
    if orig.ignoredDefense then
        table.insert(extraParts, 'DefIgn')
    end
    if orig.atkVaries then
        table.insert(extraParts, 'AtkMod')
    end
    if orig.accVaries then
        table.insert(extraParts, 'AccMod')
    end
    if ws.elementName then
        table.insert(extraParts, ws.elementName)
    end
    local extraStr = #extraParts > 0 and (' | ' .. table.concat(extraParts, ',')) or ''
    return string.format('%s | WSC: %s%s', ftpStr, wscStr, extraStr)
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
