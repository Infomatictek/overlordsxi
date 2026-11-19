-----------------------------------
-- !kurogane — GM-only experimental clone spawn probe.
-- Not a player JA; never enable on production before validation.
-----------------------------------
require('modules/custom/lua/kurogane_clones')
local K = xi.overlords.kurogane
local commandObj = {}
commandObj.cmdprops = { permission = 4, parameters = 'ss' }

local function tell(player, msg)
    player:printToPlayer('[Kurogane] ' .. msg, xi.msg.channel.SYSTEM_3, '')
end

commandObj.onTrigger = function(player, sub, amount)
    sub = tostring(sub or 'status'):lower()
    if sub == 'enable' then
        K.ENABLE_EXPERIMENTAL_CLONES = true
        tell(player, 'Experimental dynamic clones enabled for this xi_map process (GM testing only).')
    elseif sub == 'disable' then
        K.ENABLE_EXPERIMENTAL_CLONES = false
        K.dismissAll(player)
        tell(player, 'Experimental dynamic clones disabled; your copies dismissed.')
    elseif sub == 'spawn' then
        local ok, result = K.spawn(player, tonumber(amount) or 3)
        tell(player, ok and ('Spawn request created ' .. tostring(result) .. ' copies.') or ('Spawn failed: ' .. tostring(result)))
    elseif sub == 'dismiss' then
        K.dismissAll(player)
        tell(player, 'Your copies dismissed.')
    elseif sub == 'status' then
        local snap = K.getSnapshot(player)
        tell(player, string.format('Prototype: %s | Copies: %d | Next expiry: %ds | Damage: DISABLED',
            K.ENABLE_EXPERIMENTAL_CLONES and 'ENABLED' or 'DISABLED', snap.clones, snap.next_exp))
    else
        tell(player, 'Usage: !kurogane enable|disable|spawn [1-5]|dismiss|status')
    end
end

if xi.module and xi.module.registerCommand then
    xi.module.registerCommand('kurogane', commandObj)
end
return commandObj
