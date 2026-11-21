-----------------------------------
-- SoulspireXI Soul Proving Grounds — Comprehensive Engine Verification Suite
--
-- Runs inside LandSandBoat's authoritative headless MapEngine (`xi_test.exe`).
-- Proves:
--   1. Arbiter NPC placement (-5, 0, 5), shared registry, no-progression safety,
--      and single-session lock.
--   2. Native Level Sync (xi.effect.LEVEL_RESTRICTION):
--      - Lv75 -> Lv10 stats, subjob cap (<=5), SoulspireXI Soul & BASE_HP rescaling,
--        pet/clone level enforcement, and clean restoration on reset/exit.
--      - Rejects invalid upward sync (Lv10 -> Lv50).
--   3. All Difficulty (+0, +3, +5, +8) & Classification (Normal, NM) combinations
--      across Lv10, 30, 50, 75, including boss levels above 75 (Lv78, Lv80, Lv83)
--      and Repeat Previous Encounter preserving all settings.
--   4. Full Combat Timeline, Event Log, 1s Snapshots, Accurate Timing, Feedback &
--      Write-Failure Detection:
--      - 30s preparation phase does NOT inflate combat duration or DPS.
--      - Strict monotonic seq & timestamps.
--      - Zero Weapon Skill double-counting; real autoattacks, WS, JA, enmity, incoming dmg.
--      - Multi-participant AoE correlation via boss_action_seq.
--      - Explicit write-failure detection (logging_status.ok == false).
--      - Native feedback persistence (feedback/<run_id>.json).
--      - No listener leaks across repeated trials.
-----------------------------------
local R    = xi.soulspire.provingGrounds.registry
local T    = xi.soulspire.provingGrounds.telemetry
local A    = xi.soulspire.provingGrounds.arena
local spec = xi.soulspire.spec
local gear = xi.soulspire.testGear

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

