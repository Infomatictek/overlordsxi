-----------------------------------
-- SoulspireXI — Soul Weapon Configuration & BRD Adventurer Regression Suite
-- Runs inside authoritative headless xi_test against the real LandSandBoat engine.
-----------------------------------
local spec = xi.soulspire.spec
local wc   = xi.soulspire.weaponConfig

local ITEM_WIND_KNIFE_P1  = 20568 -- Dagger (Lv1, All jobs, slot=3)
local ITEM_BRONZE_DAGGER  = 16449 -- Dagger (Lv1, slot=3)
local ITEM_ONION_SWORD    = 16534 -- Sword  (Lv1, BRD equippable, slot=3)
local ITEM_ASH_CLUB_P1    = 17137 -- Club   (Lv1, All jobs, slot=3)
local ITEM_METAL_SHIELD   = 28651 -- Shield (Lv1, All jobs, slot=2)
local ITEM_ONION_STAFF    = 17104 -- Staff  (Lv1, 2H, BRD equippable, slot=1)
local ITEM_BRONZE_SPEAR   = 16859 -- Polearm (Lv7, 2H, WAR equippable)
local ITEM_ASPIS_BUCKLER  = 12299 -- Size-1 Buckler (Lv9, WAR equippable)
local ITEM_LAUAN_SHIELD   = 12289 -- Size-2 Shield (Lv1, WAR equippable - must be rejected by Spartan Polearm)

local function spawnBrdWar(level)
    local player = xi.test.world:spawnPlayer({
        zone  = xi.zone.WEST_RONFAURE,
        job   = xi.job.BRD,
        level = level or 10,
    })
    player:changesJob(xi.job.WAR)
    player:setLevel(level or 10)
    player:changeContainerSize(xi.inv.INVENTORY, 60)
    return player
end

local function spawnStationaryMob(player)
    local mob = player.entities:moveTo('Wild_Rabbit')
    mob:respawn()
    mob:setAutoAttackEnabled(false)
    mob:setMobAbilityEnabled(false)
    mob:setMobMod(xi.mobMod.NO_MOVE, 1)
    mob:setMaxHP(5000)
    mob:setHP(5000)
    local pos = mob:getPos()
    player:setPos(pos.x, pos.y, pos.z)
    return mob
end

