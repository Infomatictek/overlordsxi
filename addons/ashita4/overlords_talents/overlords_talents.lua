--[[
* OverlordsXI - Weaponskill Talent Tree Addon for Ashita v4
*
* Communicates silently with the LandSandBoat !talent command using
* [OXTAL]|... tagged 0x017 packets (blocked from the chat log).
*
* Commands:
*   /talents         - Toggle the talent tree window
*   /tal             - Alias for /talents
*   /talents sync    - Force resync catalog & points from server
--]]

addon.name    = 'overlords_talents'
addon.author  = 'OverlordsXI'
addon.version = '1.0.0'
addon.desc    = 'Per-weaponskill talent tree UI for OverlordsXI.'

require('common')
local bit   = require('bit')
local imgui = require('imgui')

local PROTO_TAG     = '[OXTAL]|'
local CHILD_NONE    = ImGuiChildFlags_None or 0
local CHILD_BORDERS = ImGuiChildFlags_Borders or ImGuiChildFlags_Border or 1

local SKILL_LIST =
{
    { id = -1, name = 'Equipped' },
    { id = 0,  name = 'All Weapons' },
    { id = 1,  name = 'Hand-to-Hand' },
    { id = 2,  name = 'Dagger' },
    { id = 3,  name = 'Sword' },
    { id = 4,  name = 'Great Sword' },
    { id = 5,  name = 'Axe' },
    { id = 6,  name = 'Great Axe' },
    { id = 7,  name = 'Scythe' },
    { id = 8,  name = 'Polearm' },
    { id = 9,  name = 'Katana' },
    { id = 10, name = 'Great Katana' },
    { id = 11, name = 'Club' },
    { id = 12, name = 'Staff' },
    { id = 25, name = 'Archery' },
    { id = 26, name = 'Marksmanship' },
}

local state =
{
    open            = { false },
    synced          = false,
    syncRequestedAt = 0,
    jobKey          = '---',
    jobLevel        = 1,
    avail           = 0,
    spent           = 0,
    earned          = 1,
    mainSkill       = 0,
    rangedSkill     = 0,
    catalog         = {},       -- ordered list of { id, skill, name, wsType }
    catalogById     = {},
    tempCatalog     = nil,
    spentByWs       = {},
    tempSpent       = nil,
    selectedSkill   = -1,       -- -1 = Equipped
    selectedWsId    = nil,
    wsDetail        = nil,      -- { id, name, skillName, wsType, spent, orig, nodes = {} }
    tempWs          = nil,
    searchBuf       = { '' },
    investedOnly    = { false },
    confirmResetAll = false,
    confirmResetAt  = 0,
    statusText      = nil,
    statusTime      = 0,
    lastKnownJob    = nil,
    lastKnownLvl    = nil,
    lastAutoCheck   = 0,
    renderError     = nil,
}

local function abgr(r, g, b, a)
    if imgui.ColorConvertFloat4ToU32 then
        return imgui.ColorConvertFloat4ToU32({ r, g, b, a or 1.0 })
    end
    local val = bit.bor(
        bit.lshift(math.floor((a or 1) * 255), 24),
        bit.lshift(math.floor(b * 255), 16),
        bit.lshift(math.floor(g * 255), 8),
        math.floor(r * 255)
    )
    if val < 0 then
        val = val + 4294967296
    end
    return val
end

local function toXY(a, b)
    if type(a) == 'table' then
        return a[1] or a.x or 0, a[2] or a.y or 0
    end
    return a or 0, b or 0
end

local function splitPipe(str)
    local out = {}
    local start = 1
    while true do
        local pos = string.find(str, '|', start, true)
        if not pos then
            table.insert(out, string.sub(str, start))
            break
        end
        table.insert(out, string.sub(str, start, pos - 1))
        start = pos + 1
    end
    return out
end

local function queueServerCmd(subcmd)
    AshitaCore:GetChatManager():QueueCommand(1, '/say !talent ' .. subcmd)
end

local function setStatus(msg)
    state.statusText = msg
    state.statusTime = os.clock()
end

local function requestWS(wsId)
    if wsId == nil then
        return
    end
    state.selectedWsId = wsId
    queueServerCmd('ws ' .. tostring(wsId))
end

local function requestFullSync()
    state.syncRequestedAt = os.clock()
    queueServerCmd('sync')
end