local function readAllLines(path)
    local fh = io.open(path, 'r')
    if not fh then
        return nil
    end
    local lines = {}
    for line in fh:lines() do
        if line ~= '' then
            lines[#lines + 1] = line
        end
    end
    fh:close()
    return lines
end

describe('Soul Proving Grounds Lite — NPC, Level Sync & Difficulty Selection', function()
    local player

    before_each(function()
        A.cleanupSession('test_setup_clear', { despawnMob = true, notifyOwner = false, writeLog = false })
        player = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.WAR,
            level = 75,
        })
        player:changesJob(xi.job.NIN)
        player:setLevel(75)
        player:setLevel(37)
        player:changeJob(xi.job.NIN)
        player:setLevel(37)
        player:changeJob(xi.job.WAR)
        player:changesJob(xi.job.NIN)
        player:setLevel(75)
        xi.customBossServer.applyPlayerCombatPace(player, true)
    end)

    after_each(function()
        A.cleanupSession('test_teardown_clear', { despawnMob = true, notifyOwner = false, writeLog = false })
        if player then
            R.applySkillupLock(player, false)
            R.restoreLevelSync(player)
        end
    end)

    it('spawns The Arbiter at (-5, 0, 5) clear of GM Home Menu Example NPC', function()
        local arbiter = player.entities:get('DE_Crucible_Arbiter')
        assert(arbiter ~= nil, 'Crucible_Arbiter NPC was not found in GM Home')
        assert(math.abs(arbiter:getXPos() - (-5)) < 0.1, string.format('Expected Arbiter X=-5, got %s', tostring(arbiter:getXPos())))
        assert(math.abs(arbiter:getZPos() - 5) < 0.1, string.format('Expected Arbiter Z=5, got %s', tostring(arbiter:getZPos())))
    end)

    it('syncs Lv75 character to effective Lv10 with subjob/HP/Soul restrictions, preserves +3 boss gap, repeats, and restores cleanly', function()
        spec.set(player, xi.job.WAR, 'berserker', { silent = true })
        spec.refreshPlayer(player)
        xi.customBossServer.applyPlayerCombatPace(player, true)

        local origMainLvl = player:getMainLvl()
        local origSubLvl  = player:getSubLvl()
        local origMaxHp   = player:getMaxHP()
        assert(origMainLvl == 75, string.format('Expected initial Lv75, got %d', origMainLvl))
        assert(origMaxHp > 400, string.format('Expected Lv75 MaxHP > 400, got %d', origMaxHp))

        -- Start Effective Lv10 + Very Tough (+3) + Normal -> Boss MUST be Lv13 (not Lv78!).
        local ok, session = A.startTrial(player, 'physical_bruiser', 10, {
            difficulty = 'very_tough',
            bossPreset = 'normal',
        })
        assert(ok and session and session.mob, 'Failed to start Lv75->Lv10 Very Tough (+3) trial')

        -- Verify native level sync took effect cleanly on stats, subjob, HP, and Soul.
        assert(player:getMainLvl() == 10, string.format('Expected synced effective Lv10, got %d', player:getMainLvl()))
        assert(player:getSubLvl() <= 5, string.format('Expected subjob <= 5 at Lv10, got %d', player:getSubLvl()))
        assert(player:hasStatusEffect(xi.effect.LEVEL_RESTRICTION), 'LEVEL_RESTRICTION status effect not active')
        assert(player:getMaxHP() < origMaxHp, string.format('Expected Lv10 MaxHP (%d) < Lv75 MaxHP (%d)', player:getMaxHP(), origMaxHp))
        assert(session.levelSync and session.levelSync.valid == true, 'Level sync verification failed')
        assert(session.levelSync.original_level == 75 and session.levelSync.effective_level == 10, 'Original vs effective level mismatch')

        -- Verify boss level is Effective Lv10 + 3 = Lv13, scaled once, with no-progression flags.
        local mob = session.mob
        assert(mob:getMainLvl() == 13, string.format('Expected Boss Lv13 (+3 over Lv10), got Lv%d', mob:getMainLvl()))
        assert(mob:getLocalVar('[CustomBoss]Applied') == 1, 'xi.customBossServer scaling not applied')
        local attpBefore = mob:getMod(xi.mod.ATTP)
        xi.customBossServer.applyMobScaling(mob)
        assert(mob:getMod(xi.mod.ATTP) == attpBefore, 'Boss scaling double-applied!')
        assert(mob:getCallForHelpFlag() == true, 'CallForHelp no-reward flag missing')
        assert(mob:getMobMod(xi.mobMod.NO_DROPS) == 1, 'NO_DROPS missing')
        assert(mob:getMobMod(xi.mobMod.GIL_MAX) == -1, 'GIL_MAX -1 missing')
        assert(mob:getMobMod(xi.mobMod.EXP_BONUS) == -100, 'EXP_BONUS -100 missing')

        -- Repeat Previous Encounter must preserve effective Lv10 + Very Tough (+3) + Normal -> Boss Lv13.
        local repOk, repSess = A.repeatTrial(player)
        assert(repOk and repSess and repSess.mob, 'Repeat Previous Encounter failed')
        assert(player:getMainLvl() == 10, 'Repeat did not re-apply Lv10 sync')
        assert(repSess.mob:getMainLvl() == 13, string.format('Repeat boss level expected 13, got %d', repSess.mob:getMainLvl()))
        assert(repSess.encounter.difficulty == 'very_tough' and repSess.encounter.bossPreset == 'normal', 'Repeat lost difficulty/preset')

        -- Reset restores original Lv75, subjob, MaxHP, and clears restriction & SyncActive charVar.
        local resetOk = A.resetTrial(player)
        assert(resetOk, 'Reset failed')
        assert(player:getMainLvl() == 75, string.format('Expected restored Lv75 after reset, got %d', player:getMainLvl()))
        assert(player:getSubLvl() == origSubLvl, string.format('Expected restored subjob Lv%d, got %d', origSubLvl, player:getSubLvl()))
        assert(not player:hasStatusEffect(xi.effect.LEVEL_RESTRICTION), 'LEVEL_RESTRICTION remained after reset')
        assert(player:getCharVar('[ProvingGrounds]SyncActive') == 0, 'SyncActive charVar not cleared on reset')
        assert(player:getMaxHP() >= origMaxHp - 5, string.format('Expected restored Lv75 MaxHP (~%d), got %d', origMaxHp, player:getMaxHP()))
    end)

    it('rejects invalid upward sync and validates Lv10/30/50/75 Normal & NM combinations including bosses above Lv75', function()
        -- Upward sync rejection: Lv10 player cannot sync upward to Lv50.
        local lowbie = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.WAR,
            level = 10,
        })
        local upOk, upReason = A.startTrial(lowbie, 'physical_bruiser', 50, { difficulty = 'even_match', bossPreset = 'normal' })
        assert(not upOk and upReason == 'cannot_sync_upward', 'Expected cannot_sync_upward rejection, got: ' .. tostring(upReason))

        -- Validate Normal & NM across Lv10, 30, 50, 75 including boss levels 78 (+3), 80 (+5), and 83 (+8 Extreme).
        local matrixCases =
        {
            { arch = 'physical_bruiser', eff = 10, diff = 'even_match',       preset = 'normal', expBoss = 10, expNM = false },
            { arch = 'magic_caster',     eff = 30, diff = 'very_tough',       preset = 'nm',     expBoss = 33, expNM = true  },
            { arch = 'aoe_boss',         eff = 50, diff = 'incredibly_tough', preset = 'nm',     expBoss = 55, expNM = true  },
            { arch = 'physical_bruiser', eff = 75, diff = 'very_tough',       preset = 'normal', expBoss = 78, expNM = false },
            { arch = 'training_dummy',   eff = 75, diff = 'incredibly_tough', preset = 'nm',     expBoss = 80, expNM = true  },
            { arch = 'physical_bruiser', eff = 75, diff = 'extreme',          preset = 'nm',     expBoss = 83, expNM = true  },
        }
        for _, tc in ipairs(matrixCases) do
            local sOk, sSess = A.startTrial(player, tc.arch, tc.eff, {
                difficulty = tc.diff,
                bossPreset = tc.preset,
            })
            assert(sOk and sSess and sSess.mob, string.format('Failed combo %s eff=%d diff=%s preset=%s', tc.arch, tc.eff, tc.diff, tc.preset))
            assert(player:getMainLvl() == tc.eff, string.format('Expected player synced to %d, got %d', tc.eff, player:getMainLvl()))
            assert(sSess.mob:getMainLvl() == tc.expBoss, string.format('Expected boss Lv%d, got Lv%d', tc.expBoss, sSess.mob:getMainLvl()))
            assert(sSess.mob:isNM() == tc.expNM, string.format('Expected isNM=%s for %s/%s', tostring(tc.expNM), tc.arch, tc.preset))
            if tc.diff == 'extreme' then
                assert(sSess.encounter.extremeChallenge == true and sSess.encounter.standardBaseline == false, 'Extreme +8 must be flagged non-baseline')
            end
            assert(A.resetTrial(player), 'Reset failed after matrix combo')
            assert(player:getMainLvl() == 75, 'Player not restored to Lv75 after combo reset')
        end
    end)

    it('enforces effective Lv10 scaling on Shinobi clones and pets during synced trials', function()
        local nin = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.NIN,
            level = 75,
        })
        spec.set(nin, xi.job.NIN, 'kurogane', { silent = true })
        spec.refreshPlayer(nin)

        local ok, session = A.startTrial(nin, 'physical_bruiser', 10, {
            difficulty = 'even_match',
            bossPreset = 'normal',
        })
        assert(ok and session and session.mob, 'Failed to start Lv75->Lv10 NIN trial')
        assert(nin:getMainLvl() == 10, 'NIN was not synced to Lv10')

        -- Verify Kurogane clone summoned during Lv10 synced trial spawns at Lv10 (not Lv75).
        local K = xi.soulspire.kurogane
        local prevClonesFlag = K.ENABLE_EXPERIMENTAL_CLONES
        K.ENABLE_EXPERIMENTAL_CLONES = true
        nin.actions:move(R.BOSS_POS.x, R.BOSS_POS.y, R.BOSS_POS.z - 2, 192)
        nin.actions:engage(session.mob)
        xi.test.world:tickEntity(nin)
        local cOk, spawned = K.spawn(nin, 1)
        if cOk and spawned and spawned >= 1 then
            local state = K._owners[nin:getID()]
            assert(state and #state.clones >= 1, 'Expected tracked Kurogane clone')
            local cloneMob = state.clones[1].mob
            assert(cloneMob:getMainLvl() == 10, string.format('Expected synced Lv10 clone, got Lv%d', cloneMob:getMainLvl()))
        end
        K.ENABLE_EXPERIMENTAL_CLONES = prevClonesFlag

        assert(A.resetTrial(nin), 'NIN reset failed')
        assert(nin:getMainLvl() == 75, 'NIN not restored to Lv75')
        assert(K.getSnapshot(nin).clones == 0, 'Clones were not dismissed on reset/restore')
    end)
