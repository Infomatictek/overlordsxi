-----------------------------------
-- func: shield
-- desc: Alias for !buckler.
-----------------------------------
---@type TCommand
local commandObj = {}

local buckler = xi.commands and xi.commands.buckler
if buckler then
    commandObj.cmdprops = buckler.cmdprops
    commandObj.onTrigger = buckler.onTrigger
else
    commandObj.cmdprops =
    {
        permission = 0,
        parameters = '',
    }
    commandObj.onTrigger = function(player)
        player:printToPlayer('Buckler command is not loaded.', xi.msg.channel.SYSTEM_3, '')
    end
end

xi.commands = xi.commands or {}
xi.commands.shield = commandObj

if xi.module and xi.module.registerCommand then
    xi.module.registerCommand('shield', commandObj)
end

return commandObj