-----------------------------------
-- Protocol Parser
-----------------------------------
local function handleProtoLine(payload)
    local parts = splitPipe(payload)
    local kind = parts[1]

    if kind == 'META' then
        state.jobKey      = parts[2] or '---'
        state.jobLevel    = tonumber(parts[3]) or 1
        state.avail       = tonumber(parts[4]) or 0
        state.spent       = tonumber(parts[5]) or 0
        state.earned      = tonumber(parts[6]) or 1
        state.mainSkill   = tonumber(parts[7]) or 0
        state.rangedSkill = tonumber(parts[8]) or 0
    elseif kind == 'SPENT_BEGIN' then
        state.tempSpent = {}
    elseif kind == 'SPENT' then
        state.tempSpent = state.tempSpent or {}
        if parts[2] and parts[2] ~= '' then
            for entry in string.gmatch(parts[2], '([^,]+)') do
                local wsId, pts = string.match(entry, '^(%d+):(%d+)$')
                if wsId and pts then
                    state.tempSpent[tonumber(wsId)] = tonumber(pts)
                end
            end
        end
    elseif kind == 'SPENT_END' then
        if state.tempSpent ~= nil then
            state.spentByWs = state.tempSpent
            state.tempSpent = nil
        end
    elseif kind == 'CAT_BEGIN' then
        state.tempCatalog = {}
    elseif kind == 'CAT' then
        state.tempCatalog = state.tempCatalog or {}
        if parts[2] and parts[2] ~= '' then
            for entry in string.gmatch(parts[2], '([^,]+)') do
                local wsId, skillId, name, wsType = string.match(entry, '^(%d+):(%d+):(.+):([^:]+)$')
                if wsId then
                    table.insert(state.tempCatalog,
                    {
                        id     = tonumber(wsId),
                        skill  = tonumber(skillId),
                        name   = name,
                        wsType = wsType,
                    })
                end
            end
        end
    elseif kind == 'CAT_END' then
        if state.tempCatalog ~= nil then
            state.catalog = state.tempCatalog
            state.catalogById = {}
            for _, ws in ipairs(state.catalog) do
                state.catalogById[ws.id] = ws
            end
            state.tempCatalog = nil
            state.synced = true
            if state.selectedWsId == nil then
                for _, ws in ipairs(state.catalog) do
                    if ws.skill == state.mainSkill or ws.skill == state.rangedSkill then
                        requestWS(ws.id)
                        break
                    end
                end
            elseif state.wsDetail == nil or state.wsDetail.id ~= state.selectedWsId then
                requestWS(state.selectedWsId)
            end
        end
    elseif kind == 'WS' then
        state.tempWs =
        {
            id        = tonumber(parts[2]),
            name      = parts[3] or 'Unknown',
            skillName = parts[4] or '',
            wsType    = parts[5] or 'physical',
            spent     = tonumber(parts[6]) or 0,
            orig      = parts[7] or '',
            nodes     = {},
            byKey     = {},
        }
    elseif kind == 'NODE' then
        if state.tempWs ~= nil and tonumber(parts[2]) == state.tempWs.id then
            local node =
            {
                key         = parts[3],
                tier        = tonumber(parts[4]) or 1,
                col         = tonumber(parts[5]) or 1,
                rank        = tonumber(parts[6]) or 0,
                maxRank     = tonumber(parts[7]) or 1,
                canLearn    = (tonumber(parts[8]) or 0) == 1,
                reqWsPoints = tonumber(parts[9]) or 0,
                reqKey      = parts[10] ~= '' and parts[10] or nil,
                reqRank     = tonumber(parts[11]) or 0,
                name        = parts[12] or parts[3],
                desc        = parts[13] or '',
                reqLevel    = tonumber(parts[14]) or 1,
                scTier      = tonumber(parts[15]) or 0,
                scId        = tonumber(parts[16]) or 0,
                scName      = parts[17] or '',
            }
            table.insert(state.tempWs.nodes, node)
            state.tempWs.byKey[node.key] = node
        end
    elseif kind == 'WS_END' then
        if state.tempWs ~= nil and tonumber(parts[2]) == state.tempWs.id then
            state.avail = tonumber(parts[3]) or state.avail
            state.wsDetail = state.tempWs
            state.tempWs = nil
        end
    elseif kind == 'ERR' then
        setStatus(parts[2] or 'Action failed.')
    end
end

