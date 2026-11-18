-----------------------------------
-- func: shield
-- desc: Alias for !buckler.
-----------------------------------
local buckler = require('modules/custom/commands/buckler')
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops = buckler.cmdprops
commandObj.onTrigger = buckler.onTrigger

return commandObj