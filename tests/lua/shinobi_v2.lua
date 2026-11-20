-----------------------------------
-- OverlordsXI Shinobi 2.0 — Real Engine Integration & Combat Benchmark Suite
-- Runs inside xi_test.exe against live LandSandBoat map engine, MariaDB,
-- C++ battleutils (patch 0045), kurogane_clones.lua, nin_specs.lua,
-- boss_like_combat_and_exp.lua, and overlords_soul_hud.lua.
-----------------------------------
local spec = xi.overlords.spec
local K    = xi.overlords.kurogane
local hud  = xi.overlords.hud

local simClock = 100000

local function advanceSim(seconds, player, target)
    local steps = math.max(1, math.floor(seconds or 1))
    for _ = 1, steps do
        simClock = simClock + 1
        xi.test.world:skipTime(1)
        if player then
            xi.test.world:tickEntity(player)
            local st = K._owners[player:getID()]
            if st and st.clones then
                for _, rec in ipairs(st.clones) do
                    if rec.mob then
                        xi.test.world:tickEntity(rec.mob)
                    end
                end
            end
        end
        if target then
            xi.test.world:tickEntity(target)
        end
    end
end

local function setupShinobiPlayer(level, zoneId)
    local player = xi.test.world:spawnPlayer({
        zone  = zoneId or xi.zone.WEST_RONFAURE,
        job   = xi.job.NIN,
        level = level,
    })
    spec.set(player, xi.job.NIN, 'kurogane')
    spec.refreshPlayer(player)
    -- Prevent random melee hits from interrupting deterministic spell-loop tests.
    player:addMod(xi.mod.SPELLINTERRUPT, 100)
    assert(player:getLocalVar('OX_SHINOBI_ACTIVE') == 1, 'OX_SHINOBI_ACTIVE was not set to 1')
    return player
end

local function engageFreshTarget(player, mobName)
    local target = player.entities:get(mobName or 'Wild_Rabbit')
    target:respawn()
    target:setPos(player:getXPos() + 1.5, player:getYPos(), player:getZPos(), 0)
    target:setUnkillable(true)
    target:setHP(target:getMaxHP())
    -- Face the target so combat autoattacks and spells have clear line of sight.
    player:setPos(player:getXPos(), player:getYPos(), player:getZPos(), 0)
    xi.test.world:tickEntity(target)
    player.actions:engage(target)
    xi.test.world:tickEntity(player)
    assert(player:isEngaged(), 'player failed to engage test target')
    return target
end

local function castSpell(player, target, spellId, waitSec, expectCast)
    player.actions:useSpell(target, spellId)
    xi.test.world:tickEntity(player)
    advanceSim(waitSec or 5, player, target)
    if expectCast then
        assert(player:hasRecast(xi.recast.MAGIC, spellId),
            string.format('Expected spell %d to cast and set recast (cast was blocked/interrupted)', spellId))
    end
end

