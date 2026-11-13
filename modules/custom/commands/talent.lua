-----------------------------------
-- func: talent
-- desc: Weaponskill talent tree UI, CLI, and Ashita v4 sync protocol.
-----------------------------------
require('modules/custom/lua/overlords_ws_catalog')
require('modules/custom/lua/overlords_ws_talents')
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 'sss',
}

local catalog = xi.overlords.wsCatalog
local talents = xi.overlords.wsTalents

local function tell(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
end

local function sendProtoErr(player, message)
    player:printToPlayer('[OXTAL]|ERR|' .. tostring(message), xi.msg.channel.SYSTEM_3, '')
end

local function delaySendMenu(player, menuBuilder)
    player:timer(50, function(playerArg)
        if playerArg ~= nil then
            playerArg:customMenu(menuBuilder())
        end
    end)
end

-----------------------------------
-- Paginated customMenu Fallback UI
-----------------------------------
local openRootMenu
local openSkillListMenu
local openWSListMenu
local openWSDetailMenu

openWSDetailMenu = function(player, wsId, backFn)
    local jobId = player:getMainJob()
    local tree = talents.getTreeForWS(wsId)
    if tree == nil then
        return { title = 'Unknown WS', options = { { 'Back', function(p) delaySendMenu(p, backFn) end } } }
    end

    local ws = tree.ws
    local avail = talents.getAvailablePoints(player, jobId)
    local ranks, wsSpent = talents.getWSRanks(player, jobId, wsId)
    local options = {}

    for _, node in ipairs(tree.nodes) do
        local r = ranks[node.key] or 0
        local canLearn = talents.canInvest(player, jobId, wsId, node.key)
        local statusTag = r >= node.maxRank and 'MAX' or (canLearn and '+' or 'LOCK')
        local label = string.format('[%s] %s (%d/%d)', statusTag, node.name, r, node.maxRank)
        local capturedKey = node.key
        local capturedNode = node
        local capturedRank = r

        table.insert(options,
        {
            label,
            function(p)
                tell(p, string.format('%s [%d/%d]: %s', capturedNode.name, capturedRank, capturedNode.maxRank, capturedNode.describe(capturedRank, ws)))
                local ok, res = talents.invest(p, p:getMainJob(), wsId, capturedKey)
                if ok then
                    tell(p, string.format('Upgraded %s -> %s Rank %d/%d.', ws.name, capturedNode.name, res, capturedNode.maxRank))
                    talents.sendMetaAndSpent(p)
                else
                    tell(p, res)
                end
                delaySendMenu(p, function() return openWSDetailMenu(p, wsId, backFn) end)
            end,
        })
    end

    if wsSpent > 0 then
        table.insert(options,
        {
            string.format('Reset %s (%d pts)', ws.name, wsSpent),
            function(p)
                talents.resetWS(p, p:getMainJob(), wsId)
                tell(p, string.format('Reset all talent points in %s.', ws.name))
                talents.sendMetaAndSpent(p)
                delaySendMenu(p, function() return openWSDetailMenu(p, wsId, backFn) end)
            end,
        })
    end

    table.insert(options,
    {
        'Back',
        function(p)
            delaySendMenu(p, backFn)
        end,
    })

    return
    {
        title = string.format('%s | WS:%d | Avail:%d', ws.name, wsSpent, avail),
        options = options,
    }
end

openWSListMenu = function(player, title, wsList, page, backFn)
    local jobId = player:getMainJob()
    local perPage = 5
    local totalPages = math.max(1, math.ceil(#wsList / perPage))
    local curPage = math.max(1, math.min(page or 1, totalPages))
    local startIdx = (curPage - 1) * perPage + 1
    local endIdx = math.min(#wsList, startIdx + perPage - 1)

    local options = {}
    for i = startIdx, endIdx do
        local ws = wsList[i]
        local spent = talents.getWSSpent(player, jobId, ws.id)
        local label = spent > 0 and string.format('%s [%d pts]', ws.name, spent) or ws.name
        local capturedId = ws.id
        table.insert(options,
        {
            label,
            function(p)
                delaySendMenu(p, function()
                    return openWSDetailMenu(p, capturedId, function()
                        return openWSListMenu(p, title, wsList, curPage, backFn)
                    end)
                end)
            end,
        })
    end

    if curPage < totalPages then
        table.insert(options,
        {
            string.format('Next Page (%d/%d)', curPage + 1, totalPages),
            function(p)
                delaySendMenu(p, function() return openWSListMenu(p, title, wsList, curPage + 1, backFn) end)
            end,
        })
    end

    if curPage > 1 then
        table.insert(options,
        {
            string.format('Prev Page (%d/%d)', curPage - 1, totalPages),
            function(p)
                delaySendMenu(p, function() return openWSListMenu(p, title, wsList, curPage - 1, backFn) end)
            end,
        })
    end

    table.insert(options,
    {
        'Back',
        function(p)
            delaySendMenu(p, backFn)
        end,
    })

    return
    {
        title = string.format('%s (%d/%d)', title, curPage, totalPages),
        options = options,
    }
end

openSkillListMenu = function(player, page)
    local skills = catalog.skillOrder
    local perPage = 5
    local totalPages = math.max(1, math.ceil(#skills / perPage))
    local curPage = math.max(1, math.min(page or 1, totalPages))
    local startIdx = (curPage - 1) * perPage + 1
    local endIdx = math.min(#skills, startIdx + perPage - 1)
    local options = {}

    for i = startIdx, endIdx do
        local sk = skills[i]
        local list = catalog.bySkill[sk.skill] or {}
        table.insert(options,
        {
            string.format('%s (%d)', sk.name, #list),
            function(p)
                delaySendMenu(p, function()
                    return openWSListMenu(p, sk.name, list, 1, function()
                        return openSkillListMenu(p, curPage)
                    end)
                end)
            end,
        })
    end

    if curPage < totalPages then
        table.insert(options,
        {
            'Next Page',
            function(p)
                delaySendMenu(p, function() return openSkillListMenu(p, curPage + 1) end)
            end,
        })
    end

    if curPage > 1 then
        table.insert(options,
        {
            'Prev Page',
            function(p)
                delaySendMenu(p, function() return openSkillListMenu(p, curPage - 1) end)
            end,
        })
    end

    table.insert(options,
    {
        'Back',
        function(p)
            delaySendMenu(p, function() return openRootMenu(p) end)
        end,
    })

    return
    {
        title = string.format('Weapon Categories (%d/%d)', curPage, totalPages),
        options = options,
    }
end

openRootMenu = function(player)
    local jobId = player:getMainJob()
    local jobKey = talents.getJobKey(jobId)
    local avail, earned, spent = talents.getAvailablePoints(player, jobId)
    local mainSkill = player:getWeaponSkillType(xi.slot.MAIN) or 0
    local rangedSkill = player:getWeaponSkillType(xi.slot.RANGED) or 0

    local equippedList = {}
    for _, ws in ipairs(catalog.bySkill[mainSkill] or {}) do
        table.insert(equippedList, ws)
    end
    if rangedSkill ~= 0 and rangedSkill ~= mainSkill then
        for _, ws in ipairs(catalog.bySkill[rangedSkill] or {}) do
            table.insert(equippedList, ws)
        end
    end

    local _, perWs = talents.getTotalSpent(player, jobId)
    local investedList = {}
    for wsId, _ in pairs(perWs) do
        if catalog.byId[wsId] then
            table.insert(investedList, catalog.byId[wsId])
        end
    end
    table.sort(investedList, function(a, b) return a.id < b.id end)

    local options = {}
    if #equippedList > 0 then
        table.insert(options,
        {
            string.format('Equipped Weapon WS (%d)', #equippedList),
            function(p)
                delaySendMenu(p, function()
                    return openWSListMenu(p, 'Equipped Weapon', equippedList, 1, function() return openRootMenu(p) end)
                end)
            end,
        })
    end

    table.insert(options,
    {
        'Browse All Weapon Types',
        function(p)
            delaySendMenu(p, function() return openSkillListMenu(p, 1) end)
        end,
    })

    if #investedList > 0 then
        table.insert(options,
        {
            string.format('Invested WS (%d)', #investedList),
            function(p)
                delaySendMenu(p, function()
                    return openWSListMenu(p, 'Invested WS', investedList, 1, function() return openRootMenu(p) end)
                end)
            end,
        })
    end

    if spent > 0 then
        table.insert(options,
        {
            string.format('Reset All %s Talents (%d pts)', jobKey, spent),
            function(p)
                delaySendMenu(p, function()
                    return
                    {
                        title = string.format('Confirm Reset All %s?', jobKey),
                        options =
                        {
                            {
                                'Yes, Reset All Points',
                                function(p2)
                                    talents.resetAll(p2, p2:getMainJob())
                                    tell(p2, string.format('Reset all %s weaponskill talent points.', jobKey))
                                    talents.sendMetaAndSpent(p2)
                                    delaySendMenu(p2, function() return openRootMenu(p2) end)
                                end,
                            },
                            {
                                'Cancel',
                                function(p2)
                                    delaySendMenu(p2, function() return openRootMenu(p2) end)
                                end,
                            },
                        },
                    }
                end)
            end,
        })
    end

    table.insert(options, { 'Close', function() end })

    return
    {
        title = string.format('%s WS Talents (%d/%d avail)', jobKey, avail, earned),
        options = options,
    }
end

-----------------------------------
-- Command Entrypoint
-----------------------------------
local function combineArgs(a, b)
    if a == nil then
        return nil
    end
    if b == nil or b == '' then
        return a
    end
    return a .. ' ' .. b
end

commandObj.onTrigger = function(player, action, arg1, arg2)
    local cmd = action and string.lower(action) or nil
    local jobId = player:getMainJob()

    if cmd == nil or cmd == 'menu' then
        player:customMenu(openRootMenu(player))
        return
    end

    -----------------------------------
    -- Silent Ashita v4 UI Protocol
    -----------------------------------
    if cmd == 'sync' then
        talents.sendCatalogSync(player)
        return
    end

    if cmd == 'state' then
        talents.sendMetaAndSpent(player)
        return
    end

    if cmd == 'ws' then
        local ws = catalog.resolve(combineArgs(arg1, arg2))
        if ws == nil then
            sendProtoErr(player, 'Unknown weaponskill.')
            return
        end
        talents.sendWSDetail(player, ws.id)
        return
    end

    if cmd == 'uadd' then
        local ws = catalog.resolve(arg1)
        if ws == nil or arg2 == nil then
            sendProtoErr(player, 'Invalid uadd arguments.')
            return
        end
        local ok, res = talents.invest(player, jobId, ws.id, string.lower(arg2))
        if not ok then
            sendProtoErr(player, res)
            return
        end
        talents.sendMetaAndSpent(player)
        talents.sendWSDetail(player, ws.id)
        return
    end

    if cmd == 'usub' then
        local ws = catalog.resolve(arg1)
        if ws == nil or arg2 == nil then
            sendProtoErr(player, 'Invalid usub arguments.')
            return
        end
        local ok, res = talents.refundNode(player, jobId, ws.id, string.lower(arg2))
        if not ok then
            sendProtoErr(player, res)
            return
        end
        talents.sendMetaAndSpent(player)
        talents.sendWSDetail(player, ws.id)
        return
    end

    if cmd == 'uresetws' then
        local ws = catalog.resolve(arg1)
        if ws == nil then
            sendProtoErr(player, 'Unknown weaponskill.')
            return
        end
        talents.resetWS(player, jobId, ws.id)
        talents.sendMetaAndSpent(player)
        talents.sendWSDetail(player, ws.id)
        return
    end

    if cmd == 'ureset' then
        talents.resetAll(player, jobId)
        talents.sendMetaAndSpent(player)
        return
    end

    -----------------------------------
    -- Chat / Macro Commands
    -----------------------------------
    if cmd == 'help' then
        tell(player, 'Usage: !talent | !talent info <ws> | !talent add <ws> <node> | !talent sub <ws> <node> | !talent reset [ws]')
        return
    end

    if cmd == 'info' then
        local ws = catalog.resolve(combineArgs(arg1, arg2))
        if ws == nil then
            tell(player, 'Unknown weaponskill. Example: !talent info fast_blade')
            return
        end
        local tree = talents.getTreeForWS(ws.id)
        local ranks, wsSpent = talents.getWSRanks(player, jobId, ws.id)
        local avail, earned = talents.getAvailablePoints(player, jobId)
        tell(player, string.format('%s (%s) - WS Pts: %d | Job Avail: %d/%d | Orig: %s',
            ws.name, ws.skillName, wsSpent, avail, earned, talents.formatOrigSummary(ws)))
        for _, node in ipairs(tree.nodes) do
            local r = ranks[node.key] or 0
            tell(player, string.format('  %s (%s) [%d/%d] - %s', node.key, node.name, r, node.maxRank, node.describe(r, ws)))
        end
        return
    end

    if cmd == 'add' then
        local ws = catalog.resolve(arg1)
        if ws == nil or arg2 == nil then
            tell(player, 'Usage: !talent add <ws_key_or_id> <node_key> (use !talent info <ws> to see node keys)')
            return
        end
        local nodeKey = string.lower(arg2)
        local ok, res = talents.invest(player, jobId, ws.id, nodeKey)
        if not ok then
            tell(player, res)
            return
        end
        local node = talents.getTreeForWS(ws.id).byKey[nodeKey]
        tell(player, string.format('%s: %s upgraded to Rank %d/%d.', ws.name, node.name, res, node.maxRank))
        talents.sendMetaAndSpent(player)
        return
    end

    if cmd == 'sub' then
        local ws = catalog.resolve(arg1)
        if ws == nil or arg2 == nil then
            tell(player, 'Usage: !talent sub <ws_key_or_id> <node_key>')
            return
        end
        local nodeKey = string.lower(arg2)
        local ok, res = talents.refundNode(player, jobId, ws.id, nodeKey)
        if not ok then
            tell(player, res)
            return
        end
        local node = talents.getTreeForWS(ws.id).byKey[nodeKey]
        tell(player, string.format('%s: %s refunded to Rank %d/%d.', ws.name, node.name, res, node.maxRank))
        talents.sendMetaAndSpent(player)
        return
    end

    if cmd == 'reset' then
        local wsArg = combineArgs(arg1, arg2)
        if wsArg ~= nil and string.lower(wsArg) ~= 'all' then
            local ws = catalog.resolve(wsArg)
            if ws == nil then
                tell(player, 'Unknown weaponskill: ' .. wsArg)
                return
            end
            talents.resetWS(player, jobId, ws.id)
            tell(player, string.format('Reset all talent points in %s.', ws.name))
            talents.sendMetaAndSpent(player)
            return
        end

        talents.resetAll(player, jobId)
        tell(player, string.format('Reset all %s weaponskill talent points.', talents.getJobKey(jobId)))
        talents.sendMetaAndSpent(player)
        return
    end

    tell(player, 'Unknown subcommand. Use !talent or !talent help.')
end

return commandObj
