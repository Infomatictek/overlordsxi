-----------------------------------
-- Soul Proving Grounds Lite (prototype)
-- Existing models, native customMenu, no client DAT changes.
-- Initially restricted to GM Home for controlled validation.
-----------------------------------
require('modules/module_utils')
require('scripts/zones/GM_Home/Zone')
require('modules/custom/lua/boss_like_combat_and_exp')

local m = Module:new('overlords_proving_grounds_lite')
local ARENA_ZONE = xi.zone.GM_HOME
local NPC_POS = { x = 5, y = 0, z = 5 }
local BOSS_POS = { x = 5, y = 0, z = 25 }
local LEVELS = { 10, 30, 50, 75 }
local active = nil

-- Proven group lookup from LSB's original !fafnir test command.
-- This is deliberately a single known prototype opponent: distinct caster,
-- AoE and dummy AI profiles will not be advertised until validated.
local PROTOTYPE = { groupId = 5, groupZoneId = 154 }

local function tell(player, message)
    player:printToPlayer('[Crucible] ' .. message, xi.msg.channel.SYSTEM_3, '')
end

local function openLater(player, builder)
    player:timer(50, function(p)
        if p and p:getZoneID() == ARENA_ZONE then
            p:customMenu(builder(p))
        end
    end)
end

local function findCurrent()
    if active and active.mob and active.mob.isAlive and active.mob:isAlive() then
        if not active.mob.getStatus or active.mob:getStatus() ~= xi.status.DISAPPEAR then
            return active
        end
    end
    active = nil
    return nil
end

local function resetTrial(player)
    local current = findCurrent()
    if not current then
        tell(player, 'No trial is active.')
        return
    end
    -- Use entity status instead of respawning. The dynamic target ID is
    -- released when this prototype entity disappears.
    current.mob:setStatus(xi.status.DISAPPEAR)
    active = nil
    tell(player, 'Trial cleared.')
end

local function startTrial(player, level)
    if not player or player:getZoneID() ~= ARENA_ZONE then
        return
    end
    if findCurrent() then
        tell(player, 'One trial is already running. Reset it before starting another.')
        return
    end

    local zone = player:getZone()
    if not zone then
        tell(player, 'Arena is not available.')
        return
    end

    local selected = math.floor(tonumber(level) or 0)
    if selected < 10 or selected > 75 then
        tell(player, 'Unsupported level.')
        return
    end

    local mob = zone:insertDynamicEntity({
        objtype = xi.objType.MOB,
        name = 'Crucible_Challenger',
        packetName = 'Crucible Challenger',
        groupId = PROTOTYPE.groupId,
        groupZoneId = PROTOTYPE.groupZoneId,
        minLevel = selected,
        maxLevel = selected,
        x = BOSS_POS.x,
        y = BOSS_POS.y,
        z = BOSS_POS.z,
        rotation = 128,
        respawn = 0,
        releaseIdOnDisappear = true,
        specialSpawnAnimation = false,
        onMobDeath = function(deadMob)
            if active and active.mob and active.mob:getID() == deadMob:getID() then
                active = nil
            end
        end,
    })

    if not mob then
        tell(player, 'Could not create the trial enemy.')
        return
    end

    mob:setDropID(0)
    mob:setMobMod(xi.mobMod.NO_DROPS, 1)
    mob:setSpawn(BOSS_POS.x, BOSS_POS.y, BOSS_POS.z, 128)
    mob:spawn(600)
    if xi.customBossServer and xi.customBossServer.applyMobScaling then
        xi.customBossServer.applyMobScaling(mob)
    end

    active = { mob = mob, level = selected, owner = player:getID() }
    tell(player, string.format('Level %d Challenger spawned. Uses live boss-combat scaling. Auto-despawns after ten minutes.', selected))
end

local rootMenu
local levelMenu

levelMenu = function(player)
    local options = {}
    for _, level in ipairs(LEVELS) do
        local chosen = level
        table.insert(options, { 'Level ' .. chosen, function(p) startTrial(p, chosen) end })
    end
    table.insert(options, { 'Match my level (10-75)', function(p)
        startTrial(p, math.max(10, math.min(75, p:getMainLvl())))
    end })
    table.insert(options, { 'Back', function(p)
        openLater(p, rootMenu)
    end })
    return { title = 'Crucible - Challenger Level', options = options }
end

rootMenu = function(player)
    return {
        title = 'The Arbiter - Proving Grounds Lite',
        options = {
            { 'Start Physical Trial', function(p)
                openLater(p, levelMenu)
            end },
            { 'Reset Active Trial', function(p)
                resetTrial(p)
            end },
            { 'Trial Information', function(p)
                tell(p, 'Prototype: existing Fafnir behavior at selectable level; uses global boss scaling.')
                tell(p, 'This is NOT yet a controlled physical-only, magic, AoE, or dummy benchmark.')
                tell(p, 'No custom animations or DAT edits. Testing limited to GM Home.')
            end },
            { 'Close', function() end },
        },
    }
end

m:addOverride('xi.zones.GM_Home.Zone.onInitialize', function(zone)
    super(zone)
    if zone:getID() ~= ARENA_ZONE then
        return
    end
    zone:insertDynamicEntity({
        objtype = xi.objType.NPC,
        name = 'Crucible_Arbiter',
        packetName = 'The Arbiter',
        look = 2433,
        x = NPC_POS.x,
        y = NPC_POS.y,
        z = NPC_POS.z,
        rotation = 0,
        widescan = 1,
        onTrigger = function(player)
            player:customMenu(rootMenu(player))
        end,
    })
end)

return m