describe('Shinobi 2.0 real-engine integration', function()
    local player
    local target
    local origNowSec

    before_each(function()
        origNowSec = xi.overlords.nowSec
        simClock = 100000
        xi.overlords.nowSec = function()
            return simClock
        end
        K.ENABLE_EXPERIMENTAL_CLONES = true
        K.ENABLE_EXPERIMENTAL_COMBAT = true
        player = nil
        target = nil
    end)

    after_each(function()
        if player then
            K.dismissAll(player)
        end
        if target then
            target:setUnkillable(false)
        end
        if origNowSec then
            xi.overlords.nowSec = origNowSec
        end
    end)

    it('grants Lv10 kit spells, casts zero-tool Shadow Squadron Ichi, and blocks locked spells', function()
        player = setupShinobiPlayer(10)
        target = engageFreshTarget(player)

        -- Lv10 Shinobi automatically learns 338, 320, 323, 326 and does NOT have 329, 339, 332, 335
        for _, sid in ipairs({ 338, 320, 323, 326 }) do
            assert(player:hasSpell(sid), 'Lv10 Shinobi missing auto-granted spell ' .. tostring(sid))
        end
        for _, sid in ipairs({ 329, 339, 332, 335 }) do
            assert(not player:hasSpell(sid), 'Lv10 Shinobi unexpectedly has locked spell ' .. tostring(sid))
        end

        -- Zero ninja tools in inventory: Shadow Squadron: Ichi (338) must succeed via C++ patch 0045
        castSpell(player, player, xi.magic.spell.UTSUSEMI_ICHI, 5)

        local snap = K.getSnapshot(player)
        assert(snap.clones == 2, string.format('Expected 2 clones from Ichi at Lv10, got %d', snap.clones))
        assert(not player:hasStatusEffect(xi.effect.COPY_IMAGE), 'Shinobi must never gain defensive COPY_IMAGE shadows')
        assert(player:hasRecast(xi.recast.MAGIC, xi.magic.spell.UTSUSEMI_ICHI), 'Ichi must set recast timer')

        -- Verify HP formula at Lv10: clamp(20 + 2*10, 40, 170) == 40
        local st = K._owners[player:getID()]
        assert(st and st.clones[1] and st.clones[1].mob:getMaxHP() == 40 and st.clones[1].mob:getHP() == 40,
            string.format('Lv10 clone HP must be 40/40 (got %d/%d)',
                st and st.clones[1] and st.clones[1].mob:getHP() or -1,
                st and st.clones[1] and st.clones[1].mob:getMaxHP() or -1))
    end)

    it('executes full Lv10 Feint -> Switch -> Cascade loop with zero enemy debuffs and zero tools', function()
        player = setupShinobiPlayer(10)
        target = engageFreshTarget(player)

        -- Invalid cast before clones exist: False Assault rejected without consuming recast
        castSpell(player, target, xi.magic.spell.KATON_ICHI, 1)
        assert(not player:hasRecast(xi.recast.MAGIC, xi.magic.spell.KATON_ICHI),
            'Rejected False Assault with 0 clones must NOT consume recast')

        -- Summon 2 clones with Shadow Squadron: Ichi
        castSpell(player, player, xi.magic.spell.UTSUSEMI_ICHI, 5)
        assert(K.getSnapshot(player).clones == 2, 'Expected 2 living clones')

        -- Wait for real attributed clone autoattacks to land (up to 16s) to trigger Build Feint
        local feintReached = false
        local trace = {}
        for sec = 1, 16 do
            advanceSim(1, player, target)
            local s = K.getSnapshot(player)
            trace[#trace + 1] = string.format(
                't=%d(c=%d,eng=%d,hits=%d,fh=%d,ph=%d)',
                sec, s.clones, s.engaged, s.attributed_hits, s.feint_hits, s.phase)
            if s.phase == K.PHASE_FEINT then
                feintReached = true
                break
            end
        end
        assert(feintReached, 'Two distinct living clones did not build Feint: ' .. table.concat(trace, ' | '))

        -- Step 1: False Assault (320) -> Switch Ready + 12s Opening, NO NINJUTSU_ELE_DEBUFF
        castSpell(player, target, xi.magic.spell.KATON_ICHI, 5, true)
        assert(not target:hasStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF), 'False Assault applied vanilla elemental debuff!')
        local snap = K.getSnapshot(player)
        assert(snap.phase == K.PHASE_SWITCH, 'False Assault must advance Feint -> Switch, got phase ' .. tostring(snap.phase))
        assert(snap.opening_rem > 0, 'False Assault must grant Opening')
        assert(snap.last_cmd == 'FA', 'last_cmd should be FA')

        -- Step 2: Mirror Step (323) -> Cascade Ready + consumes Opening, NO NINJUTSU_ELE_DEBUFF
        castSpell(player, target, xi.magic.spell.HYOTON_ICHI, 5, true)
        assert(not target:hasStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF), 'Mirror Step applied vanilla elemental debuff!')
        snap = K.getSnapshot(player)
        assert(snap.phase == K.PHASE_CASCADE, 'Mirror Step must advance Switch -> Cascade, got phase ' .. tostring(snap.phase))
        assert(snap.opening_rem == 0, 'Mirror Step must consume Opening')
        assert(snap.mirror_rem > 0, 'Mirror Step rhythm must be active')

        -- Step 3: Crosscut (326) -> triggers Cascade strike & resets cycle (last_cmd cleared; phase resets to Building,
        -- or fast Mirror-Step clones may already re-build Feint within the settle window).
        target:setHP(target:getMaxHP())
        local hpBefore = target:getHP()
        castSpell(player, target, xi.magic.spell.HUTON_ICHI, 5, true)
        assert(not target:hasStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF), 'Crosscut applied vanilla elemental debuff!')
        assert(target:getHP() < hpBefore, 'Crosscut + Cascade must deal real damage to target')
        snap = K.getSnapshot(player)
        assert((snap.phase == K.PHASE_BUILDING or snap.phase == K.PHASE_FEINT) and snap.last_cmd == '',
            string.format('Cascade must reset cycle and clear last_cmd (got phase=%d last_cmd=%q)', snap.phase, tostring(snap.last_cmd)))

        -- Verify HUD packet includes all tactical telemetry within 224-byte budget
        local pkt = hud.buildPacketData(player)
        assert(pkt.soulKey == 'kurogane' and pkt.unlocked == 1)
        assert(#pkt.kv <= 224, 'HUD KV exceeded 224 bytes: ' .. tostring(#pkt.kv))
    end)

    it('enforces Lv30/37/50/70 unlocks, Level Sync blocking, Shadow Legion & Phantom Assault, and Kagemusha isolation', function()
        player = setupShinobiPlayer(75)
        target = engageFreshTarget(player)

        -- Lv75 Shinobi learns all 8 kit spells
        for _, sid in ipairs({ 338, 339, 320, 323, 326, 329, 332, 335 }) do
            assert(player:hasSpell(sid), 'Lv75 Shinobi missing spell ' .. tostring(sid))
        end

        -- Summon Ni (3) + Ichi (2) -> 5 living clones, exact HP = 170/170 at Lv75
        castSpell(player, player, xi.magic.spell.UTSUSEMI_NI, 5, true)
        assert(K.getSnapshot(player).clones == 3, string.format('Ni must summon 3 clones, got %d', K.getSnapshot(player).clones))

        castSpell(player, player, xi.magic.spell.UTSUSEMI_ICHI, 5, true)
        assert(K.getSnapshot(player).clones == 5, string.format('Ni + Ichi must cap at 5 clones, got %d', K.getSnapshot(player).clones))
        local st = K._owners[player:getID()]
        assert(st.clones[1].mob:getMaxHP() == 170 and st.clones[1].mob:getHP() == 170, string.format(
            'Lv75 clone HP must be 170/170 (got hp=%d maxHP=%d lvl=%d)',
            st.clones[1].mob:getHP(), st.clones[1].mob:getMaxHP(), st.clones[1].mob:getMainLvl()))

        -- Cast Lv30 Shadow Pin (329), Lv50 Thunder Relay (332), Lv70 Final Mirage (335)
        castSpell(player, target, xi.magic.spell.DOTON_ICHI, 5, true)
        assert(not target:hasStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF), 'Shadow Pin applied debuff!')
        assert(K.getSnapshot(player).pin_rem > 0, 'Shadow Pin must activate pin window')

        castSpell(player, target, xi.magic.spell.RAITON_ICHI, 5, true)
        assert(not target:hasStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF), 'Thunder Relay applied debuff!')

        castSpell(player, target, xi.magic.spell.SUITON_ICHI, 5, true)
        assert(not target:hasStatusEffect(xi.effect.NINJUTSU_ELE_DEBUFF), 'Final Mirage applied debuff!')

        -- Refresh squad to 5 fresh clones before testing custom JAs (25s+ elapsed since initial Ni/Ichi)
        player:resetRecasts()
        castSpell(player, player, xi.magic.spell.UTSUSEMI_NI, 5, true)
        castSpell(player, player, xi.magic.spell.UTSUSEMI_ICHI, 5, true)
        assert(K.getSnapshot(player).clones == 5, string.format('Refreshed squad must have 5 clones, got %d', K.getSnapshot(player).clones))

        -- Existing custom JAs: Phantom Assault (488) and Shadow Legion (487)
        local paOk, paCount = K.executePhantomAssault(player)
        assert(paOk and paCount == 5, string.format('Phantom Assault must boost all 5 clones (ok=%s count=%s live=%d)',
            tostring(paOk), tostring(paCount), K.getSnapshot(player).clones))
        local slOk, slHits = K.executeShadowLegion(player, target)
        assert(slOk and slHits == 5, string.format('Shadow Legion must strike with all 5 clones (ok=%s hits=%s)',
            tostring(slOk), tostring(slHits)))

        -- Level Sync down to Lv25: stale Lv75 clones dismiss, and Lv30/37/50/70 spells are rejected BEFORE recast!
        player:setLevel(25)
        spec.refreshPlayer(player)
        assert(K.getSnapshot(player).clones == 0, 'Level change must dismiss stale clones')

        player:resetRecasts()
        player:addMod(xi.mod.SPELLINTERRUPT, 100)
        castSpell(player, player, xi.magic.spell.UTSUSEMI_ICHI, 5, true)
        assert(K.getSnapshot(player).clones == 2, 'Lv25 Ichi must still work')

        -- Attempt direct cast of Lv30 Shadow Pin (329) at Lv25 -> must be rejected without setting recast!
        player:resetRecasts()
        castSpell(player, target, xi.magic.spell.DOTON_ICHI, 1)
        assert(not player:hasRecast(xi.recast.MAGIC, xi.magic.spell.DOTON_ICHI),
            'Lv25 Shinobi must NOT be able to cast Shadow Pin (329) via direct cast!')

        -- Switch to Kagemusha: clones dismissed, OX_SHINOBI_ACTIVE cleared, Utsusemi: Ichi grants defensive COPY_IMAGE!
        spec.set(player, xi.job.NIN, 'kagemusha')
        spec.refreshPlayer(player)
        assert(player:getLocalVar('OX_SHINOBI_ACTIVE') == 0, 'Soul swap to Kagemusha must clear OX_SHINOBI_ACTIVE')
        assert(K.getSnapshot(player).clones == 0, 'Soul swap must dismiss Shinobi clones')

        player:resetRecasts()
        player:addMod(xi.mod.SPELLINTERRUPT, 100)
        castSpell(player, player, xi.magic.spell.UTSUSEMI_ICHI, 5, true)
        assert(player:hasStatusEffect(xi.effect.COPY_IMAGE), 'Kagemusha Utsusemi: Ichi must still grant defensive shadows!')
        assert(K.getSnapshot(player).clones == 0, 'Kagemusha must never summon Shinobi clones')
    end)

    it('verifies boss-style clone survivability (minor spikes/incidental AoE vs lethal heavy AoE/direct hits)', function()
        player = setupShinobiPlayer(75)
        target = engageFreshTarget(player)

        castSpell(player, player, xi.magic.spell.UTSUSEMI_NI, 5)
        castSpell(player, player, xi.magic.spell.UTSUSEMI_ICHI, 5)
        assert(K.getSnapshot(player).clones == 5, 'Expected 5 living Lv75 clones')

        local st = K._owners[player:getID()]
        local clone1 = st.clones[1].mob
        local clone2 = st.clones[2].mob
        local clone3 = st.clones[3].mob
        assert(clone1:getHP() == 170 and clone1:getMaxHP() == 170)

        -- 1. Incidental magic AoE (140 raw magic dmg): -30% MDT -> ~98 dmg -> clone survives with >0 HP!
        clone1:takeDamage(140, target, xi.attackType.MAGICAL, xi.damageType.FIRE)
        assert(clone1:isAlive() and clone1:getHP() > 0 and clone1:getHP() < 170,
            string.format('Healthy Lv75 clone should survive 1 incidental 140 magic AoE (remaining HP=%d)', clone1:getHP()))

        -- 2. Heavy boss AoE (360 raw magic dmg -> ~252 after -30% MDT): lethal to 170 HP clone!
        clone2:takeDamage(360, target, xi.attackType.MAGICAL, xi.damageType.FIRE)
        assert(not clone2:isAlive() or clone2:getHP() == 0, 'Heavy boss AoE must kill a 170 HP clone')

        -- 3. Direct boss physical melee hit (220 physical dmg): lethal! Clones can never tank!
        clone3:takeDamage(220, target, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
        assert(not clone3:isAlive() or clone3:getHP() == 0, 'Direct boss melee hit must kill a 170 HP clone')
    end)
end)
