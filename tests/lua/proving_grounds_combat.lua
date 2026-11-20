-----------------------------------
-- OverlordsXI Soul Proving Grounds — Integration & Real Combat Proof Suite
--
-- Runs inside LandSandBoat's authoritative headless MapEngine (`xi_test.exe`).
-- Proves:
--   1. NPC Proving Grounds (The Arbiter) + Shared Encounter Registry in GM Home:
--      - Exact boss level, single-application xi.customBossServer scaling,
--        strict behavior isolation, unavailable archetype rejection, single-session
--        isolation lock, reset, repeat, and cleanup.
--   2. No-Progression Safety:
--      - Zero EXP, zero drops, zero gil, CallForHelp safety flag, skill-up lock/unlock.
--   3. Stage B / Milestone C Proof of Concept:
--      - One server-controlled Lv10 character (WAR / Berserker Soul + accessible Lv10
--        gear) fighting one Lv10 Physical Bruiser boss via real client packets,
--        real autoattack delays, real TP generation, real Weapon Skill execution,
--        real Job Ability execution, real enmity, real boss counter-attacks, and
--        server-authoritative JSONL telemetry output.
-----------------------------------
local R    = xi.overlords.provingGrounds.registry
local T    = xi.overlords.provingGrounds.telemetry
local A    = xi.overlords.provingGrounds.arena
local spec = xi.overlords.spec
local gear = xi.overlords.testGear

local function selectLv10WeaponskillForPlayer(player)
    local skillType = player.getWeaponSkillType and player:getWeaponSkillType(xi.slot.MAIN) or 0
    local bySkill =
    {
        [xi.skill.HAND_TO_HAND] = xi.weaponskill.COMBO,
        [xi.skill.DAGGER]       = xi.weaponskill.WASP_STING,
        [xi.skill.SWORD]        = xi.weaponskill.FAST_BLADE,
        [xi.skill.GREAT_SWORD]  = xi.weaponskill.HARD_SLASH,
        [xi.skill.AXE]          = xi.weaponskill.RAGING_AXE,
        [xi.skill.GREAT_AXE]    = xi.weaponskill.SHIELD_BREAK,
        [xi.skill.SCYTHE]       = xi.weaponskill.SLICE,
        [xi.skill.POLEARM]      = xi.weaponskill.DOUBLE_THRUST,
        [xi.skill.KATANA]       = xi.weaponskill.BLADE_RIN,
        [xi.skill.GREAT_KATANA] = xi.weaponskill.TACHI_ENPI,
        [xi.skill.CLUB]         = xi.weaponskill.SHINING_STRIKE,
        [xi.skill.STAFF]        = xi.weaponskill.HEAVY_SWING,
    }
    return bySkill[skillType] or xi.weaponskill.SHIELD_BREAK
end

