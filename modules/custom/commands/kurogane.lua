-----------------------------------
-- !kurogane — GM-only experimental clone spawn probe.
-- Not a player JA; never enable on production before validation.
-----------------------------------
require('modules/custom/lua/kurogane_clones')
local K = xi.overlords.kurogane
local commandObj = {}
commandObj.cmdprops = { permission = 4, parameters = 'ss' }

local function tell(player, msg)
    player:printToPlayer('[Shinobi] ' .. msg, xi.msg.channel.SYSTEM_3, '')
end

commandObj.onTrigger = function(player, sub, amount)
    sub = tostring(sub or 'status'):lower()
    if sub == 'enable' then
        K.ENABLE_EXPERIMENTAL_CLONES = true
        tell(player, 'Experimental dynamic clones enabled for this xi_map process (GM testing only).')
    elseif sub == 'disable' then
        K.ENABLE_EXPERIMENTAL_CLONES = false
        K.ENABLE_EXPERIMENTAL_COMBAT = false
        K.dismissAllOwners()
        tell(player, 'Experimental dynamic clones disabled; all test copies dismissed.')
    elseif sub == 'combat' then
        local mode = tostring(amount or ''):lower()
        if mode == 'on' then
            if not K.ENABLE_EXPERIMENTAL_CLONES then
                tell(player, 'Enable the prototype first.')
                return
            end
            K.ENABLE_EXPERIMENTAL_COMBAT = true
            tell(player, 'Native clone melee ENABLED. Claim/threat transfer is active; damage balance remains GM-test only.')
        elseif mode == 'off' then
            K.ENABLE_EXPERIMENTAL_COMBAT = false
            K.dismissAllOwners()
            tell(player, 'Clone combat disabled; all active test copies dismissed.')
        else
            tell(player, 'Usage: !kurogane combat on|off')
        end
    elseif sub == 'spawn' then
        local ok, result = K.spawn(player, tonumber(amount) or 3)
        if ok then
            local snap = K.getSnapshot(player)
            tell(player, ('Spawned %d | Alive %d | Engaged %d | Startup %d | Inactive %d | Look %d/%d | Target %d. %s'):format(
                result, snap.clones, snap.engaged or 0, snap.startup or 0, snap.inactive or 0,
                snap.appearance_ok or 0, snap.clones, snap.target_id or 0, snap.diagnostic or ''))
        else
            tell(player, 'Spawn failed: ' .. tostring(result))
        end
    elseif sub == 'look' then
        local result, err = K.getLookDiagnostics(player)
        if not result then
            tell(player, 'Appearance diagnostics unavailable: ' .. tostring(err))
        else
            tell(player, 'OWNER: ' .. result.owner)
            tell(player, 'CLONE: ' .. result.clone)
        end
    elseif sub == 'dismiss' then
        K.dismissAll(player)
        tell(player, 'Your copies dismissed.')
    elseif sub == 'status' then
        local snap = K.getSnapshot(player)
        local errorText = snap.last_error ~= '' and (' | Error: ' .. snap.last_error) or ''
        local phaseText = string.format('%s(%ds hits=%d/2 open=%ds last=%s)',
            snap.phase_name or 'Building', snap.phase_rem or 0, snap.feint_hits or 0,
            snap.opening_rem or 0, (snap.last_cmd and snap.last_cmd ~= '') and snap.last_cmd or '-')
        tell(player, string.format('Shinobi %s | Clones %d (eng %d/start %d/inactive %d/wrong %d) | Phase %s | Look %d/%d | Target %d alive=%s ownerEng=%s | Hits %d attempts %d | Next %ds | Melee %s%s',
            K.ENABLE_EXPERIMENTAL_CLONES and 'ON' or 'OFF', snap.clones, snap.engaged or 0,
            snap.startup or 0, snap.inactive or 0, snap.wrong_target or 0,
            phaseText,
            snap.appearance_ok or 0, snap.clones, snap.target_id or 0,
            tostring(snap.target_alive == true), tostring(snap.owner_engaged == true),
            snap.attributed_hits or 0, snap.attempts or 0, snap.next_exp,
            K.ENABLE_EXPERIMENTAL_COMBAT and 'ON' or 'OFF', errorText))
    else
        tell(player, 'Usage: !kurogane enable|disable|combat on|off|spawn [1-5]|look|dismiss|status')
    end
end

if xi.module and xi.module.registerCommand then
    xi.module.registerCommand('kurogane', commandObj)
end
return commandObj
