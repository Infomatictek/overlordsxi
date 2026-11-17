-----------------------------------
-- func: spec
-- desc: Job crystal / spec selector (customMenu UI, CLI, and [OXSPEC] Ashita protocol).
-----------------------------------
require('modules/custom/lua/overlords_job_specs')
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 'sss',
}

local spec = xi.overlords.spec

local function tell(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
end

local function jobName(jobId)
    return spec.getJobName(jobId)
end

local function delaySendMenu(player, menuBuilder)
    player:timer(50, function(playerArg)
        if playerArg ~= nil then
            playerArg:customMenu(menuBuilder())
        end
    end)
end

local function printUsage(player)
    tell(player, 'Usage: !spec | !spec list | !spec info [crystal] | !spec set <crystal> | !spec remove')
end

local function formatEntryTag(player, jobId, entry, active)
    local isSocketed = (active ~= nil and active.id == entry.id)
    local eligible, reqLvl = spec.isLevelEligible(player, jobId, entry)
    if isSocketed then
        if not eligible then
            return string.format(' [Socketed - Inactive < Lv.%d]', reqLvl)
        end
        return ' [Socketed]'
    end
    if not eligible then
        return string.format(' [Lv.%d]', reqLvl)
    end
    return ''
end

local function printCurrent(player, jobId)
    local current = spec.get(player, jobId)
    if current == nil then
        tell(player, string.format('Current %s crystal: none', jobName(jobId)))
    else
        local tag = formatEntryTag(player, jobId, current, current)
        tell(player, string.format('Current %s crystal: %s (%s)%s - %s', jobName(jobId), current.name, current.key, tag, current.role))
    end
end

local function printCrystalInfo(player, jobId, entry)
    local active = spec.get(player, jobId)
    local tag = formatEntryTag(player, jobId, entry, active)
    local reqLvl = tonumber(entry.reqLevel) or spec.DEFAULT_REQ_LEVEL
    tell(player, string.format('%s (%s) [Lv.%d+]%s - %s', entry.name, entry.key, reqLvl, tag, entry.role))
    if entry.description ~= '' then
        tell(player, '  ' .. entry.description)
    end
    for _, line in ipairs(entry.highlights or {}) do
        tell(player, '  * ' .. line)
    end
end

local function printList(player, jobId)
    local crystals = spec.list(jobId)
    if #crystals == 0 then
        tell(player, string.format('No crystals are configured for %s yet.', jobName(jobId)))
        return
    end

    local active = spec.get(player, jobId)
    tell(player, string.format('%s crystals:', jobName(jobId)))
    for _, entry in ipairs(crystals) do
        local tag = formatEntryTag(player, jobId, entry, active)
        tell(player, string.format('  %s - %s%s (%s): %s', entry.key, entry.name, tag, entry.role, entry.description))
    end
end

-----------------------------------
-- In-game customMenu Fallback UI
-----------------------------------
local openCrystalMenu
local openInspectMenu

openInspectMenu = function(player)
    local jobId = player:getMainJob()
    local crystals = spec.list(jobId)
    local options = {}

    for _, entry in ipairs(crystals) do
        local captured = entry
        table.insert(options,
        {
            string.format('Inspect %s', captured.name),
            function(p)
                printCrystalInfo(p, p:getMainJob(), captured)
                delaySendMenu(p, function() return openInspectMenu(p) end)
            end,
        })
    end

    table.insert(options,
    {
        'Back',
        function(p)
            delaySendMenu(p, function() return openCrystalMenu(p) end)
        end,
    })

    return
    {
        title   = string.format('%s Crystal Details', jobName(jobId)),
        options = options,
    }
end

openCrystalMenu = function(player)
    local jobId = player:getMainJob()
    local crystals = spec.list(jobId)
    local current = spec.get(player, jobId)
    local options = {}

    for _, entry in ipairs(crystals) do
        local label = entry.name .. formatEntryTag(player, jobId, entry, current)
        local captured = entry

        table.insert(options,
        {
            label,
            function(p)
                local activeJob = p:getMainJob()
                local selected, errMsg = spec.set(p, activeJob, captured.key)
                if selected == nil then
                    tell(p, errMsg or 'Unable to socket crystal.')
                else
                    tell(p, string.format('Socketed %s crystal: %s (%s).', jobName(activeJob), selected.name, selected.role))
                end
                delaySendMenu(p, function() return openCrystalMenu(p) end)
            end,
        })
    end

    if #crystals > 0 then
        table.insert(options,
        {
            'Inspect bonuses',
            function(p)
                delaySendMenu(p, function() return openInspectMenu(p) end)
            end,
        })
    end

    if current ~= nil then
        table.insert(options,
        {
            'Remove crystal',
            function(p)
                local activeJob = p:getMainJob()
                local ok, errMsg = spec.clear(p, activeJob)
                if not ok then
                    tell(p, errMsg or 'Unable to remove crystal.')
                else
                    tell(p, string.format('Removed %s crystal.', jobName(activeJob)))
                end
                delaySendMenu(p, function() return openCrystalMenu(p) end)
            end,
        })
    end

    table.insert(options, { 'Back / Close', function() end })

    local titleSuffix = current ~= nil and (' [' .. current.name .. ']') or ''
    return
    {
        title   = string.format('%s crystals%s', jobName(jobId), titleSuffix),
        options = options,
    }
end

-----------------------------------
-- Command Entrypoint
-----------------------------------
local function combineArgs(a, b)
    if a == nil or a == '' then
        return nil
    end
    if b == nil or b == '' then
        return a
    end
    return a .. ' ' .. b
end

commandObj.onTrigger = function(player, action, value, extra)
    if player == nil then
        return
    end

    spec.ensureUpToDate(player)

    local jobId = player:getMainJob()
    local cmd = action and string.lower(action) or nil

    -----------------------------------
    -- Silent Ashita v4 Addon Protocol
    -----------------------------------
    if cmd == 'sync' then
        local targetJobId = tonumber(value) or jobId
        spec.sendSync(player, targetJobId)
        return
    end

    if cmd == 'state' then
        local targetJobId = tonumber(value) or jobId
        spec.sendState(player, targetJobId)
        return
    end

    if cmd == 'boost' then
        if xi.overlords and xi.overlords.mnk and xi.overlords.mnk.sendChiBoostSync then
            xi.overlords.mnk.sendChiBoostSync(player, true)
        end
        return
    end

    if cmd == 'uset' then
        local target = combineArgs(value, extra)
        if target == nil then
            spec.sendError(player, 'Missing crystal key or id.')
            return
        end
        local selected, errMsg = spec.set(player, jobId, target, { protoSync = true })
        if selected == nil then
            spec.sendError(player, errMsg or string.format('Unknown %s crystal: %s', jobName(jobId), target))
        end
        return
    end

    if cmd == 'uclear' or cmd == 'uremove' then
        local ok, errMsg = spec.clear(player, jobId, { protoSync = true })
        if not ok then
            spec.sendError(player, errMsg or 'Unable to remove crystal.')
        end
        return
    end

    -----------------------------------
    -- Interactive UI & Chat CLI
    -----------------------------------
    if cmd == nil or cmd == 'menu' then
        local crystals = spec.list(jobId)
        if #crystals == 0 then
            printCurrent(player, jobId)
            tell(player, string.format('No crystals are configured for %s yet.', jobName(jobId)))
            printUsage(player)
            return
        end

        player:customMenu(openCrystalMenu(player))
        return
    end

    if cmd == 'help' then
        printUsage(player)
        return
    end

    if cmd == 'current' then
        printCurrent(player, jobId)
        return
    end

    if cmd == 'list' then
        printList(player, jobId)
        return
    end

    if cmd == 'info' then
        local target = combineArgs(value, extra)
        local entry = target and spec.resolve(jobId, target) or spec.get(player, jobId)
        if entry == nil then
            if target ~= nil then
                tell(player, string.format('Unknown %s crystal: %s', jobName(jobId), target))
            else
                tell(player, string.format('No %s crystal currently socketed. Use !spec info <crystal>.', jobName(jobId)))
            end
            printList(player, jobId)
            return
        end
        printCrystalInfo(player, jobId, entry)
        return
    end

    if cmd == 'clear' or cmd == 'remove' or cmd == 'unsocket' or cmd == 'none' then
        local ok, errMsg = spec.clear(player, jobId)
        if ok then
            tell(player, string.format('Removed %s crystal.', jobName(jobId)))
        else
            tell(player, errMsg or string.format('No crystals are configured for %s yet.', jobName(jobId)))
        end
        return
    end

    local requestedSpec = combineArgs(value, extra)
    if cmd ~= 'set' and cmd ~= 'socket' then
        requestedSpec = combineArgs(action, value)
    end

    if requestedSpec == nil then
        tell(player, 'Choose a crystal key from !spec list.')
        printUsage(player)
        return
    end

    local selected, errMsg = spec.set(player, jobId, requestedSpec)
    if selected == nil then
        tell(player, errMsg or string.format('Unknown %s crystal: %s', jobName(jobId), requestedSpec))
        printList(player, jobId)
        return
    end

    tell(player, string.format('Socketed %s crystal: %s (%s).', jobName(jobId), selected.name, selected.role))
end

xi.commands = xi.commands or {}
xi.commands.spec = commandObj

if xi.module and xi.module.registerCommand then
    xi.module.registerCommand('spec', commandObj)
end

if xi.commands.gear == nil then
    package.loaded['modules/custom/commands/gear'] = nil
    pcall(require, 'modules/custom/commands/gear')
end


