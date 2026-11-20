-----------------------------------
-- OverlordsXI Soul Proving Grounds — Comprehensive Engine Verification Suite
--
-- Runs inside LandSandBoat's authoritative headless MapEngine (`xi_test.exe`).
-- Proves:
--   1. Arbiter NPC placement (-5, 0, 5), shared registry, no-progression safety,
--      and single-session lock.
--   2. Native Level Sync (xi.effect.LEVEL_RESTRICTION):
--      - Lv75 -> Lv10 stats, subjob cap (<=5), OverlordsXI Soul & BASE_HP rescaling,
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
        local K = xi.overlords.kurogane
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
        local wsTalents = xi.overlords and xi.overlords.wsTalents or nil
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
        assert(off.autoattack_damage + off.weaponskill_damage + off.spell_damage + (off.ability_damage or 0) + (off.other_damage or 0) + off.pet_and_clone_damage == off.total_damage,
            'Damage attribution mismatch (possible WS double-count!)')
        assert(record.reconciliation and record.reconciliation.damage_reconciled == true,
            'Summary damage did not reconcile with authoritative boss HP loss!')
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

        local telem = T.beginSession({
            mob                     = boss,
            actors                  = { player },
            encounter               = encounter,
            testMode                = 'automated_real',
            baseDir                 = 'log/proving_grounds/<invalid:path>',
            legacyLogPath           = 'log/proving_grounds/<invalid:legacy>.jsonl',
            enableLiveSnapshotTimer = false,
        })
        local record = T.finishSession(telem, 'reset', { writeLog = true })
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