-----------------------------------
-- Ashita Events
-----------------------------------
ashita.events.register('load', 'ox_talents_load', function()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    if player ~= nil and player:GetMainJob() > 0 then
        local getLvl = player.GetMainJobLevel or player.GetMainLevel
        state.lastKnownJob = player:GetMainJob()
        state.lastKnownLvl = getLvl and getLvl(player) or 1
    end
end)

ashita.events.register('command', 'ox_talents_cmd', function(e)
    local args = e.command:args()
    if #args == 0 then
        return
    end

    local cmd = string.lower(args[1])
    if cmd ~= '/talents' and cmd ~= '/tal' then
        return
    end

    e.blocked = true

    if args[2] ~= nil and string.lower(args[2]) == 'sync' then
        requestFullSync()
        setStatus('Syncing weaponskill talents from server...')
        return
    end

    state.open[1] = not state.open[1]
    if state.open[1] then
        if not state.synced then
            requestFullSync()
        else
            queueServerCmd('state')
            if state.selectedWsId ~= nil then
                requestWS(state.selectedWsId)
            end
        end
    end
end)

ashita.events.register('packet_in', 'ox_talents_packet_in', function(e)
    if e.id ~= 0x017 then
        return
    end

    if #e.data < 25 then
        return
    end

    local msg = string.sub(e.data, 24):match('^([^%z]*)')
    if msg == nil or string.sub(msg, 1, #PROTO_TAG) ~= PROTO_TAG then
        return
    end

    e.blocked = true
    handleProtoLine(string.sub(msg, #PROTO_TAG + 1))
end)

-----------------------------------
-- ImGui Tree Renderer
-----------------------------------
local function getFilteredCatalog()
    local list = {}
    local rawQuery = (state.searchBuf[1] or ''):gsub('%z.*$', '')
    local query = string.lower(rawQuery)
    local sk = state.selectedSkill

    for _, ws in ipairs(state.catalog) do
        local matchSkill = false
        if sk == 0 then
            matchSkill = true
        elseif sk == -1 then
            matchSkill = (ws.skill == state.mainSkill) or (state.rangedSkill ~= 0 and ws.skill == state.rangedSkill)
        else
            matchSkill = (ws.skill == sk)
        end

        if matchSkill then
            local spent = state.spentByWs[ws.id] or 0
            local matchInvested = (not state.investedOnly[1]) or (spent > 0)
            local matchQuery = (query == '') or (string.find(string.lower(ws.name), query, 1, true) ~= nil)
            if matchInvested and matchQuery then
                table.insert(list, ws)
            end
        end
    end

    return list
end

local function drawTreeCanvas()
    local detail = state.wsDetail
    if detail == nil then
        imgui.TextDisabled('Select a weaponskill on the left to customize its talent tree.')
        if not state.synced then
            imgui.Spacing()
            if imgui.Button('Sync Catalog Now', { 160, 28 }) then
                requestFullSync()
            end
        end
        return
    end

    -- WS Header
    imgui.TextColored({ 1.0, 0.85, 0.35, 1.0 }, string.format('%s', detail.name))
    imgui.SameLine()
    imgui.TextDisabled(string.format('(%s | %s)', detail.skillName, detail.wsType))

    imgui.TextColored({ 0.72, 0.86, 1.0, 1.0 }, detail.orig)
    imgui.Text(string.format('Points in %s: %d   |   Available Job Points: %d', detail.name, detail.spent, state.avail))
    imgui.SameLine()
    if detail.spent > 0 then
        if imgui.SmallButton('Reset WS') then
            queueServerCmd('uresetws ' .. tostring(detail.id))
        end
    end

    imgui.TextDisabled('Left-Click node: +1 Rank  |  Right-Click node: -1 Rank  |  Col 4 < >: Pick Skillchain')
    imgui.Separator()

    -- Draw Tree Grid (4 Tiers x 4 Columns)
    local canvasPosX, canvasPosY = toXY(imgui.GetCursorScreenPos())
    local availW, availH = toXY(imgui.GetContentRegionAvail())
    local cardW = 160
    local cardH = 74
    local gapX  = 14
    local gapY  = 34

    local tierLabels =
    {
        [1] = 'Tier 1: Foundation (Lv 1+, 0+ WS pts)',
        [2] = 'Tier 2: Specialization (Lv 20+, 10+ WS pts)',
        [3] = 'Tier 3: Mastery (Lv 42+, 22+ WS pts)',
        [4] = 'Tier 4: Capstone (Lv 62+, 35+ WS pts)',
    }

    -- Compute node screen coordinates
    local coords = {}
    local maxCol = 1
    local maxTier = 1
    for _, node in ipairs(detail.nodes) do
        local tierRow = node.tier - 1
        local colIdx  = node.col - 1
        if node.col > maxCol then
            maxCol = node.col
        end
        if node.tier > maxTier then
            maxTier = node.tier
        end
        local x = canvasPosX + 10 + colIdx * (cardW + gapX)
        local y = canvasPosY + 24 + tierRow * (cardH + gapY)
        coords[node.key] = { x = x, y = y }
    end

    local dl = imgui.GetWindowDrawList()

    -- Draw Tier Headers
    for t = 1, maxTier do
        local hy = canvasPosY + 4 + (t - 1) * (cardH + gapY)
        imgui.SetCursorScreenPos({ canvasPosX + 10, hy })
        imgui.TextDisabled(tierLabels[t] or ('Tier ' .. tostring(t)))
    end

    -- Draw Prerequisite Connector Lines
    for _, node in ipairs(detail.nodes) do
        if node.reqKey ~= nil and coords[node.reqKey] ~= nil and coords[node.key] ~= nil then
            local p = coords[node.reqKey]
            local c = coords[node.key]
            local parentNode = detail.byKey[node.reqKey]
            local activeLink = (parentNode ~= nil and parentNode.rank >= node.reqRank)
                and (detail.spent >= node.reqWsPoints)
                and (state.jobLevel >= (node.reqLevel or 1))
            local lineCol = activeLink and abgr(0.95, 0.78, 0.25, 0.90) or abgr(0.38, 0.42, 0.48, 0.65)
            local x1 = p.x + cardW * 0.5
            local y1 = p.y + cardH
            local x2 = c.x + cardW * 0.5
            local y2 = c.y
            local midY = (y1 + y2) * 0.5
            dl:AddLine({ x1, y1 }, { x1, midY }, lineCol, 2.0)
            dl:AddLine({ x1, midY }, { x2, midY }, lineCol, 2.0)
            dl:AddLine({ x2, midY }, { x2, y2 }, lineCol, 2.0)
        end
    end

    -- Draw Node Cards
    for _, node in ipairs(detail.nodes) do
        local pos = coords[node.key]
        local x, y = pos.x, pos.y

        local isMaxed = node.rank >= node.maxRank
        local bgCol, borderCol, titleCol
        if isMaxed then
            bgCol     = abgr(0.14, 0.25, 0.28, 0.95)
            borderCol = abgr(1.00, 0.80, 0.22, 1.00)
            titleCol  = { 1.00, 0.88, 0.35, 1.00 }
        elseif node.rank > 0 then
            bgCol     = abgr(0.11, 0.22, 0.32, 0.95)
            borderCol = abgr(0.32, 0.76, 1.00, 1.00)
            titleCol  = { 0.55, 0.88, 1.00, 1.00 }
        elseif node.canLearn then
            bgCol     = abgr(0.11, 0.24, 0.16, 0.95)
            borderCol = abgr(0.30, 0.85, 0.45, 1.00)
            titleCol  = { 0.60, 1.00, 0.68, 1.00 }
        else
            bgCol     = abgr(0.12, 0.13, 0.16, 0.90)
            borderCol = abgr(0.35, 0.37, 0.42, 0.85)
            titleCol  = { 0.62, 0.64, 0.68, 1.00 }
        end

        dl:AddRectFilled({ x, y }, { x + cardW, y + cardH }, bgCol, 6.0)
        dl:AddRect({ x, y }, { x + cardW, y + cardH }, borderCol, 6.0, 0, 2.0)

        local isScNode = (node.scTier or 0) > 0
        local btnH = isScNode and (cardH - 22) or cardH
        imgui.SetCursorScreenPos({ x, y })
        imgui.InvisibleButton('##node_' .. node.key, { cardW, btnH })
        local hovered = imgui.IsItemHovered()

        if imgui.IsItemClicked(0) then
            queueServerCmd(string.format('uadd %u %s', detail.id, node.key))
        elseif imgui.IsItemClicked(1) then
            queueServerCmd(string.format('usub %u %s', detail.id, node.key))
        end

        -- Card Text Overlay
        imgui.SetCursorScreenPos({ x + 7, y + 5 })
        imgui.TextColored(titleCol, node.name)
        imgui.SetCursorScreenPos({ x + 7, y + 23 })
        imgui.Text(string.format('Rank: %d / %d', node.rank, node.maxRank))

        if isScNode then
            imgui.SetCursorScreenPos({ x + 7, y + 48 })
            if imgui.SmallButton('<##sc_prev_' .. node.key) then
                queueServerCmd(string.format('uscc %u %u -1', detail.id, node.scTier))
            end
            imgui.SameLine()
            imgui.TextColored({ 0.85, 0.92, 1.0, 1.0 }, node.scName ~= '' and node.scName or 'Pick')
            imgui.SameLine()
            imgui.SetCursorScreenPos({ x + cardW - 24, y + 48 })
            if imgui.SmallButton('>##sc_next_' .. node.key) then
                queueServerCmd(string.format('uscc %u %u 1', detail.id, node.scTier))
            end
        else
            imgui.SetCursorScreenPos({ x + 7, y + 42 })
            local shortDesc = #node.desc > 23 and (string.sub(node.desc, 1, 20) .. '...') or node.desc
            imgui.TextDisabled(shortDesc)
        end

        if hovered then
            imgui.BeginTooltip()
            local okTip, errTip = pcall(function()
                imgui.TextColored(titleCol, string.format('%s (%d/%d)', node.name, node.rank, node.maxRank))
                imgui.Separator()
                imgui.PushTextWrapPos(290)
                local okWrap, errWrap = pcall(function()
                    imgui.Text(node.desc)
                    if (node.reqLevel or 1) > 1 and state.jobLevel < node.reqLevel then
                        imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, string.format('Requires Level %d %s (currently %d).', node.reqLevel, state.jobKey, state.jobLevel))
                    end
                    if node.reqWsPoints > 0 and detail.spent < node.reqWsPoints then
                        imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, string.format('Requires %d points invested in %s.', node.reqWsPoints, detail.name))
                    end
                    if node.reqKey ~= nil then
                        local pNode = detail.byKey[node.reqKey]
                        if pNode ~= nil and pNode.rank < node.reqRank then
                            imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, string.format('Requires %s Rank %d.', pNode.name, node.reqRank))
                        end
                    end
                    if isScNode then
                        imgui.TextDisabled('Use < / > at bottom of card to choose Skillchain property.')
                    end
                end)
                imgui.PopTextWrapPos()
                if not okWrap then
                    error(errWrap)
                end
            end)
            imgui.EndTooltip()
            if not okTip then
                state.renderError = tostring(errTip)
            end
        end
    end

    -- Reserve canvas bounds for scrolling
    local contentW = 24 + maxCol * cardW + math.max(0, maxCol - 1) * gapX
    local contentH = 24 + maxTier * (cardH + gapY)
    imgui.SetCursorScreenPos({ canvasPosX, canvasPosY + math.max(availH - 10, contentH) })
    imgui.Dummy({ math.max(availW - 10, contentW), 4 })
