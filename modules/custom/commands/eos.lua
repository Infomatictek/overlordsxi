-----------------------------------
-- func: eos
-- desc: Controls the player's Eos or Titania faerie companion.
-----------------------------------
require('modules/custom/lua/soulspire_job_specs')
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 's'
}

local eosPetId     = 128
local titaniaPetId = 129

local function tell(player, message)
    player:printToPlayer(message, xi.msg.channel.SYSTEM_3, '')
end

local function getFaerieInfo(pet)
    if pet == nil then
        return nil, nil
    end

    local pid = pet:getPetID()
    if pid == eosPetId then
        return pet, 'Eos'
    elseif pid == titaniaPetId then
        return pet, 'Titania'
    end

    return nil, nil
end

local function getFaeriePet(player)
    if not player:hasPet() then
        return nil, nil
    end

    return getFaerieInfo(player:getPet())
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

    local pet, petLabel = getFaeriePet(player)
    if pet == nil then
        tell(player, 'Eos or Titania is not currently summoned.')
        return
    end

    if action == 'heal' or action == 'mend' then
        local missingHp = pet:getMaxHP() - pet:getHP()
        if missingHp <= 0 then
            tell(player, petLabel .. ' is already at full HP.')
            return
        end

        pet:addHP(missingHp)
        tell(player, petLabel .. ' has been healed.')
        return
    end

    if action == 'dismiss' or action == 'release' then
        player:despawnPet()
        tell(player, petLabel .. ' has been dismissed.')
        return
    end

    printUsage(player)
end

xi.commands = xi.commands or {}
xi.commands.eos = commandObj

if xi.module and xi.module.registerCommand then
    xi.module.registerCommand('eos', commandObj)
end