describe('Soul Proving Grounds Lite — NPC, Shared Registry & Safety', function()
    local player

    before_each(function()
        A.cleanupSession('test_setup_clear', { despawnMob = true, notifyOwner = false, writeLog = false })
        player = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.WAR,
            level = 10,
        })
    end)

    after_each(function()
        A.cleanupSession('test_teardown_clear', { despawnMob = true, notifyOwner = false, writeLog = false })
    end)

    it('spawns The Arbiter NPC in GM Home', function()
        local arbiter = player.entities:get('DE_Crucible_Arbiter')
        assert(arbiter ~= nil, 'Crucible_Arbiter NPC was not found in GM Home')
    end)

    it('spawns Lv10 Physical Bruiser with exact level, single boss scaling, and no-progression flags', function()
        local ok, session = A.startTrial(player, 'physical_bruiser', 10)
        assert(ok and session and session.mob, 'Failed to start Lv10 Physical Bruiser trial')

        local mob = session.mob
        assert(mob:getMainLvl() == 10, string.format('Expected boss Lv10, got Lv%d', mob:getMainLvl()))
        assert(mob:getLocalVar('[CustomBoss]Applied') == 1, 'xi.customBossServer scaling was not applied')
        assert(mob:getLocalVar('[ProvingGrounds]TrialMob') == 1, 'TrialMob marker localVar missing')

        -- Confirm scaling is never double-applied on repeated calls.
        local attpBefore = mob:getMod(xi.mod.ATTP)
        local defpBefore = mob:getMod(xi.mod.DEFP)
        local hppBefore  = mob:getMod(xi.mod.HPP)
        assert(attpBefore > 0 and defpBefore > 0 and hppBefore > 0, 'Expected positive boss scaling modifiers')

        xi.customBossServer.applyMobScaling(mob)
        assert(mob:getMod(xi.mod.ATTP) == attpBefore, 'Boss ATTP was double-applied')
        assert(mob:getMod(xi.mod.DEFP) == defpBefore, 'Boss DEFP was double-applied')
        assert(mob:getMod(xi.mod.HPP) == hppBefore, 'Boss HPP was double-applied')

        -- Verify no-progression safeguards on mob & player.
        assert(mob:getCallForHelpFlag() == true, 'CallForHelp no-reward flag was not enabled')
        assert(mob:getMobMod(xi.mobMod.NO_DROPS) == 1, 'NO_DROPS mob mod not set')
        assert(mob:getMobMod(xi.mobMod.GIL_MAX) == -1, 'GIL_MAX -1 suppression not set')
        assert(mob:getMobMod(xi.mobMod.EXP_BONUS) == -100, 'EXP_BONUS -100 suppression not set')
        assert(player:getLocalVar('[ProvingGrounds]SkillupLocked') == 1, 'Player skill-up lock was not applied')

        -- Verify belt-and-suspenders EXP formula returns 0 for trial mobs.
        local expResult = xi.experiencePoints.calculate(player, mob, {
            baseExp            = 200,
            partySize          = 1,
            regionId           = xi.region.RONFAURE,
            highestMemberLevel = 10,
            memberLevel        = 10,
            memberTNL          = 2000,
            highestMemberTNL   = 2000,
            mobDifficulty      = xi.mobDifficulty.EVEN_MATCH,
            chainActive        = false,
            chainNumber        = 0,
        })
        assert(expResult and expResult.exp == 0, string.format('Expected 0 EXP for trial mob, got %s', tostring(expResult and expResult.exp)))

        -- Reset releases lock and removes skill-up lock.
        local resetOk = A.resetTrial(player)
        assert(resetOk, 'Owner failed to reset active trial')
        assert(A.getActiveSession() == nil, 'Active session lock was not cleared after reset')
        assert(player:getLocalVar('[ProvingGrounds]SkillupLocked') == 0, 'Player skill-up lock was not removed on reset')
    end)

    it('enforces single-session isolation lock, supports repeat, and rejects unavailable archetypes', function()
        local ok, session = A.startTrial(player, 'physical_bruiser', 10)
        assert(ok and session, 'Failed to start initial trial')

        -- Second tester in GM Home must be blocked from starting or resetting.
        local other = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.PLD,
            level = 10,
        })
        local otherStartOk, startReason = A.startTrial(other, 'training_dummy', 10)
        assert(not otherStartOk and startReason == 'arena_locked', 'Second player was not blocked from starting concurrent trial')

        local otherResetOk, resetReason = A.resetTrial(other)
        assert(not otherResetOk and resetReason == 'locked_by_other', 'Second player was not blocked from resetting owner trial')

        -- Owner repeats previous encounter cleanly.
        local repOk, repSession = A.repeatTrial(player)
        assert(repOk and repSession and repSession.encounter.bossType == 'physical_bruiser' and repSession.encounter.bossLevel == 10,
            'Repeat Previous Encounter did not recreate Lv10 Physical Bruiser')

        assert(A.resetTrial(player), 'Owner reset failed')

        -- Verify remaining NPC-available archetypes spawn cleanly at Lv10.
        for _, archKey in ipairs({ 'magic_caster', 'aoe_boss', 'training_dummy' }) do
            local sOk, sSess = A.startTrial(player, archKey, 10)
            assert(sOk and sSess and sSess.mob, 'Failed to spawn archetype: ' .. archKey)
            assert(sSess.mob:getMainLvl() == 10, 'Wrong level for archetype: ' .. archKey)
            assert(A.resetTrial(player), 'Failed to reset archetype: ' .. archKey)
        end

        -- Unavailable archetype must be explicitly rejected, never silently substituted.
        local unavailOk, unavailErr = A.startTrial(player, 'mobile_boss', 10)
        assert(not unavailOk and unavailErr == 'archetype_unavailable', 'Unavailable archetype was not cleanly rejected')
    end)
end)