end

local function drawSidebar()
    local curSkillName = 'Equipped'
    for _, sk in ipairs(SKILL_LIST) do
        if sk.id == state.selectedSkill then
            curSkillName = sk.name
            break
        end
    end

    imgui.PushItemWidth(-1)
    local okFilter, errFilter = pcall(function()
        if imgui.BeginCombo('##skill_filter', curSkillName) then
            local okCombo, errCombo = pcall(function()
                for _, sk in ipairs(SKILL_LIST) do
                    local isSel = (sk.id == state.selectedSkill)
                    if imgui.Selectable(sk.name, isSel) then
                        state.selectedSkill = sk.id
                    end
                end
            end)
            imgui.EndCombo()
            if not okCombo then
                error(errCombo)
            end
        end
        imgui.InputText('##ws_search', state.searchBuf, 64)
    end)
    imgui.PopItemWidth()
    if not okFilter then
        error(errFilter)
    end

    imgui.Checkbox('Invested Only', state.investedOnly)
    imgui.Separator()

    local filtered = getFilteredCatalog()
    if imgui.BeginChild('ox_ws_list', { 0, 0 }, CHILD_NONE) then
        local okList, errList = pcall(function()
            for _, ws in ipairs(filtered) do
                local pts = state.spentByWs[ws.id] or 0
                local eqMark = (ws.skill == state.mainSkill or (state.rangedSkill ~= 0 and ws.skill == state.rangedSkill)) and '* ' or ''
                local label = pts > 0 and string.format('%s%s [%d]##ws_%u', eqMark, ws.name, pts, ws.id)
                                      or string.format('%s%s##ws_%u', eqMark, ws.name, ws.id)
                local isSelected = (state.selectedWsId == ws.id)
                if imgui.Selectable(label, isSelected) then
                    requestWS(ws.id)
                end
            end
        end)
        if not okList then
            state.renderError = tostring(errList)
        end
    end
    imgui.EndChild()
