-----------------------------------
-- SoulspireXI — Soul Spell Authorization & Subjob Isolation Regression Suite
-- Runs inside authoritative headless xi_test against the real LandSandBoat engine.
-----------------------------------
local spec = xi.soulspire.spec

local function lastMagicDataBit(player, spellId)
    local last = nil
    for _, p in ipairs(player.packets:getIncoming()) do
        if p.type == 0x0AA then
            last = p.data
        end
    end
    if not last then
        return nil
    end
    local b = last[4 + math.floor(spellId / 8)] or 0
    return math.floor(b / (2 ^ (spellId % 8))) % 2 == 1
end

local function receivedCannotCast47(player)
    for _, p in ipairs(player.packets:getIncoming()) do
        if p.type == 0x029 then
            local msg = (p.data[0x18] or 0) + (p.data[0x19] or 0) * 256
            if msg == 47 then
                return true
            end
        end
    end
    return false
end

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

describe('Soul Spell Authorization & Subjob Isolation', function()
    it('allows Terramancer Lv10 to cast Stone Chip (159) and establish claim', function()
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.GEO,
            level = 10,
        })
        player:setMP(200)
        player.packets:clear()
        spec.set(player, xi.job.GEO, 'terramancer', { silent = true })
        spec.refreshPlayer(player)

        assert(lastMagicDataBit(player, 159) == true, '0x0AA must enable Stone Chip (159) for Terramancer Lv10')
        assert(lastMagicDataBit(player, 160) == true, '0x0AA must enable Shallow Fault (160) for Terramancer Lv10')
        assert(lastMagicDataBit(player, 161) == false, '0x0AA must NOT enable Deep Fault (161) at Lv10')

        local mob = spawnStationaryMob(player)
        local hpBefore = mob:getHP()
        player.actions:useSpell(mob, xi.magic.spell.STONE)
        xi.test.world:skipTime(3)

        assert(mob:getHP() < hpBefore, 'Stone Chip (159) must deal earth damage')
        assert(player:hasClaim(mob), 'Stone Chip (159) must establish claim')
    end)

    it('allows Terramancer Lv10 to cast Shallow Fault (160) on a claimed target and trigger delayed eruption', function()
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.GEO,
            level = 10,
        })
        player:setMP(200)
        spec.set(player, xi.job.GEO, 'terramancer', { silent = true })
        spec.refreshPlayer(player)

        local mob = spawnStationaryMob(player)
        mob:updateClaim(player)

        local mpBefore = player:getMP()
        local hpBefore = mob:getHP()
        player.actions:useSpell(mob, xi.magic.spell.STONE_II)
        xi.test.world:skipTime(2)
        assert(player:getMP() < mpBefore, 'Shallow Fault (160) must spend 7% max MP')
        assert(player:getLocalVar('OX_TRM_COOLDOWN') > 0, 'Shallow Fault (160) must arm shared cooldown')

        xi.test.world:skipTime(4)
        assert(mob:getHP() < hpBefore, 'Shallow Fault (160) must erupt for damage after 2s fuse')
    end)

    it('rejects Terramancer Lv10 casting Deep Fault (161, Lv30 unlock)', function()
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.GEO,
            level = 10,
        })
        player:setMP(200)
        spec.set(player, xi.job.GEO, 'terramancer', { silent = true })
        spec.refreshPlayer(player)

        local mob = spawnStationaryMob(player)
        mob:updateClaim(player)
        player.packets:clear()
        player.actions:useSpell(mob, xi.magic.spell.STONE_III)
        xi.test.world:skipTime(1)
        assert(receivedCannotCast47(player), 'Terramancer Lv10 must be rejected from casting Deep Fault (161)')
    end)

    it('enforces Shinobi unlock levels (338 at Lv10, 339 rejected at Lv10 and allowed at Lv37)', function()
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.NIN,
            level = 10,
        })
        player:addSpell(xi.magic.spell.UTSUSEMI_ICHI)
        player:addSpell(xi.magic.spell.UTSUSEMI_NI)
        spec.set(player, xi.job.NIN, 'shinobi', { silent = true })
        spec.refreshPlayer(player)

        -- Lv10 Shinobi attempting Utsusemi: Ni (339, Lv37 unlock) must be rejected
        player.packets:clear()
        player.actions:useSpell(player, xi.magic.spell.UTSUSEMI_NI)
        xi.test.world:skipTime(2)
        assert(receivedCannotCast47(player), 'Shinobi Lv10 must NOT be allowed to cast Utsusemi: Ni (339)')

        -- Lv37 Shinobi has Utsusemi: Ni (339) unlocked
        player:setLevel(37)
        spec.refreshPlayer(player)
        player.packets:clear()
        player.actions:useSpell(player, xi.magic.spell.UTSUSEMI_NI)
        xi.test.world:skipTime(2)
        assert(not receivedCannotCast47(player), 'Shinobi Lv37 must pass spell authorization for Utsusemi: Ni (339)')
    end)

    it('blocks Lv10 subjobs from inheriting Soul-backported spells (including WAR20/NIN10 Utsusemi: Ni)', function()
        local subjobTests =
        {
            { sjob = xi.job.NIN, spell = 338, enemy = false }, -- Utsusemi: Ichi (NIN 12)
            { sjob = xi.job.NIN, spell = 339, enemy = false }, -- Utsusemi: Ni (NIN 37)
            { sjob = xi.job.NIN, spell = 320, enemy = true  }, -- Katon: Ichi (NIN 15)
            { sjob = xi.job.GEO, spell = 160, enemy = true  }, -- Stone II (GEO 34)
            { sjob = xi.job.DRK, spell = 246, enemy = true  }, -- Drain II (DRK 62)
            { sjob = xi.job.DRK, spell = 277, enemy = false }, -- Dread Spikes (DRK 71)
            { sjob = xi.job.RDM, spell = 312, enemy = false }, -- Enfire II (RDM 58)
            { sjob = xi.job.RDM, spell = 511, enemy = false }, -- Haste II (RDM 96)
            { sjob = xi.job.BLU, spell = 593, enemy = false }, -- Magic Fruit (BLU 58)
            { sjob = xi.job.BLM, spell = 144, enemy = true  }, -- Fire (BLM 13)
            { sjob = xi.job.SCH, spell = 99,  enemy = false }, -- Sandstorm (SCH 41)
            { sjob = xi.job.WHM, spell = 30,  enemy = true  }, -- Banish III (WHM 65)
        }
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.WAR,
            level = 20,
        })
        player:setMP(500)
        player:addItem(xi.item.SHIHEI, 99)
        local mob = spawnStationaryMob(player)

        for _, tc in ipairs(subjobTests) do
            player:changesJob(tc.sjob)
            player:addSpell(tc.spell)
            player.packets:clear()
            player.actions:useSpell(tc.enemy and mob or player, tc.spell)
            xi.test.world:skipTime(1)
            assert(receivedCannotCast47(player), string.format(
                'WAR20/sjob=%d must NOT be able to cast Soul-backported spell %d', tc.sjob, tc.spell))
        end
    end)

    it('rejects wrong Souls, clears stale permissions on Soul/level/job changes, and preserves vanilla spells', function()
        local player = xi.test.world:spawnPlayer({
            zone  = xi.zone.WEST_RONFAURE,
            job   = xi.job.GEO,
            level = 10,
        })
        player:setMP(300)
        player:addSpell(159)
        player:addSpell(160)
        local mob = spawnStationaryMob(player)
        mob:updateClaim(player)

        -- Activate Terramancer, then swap to Verdant
        spec.set(player, xi.job.GEO, 'terramancer', { silent = true })
        spec.refreshPlayer(player)
        assert(player:getLocalVar('OX_TRM_ACTIVE') == 1, 'Terramancer must set OX_TRM_ACTIVE=1')

        spec.set(player, xi.job.GEO, 'verdant', { silent = true })
        spec.refreshPlayer(player)
        assert(player:getLocalVar('OX_TRM_ACTIVE') == 0, 'Swapping to Verdant must clear OX_TRM_ACTIVE')
        player.packets:clear()
        player.actions:useSpell(mob, xi.magic.spell.STONE_II)
        xi.test.world:skipTime(1)
        assert(receivedCannotCast47(player), 'Verdant Lv10 must NOT cast Terramancer Shallow Fault (160)')

        -- Swap to Diviner: 0x0AA must not expose 160 and casting 160 must be rejected
        player.packets:clear()
        spec.set(player, xi.job.GEO, 'diviner', { silent = true })
        spec.refreshPlayer(player)
        assert(lastMagicDataBit(player, 160) == false, 'Diviner 0x0AA must NOT expose Stone II (160)')
        player.packets:clear()
        player.actions:useSpell(mob, xi.magic.spell.STONE_II)
        xi.test.world:skipTime(1)
        assert(receivedCannotCast47(player), 'Diviner Lv10 must NOT cast Terramancer Shallow Fault (160)')

        -- Re-activate Terramancer, then drop below Lv10 -> OX_TRM_ACTIVE must clear and 160 must be rejected
        spec.set(player, xi.job.GEO, 'terramancer', { silent = true })
        spec.refreshPlayer(player)
        player:setLevel(9)
        spec.refreshPlayer(player)
        assert(player:getLocalVar('OX_TRM_ACTIVE') == 0, 'Dropping below Lv10 must clear OX_TRM_ACTIVE')
        player.packets:clear()
        player.actions:useSpell(mob, xi.magic.spell.STONE_II)
        xi.test.world:skipTime(1)
        assert(receivedCannotCast47(player), 'GEO Lv9 Terramancer must NOT cast Shallow Fault (160)')

        -- Preserve vanilla spell behavior when no Soul override is active (WHM Bishop Lv10 Cure)
        player:changeJob(xi.job.WHM)
        player:setLevel(10)
        player:addSpell(xi.magic.spell.CURE)
        player:setHP(50)
        spec.set(player, xi.job.WHM, 'bishop', { silent = true })
        spec.refreshPlayer(player)
        player.packets:clear()
        player.actions:useSpell(player, xi.magic.spell.CURE)
        xi.test.world:skipTime(3)
        assert(not receivedCannotCast47(player), 'Vanilla Cure (1) must remain castable on WHM Bishop Lv10')
        assert(player:getHP() > 50, 'Vanilla Cure (1) must heal HP')
    end)
end)
