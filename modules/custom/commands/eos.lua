-----------------------------------
-- func: eos
-- desc: Controls the player's Eos companion.
-----------------------------------
require('modules/custom/lua/overlords_job_specs')
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 's'
}

local eosPetId = 128

local function tell(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
end

local function isEosPet(pet)
    return pet ~= nil and pet:getPetID() == eosPetId
end

local function getEosPet(player)
    if not player:hasPet() then
        return nil
    end

    local pet = player:getPet()
    if isEosPet(pet) then
        return pet
    end

    return nil
end

local function printUsage(player)
    tell(player, 'Usage: !eos heal, !eos dismiss')
end

commandObj.onTrigger = function(player, action)
    action = action and string.lower(action) or nil

    if action == nil or action == 'help' then
        printUsage(player)
        return
    end

    local pet = getEosPet(player)
    if pet == nil then
        tell(player, 'Eos is not currently summoned.')
        return
    end

    if action == 'heal' or action == 'mend' then
        local missingHp = pet:getMaxHP() - pet:getHP()
        if missingHp <= 0 then
            tell(player, 'Eos is already at full HP.')
            return
        end

        pet:addHP(missingHp)
        tell(player, 'Eos has been healed.')
        return
    end

    if action == 'dismiss' or action == 'release' then
        player:despawnPet()
        tell(player, 'Eos has been dismissed.')
        return
    end

    printUsage(player)
end

xi.module.registerCommand('eos', commandObj)
