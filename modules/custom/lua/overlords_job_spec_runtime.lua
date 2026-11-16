-----------------------------------
-- OverlordsXI Job Crystal Runtime Lifecycle
-- Safely applies/refreshes active job crystal passive mods on login,
-- zoning, level changes, and level syncs without double-stacking.
-----------------------------------
require('modules/module_utils')
require('modules/custom/lua/overlords_job_specs')
require('scripts/globals/player')
-----------------------------------
local m = Module:new('overlords_job_spec_runtime')

local spec = xi.overlords.spec

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    if player ~= nil and player:isPC() then
        -- Reset cached session state before any super() hooks run when CCharEntity
        -- is newly created (fresh login or cross-process zoning), while preserving
        -- same-process zoning state.
        if player.getLocalVar and player:getLocalVar('OX_SPEC_SYNCED') == 0 then
            if player.getID then
                spec.appliedByCharId[player:getID()] = nil
            end
            if player.setLocalVar then
                player:setLocalVar('OX_SPEC_SYNCED', 1)
            end
        elseif not player.getLocalVar and not zoning and player.getID then
            spec.appliedByCharId[player:getID()] = nil
        end
    end

    super(player, firstLogin, zoning)

    if player ~= nil and player:isPC() then
        spec.refreshPlayer(player)
    end
end)

m:addOverride('xi.player.onPlayerLevelUp', function(player)
    super(player)

    if player ~= nil and player:isPC() then
        spec.refreshPlayer(player)
    end
end)

m:addOverride('xi.player.onPlayerLevelDown', function(player)
    super(player)

    if player ~= nil and player:isPC() then
        spec.refreshPlayer(player)
    end
end)

-- Ensure !gear is registered even when hot-synced into a running xi_map process via FileWatcher
package.loaded['modules/custom/commands/gear'] = nil
pcall(require, 'modules/custom/commands/gear')

return m