describe('Soul Proving Grounds — Stage B Real Combat Proof (Lv10 Solo)', function()
    local player
    local boss

    before_each(function()
        A.cleanupSession('stage_b_setup', { despawnMob = true, notifyOwner = false, writeLog = false })
        boss = nil
        player = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.WAR,
            level = 10,
        })
    end)

    after_each(function()
        if player then
            R.applySkillupLock(player, false)
            if player:isEngaged() then
                player:disengage()
            end
        end
        if boss and boss.setStatus then
            pcall(function()
                boss:setStatus(xi.status.DISAPPEAR)
            end)
        end
        A.cleanupSession('stage_b_teardown', { despawnMob = true, notifyOwner = false, writeLog = false })
    end)

    it('proves one server-controlled Lv10 character fighting one Lv10 Physical Bruiser with real combat mechanics', function()
        -- 1. Configure Lv10 WAR with Berserker Soul and accessible Lv10 TP equipment (NOT Lv75 BiS).
        local specOk = spec.set(player, xi.job.WAR, 'berserker', { silent = true })
        assert(specOk, 'Failed to activate WAR Berserker Soul')
        spec.refreshPlayer(player)

        local loadout, gearErr = gear.equipLoadout(player, {
            level     = 10,
            role      = 'tp',
            setLevel  = true,
            equip     = true,
            capSkills = true,
        })
        assert(loadout ~= nil, 'Failed to equip accessible Lv10 loadout: ' .. tostring(gearErr))
        assert(loadout.equippedCount > 0, 'Expected accessible Lv10 items to be equipped')

        -- Verify no item exceeds Lv10 (accessible Lv10 rule).
        for _, entry in pairs(loadout.slots or {}) do
            assert((entry.lvl or 1) <= 10, string.format('Equipped item %s exceeds Lv10 (lvl=%s)', tostring(entry.name), tostring(entry.lvl)))
        end

        -- Sync player combat pace and unlock Lv10 Weapon Skill via OverlordsXI WS Talent tree.
        xi.customBossServer.applyPlayerCombatPace(player, true)
        local wsId = selectLv10WeaponskillForPlayer(player)
        local wsTalents = xi.overlords and xi.overlords.wsTalents or nil
        if wsTalents and wsTalents.getTreeForWS and wsTalents.invest then
            local tree = wsTalents.getTreeForWS(wsId, player, xi.job.WAR)
            if tree and tree.nodes then
                for _, node in ipairs(tree.nodes) do
                    if (node.tier or 1) == 1 then
                        local invOk = wsTalents.invest(player, xi.job.WAR, wsId, node.key)
                        if invOk then
                            break
                        end
                    end
                end
            end
            assert(wsTalents.isWSUnlocked(player, wsId, xi.job.WAR), 'Failed to unlock Lv10 Weapon Skill via WS Talent tree')
        end

        player:setHP(player:getMaxHP())
        player:setMP(player:getMaxMP())
        player:setTP(0)
        R.applySkillupLock(player, true)

        -- 2. Build shared encounter config and spawn Lv10 Physical Bruiser via the SAME registry spawner.
        local encounter, encErr = R.buildEncounterConfig({
            bossType         = 'physical_bruiser',
            bossLevel        = 10,
            playerLevel      = 10,
            difficulty       = 'even_match',
            bossPreset       = 'normal',
            durationSec      = 90,
            partyComposition = 'solo',
            seed             = 12345,
        })
        assert(encounter ~= nil, 'Failed to build shared encounter config: ' .. tostring(encErr))

        local zone = player:getZone()
        local spawnErr
        boss, spawnErr = R.spawnTrialMob(zone, encounter, {
            spawnLifetimeSec = 120,
        })
        assert(boss ~= nil, 'Failed to spawn Lv10 Physical Bruiser: ' .. tostring(spawnErr))
        assert(boss:getMainLvl() == 10, 'Spawned boss level mismatch')

        local bossStartHp = boss:getMaxHP()
        assert(bossStartHp > 0, 'Boss MaxHP was not initialized')

        -- Position player directly south of boss in melee range (2 yalms), facing north (+Z, rot=192).
        player.actions:move(R.BOSS_POS.x, R.BOSS_POS.y, R.BOSS_POS.z - 2, 192)
        xi.test.world:tickEntity(player)
        xi.test.world:tickEntity(boss)

        -- 3. Attach server-authoritative telemetry logger using simulated combat clock.
        local simSeconds = 0
        local telem = T.beginSession({
            mob       = boss,
            actors    = { player },
            encounter = encounter,
            testMode  = 'automated_real',
            clockFn   = function()
                return simSeconds
            end,
        })

        -- 4. Explicit deterministic combat policy: lv10_war_berserker_v1
        --    - Engage target via real 0x01A action packet.
        --    - Use Provoke (Lv5 WAR JA) on cooldown (30s) to exercise JA + enmity + cooldown path.
        --    - Fire matching Lv10 Weapon Skill whenever TP >= 1000.
        local lastProvokeSec = -999
        local maxDurationSec = 90

        player.actions:engage(boss)
        xi.test.world:tickEntity(player)
        xi.test.world:tickEntity(boss)
        assert(player:isEngaged(), 'Server-controlled character failed to engage Lv10 boss')

        local outcome = 'timeout'
        for sec = 1, maxDurationSec do
            simSeconds = sec

            if not boss:isAlive() then
                outcome = 'victory'
                break
            end
            if not player:isAlive() then
                outcome = 'defeat'
                break
            end

            -- Use Provoke on cooldown (real JA packet -> real recast + enmity).
            if (sec - lastProvokeSec) >= 31 then
                player.actions:useAbility(boss, xi.jobAbility.PROVOKE)
                lastProvokeSec = sec
            elseif player:getTP() >= 1000 then
                -- Execute real Weapon Skill packet when TP >= 1000.
                player.actions:useWeaponskill(boss, wsId)
            end

            -- Advance real steady clock by 1 second and tick both entities + world.
            xi.test.world:skipTime(1)
            xi.test.world:tickEntity(player)
            xi.test.world:tickEntity(boss)
            if telem.sampleNow then
                telem.sampleNow()
            end

            if not boss:isAlive() then
                outcome = 'victory'
                break
            end
            if not player:isAlive() then
                outcome = 'defeat'
                break
            end
        end

        -- 5. Finalize telemetry & write machine-readable JSONL report.
        local record = T.finishSession(telem, outcome, {
            durationSec = math.max(1, simSeconds),
            writeLog    = true,
        })
        assert(record ~= nil, 'Telemetry finishSession returned nil')

        local off = record.metrics.offense
        local def = record.metrics.defense
        local thr = record.metrics.threat
        local res = record.metrics.resources_and_pets
        local saf = record.metrics.safety

        -- Print concise real-combat summary into test log for auditability.
        print(string.format(
            '[STAGE_B_PROOF] outcome=%s dur=%ds soul=%s/%s totalDmg=%d (auto=%d ws=%d wsUses=%d jaUses=%d) hits=%d misses=%d crits=%d incomingDmg=%d maxSpike=%d enmity=%d tpGen=%d tpSpent=%d expClean=%s',
            tostring(record.outcome),
            simSeconds,
            tostring(record.job),
            tostring(record.soul_key),
            off.total_damage,
            off.autoattack_damage,
            off.weaponskill_damage,
            off.weaponskill_uses,
            off.ability_uses,
            off.melee_hits,
            off.melee_misses,
            off.crit_hits,
            def.actual_incoming_damage,
            def.max_damage_spike,
            thr.enmity_generation,
            res.tp_generated,
            res.tp_spent,
            tostring(saf.progression_clean)
        ))

        -- 6. Authoritative real-combat assertions (Milestone C gate).
        assert(record.test_mode == 'automated_real', 'Expected test_mode=automated_real')
        assert(record.soul_key == 'berserker', 'Expected Berserker Soul active on combat actor')
        assert(record.boss_level == 10 and record.character_level == 10, 'Expected Lv10 vs Lv10 encounter')
        assert((off.melee_hits + off.melee_misses) > 0, 'No real melee autoattacks executed')
        assert(off.total_damage > 0, 'No real damage dealt to boss')
        assert(off.autoattack_damage > 0, 'No real autoattack damage recorded')
        assert(off.weaponskill_uses > 0 and res.tp_spent >= 1000, 'No real Weapon Skill executed via TP')
        assert(off.weaponskill_damage > 0, 'No real Weapon Skill damage recorded')
        assert(off.ability_uses > 0, 'No real Job Ability executed')
        assert(thr.enmity_generation > 0, 'No real enmity generated on boss')
        assert(def.actual_incoming_damage > 0, 'No real incoming boss combat damage recorded')
        assert(saf.progression_clean == true and saf.exp_points_observed == 0, 'Trial mob leaked EXP progression!')
        -- Confirm unsupported metrics are explicitly reported as "unavailable", never fabricated.
        assert(def.raw_incoming_damage == 'unavailable', 'Expected raw_incoming_damage to be explicitly unavailable')
    end)
end)
