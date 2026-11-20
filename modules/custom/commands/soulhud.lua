-----------------------------------
-- func: !soulhud
-- desc: Silent Ashita v4 Universal Soul HUD sync command.
-----------------------------------
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 's',
}

commandObj.onTrigger = function(player, sub)
    if player == nil then
        return
    end

    local action = string.lower(tostring(sub or 'sync'))
    if action == 'sync' or action == '' then
        if player.setLocalVar then
            player:setLocalVar('OX_HUD_SUB', 1)
        end
        if xi.soulspire and xi.soulspire.hud and xi.soulspire.hud.sync then
            xi.soulspire.hud.sync(player, true)
        end
    else
        player:printToPlayer('Usage: !soulhud sync', xi.msg.channel.SYSTEM_3)
    end
end

if xi.module and xi.module.registerCommand then
    xi.module.registerCommand('soulhud', commandObj)
end

return commandObj
