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
        if xi.overlords and xi.overlords.hud and xi.overlords.hud.sync then
            xi.overlords.hud.sync(player, true)
        end
    else
        player:printToPlayer('Usage: !soulhud sync', xi.msg.channel.SYSTEM_3)
    end
end

return commandObj
