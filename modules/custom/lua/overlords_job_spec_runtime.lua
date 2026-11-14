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
    super(player, firstLogin, zoning)

    if player ~= nil and player:isPC() then
        -- On fresh login (not zoning), clear any stale cached table entry for this char ID
        -- because server/zone session recreated CCharEntity base stats cleanly.
        if not zoning and player.getID then
            spec.appliedByCharId[player:getID()] = nil
        end

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

return m
