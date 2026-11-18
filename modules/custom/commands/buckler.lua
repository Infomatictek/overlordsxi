-----------------------------------
-- func: buckler
-- desc: Backup menu to equip a Size-1 Buckler in the Sub slot alongside a
--       2H Polearm (WAR Spartan/Gladiator). Alias: !shield
-----------------------------------
require('modules/custom/lua/overlords_job_specs')
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = '',
}

local function tell(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
end

commandObj.onTrigger = function(player)
    local B = xi.overlords and xi.overlords.buckler
    if B == nil then
        tell(player, 'Buckler module is not loaded.')
        return
    end

    if not B.isPolearmBucklerPlayer(player) then
        tell(player, 'Requires WAR with an active Spartan or Gladiator crystal.')
        return
    end

    local options = {}
    table.insert(options,
    {
        '[Unequip Sub]',
        function(p)
            B.equipBuckler(p, nil)
        end,
    })

    for _, entry in ipairs(B.findBucklers(player)) do
        local captured = entry
        table.insert(options,
        {
            captured.name,
            function(p)
                B.equipBuckler(p, captured)
            end,
        })
    end

    if #options == 1 then
        tell(player, 'No Size-1 Bucklers found in Inventory or Wardrobes at your level.')
    end

    player:customMenu({ title = 'Buckler (Sub)', options = options })
end

return commandObj