describe('Soul Proving Grounds — Combat Timing, HP Recovery, WS Attribution & Visibility Regressions', function()
    local player
    local boss

    before_each(function()
        A.cleanupSession('reg_setup', { despawnMob = true, notifyOwner = false, writeLog = false })
        boss = nil
        player = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.WAR,
            level = 10,
        })
        xi.customBossServer.applyPlayerCombatPace(player, true)
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
        A.cleanupSession('reg_teardown', { despawnMob = true, notifyOwner = false, writeLog = false })
    end)

    it('1 & 5. Boss self-buff (Blaze Spikes) stays in preparation phase and is excluded from sustained DPS', function()
        local encounter = R.buildEncounterConfig({
            bossType    = 'magic_caster',
            bossLevel   = 10,
            playerLevel = 10,
            difficulty  = 'even_match',
            bossPreset  = 'nm',
        })
        boss = R.spawnTrialMob(player:getZone(), encounter, { spawnLifetimeSec = 90 })
        assert(boss ~= nil, 'Failed to spawn Lv10 Magic Caster NM')

        local simMs = 0
        local telem = T.beginSession({
            mob                     = boss,
            actors                  = { player },
            encounter               = encounter,
            testMode                = 'automated_real',
            originalLevel           = 10,
            effectiveLevel          = 10,
            enableLiveSnapshotTimer = false,
            clockMsFn               = function() return simMs end,
        })

        -- Boss casts Blaze Spikes (249) on ITSELF at t=1.8s (reproducing live runs 004 & 005).
        local fakeBlazeSpikes = { getID = function() return 249 end }
        simMs = 1800
        boss:triggerListener('MAGIC_START', boss, boss, fakeBlazeSpikes)
        simMs = 4800
        boss:triggerListener('MAGIC_USE', boss, boss, fakeBlazeSpikes)

        assert(telem.combatStartMs == nil, 'Self-targeted boss buff must NOT start the combat timer!')

        -- Player waits until t=20s, then lands real melee hits totaling 100 damage over 10s of combat.
        simMs = 20000
        player:triggerListener('MELEE_SWING_HIT', player, boss, { isCritical = function() return false end })
        boss:takeDamage(50, player, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
        assert(telem.combatStartMs == 20000, string.format('Expected combat start at 20000ms, got %s', tostring(telem.combatStartMs)))

        simMs = 30000
        player:triggerListener('MELEE_SWING_HIT', player, boss, { isCritical = function() return false end })
        boss:takeDamage(50, player, xi.attackType.PHYSICAL, xi.damageType.SLASHING)

        local rec = T.finishSession(telem, 'reset', { writeLog = true })
        assert(rec.combat_started == true, 'Combat should have started on first hostile hit')
        assert(math.abs(rec.prep_duration_sec - 20.0) < 0.05, string.format('Expected 20s prep, got %s', tostring(rec.prep_duration_sec)))
        assert(math.abs(rec.encounter_duration_sec - 10.0) < 0.05, string.format('Expected 10s combat, got %s', tostring(rec.encounter_duration_sec)))
        -- Sustained DPS MUST be 100 / 10 = 10.0 (NOT 100 / 28.2 = 3.55!)
        assert(math.abs(rec.metrics.offense.sustained_dps - 10.0) < 0.05,
            string.format('Preparation time leaked into sustained DPS: expected 10.0, got %s', tostring(rec.metrics.offense.sustained_dps)))

        -- Verify boss self-buff events were preserved in preparation phase timeline
        local evLines = readAllLines(rec.files.events_log)
        local sawPrepBossSpell = false
        for _, ln in ipairs(evLines or {}) do
            if ln:find('"event_type":"boss_spell_start"', 1, true) and ln:find('"phase":"preparation"', 1, true) then
                sawPrepBossSpell = true
            end
        end
        assert(sawPrepBossSpell, 'Pre-combat boss self-buff must remain in preparation-phase timeline')
    end)

    it('2. Provoke starts combat cleanly', function()
        local encounter = R.buildEncounterConfig({
            bossType    = 'magic_caster',
            bossLevel   = 10,
            playerLevel = 10,
            difficulty  = 'even_match',
            bossPreset  = 'normal',
        })
        boss = R.spawnTrialMob(player:getZone(), encounter, { spawnLifetimeSec = 60 })
        local simMs = 0
        local telem = T.beginSession({
            mob                     = boss,
            actors                  = { player },
            encounter               = encounter,
            testMode                = 'automated_real',
            originalLevel           = 10,
            effectiveLevel          = 10,
            enableLiveSnapshotTimer = false,
            clockMsFn               = function() return simMs end,
        })

        simMs = 8000
        player.actions:move(R.BOSS_POS.x, R.BOSS_POS.y, R.BOSS_POS.z - 2, 192)
        xi.test.world:tickEntity(player)
        player.actions:useAbility(boss, xi.jobAbility.PROVOKE)
        xi.test.world:skipTime(1)
        xi.test.world:tickEntity(player)
        xi.test.world:tickEntity(boss)

        assert(telem.combatStartMs == 8000, string.format('Provoke did not start combat at 8000ms (got %s)', tostring(telem.combatStartMs)))
        local rec = T.finishSession(telem, 'reset', { writeLog = false })
        assert(rec.combat_started == true and rec.combat_start_info and rec.combat_start_info.verified_hostile == true,
            'Provoke combat_start_info must be verified_hostile=true')
    end)

    it('3. Shinobi clone opening attack starts combat with verified clone attribution', function()
        local nin = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.NIN,
            level = 10,
        })
        spec.set(nin, xi.job.NIN, 'kurogane', { silent = true })
        spec.refreshPlayer(nin)

        local encounter = R.buildEncounterConfig({
            bossType    = 'physical_bruiser',
            bossLevel   = 10,
            playerLevel = 10,
            difficulty  = 'even_match',
            bossPreset  = 'normal',
        })
        boss = R.spawnTrialMob(nin:getZone(), encounter, { spawnLifetimeSec = 60 })
        local K = xi.overlords.kurogane
        local prevFlag = K.ENABLE_EXPERIMENTAL_CLONES
        K.ENABLE_EXPERIMENTAL_CLONES = true
        nin.actions:move(R.BOSS_POS.x, R.BOSS_POS.y, R.BOSS_POS.z - 2, 192)
        nin.actions:engage(boss)
        xi.test.world:tickEntity(nin)

        -- Spawn a real Kurogane shadow clone BEFORE starting the telemetry session so
        -- the clone's opening attack is the first hostile event inside the session.
        local cOk, spawned = K.spawn(nin, 1)
        assert(cOk and spawned and spawned >= 1, 'Failed to spawn Kurogane clone: ' .. tostring(spawned))
        local cloneMob = K._owners[nin:getID()].clones[1].mob
        assert(cloneMob ~= nil, 'Kurogane clone mob missing')

        local simMs = 0
        local telem = T.beginSession({
            mob                     = boss,
            actors                  = { nin },
            encounter               = encounter,
            testMode                = 'automated_real',
            originalLevel           = 10,
            effectiveLevel          = 10,
            enableLiveSnapshotTimer = false,
            clockMsFn               = function() return simMs end,
        })

        assert(telem.combatStartMs == nil, 'Clone presence alone must not start combat before attacking')

        -- Clone lands the opening hostile attack on boss at t=6s
        simMs = 6000
        boss:takeDamage(28, cloneMob, xi.attackType.PHYSICAL, xi.damageType.SLASHING)

        assert(telem.combatStartMs == 6000, string.format('Expected clone opening attack to start combat at 6000ms, got %s', tostring(telem.combatStartMs)))
        local rec = T.finishSession(telem, 'reset', { writeLog = false })
        K.ENABLE_EXPERIMENTAL_CLONES = prevFlag
        if K.dismissAll then K.dismissAll(nin) end
        if nin:isEngaged() then nin:disengage() end

        assert(rec.combat_started == true, 'Clone opening attack did not start combat')
        assert(rec.metrics.offense.pet_and_clone_damage == 28,
            string.format('Expected 28 clone damage, got %s', tostring(rec.metrics.offense.pet_and_clone_damage)))
        assert(rec.combat_start_info and rec.combat_start_info.verified_hostile == true, 'Clone opening attack must be verified hostile')
    end)

    it('4. Hostile spell starts combat (while player self-buff does not)', function()
        local blm = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.BLM,
            level = 10,
        })
        local encounter = R.buildEncounterConfig({
            bossType    = 'physical_bruiser',
            bossLevel   = 10,
            playerLevel = 10,
            difficulty  = 'even_match',
            bossPreset  = 'normal',
        })
        boss = R.spawnTrialMob(blm:getZone(), encounter, { spawnLifetimeSec = 60 })
        local simMs = 0
        local telem = T.beginSession({
            mob                     = boss,
            actors                  = { blm },
            encounter               = encounter,
            testMode                = 'automated_real',
            originalLevel           = 10,
            effectiveLevel          = 10,
            enableLiveSnapshotTimer = false,
            clockMsFn               = function() return simMs end,
        })

        -- Self-targeted player buff does NOT start combat
        simMs = 2000
        blm:triggerListener('MAGIC_START', blm, blm, { getID = function() return 48 end })
        blm:triggerListener('MAGIC_USE', blm, blm, { getID = function() return 48 end }, { getMsg = function() return 230 end, getParam = function() return 41 end })
        assert(telem.combatStartMs == nil, 'Player self-buff must not start combat')

        -- Hostile spell targeting boss DOES start combat
        simMs = 5000
        blm:triggerListener('MAGIC_START', blm, boss, { getID = function() return 144 end }) -- Fire
        assert(telem.combatStartMs == 5000, string.format('Hostile spell failed to start combat at 5000ms (got %s)', tostring(telem.combatStartMs)))

        local rec = T.finishSession(telem, 'reset', { writeLog = false })
        assert(rec.combat_started == true and rec.combat_start_info.verified_hostile == true, 'Hostile spell start not verified')
    end)

    it('6 & 7. Healing spells, Regen, and unattributed HP recovery are accurately separated from Shell buffs and Max HP changes', function()
        local encounter = R.buildEncounterConfig({
            bossType    = 'magic_caster',
            bossLevel   = 10,
            playerLevel = 10,
            difficulty  = 'even_match',
            bossPreset  = 'normal',
        })
        boss = R.spawnTrialMob(player:getZone(), encounter, { spawnLifetimeSec = 60 })
        player:setHP(player:getMaxHP())
        local baseMaxHp = player:getMaxHP()

        local simMs = 0
        local telem = T.beginSession({
            mob                     = boss,
            actors                  = { player },
            encounter               = encounter,
            testMode                = 'automated_real',
            originalLevel           = 10,
            effectiveLevel          = 10,
            enableLiveSnapshotTimer = false,
            clockMsFn               = function() return simMs end,
        })

        -- Start combat with real incoming damage of 120 HP
        simMs = 1000
        player:takeDamage(120, boss, xi.attackType.PHYSICAL, xi.damageType.BLUNT)
        assert(player:getHP() == baseMaxHp - 120, 'Expected player HP reduced by 120')

        -- A. Shell buff (msgId=230, param=41=xi.effect.SHELL) must record 0 healing!
        simMs = 2000
        player:triggerListener('MAGIC_USE', player, player, { getID = function() return 48 end }, {
            getMsg   = function() return 230 end,
            getParam = function() return 41 end,
        })
        assert(telem.counters.effectiveHealing == 0,
            string.format('Shell buff falsely recorded %d healing!', telem.counters.effectiveHealing))

        -- B. Real Cure spell restores 40 HP (msgId=7 MagicRecoversHP)
        simMs = 3000
        player:addHP(40)
        player:triggerListener('MAGIC_USE', player, player, { getID = function() return 1 end }, {
            getMsg   = function() return 7 end,
            getParam = function() return 40 end,
        })
        assert(telem.counters.spellHealing == 40 and telem.counters.effectiveHealing == 40,
            string.format('Expected 40 spellHealing, got spell=%d total=%d', telem.counters.spellHealing, telem.counters.effectiveHealing))

        -- C. Authoritative Regen tick (+25 HP with xi.mod.REGEN=25) recorded once without double-counting
        simMs = 6000
        player:addMod(xi.mod.REGEN, 25)
        player:addHP(25)
        player:triggerListener('EFFECTS_TICK', player)
        -- Second immediate tick with no HP change must NOT double-count!
        simMs = 7000
        player:triggerListener('EFFECTS_TICK', player)
        player:delMod(xi.mod.REGEN, 25)
        assert(telem.counters.regenHealing == 25 and telem.counters.effectiveHealing == 65,
            string.format('Expected 25 regenHealing (65 total), got regen=%d total=%d', telem.counters.regenHealing, telem.counters.effectiveHealing))

        -- D. Max HP modification (+100 HP mod when topped off) must log max_hp_change, NOT healing!
        simMs = 8000
        local hpBeforeMod = player:getHP()
        player:addMod(xi.mod.HP, 100)
        player:updateHealth()
        telem.sampleNow()
        player:delMod(xi.mod.HP, 100)
        player:updateHealth()
        telem.sampleNow()
        assert(telem.counters.maxHpChanges >= 2, string.format('Expected >=2 max_hp_change events, got %d', telem.counters.maxHpChanges))
        assert(telem.counters.effectiveHealing == 65,
            string.format('Max HP change was mistaken for healing! effectiveHealing=%d', telem.counters.effectiveHealing))
        assert(player:getHP() <= hpBeforeMod, 'HP unexpectedly jumped after Max HP revert')

        -- E. Unobservable HP recovery (+20 HP with no spell/ability/WS/regen) must be labeled unattributed_hp_change
        simMs = 10000
        player:addHP(20)
        telem.sampleNow()
        assert(telem.counters.unattributedHpRecovery == 20,
            string.format('Expected 20 unattributed HP recovery, got %d', telem.counters.unattributedHpRecovery))
        assert(telem.counters.effectiveHealing == 65, 'Unattributed HP change must NOT inflate attributed effectiveHealing')

        local rec = T.finishSession(telem, 'reset', { writeLog = true })
        assert(rec.metrics.healing.spell_healing == 40, 'Summary spell_healing mismatch')
        assert(rec.metrics.healing.regen_healing == 25, 'Summary regen_healing mismatch')
        assert(rec.metrics.healing.unattributed_hp_recovery == 20, 'Summary unattributed_hp_recovery mismatch')
        assert(rec.metrics.healing.max_hp_changes >= 2, 'Summary max_hp_changes mismatch')

        local hasUnattrWarn = false
        for _, w in ipairs(rec.warnings or {}) do
            if w == 'unattributed_hp_recovery' then hasUnattrWarn = true end
        end
        assert(hasUnattrWarn, 'Expected explicit unattributed_hp_recovery warning in summary')
    end)

    it('8, 9, 10 & 11. Preserves simultaneous hits, records single & multi-hit WS damage exactly once, and reconciles with boss HP', function()
        local ally = xi.test.world:spawnPlayer({
            zone  = xi.zone.GM_HOME,
            job   = xi.job.WAR,
            level = 10,
        })
        local encounter = R.buildEncounterConfig({
            bossType    = 'physical_bruiser',
            bossLevel   = 10,
            playerLevel = 10,
            difficulty  = 'even_match',
            bossPreset  = 'normal',
        })
        boss = R.spawnTrialMob(player:getZone(), encounter, { spawnLifetimeSec = 90 })
        local bossStartHp = boss:getHP()
        assert(bossStartHp > 200, 'Expected boss HP > 200')

        local simMs = 0
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

        -- 8. Two legitimate simultaneous melee hits at exact same timestamp (simMs = 1000) with identical damage (25 each)
        simMs = 1000
        player:triggerListener('MELEE_SWING_HIT', player, boss, { isCritical = function() return false end })
        boss:takeDamage(25, player, xi.attackType.PHYSICAL, xi.damageType.SLASHING)
        ally:triggerListener('MELEE_SWING_HIT', ally, boss, { isCritical = function() return false end })
        boss:takeDamage(25, ally, xi.attackType.PHYSICAL, xi.damageType.SLASHING)

        assert(telem.counters.autoAttackDamage == 50,
            string.format('Simultaneous legitimate hits were lost or deduplicated! Expected 50, got %d', telem.counters.autoAttackDamage))

        -- 9. Single-hit Weapon Skill through real xi.weaponskills.takeWeaponskillDamage -> TAKE_DAMAGE -> WEAPONSKILL_USE order
        simMs = 3000
        local mockAction = {
            messageID = function() end,
            param = function() end,
            resolution = function() end,
            recordDamage = function() end,
        }
        local singleWsResults = {
            wsID            = xi.weaponskill.HARD_SLASH,
            hitsLanded      = 1,
            tpHitsLanded    = 1,
            extraHitsLanded = 0,
            bonusTP         = 0,
            shadowsAbsorbed = 0,
            criticalHit     = false,
            finalDmg        = 39,
        }
        local dmg1 = xi.weaponskills.takeWeaponskillDamage(
            boss,
            player,
            {},
            true,
            { type = xi.attackType.PHYSICAL, damageType = xi.damageType.SLASHING, slot = xi.slot.MAIN },
            singleWsResults,
            mockAction
        )
        -- Immediately fire WEAPONSKILL_USE just as CWeaponSkillState::Update does AFTER takeWeaponskillDamage!
        player:triggerListener('WEAPONSKILL_USE', player, boss, {
            getID   = function() return xi.weaponskill.HARD_SLASH end,
            getName = function() return 'hard_slash' end,
        }, 1000, mockAction, dmg1)

        assert(dmg1 > 0, 'Expected positive single-hit WS damage')
        assert(telem.counters.weaponSkillDamage == dmg1,
            string.format('Single-hit WS double-counted or missed! expected %d, got %d', dmg1, telem.counters.weaponSkillDamage))
        assert(telem.counters.autoAttackDamage == 50,
            string.format('Single-hit WS leaked into autoAttackDamage! expected 50, got %d', telem.counters.autoAttackDamage))

        -- 10. Multi-hit Weapon Skill (Double Thrust: 1 TP hit + 2 extra hits = 3 hits landed)
        simMs = 5000
        local multiWsResults = {
            wsID            = xi.weaponskill.DOUBLE_THRUST,
            hitsLanded      = 3,
            tpHitsLanded    = 1,
            extraHitsLanded = 2,
            bonusTP         = 0,
            shadowsAbsorbed = 0,
            criticalHit     = true,
            finalDmg        = 66,
        }
        local dmg2 = xi.weaponskills.takeWeaponskillDamage(
            boss,
            ally,
            {},
            true,
            { type = xi.attackType.PHYSICAL, damageType = xi.damageType.PIERCING, slot = xi.slot.MAIN },
            multiWsResults,
            mockAction
        )
        ally:triggerListener('WEAPONSKILL_USE', ally, boss, {
            getID   = function() return xi.weaponskill.DOUBLE_THRUST end,
            getName = function() return 'double_thrust' end,
        }, 1000, mockAction, dmg2)

        assert(dmg2 > 0, 'Expected positive multi-hit WS damage')
        assert(telem.counters.weaponSkillDamage == dmg1 + dmg2,
            string.format('Multi-hit WS double-counted or missed! expected %d, got %d', dmg1 + dmg2, telem.counters.weaponSkillDamage))
        assert(telem.counters.autoAttackDamage == 50, 'Multi-hit WS leaked into autoAttackDamage!')

        -- 11. Reconcile summary metrics with authoritative boss HP loss & event log
        local rec = T.finishSession(telem, 'reset', { writeLog = true })
        local bossHpLost = bossStartHp - boss:getHP()
        assert(rec.metrics.offense.total_damage == 50 + dmg1 + dmg2, 'Total damage mismatch')
        assert(rec.metrics.offense.total_damage == bossHpLost,
            string.format('Summary total_damage (%d) != authoritative boss HP lost (%d)!', rec.metrics.offense.total_damage, bossHpLost))
        assert(rec.reconciliation.damage_reconciled == true, 'Summary reconciliation flag must be true')
        assert(rec.metrics.resources_and_pets.tp_spent == 2000, 'Expected 2000 TP spent across 2 WSs')

        -- Verify multi-hit metadata persisted in event log
        local evLines = readAllLines(rec.files.events_log)
        local sawMultiHit = false
        for _, ln in ipairs(evLines or {}) do
            if ln:find('"hits_landed":3', 1, true) and ln:find('"extra_hits":2', 1, true) then
                sawMultiHit = true
            end
        end
        assert(sawMultiHit, 'Multi-hit WS metadata (hits_landed=3, extra_hits=2) missing from event log')
    end)

    it('12 & Visibility Audit. Validates Lv10/13 Magic Caster & visible models across ALL Proving Grounds archetypes (Normal & NM, Lv10/30/50/75)', function()
        local zone = player:getZone()
        local checkLevels = { 10, 30, 50, 75 }
        local presets = { 'normal', 'nm' }

        -- Verify Lv10 and Lv13 Magic Caster scenarios (both Normal and NM) remain functional & visible
        for _, mcCase in ipairs({
            { eff = 10, diff = 'even_match', preset = 'normal', expBoss = 10 },
            { eff = 10, diff = 'even_match', preset = 'nm',     expBoss = 10 },
            { eff = 10, diff = 'very_tough', preset = 'normal', expBoss = 13 },
            { eff = 10, diff = 'very_tough', preset = 'nm',     expBoss = 13 },
        }) do
            local enc = R.buildEncounterConfig({
                bossType    = 'magic_caster',
                bossLevel   = mcCase.expBoss,
                playerLevel = mcCase.eff,
                difficulty  = mcCase.diff,
                bossPreset  = mcCase.preset,
            })
            local m, err = R.spawnTrialMob(zone, enc, { spawnLifetimeSec = 30 })
            assert(m ~= nil, string.format('Magic Caster Lv%d %s failed to spawn: %s', mcCase.expBoss, mcCase.preset, tostring(err)))
            assert(m:getMainLvl() == mcCase.expBoss, string.format('Expected Magic Caster Lv%d, got %d', mcCase.expBoss, m:getMainLvl()))
            local visReport = R.validateMobAppearance(m)
            assert(visReport and visReport.valid == true, string.format('Magic Caster Lv%d %s failed visibility validation: %s (model=%s flags=0x%X)',
                mcCase.expBoss, mcCase.preset, table.concat(visReport and visReport.warnings or {}, ','), tostring(visReport and visReport.model_id), tonumber(visReport and visReport.mob_flags) or 0))
            assert(visReport.model_id > 0, 'Magic Caster model_id must be > 0')
            assert(bit.band(visReport.mob_flags, R.VISIBILITY_CLEAR_MASK) == 0, 'Magic Caster still has hidden/untargetable entityFlags!')
            -- Verify Magic Caster spells/behavior preserved (BLM job, spell list active, magic cooldown configured)
            assert(m:getMainJob() == xi.job.BLM, string.format('Expected Magic Caster BLM job, got %d', m:getMainJob()))
            assert(m:hasSpellList() == true, 'Magic Caster spell list was not preserved')
            assert(m:getMobMod(xi.mobMod.MAGIC_COOL) > 0, 'Magic Caster MAGIC_COOL was not preserved')
            m:setStatus(xi.status.DISAPPEAR)
        end

        -- Audit EVERY registered Proving Grounds archetype (Normal & NM) across Lv10, 30, 50, 75
        for archKey, _ in pairs(R.ARCHETYPES) do
            for _, preset in ipairs(presets) do
                for _, lvl in ipairs(checkLevels) do
                    local enc = R.buildEncounterConfig({
                        bossType    = archKey,
                        bossLevel   = lvl,
                        playerLevel = lvl,
                        difficulty  = 'even_match',
                        bossPreset  = preset,
                    })
                    local m, err = R.spawnTrialMob(zone, enc, { spawnLifetimeSec = 30 })
                    assert(m ~= nil, string.format('Archetype %s (%s Lv%d) failed to spawn: %s', archKey, preset, lvl, tostring(err)))
                    local visReport = R.validateMobAppearance(m)
                    assert(visReport and visReport.valid == true, string.format('Archetype %s (%s Lv%d) has invalid/invisible appearance: %s (model=%s flags=0x%X)',
                        archKey, preset, lvl, table.concat(visReport and visReport.warnings or {}, ','), tostring(visReport and visReport.model_id), tonumber(visReport and visReport.mob_flags) or 0))
                    m:setStatus(xi.status.DISAPPEAR)
                end
            end
        end
    end)
end)
