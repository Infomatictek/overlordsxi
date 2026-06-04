-----------------------------------
-- func: spec
-- desc: Shows or changes the player's current job spec.
-----------------------------------
require('modules/custom/lua/overlords_job_specs')
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 'ss'
}

local function tell(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
end

local function jobName(jobId)
    if xi.jobName and xi.jobName[jobId] then
        return xi.jobName[jobId][2]
    end

    return string.format('job %u', jobId)
end

local function printUsage(player)
    tell(player, 'Usage: !spec, !spec list, !spec set <spec>, !spec clear')
end

local function printCurrent(player, jobId)
    local current = xi.overlords.spec.get(player, jobId)
    if current == nil then
        tell(player, string.format('Current %s spec: none', jobName(jobId)))
    else
        tell(player, string.format('Current %s spec: %s (%s)', jobName(jobId), current.name, current.key))
    end
end

local function printList(player, jobId)
    local specs = xi.overlords.spec.list(jobId)
    if #specs == 0 then
        tell(player, string.format('No specs are configured for %s yet.', jobName(jobId)))
        return
    end

    tell(player, string.format('%s specs:', jobName(jobId)))
    for _, entry in ipairs(specs) do
        tell(player, string.format('  %s - %s: %s', entry.key, entry.name, entry.description))
    end
end

commandObj.onTrigger = function(player, action, value)
    local jobId = player:getMainJob()
    action = action and string.lower(action) or nil

    if action == nil or action == 'current' then
        printCurrent(player, jobId)
        printUsage(player)
        return
    end

    if action == 'list' then
        printList(player, jobId)
        return
    end

    if action == 'clear' or action == 'none' then
        if xi.overlords.spec.clear(player, jobId) then
            tell(player, string.format('Cleared %s spec.', jobName(jobId)))
        else
            tell(player, string.format('No specs are configured for %s yet.', jobName(jobId)))
        end

        return
    end

    local requestedSpec = value
    if action ~= 'set' then
        requestedSpec = action
    end

    if requestedSpec == nil then
        tell(player, 'Choose a spec key from !spec list.')
        printUsage(player)
        return
    end

    local selected = xi.overlords.spec.set(player, jobId, requestedSpec)
    if selected == nil then
        tell(player, string.format('Unknown %s spec: %s', jobName(jobId), requestedSpec))
        printList(player, jobId)
        return
    end

    tell(player, string.format('Selected %s spec: %s (%s)', jobName(jobId), selected.name, selected.key))
end

return commandObj