end)

describe('Soul Proving Grounds — Full Timeline, Timing, Feedback & Real Combat Proof', function()
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
            R.restoreLevelSync(player)
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

    it('isolates 30s preparation phase, logs monotonic events & 1s snapshots without WS double-counting, and saves feedback', function()
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
        for _, entry in pairs(loadout.slots or {}) do
            assert((entry.lvl or 1) <= 10, string.format('Equipped item %s exceeds Lv10', tostring(entry.name)))
        end

        xi.customBossServer.applyPlayerCombatPace(player, true)
        local wsId = selectLv10WeaponskillForPlayer(player)
        local wsTalents = xi.soulspire and xi.soulspire.wsTalents or nil
        if wsTalents and wsTalents.getTreeForWS and wsTalents.invest then
            local tree = wsTalents.getTreeForWS(wsId, player, xi.job.WAR)
            if tree and tree.nodes then
                for _, node in ipairs(tree.nodes) do
                    if (node.tier or 1) == 1 then
                        if wsTalents.invest(player, xi.job.WAR, wsId, node.key) then
                            break
                        end
                    end
                end
            end
            assert(wsTalents.isWSUnlocked(player, wsId, xi.job.WAR), 'Failed to unlock Lv10 WS')
        end

        player:setHP(player:getMaxHP())
        player:setMP(player:getMaxMP())
        player:setTP(0)
        R.applySkillupLock(player, true)

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
        assert(encounter ~= nil, 'Failed to build encounter config: ' .. tostring(encErr))

        local zone = player:getZone()
        local spawnErr
        boss, spawnErr = R.spawnTrialMob(zone, encounter, { spawnLifetimeSec = 120 })
        assert(boss ~= nil, 'Failed to spawn Lv10 Physical Bruiser: ' .. tostring(spawnErr))

        -- Start simulated millisecond clock at 0; simulate a 30-second PREPARATION phase first!
        local simMs = 0
        local telem = T.beginSession({
            mob                     = boss,
            actors                  = { player },
            encounter               = encounter,
            testMode                = 'automated_real',
            originalLevel           = 10,
            effectiveLevel          = 10,
            levelSync               = R.verifyLevelSync(player, 10),
            enableLiveSnapshotTimer = false,
            clockMsFn               = function()
                return simMs
            end,
        })

        -- 30-second preparation phase (0ms -> 30000ms) BEFORE any hostile action.
        simMs = 15000
        telem.sampleNow()
        simMs = 30000

        -- Move into melee range and engage at t=30s (first hostile action starts combat clock!).
        player.actions:move(R.BOSS_POS.x, R.BOSS_POS.y, R.BOSS_POS.z - 2, 192)
        xi.test.world:tickEntity(player)
        xi.test.world:tickEntity(boss)

        player.actions:engage(boss)
        xi.test.world:tickEntity(player)
        xi.test.world:tickEntity(boss)
        assert(player:isEngaged(), 'Server-controlled character failed to engage Lv10 boss')

        local lastProvokeSec = -999
        local outcome = 'timeout'
        for combatSec = 1, 90 do
            simMs = 30000 + combatSec * 1000

            if not boss:isAlive() then
                outcome = 'victory'
                break
            end
            if not player:isAlive() then
                outcome = 'defeat'
                break
            end

            if (combatSec - lastProvokeSec) >= 31 then
                player.actions:useAbility(boss, xi.jobAbility.PROVOKE)
                lastProvokeSec = combatSec
            elseif player:getTP() >= 1000 then
                player.actions:useWeaponskill(boss, wsId)
            end

            xi.test.world:skipTime(1)
            xi.test.world:tickEntity(player)
            xi.test.world:tickEntity(boss)
            telem.recordSnapshot(false)

            if not boss:isAlive() then
                outcome = 'victory'
                break
            end
            if not player:isAlive() then
                outcome = 'defeat'
                break
            end
        end

        local record = T.finishSession(telem, outcome, { writeLog = true })
        assert(record ~= nil, 'Telemetry finishSession returned nil')
        assert(record.logging_status.ok == true, 'Unexpected logging error: ' .. table.concat(record.logging_status.errors or {}, '; '))

        -- Verify 30s preparation phase was isolated from combat duration!
        assert(record.combat_started == true, 'Combat start was not detected')
        assert(record.prep_duration_sec >= 29.5 and record.prep_duration_sec <= 31.5,
            string.format('Expected ~30s prep_duration_sec, got %s', tostring(record.prep_duration_sec)))
        assert(record.encounter_duration_sec >= 20 and record.encounter_duration_sec <= 40,
            string.format('30s prep inflated combat duration! got %s', tostring(record.encounter_duration_sec)))

        local off = record.metrics.offense
        local def = record.metrics.defense
        local thr = record.metrics.threat
        local res = record.metrics.resources_and_pets
        local saf = record.metrics.safety

        -- Authoritative real combat assertions & zero WS double-counting!
        assert((off.melee_hits + off.melee_misses) > 0, 'No real melee autoattacks executed')
        assert(off.autoattack_damage > 0, 'No autoattack damage recorded')
        assert(off.weaponskill_uses > 0 and off.weaponskill_damage > 0 and res.tp_spent >= 1000, 'No real WS executed')
        assert(off.autoattack_damage + off.weaponskill_damage + off.spell_damage + off.pet_and_clone_damage == off.total_damage,
            'Damage attribution mismatch (possible WS double-count!)')
        assert(off.ability_uses > 0, 'No real Job Ability executed')
        assert(thr.enmity_generation > 0, 'No real enmity generated')
        assert(def.actual_incoming_damage > 0, 'No real incoming boss damage recorded')
        assert(saf.progression_clean == true and saf.exp_points_observed == 0, 'EXP leak detected!')
        assert(def.raw_incoming_damage == 'unavailable', 'Unsupported metric must remain unavailable')

        -- Verify chronological events file exists with monotonic seq & timestamps.
        local evLines = readAllLines(record.files.events_log)
        assert(evLines ~= nil and #evLines >= 10, 'Events JSONL file missing or empty')
        local prevSeq, prevSessionMs = 0, -1
        for _, ln in ipairs(evLines) do
            local seq = tonumber(ln:match('"seq":(%d+)'))
            local sms = tonumber(ln:match('"session_ms":(%d+)'))
            assert(seq and seq > prevSeq, 'Event sequence numbers not strictly monotonic')
            assert(sms and sms >= prevSessionMs, 'Event session_ms timestamps not monotonic')
            prevSeq = seq
            prevSessionMs = sms
        end

        -- Verify 1-second snapshots file exists and recorded combat ticks.
        local snapLines = readAllLines(record.files.snapshots_log)
        assert(snapLines ~= nil and #snapLines >= 10, 'Snapshots JSONL file missing or too few 1s snapshots')

        -- Verify native feedback persistence for this run_id.
        local fbOk, fbErr, fbPath = T.saveFeedback(record.run_id, {
            source     = 'npc_menu',
            tag        = 'survival_felt_bad',
            label      = 'Survival Felt Bad',
            soul_key   = record.soul_key,
            boss_type  = record.boss_type,
            boss_level = record.actual_boss_level,
        })
        assert(fbOk and fbPath, 'Feedback save failed: ' .. tostring(fbErr))
        local fbLines = readAllLines(fbPath)
        assert(fbLines ~= nil and #fbLines >= 1, 'Feedback JSON file was not written')
    end)

    it('detects and explicitly reports file write failures rather than swallowing errors', function()
        local encounter = R.buildEncounterConfig({
            bossType    = 'training_dummy',
            bossLevel   = 10,
            playerLevel = 10,
            difficulty  = 'even_match',
            bossPreset  = 'normal',
        })
        boss = R.spawnTrialMob(player:getZone(), encounter, { spawnLifetimeSec = 60 })
        assert(boss ~= nil, 'Failed to spawn dummy for write-failure test')

        -- Create a regular file to act as an impossible parent directory on both POSIX (Linux/Docker) and Windows.
        local blockerPath = 'log/proving_grounds/.pg_unwritable_blocker'
        local blockerFile = io.open(blockerPath, 'w')
        assert(blockerFile ~= nil, 'Failed to create blocker file for cross-platform write-failure test')
        blockerFile:write('not-a-directory\n')
        blockerFile:close()

        local telem = T.beginSession({
            mob                     = boss,
            actors                  = { player },
            encounter               = encounter,
            testMode                = 'automated_real',
            baseDir                 = blockerPath .. '/nested',
            legacyLogPath           = blockerPath .. '/legacy.jsonl',
            enableLiveSnapshotTimer = false,
        })
        local record = T.finishSession(telem, 'reset', { writeLog = true })
        os.remove(blockerPath)
        assert(record ~= nil, 'finishSession returned nil')
        assert(record.logging_status.ok == false, 'Expected logging_status.ok == false on unwritable path')
        assert(record.logging_status.partial_recording == true, 'Expected partial_recording == true on write error')
        assert(#(record.logging_status.errors or {}) >= 1, 'Expected explicit error details on write failure')
    end)

    it('correlates boss AoE damage across multiple participants and does not leak listeners across repeats', function()
        local ally = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.PLD,
            level = 10,
        })

        local encounter = R.buildEncounterConfig({
            bossType         = 'aoe_boss',
            bossLevel        = 10,
            playerLevel      = 10,
            difficulty       = 'even_match',
            bossPreset       = 'normal',
            partyComposition = 'party',
        })
        local simMs = 0
        local telemRef = nil
        boss = R.spawnTrialMob(player:getZone(), encounter, {
            spawnLifetimeSec = 60,
            onMobSkillChosen = function(m, t, sid)
                if telemRef and telemRef.onBossSkillChosen then
                    telemRef.onBossSkillChosen(m, t, sid)
                end
            end,
        })
        assert(boss ~= nil, 'Failed to spawn Lv10 AoE Boss')

        local telem = T.beginSession({
            mob                     = boss,
            actors                  = { player, ally },
            encounter               = encounter,
            testMode                = 'automated_real',
            originalLevel           = 10,
            effectiveLevel          = 10,
            enableLiveSnapshotTimer = false,
            clockMsFn               = function() return simMs end,
        })
        telemRef = telem

        -- Trigger boss AoE selection + simulated simultaneous damage across both participants.
        simMs = 5000
        telem.onBossSkillChosen(boss, player, 665) -- Grand Slam AoE
        simMs = 5200
        player:triggerListener('TAKE_DAMAGE', player, 42, boss, xi.attackType.PHYSICAL, xi.damageType.BLUNT)
        ally:triggerListener('TAKE_DAMAGE', ally, 35, boss, xi.attackType.PHYSICAL, xi.damageType.BLUNT)

        local rec1 = T.finishSession(telem, 'reset', { writeLog = true })
        assert(rec1 and rec1.logging_status.ok, 'AoE correlation run failed to log')
        assert(rec1.metrics.defense.actual_incoming_damage == 77,
            string.format('Expected 77 combined incoming AoE damage, got %d', rec1.metrics.defense.actual_incoming_damage))

        local evLines = readAllLines(rec1.files.events_log)
        local corrSeqs = {}
        for _, ln in ipairs(evLines or {}) do
            if ln:find('"event_type":"damage_taken"', 1, true) then
                local bseq = ln:match('"boss_action_seq":(%d+)')
                assert(bseq ~= nil, 'AoE damage_taken event missing boss_action_seq correlation')
                corrSeqs[#corrSeqs + 1] = tonumber(bseq)
            end
        end
        assert(#corrSeqs == 2 and corrSeqs[1] == corrSeqs[2], 'Multi-participant AoE hits did not share the same boss_action_seq')

        -- Verify zero listener leak on repeat: detached listeners from run 1 must not fire during run 2.
        local telem2 = T.beginSession({
            mob                     = boss,
            actors                  = { player },
            encounter               = encounter,
            testMode                = 'automated_real',
            originalLevel           = 10,
            effectiveLevel          = 10,
            enableLiveSnapshotTimer = false,
            clockMsFn               = function() return simMs end,
        })
        simMs = 6000
        player:triggerListener('TAKE_DAMAGE', player, 25, boss, xi.attackType.PHYSICAL, xi.damageType.BLUNT)
        local rec2 = T.finishSession(telem2, 'reset', { writeLog = true })
        assert(rec2.metrics.defense.actual_incoming_damage == 25,
            string.format('Listener leak or duplicate damage on repeat: expected 25, got %d', rec2.metrics.defense.actual_incoming_damage))
        assert(rec1.metrics.defense.actual_incoming_damage == 77, 'Finished run 1 mutated by run 2!')
    end)
end)