describe('Soul Weapon Configuration System (BRD Adventurer Slice)', function()
    it('allows BRD10/WAR5 Adventurer to dual-wield Dagger + Sword and Sword + Dagger and executes real DW combat', function()
        local player = spawnBrdWar(10)
        spec.set(player, xi.job.BRD, 'adventurer', { silent = true })
        spec.refreshPlayer(player)
        xi.test.world:skipTime(1)

        assert(player:hasTrait(xi.trait.DUAL_WIELD), 'BRD10 Adventurer must have TRAIT_DUAL_WIELD')
        assert(player:getMod(xi.mod.DUAL_WIELD) >= 10, 'BRD10 Adventurer must have DUAL_WIELD delay mod')

        assert(player:addItem(ITEM_WIND_KNIFE_P1), 'add wind_knife_+1')
        assert(player:addItem(ITEM_ONION_SWORD), 'add onion_sword')

        -- MAIN: Dagger | SUB: Sword
        player:equipItem(ITEM_WIND_KNIFE_P1, xi.inv.INVENTORY, xi.slot.MAIN)
        player:equipItem(ITEM_ONION_SWORD, xi.inv.INVENTORY, xi.slot.SUB)
        xi.test.world:skipTime(1)

        local mainEq = player:getEquippedItem(xi.slot.MAIN)
        local subEq  = player:getEquippedItem(xi.slot.SUB)
        assert(mainEq ~= nil and mainEq:getID() == ITEM_WIND_KNIFE_P1, 'Expected wind_knife_+1 in MAIN')
        assert(subEq ~= nil and subEq:getID() == ITEM_ONION_SWORD, 'Expected onion_sword in SUB')

        -- Verify actual Dual Wield combat swings, damage, TP, and Cadence stacks
        player:addMod(xi.mod.ACC, 200)
        local mob = spawnStationaryMob(player)
        local hitCount = 0
        player:addListener('MELEE_SWING_HIT', 'TEST_BRD_DW_HIT', function()
            hitCount = hitCount + 1
        end)
        local hpBefore = mob:getHP()
        player.packets:clear()
        player.actions:engage(mob)
        xi.test.world:skipTime(14)
        player:disengage()
        player:removeListener('TEST_BRD_DW_HIT')

        local actionRounds = 0
        for _, p in ipairs(player.packets:getIncoming()) do
            if p.type == 0x028 then
                actionRounds = actionRounds + 1
            end
        end

        assert(actionRounds >= 1, 'Expected at least 1 melee action round, got ' .. tostring(actionRounds))
        assert(hitCount > actionRounds, string.format('Dual Wield must land >1 hit per round (hits=%d rounds=%d)', hitCount, actionRounds))
        assert(mob:getHP() < hpBefore, 'Dual Wield swings must deal damage')
        assert(player:getTP() > 0, 'Dual Wield swings must generate TP')

        -- Swap orientation -> MAIN: Sword | SUB: Dagger
        player:unequipItem(xi.slot.SUB)
        player:equipItem(ITEM_ONION_SWORD, xi.inv.INVENTORY, xi.slot.MAIN)
        player:equipItem(ITEM_WIND_KNIFE_P1, xi.inv.INVENTORY, xi.slot.SUB)
        xi.test.world:skipTime(1)

        assert(player:getEquippedItem(xi.slot.MAIN):getID() == ITEM_ONION_SWORD, 'Expected onion_sword in MAIN')
        assert(player:getEquippedItem(xi.slot.SUB):getID() == ITEM_WIND_KNIFE_P1, 'Expected wind_knife_+1 in SUB')
    end)

    it('rejects non-whitelisted Club offhand on BRD10/WAR5 Adventurer and drops Sub when swapping Main to Club', function()
        local player = spawnBrdWar(10)
        spec.set(player, xi.job.BRD, 'adventurer', { silent = true })
        spec.refreshPlayer(player)
        xi.test.world:skipTime(1)

        assert(player:addItem(ITEM_WIND_KNIFE_P1), 'add wind_knife_+1')
        assert(player:addItem(ITEM_ONION_SWORD), 'add onion_sword')
        assert(player:addItem(ITEM_ASH_CLUB_P1), 'add ash_club_+1')
        if not player:hasItem(ITEM_METAL_SHIELD) then
            assert(player:addItem(ITEM_METAL_SHIELD), 'add metal_slime_shield')
        end

        -- Dagger + Club in SUB must be rejected
        player:equipItem(ITEM_WIND_KNIFE_P1, xi.inv.INVENTORY, xi.slot.MAIN)
        player:equipItem(ITEM_ASH_CLUB_P1, xi.inv.INVENTORY, xi.slot.SUB)
        xi.test.world:skipTime(1)
        assert(player:getEquippedItem(xi.slot.SUB) == nil, 'Club offhand must be rejected for BRD Adventurer without native DW')

        -- Vanilla Dagger + Shield remains permitted
        player:equipItem(ITEM_METAL_SHIELD, xi.inv.INVENTORY, xi.slot.SUB)
        xi.test.world:skipTime(1)
        assert(player:getEquippedItem(xi.slot.SUB) ~= nil and player:getEquippedItem(xi.slot.SUB):getID() == ITEM_METAL_SHIELD,
            'Vanilla 1H + Shield must remain allowed for BRD Adventurer')

        -- Equip Dagger + Sword, then swap MAIN to Club -> SUB Sword must be unequipped automatically
        player:equipItem(ITEM_ONION_SWORD, xi.inv.INVENTORY, xi.slot.SUB)
        assert(player:getEquippedItem(xi.slot.SUB):getID() == ITEM_ONION_SWORD, 'Expected onion_sword in SUB')

        player:equipItem(ITEM_ASH_CLUB_P1, xi.inv.INVENTORY, xi.slot.MAIN)
        xi.test.world:skipTime(1)
        assert(player:getEquippedItem(xi.slot.MAIN):getID() == ITEM_ASH_CLUB_P1, 'Expected ash_club_+1 in MAIN')
        assert(player:getEquippedItem(xi.slot.SUB) == nil, 'Swapping MAIN to Club must unequip Soul-granted Sword in SUB')
    end)

    it('automatically unequips offhand weapon on Soul switch, Soul clear, and delevel below Lv10', function()
        local player = spawnBrdWar(10)
        spec.set(player, xi.job.BRD, 'adventurer', { silent = true })
        spec.refreshPlayer(player)
        xi.test.world:skipTime(1)

        assert(player:addItem(ITEM_WIND_KNIFE_P1), 'add wind_knife_+1')
        assert(player:addItem(ITEM_ONION_SWORD), 'add onion_sword')
        player:equipItem(ITEM_WIND_KNIFE_P1, xi.inv.INVENTORY, xi.slot.MAIN)
        player:equipItem(ITEM_ONION_SWORD, xi.inv.INVENTORY, xi.slot.SUB)
        assert(player:getEquippedItem(xi.slot.SUB):getID() == ITEM_ONION_SWORD, 'Expected onion_sword in SUB before swap')

        -- Switch to Musician -> SUB must be unequipped and Musician cannot re-equip Sword in SUB
        spec.set(player, xi.job.BRD, 'musician', { silent = true })
        spec.refreshPlayer(player)
        xi.test.world:skipTime(1)
        assert(not player:hasTrait(xi.trait.DUAL_WIELD), 'Musician must not have DUAL_WIELD')
        assert(player:getEquippedItem(xi.slot.SUB) == nil, 'Switching from Adventurer to Musician must unequip SUB weapon')
        assert(player:hasItem(ITEM_ONION_SWORD), 'Unequipped SUB weapon must be preserved in inventory')

        player:equipItem(ITEM_ONION_SWORD, xi.inv.INVENTORY, xi.slot.SUB)
        assert(player:getEquippedItem(xi.slot.SUB) == nil, 'Musician must not be able to equip offhand weapon')

        -- Re-enable Adventurer, re-equip, then clear Soul -> SUB must be unequipped
        spec.set(player, xi.job.BRD, 'adventurer', { silent = true })
        spec.refreshPlayer(player)
        player:equipItem(ITEM_ONION_SWORD, xi.inv.INVENTORY, xi.slot.SUB)
        assert(player:getEquippedItem(xi.slot.SUB):getID() == ITEM_ONION_SWORD, 'Expected onion_sword back in SUB')

        spec.clear(player, xi.job.BRD)
        xi.test.world:skipTime(1)
        assert(player:getEquippedItem(xi.slot.SUB) == nil, 'Clearing Soul must unequip Soul-granted SUB weapon')

        -- Re-enable Adventurer at Lv10, equip, then delevel to Lv9 -> SUB must be unequipped
        spec.set(player, xi.job.BRD, 'adventurer', { silent = true })
        spec.refreshPlayer(player)
        player:equipItem(ITEM_ONION_SWORD, xi.inv.INVENTORY, xi.slot.SUB)
        assert(player:getEquippedItem(xi.slot.SUB):getID() == ITEM_ONION_SWORD, 'Expected onion_sword in SUB at Lv10')

        player:setLevel(9)
        spec.refreshPlayer(player)
        xi.test.world:skipTime(1)
        assert(player:getEquippedItem(xi.slot.SUB) == nil, 'Deleveling below Lv10 must unequip Soul-granted SUB weapon')
    end)

    it('preserves vanilla Dual Wield (NIN) and existing WAR Spartan Polearm + Buckler behavior', function()
        -- Vanilla NIN10/WAR5 keeps unrestricted 1H dual wield
        local nin = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.NIN,
            level = 10,
        })
        nin:changeContainerSize(xi.inv.INVENTORY, 60)
        assert(nin:addItem(ITEM_WIND_KNIFE_P1), 'add dagger to NIN')
        assert(nin:addItem(ITEM_ASH_CLUB_P1), 'add club to NIN')
        nin:equipItem(ITEM_WIND_KNIFE_P1, xi.inv.INVENTORY, xi.slot.MAIN)
        nin:equipItem(ITEM_ASH_CLUB_P1, xi.inv.INVENTORY, xi.slot.SUB)
        assert(nin:getEquippedItem(xi.slot.SUB):getID() == ITEM_ASH_CLUB_P1, 'Vanilla NIN must still dual-wield normally')

        -- WAR10 Spartan keeps 2H Polearm + Size-1 Buckler
        local war = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.WAR,
            level = 10,
        })
        war:changeContainerSize(xi.inv.INVENTORY, 60)
        spec.set(war, xi.job.WAR, 'spartan', { silent = true })
        spec.refreshPlayer(war)
        spec.syncPolearmBuckler(war, spec.get(war, xi.job.WAR))
        assert(war:addItem(ITEM_BRONZE_SPEAR), 'add bronze_spear_+1')
        assert(war:addItem(ITEM_ASPIS_BUCKLER), 'add aspis (Size-1 Buckler)')
        assert(war:addItem(ITEM_LAUAN_SHIELD), 'add lauan_shield (Size-2 Shield)')
        war:equipItem(ITEM_BRONZE_SPEAR, xi.inv.INVENTORY, xi.slot.MAIN)
        war:equipItem(ITEM_LAUAN_SHIELD, xi.inv.INVENTORY, xi.slot.SUB)
        assert(war:getEquippedItem(xi.slot.SUB) == nil, 'WAR Spartan Polearm must reject Size-2 shield')
        war:equipItem(ITEM_ASPIS_BUCKLER, xi.inv.INVENTORY, xi.slot.SUB)
        assert(war:getEquippedItem(xi.slot.MAIN):getID() == ITEM_BRONZE_SPEAR, 'WAR Spartan must keep Polearm in MAIN')
        assert(war:getEquippedItem(xi.slot.SUB):getID() == ITEM_ASPIS_BUCKLER, 'WAR Spartan must keep Size-1 Buckler in SUB')

        -- Phase 5 advanced modes must remain inert by default
        assert(wc.evaluatePair(war, war:getEquippedItem(xi.slot.MAIN), war:getEquippedItem(xi.slot.SUB)) == wc.RESULT.VANILLA,
            'Unconfigured Souls must evaluate to VANILLA (0)')
    end)
end)