end

local function drawMainContents()
    -- Top Header Bar
    imgui.TextColored({ 1.0, 0.85, 0.35, 1.0 }, string.format('%s Lv.%d', state.jobKey, state.jobLevel))
    imgui.SameLine()
    imgui.Text(string.format('  |  Available Points: %d  (Spent: %d / Earned: %d)', state.avail, state.spent, state.earned))
    imgui.SameLine()
    if imgui.Button('Sync') then
        requestFullSync()
    end
    imgui.SameLine()
    if not state.confirmResetAll then
        if imgui.Button('Reset All') then
            state.confirmResetAll = true
            state.confirmResetAt = os.clock()
        end
    else
        if os.clock() - state.confirmResetAt > 5.0 then
            state.confirmResetAll = false
        else
            if imgui.Button('Confirm Reset All!') then
                state.confirmResetAll = false
                queueServerCmd('ureset')
                if state.selectedWsId ~= nil then
                    requestWS(state.selectedWsId)
                end
                setStatus('Reset all weaponskill talents for ' .. state.jobKey .. '.')
            end
            imgui.SameLine()
            if imgui.Button('Cancel') then
                state.confirmResetAll = false
            end
        end
    end

    if state.statusText ~= nil then
        if os.clock() - state.statusTime > 4.0 then
            state.statusText = nil
        else
            imgui.SameLine()
            imgui.TextColored({ 1.0, 0.65, 0.35, 1.0 }, '  ' .. state.statusText)
        end
    end

    if state.renderError ~= nil then
        imgui.TextColored({ 1.0, 0.35, 0.35, 1.0 }, 'UI Error: ' .. state.renderError)
    end

    imgui.Separator()

    -- Left Sidebar: Weapon Type + WS List
    if imgui.BeginChild('ox_ws_sidebar', { 255, 0 }, CHILD_BORDERS) then
        local okSide, errSide = xpcall(drawSidebar, debug.traceback)
        if not okSide then
            state.renderError = tostring(errSide)
        end
    end
    imgui.EndChild()

    imgui.SameLine()

    -- Right Canvas: Selected WS Talent Tree
    if imgui.BeginChild('ox_ws_canvas', { 0, 0 }, CHILD_BORDERS) then
        local okCanvas, errCanvas = xpcall(drawTreeCanvas, debug.traceback)
        if not okCanvas then
            state.renderError = tostring(errCanvas)
        end
    end
    imgui.EndChild()
