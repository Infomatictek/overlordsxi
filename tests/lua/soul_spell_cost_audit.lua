-----------------------------------
-- SoulspireXI — Global Soul Spell Cost & Level Compatibility Regression Suite
-- Runs inside authoritative headless xi_test against the real LandSandBoat engine.
-----------------------------------
local spec = xi.soulspire.spec

local function spawnStationaryMob(player)
    local mob = player.entities:moveTo('Wild_Rabbit')
    mob:respawn()
    mob:setAutoAttackEnabled(false)
    mob:setMobAbilityEnabled(false)
    local pos = mob:getPos()
    player:setPos(pos.x, pos.y, pos.z)
    mob:setMaxHP(5000)
    mob:setHP(5000)
    xi.test.world:skipTime(2)
    return mob
end

describe('Global Soul Spell Cost & Level Compatibility Audit', function()
    it('allows DRK Dreadnought Lv10 with Scythe to cast Drain II for 12 MP and Dread Spikes for 0 MP + 10% HP', function()
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.DRK,
            level = 10,
        })
        player:addItem(16768) -- Bronze Zaghnal (Scythe)
        player:equipItem(16768)
        spec.set(player, xi.job.DRK, 'dreadnought', { silent = true })
        spec.refreshPlayer(player)

        assert(player:getLocalVar('OX_DRN_SCYTHE') == 1, 'Dreadnought with Scythe must set OX_DRN_SCYTHE=1')
        assert(player:hasSpell(246), 'Dreadnought Lv10 must have Drain II (246)')
        assert(player:hasSpell(277), 'Dreadnought Lv10 must have Dread Spikes (277)')

        -- Drain II costs 12 MP (affordable at 15 MP, well below vanilla 37 MP)
        local mob = spawnStationaryMob(player)
        player:setMP(15)
        player.actions:useSpell(mob, xi.magic.spell.DRAIN_II)
        xi.test.world:skipTime(4)
        assert(player:getMP() == 3, 'Drain II must spend exactly 12 MP for Dreadnought with Scythe')

        -- Dread Spikes costs 0 MP (castable at 0 MP) and consumes 10% current HP
        player:setMP(0)
        player:setHP(player:getMaxHP())
        local hpBefore = player:getHP()
        player.actions:useSpell(player, xi.magic.spell.DREAD_SPIKES)
        xi.test.world:skipTime(2)
        assert(player:getMP() == 0, 'Dread Spikes must spend 0 MP for Dreadnought with Scythe')
        assert(player:getHP() < hpBefore, 'Dread Spikes must retain its 10% current HP cost')
        assert(player:hasStatusEffect(xi.effect.DREAD_SPIKES), 'Dread Spikes must apply status effect')
    end)

    it('rejects DRK Dreadnought Dread Spikes at <=15% HP without consuming HP or MP', function()
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.DRK,
            level = 10,
        })
        player:addItem(16768)
        player:equipItem(16768)
        spec.set(player, xi.job.DRK, 'dreadnought', { silent = true })
        spec.refreshPlayer(player)

        local lowHp = math.max(1, math.floor(player:getMaxHP() * 0.10))
        player:setHP(lowHp)
        player:setMP(20)
        player.actions:useSpell(player, xi.magic.spell.DREAD_SPIKES)
        xi.test.world:skipTime(2)
        assert(player:getHP() == lowHp, 'Failed Dread Spikes cast must not consume HP')
        assert(player:getMP() == 20, 'Failed Dread Spikes cast must not consume MP')
        assert(not player:hasStatusEffect(xi.effect.DREAD_SPIKES), 'Failed Dread Spikes must not apply effect')
    end)

    it('allows BLU Azure Bastion to cast 0-MP Azure Surge Blue Magic at 0 MP and discounted Physical Blue Magic', function()
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.BLU,
            level = 30,
        })
        spec.set(player, xi.job.BLU, 'azurebastion', { silent = true })
        spec.refreshPlayer(player)
        assert(player:getLocalVar('OX_AZB_ACTIVE') == 1, 'Azure Bastion must set OX_AZB_ACTIVE=1')

        player:addSpell(xi.magic.spell.HEAD_BUTT)
        player:setBlueMagicSpell(xi.magic.spell.HEAD_BUTT, 1)
        local mob = spawnStationaryMob(player)

        -- Physical Blue Magic Head Butt (12 MP vanilla -> 8 MP discounted) castable at 8 MP
        player:setMP(8)
        player.actions:useSpell(mob, xi.magic.spell.HEAD_BUTT)
        xi.test.world:skipTime(3)
        assert(player:getMP() == 0, 'Azure Bastion Head Butt must spend 8 MP (30% discount)')

        -- Azure Surge (858) makes next Blue Magic 0 MP and instant-cast even at 0 MP
        player:addStatusEffect(858, { power = 1, duration = 6, origin = player })
        player:setMP(0)
        player.actions:useSpell(mob, xi.magic.spell.HEAD_BUTT)
        xi.test.world:skipTime(2)
        assert(player:getMP() == 0, 'Azure Surge cast must succeed at 0 MP')
    end)

    it('allows BLU Magus Lv10 to cast scaled early Blue Magic without mutating vanilla costs', function()
        local magus = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.BLU,
            level = 10,
        })
        spec.set(magus, xi.job.BLU, 'magus', { silent = true })
        spec.refreshPlayer(magus)
        assert(magus:getLocalVar('OX_MAG_ACTIVE') == 1, 'Magus must set OX_MAG_ACTIVE=1')

        -- Magic Fruit (593): reqLvl 58, baseMp 72 -> 14 MP at Lv10
        magus:setMP(20)
        magus.actions:useSpell(magus, xi.magic.spell.MAGIC_FRUIT)
        xi.test.world:skipTime(4)
        assert(magus:getMP() == 6, 'Magus Lv10 Magic Fruit must spend 14 MP')

        -- Vanilla BLU at Lv58 must still pay full 72 MP (no global CSpell mutation)
        local vanillaBlu = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.BLU,
            level = 58,
        })
        vanillaBlu:addSpell(xi.magic.spell.MAGIC_FRUIT)
        vanillaBlu:setBlueMagicSpell(xi.magic.spell.MAGIC_FRUIT, 1)
        vanillaBlu:setMP(100)
        vanillaBlu.actions:useSpell(vanillaBlu, xi.magic.spell.MAGIC_FRUIT)
        xi.test.world:skipTime(4)
        assert(vanillaBlu:getMP() == 28, 'Vanilla BLU Lv58 Magic Fruit must retain full 72 MP cost')
    end)

    it('allows RUN Spellblade to cast Conduction-discounted Runic Bolt at 4 MP (Lv10, 3 stacks)', function()
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.RUN,
            level = 10,
        })
        player:addItem(16900) -- Claymore (Great Sword)
        player:equipItem(16900)
        spec.set(player, xi.job.RUN, 'spellblade', { silent = true })
        spec.refreshPlayer(player)

        player:addStatusEffect(xi.effect.IGNIS, { power = 1, duration = 300, origin = player })
        player:setLocalVar('OX_RUN_CONDUCTION', 3)
        player:setMP(4)

        local mob = spawnStationaryMob(player)
        player.actions:useSpell(mob, 363) -- Runic Bolt
        xi.test.world:skipTime(3)
        assert(player:getMP() == 0, 'Runic Bolt at Lv10 with 3 Conduction stacks must succeed at 4 MP')
    end)

    it('allows NIN Kagemusha Lv10 with Dual Katanas to cast all Kagemusha Ninjutsu without ninja tools', function()
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.NIN,
            level = 10,
        })
        player:addItem(16896) -- Kunai
        player:addItem(16896)
        player:equipItem(16896, xi.slot.MAIN)
        player:equipItem(16896, xi.slot.SUB)
        spec.set(player, xi.job.NIN, 'kagemusha', { silent = true })
        spec.refreshPlayer(player)

        assert(player:getLocalVar('OX_KGM_DUAL_KATANA') == 1, 'Kagemusha with Dual Katanas must set OX_KGM_DUAL_KATANA=1')
        local mob = spawnStationaryMob(player)
        local hpBefore = mob:getHP()
        player.actions:useSpell(mob, xi.magic.spell.KATON_ICHI)
        xi.test.world:skipTime(5)
        assert(mob:getHP() < hpBefore, 'Kagemusha Lv10 with Dual Katanas must cast Katon: Ichi without Uchitake')
    end)
end)