end

ashita.events.register('d3d_present', 'ox_talents_present', function()
    -- Auto-detect job or level changes
    local now = os.clock()
    if now - state.lastAutoCheck >= 1.0 then
        state.lastAutoCheck = now
        local player = AshitaCore:GetMemoryManager():GetPlayer()
        if player ~= nil and player:GetMainJob() > 0 then
            local getLvl = player.GetMainJobLevel or player.GetMainLevel
            local j = player:GetMainJob()
            local l = getLvl and getLvl(player) or 1
            if state.lastKnownJob ~= nil and (j ~= state.lastKnownJob or l ~= state.lastKnownLvl) then
                if state.open[1] then
                    queueServerCmd('state')
                end
            end
            state.lastKnownJob = j
            state.lastKnownLvl = l
        end
    end

    if not state.open[1] then
        return
    end

    imgui.SetNextWindowSize({ 940, 570 }, ImGuiCond_FirstUseEver or 4)
    if imgui.Begin('OverlordsXI - Weaponskill Talents###OXTalentsWin', state.open) then
        local okWin, errWin = xpcall(drawMainContents, debug.traceback)
        if not okWin then
            state.renderError = tostring(errWin)
            imgui.TextColored({ 1.0, 0.35, 0.35, 1.0 }, 'UI Error: ' .. state.renderError)
        end
    end
    imgui.End()
end)
