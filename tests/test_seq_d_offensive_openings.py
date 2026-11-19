"""Sequence D unit and regression tests for offensive openings:
Oathbreaker (PLD 3), Reaper (DRK 1), Sniper (RNG 1), Lancer (DRG 1),
Warmage (BLU 1), Primalist (SMN 1), and Terramancer (GEO 3).
"""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

REPO_ROOT = Path(__file__).resolve().parents[1]
INIT_APPEND = REPO_ROOT / 'modules' / 'init.append.txt'
LUA_DIR = REPO_ROOT / 'modules' / 'custom' / 'lua'

SEQ_D_MODULES = [
    'pld_oathbreaker.lua',
    'drk_reaper.lua',
    'rng_sniper.lua',
    'drg_lancer.lua',
    'blu_warmage.lua',
    'smn_primalist.lua',
    'geo_terramancer.lua',
]


def build_seq_d_harness(repo_root: Path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    escaped = str(repo_root).replace('\\', '/')
    lua.execute(f"""
        package.path = '{escaped}/?.lua;' .. package.path
        _TEST_NOW = 3000
        function getMonotonicSeconds() return _TEST_NOW end

        package.loaded['modules/module_utils'] = true
        package.loaded['scripts/globals/player'] = true

        Module = {{}}
        function Module:new(name)
            return {{ name = name, overrides = {{}}, addOverride = function(self, t, fn) self.overrides[t] = fn end }}
        end

        xi = {{
            job = {{
                WAR = 1, MNK = 2, WHM = 3, BLM = 4, RDM = 5, THF = 6,
                PLD = 7, DRK = 8, BST = 9, BRD = 10, RNG = 11, SAM = 12,
                NIN = 13, DRG = 14, SMN = 15, BLU = 16, COR = 17, PUP = 18,
                DNC = 19, SCH = 20, GEO = 21, RUN = 22,
            }},
            slot = {{ MAIN = 0, SUB = 1 }},
            skill = {{ SWORD = 3, GREAT_SWORD = 4, SCYTHE = 7, POLEARM = 8, MARKSMANSHIP = 26, STAFF = 12 }},
            mod = {{
                GREAT_SWORD = 1, STR = 2, ACC = 3, ATT = 4, SCYTHE = 5, MARKSMANSHIP = 6,
                RACC = 7, RATT = 8, AGI = 9, POLEARM = 10, MACC = 11, MATT = 12, INT = 13,
                SUMMONING_MAGIC_SKILL = 14, MPP = 15,
            }},
        }}

        require('modules/custom/lua/overlords_job_specs')

        function makeEntity(opts)
            opts = opts or {{}}
            local e = {{
                _id = opts.id or 1,
                _isPC = opts.isPC == true,
                _isMob = opts.isMob == true,
                _alive = opts.alive ~= false,
                _job = opts.job or 1,
                _lvl = opts.lvl or 75,
                _zone = opts.zone or 100,
                _weapon = opts.weapon or xi.skill.GREAT_SWORD,
                _maxHP = opts.maxHP or 1000,
                _maxMP = opts.maxMP or 400,
                _hpp = opts.hpp or 100,
                _dist = opts.dist or 3,
                _engaged = opts.engaged == true,
                _vars = {{}},
                _charVars = {{}},
            }}
            function e:getID() return self._id end
            function e:isPC() return self._isPC end
            function e:isMob() return self._isMob end
            function e:isAlive() return self._alive end
            function e:getMainJob() return self._job end
            function e:getMainLvl() return self._lvl end
            function e:getZoneID() return self._zone end
            function e:getWeaponSkillType() return self._weapon end
            function e:getMaxHP() return self._maxHP end
            function e:getMaxMP() return self._maxMP end
            function e:getHPP() return self._hpp end
            function e:checkDistance() return self._dist end
            function e:isEngaged() return self._engaged end
            function e:getLocalVar(k) return self._vars[k] or 0 end
            function e:setLocalVar(k, v) self._vars[k] = v end
            function e:getCharVar(k) return self._charVars[k] or 0 end
            function e:setCharVar(k, v) self._charVars[k] = v end
            return e
        end
    """)
    for mod_name in SEQ_D_MODULES:
        lua.execute(f"dofile('{str(LUA_DIR / mod_name).replace(chr(92), '/')}')")
    return lua


class SequenceDLoaderOrderTests(unittest.TestCase):
    def test_all_7_modules_registered_after_existing_job_specs(self):
        lines = [line.strip() for line in INIT_APPEND.read_text(encoding='utf-8').splitlines()]
        idx_hud = lines.index('custom/lua/overlords_soul_hud.lua')
        for mod_name in SEQ_D_MODULES:
            self.assertGreater(lines.index(f'custom/lua/{mod_name}'), idx_hud)


@unittest.skipIf(LuaRuntime is None, 'lupa not installed')
class SequenceDLuaBehaviorTests(unittest.TestCase):
    def test_oathbreaker_vows_retaliation_and_reckoning(self):
        lua = build_seq_d_harness(REPO_ROOT)
        lua.execute("""
            local otb = xi.overlords.oathbreaker
            local p = makeEntity({ id = 1, isPC = true, job = xi.job.PLD, lvl = 10, weapon = xi.skill.GREAT_SWORD, maxHP = 500 })
            p:setCharVar('OX_SPEC_PLD', 3)
            local mob = makeEntity({ id = 100, isMob = true, alive = true })

            -- Swear Condemn out of combat: +10% GS melee, Flash disabled
            assert(otb.swearVow(p, 'condemn', { engaged = false }) == true)
            assert(otb.isFlashAllowed(p) == false)
            assert(otb.applyCondemnMelee(p, 100, {}) == 110)

            -- Cannot swap while on hate list or engaged
            assert(otb.swearVow(p, 'absolve', { onHateList = true }) == false)

            -- Switch to Absolve out of combat after 5s
            _TEST_NOW = _TEST_NOW + 6
            assert(otb.swearVow(p, 'absolve', { engaged = false }) == true)
            assert(otb.isFlashAllowed(p) == true)
            assert(otb.getAbsolveDtPercent(p) == 8)

            -- Sub-threshold hit (<8% of 500 = 40) does NOT arm retaliation
            assert(otb.onPlayerDamaged(p, mob, 30) == false)
            -- Qualifying hit (>=40) arms retaliation -> Reckoning doubled (1.5 * 2 = 3.0x = 300)
            assert(otb.onPlayerDamaged(p, mob, 50) == true)
            local dmg, info = otb.executeReckoning(p, mob, 100)
            assert(dmg == 300 and info.empowered == true)

            -- Cleanup resets vow
            otb.clearState(p)
            assert(otb.getVow(p) == nil)
        """)

    def test_reaper_recovery_six_rounds_miss_and_execute(self):
        lua = build_seq_d_harness(REPO_ROOT)
        lua.execute("""
            local rpr = xi.overlords.reaper
            local p = makeEntity({ id = 2, isPC = true, job = xi.job.DRK, lvl = 70, weapon = xi.skill.SCYTHE })
            p:setCharVar('OX_SPEC_DRK', 1)
            local mob = makeEntity({ id = 101, isMob = true, alive = true, hpp = 20 })

            -- Periodic ticks / player actions never open recovery
            assert(rpr.onEnemyActionComplete(mob, { isPeriodicTick = true }) == false)
            assert(rpr.isInRecovery(mob) == false)

            -- 6 ordinary attack rounds open recovery
            for i = 1, 5 do
                assert(rpr.onEnemyActionComplete(mob, { isRegularAttackRound = true, roundSeq = i }) == false)
            end
            assert(rpr.onEnemyActionComplete(mob, { isRegularAttackRound = true, roundSeq = 6 }) == true)

            -- Missed Finality starts 16s CD without consuming recovery window
            local mdmg, minfo = rpr.executeFinality(p, mob, 100, { missed = true })
            assert(mdmg == 0 and minfo.missed == true and rpr.isInRecovery(mob) == true)

            -- Advance past 16s CD, open via damaging TP move, strike below 25% HP at Lv70: 3.0 * 1.20 = 3.6x = 360
            _TEST_NOW = _TEST_NOW + 20
            assert(rpr.onEnemyActionComplete(mob, { isDamagingSpellOrTpMove = true, actionSeq = 99 }) == true)
            local dmg, info = rpr.executeFinality(p, mob, 100, { targetHPP = 20 })
            assert(dmg == 360 and info.usedRecovery == true and rpr.isInRecovery(mob) == false)
        """)

    def test_sniper_movement_cancel_miss_and_full_aim(self):
        lua = build_seq_d_harness(REPO_ROOT)
        lua.execute("""
            local snp = xi.overlords.sniper
            local p = makeEntity({ id = 3, isPC = true, job = xi.job.RNG, lvl = 75, dist = 15 })
            p:setCharVar('OX_SPEC_RNG', 1)
            local mob = makeEntity({ id = 102, isMob = true, alive = true })

            -- Moving >1y cancels aim with 0 ammo spent and 3s retry
            assert(snp.startSightlineAim(p, mob, { x = 0, z = 0 }) == true)
            _TEST_NOW = _TEST_NOW + 3
            local dCancel, iCancel = snp.resolveSightlineShot(p, mob, 100, { x = 2.0, z = 0 })
            assert(dCancel == 0 and iCancel.cancelled == true and iCancel.ammoSpent == 0)

            -- After 3s retry, 4s full aim at Lv75 deals 3.2x with 1 ammo, +30 RACC
            _TEST_NOW = _TEST_NOW + 3
            assert(snp.startSightlineAim(p, mob, { x = 0, z = 0 }) == true)
            _TEST_NOW = _TEST_NOW + 4
            local dmg, info = snp.resolveSightlineShot(p, mob, 100, { x = 0.5, z = 0 })
            assert(dmg == 320 and info.ammoSpent == 1 and info.raccBonus == 30)
        """)

    def test_lancer_launch_range_blocked_terrain_and_jump_followup(self):
        lua = build_seq_d_harness(REPO_ROOT)
        lua.execute("""
            local lnc = xi.overlords.lancer
            local p = makeEntity({ id = 4, isPC = true, job = xi.job.DRG, lvl = 70, weapon = xi.skill.POLEARM })
            p:setCharVar('OX_SPEC_DRG', 1)
            local mob = makeEntity({ id = 103, isMob = true, alive = true })

            -- Too close (<4y) rejected
            local dShort, errShort = lnc.executeVault(p, mob, 100, { distance = 2.5 })
            assert(dShort == nil and errShort == 'invalid_launch_range')

            -- Blocked terrain cancels displacement & damage with 3s retry
            local dBlock, iBlock = lnc.executeVault(p, mob, 100, { distance = 10, pathBlocked = true })
            assert(dBlock == 0 and iBlock.cancelled == true and iBlock.displaced == false)

            -- Long lane (>7-12y) at Lv70: 2.8x = 280 + arms +20% Jump follow-up once within 5s
            _TEST_NOW = _TEST_NOW + 3
            local dmg, info = lnc.executeVault(p, mob, 100, { distance = 10 })
            assert(dmg == 280 and info.longLane == true)
            local jDmg, used = lnc.consumeJumpFollowup(p, 200)
            assert(jDmg == 240 and used == true)
            local jDmg2, used2 = lnc.consumeJumpFollowup(p, 200)
            assert(jDmg2 == 200 and used2 == false)
        """)

    def test_warmage_assess_prey_ties_starter_pair_and_single_target_policy(self):
        lua = build_seq_d_harness(REPO_ROOT)
        lua.execute("""
            local wmg = xi.overlords.warmage
            local p = makeEntity({ id = 5, isPC = true, job = xi.job.BLU, lvl = 10 })
            p:setCharVar('OX_SPEC_BLU', 1)
            local mob = makeEntity({ id = 104, isMob = true, alive = true })

            -- Equal minimum resistance for blunt & piercing: both qualify (+12% at Lv10)
            local rec = assert(wmg.assessPrey(p, mob, { blunt = -10, piercing = -10, slashing = 0, element = 10 }))
            assert(rec.categories.blunt == true and rec.categories.piercing == true)

            local dBlunt, iBlunt = wmg.resolveBlueSpell(p, mob, 'sprout_smack', 100, {})
            local dPierce, iPierce = wmg.resolveBlueSpell(p, mob, 'power_attack', 100, {})
            local dSlash, iSlash = wmg.resolveBlueSpell(p, mob, 'foot_kick', 100, {})
            assert(dBlunt == 112 and iBlunt.matched == true)
            assert(dPierce == 112 and iPierce.matched == true)
            assert(dSlash == 100 and iSlash.matched == false)
            -- Sword/WS never receive Warmage bonus
            local dWs, iWs = wmg.resolveBlueSpell(p, mob, 'sprout_smack', 100, { isWeaponSkill = true })
            assert(dWs == 100 and iWs.matched == false)
        """)

    def test_primalist_challenge_aspect_swap_clear_and_resist_check(self):
        lua = build_seq_d_harness(REPO_ROOT)
        lua.execute("""
            local prm = xi.overlords.primalist
            local p = makeEntity({ id = 6, isPC = true, job = xi.job.SMN, lvl = 75 })
            p:setCharVar('OX_SPEC_SMN', 1)
            local mob = makeEntity({ id = 105, isMob = true, alive = true })

            assert(#prm.getAvailableAvatars(10) == 2)
            assert(#prm.getAvailableAvatars(50) == 7)

            -- Challenge Aspect with Ifrit (fire), then swap avatar -> promise cleared
            assert(prm.challengeAspect(p, 'ifrit', mob) ~= nil)
            prm.onAvatarChanged(p)
            local dAfterSwap, iSwap = prm.resolveAvatarRage(p, 'ifrit', mob, 200, { resistances = { fire = -20 } })
            assert(dAfterSwap == 200 and iSwap.empowered == false)

            -- Re-commit after 20s CD: lowest-resistance fire gains +35% at Lv75 -> 270
            _TEST_NOW = _TEST_NOW + 21
            assert(prm.challengeAspect(p, 'ifrit', mob) ~= nil)
            local dmg, info = prm.resolveAvatarRage(p, 'ifrit', mob, 200, { resistances = { fire = -20, ice = 10 } })
            assert(dmg == 270 and info.empowered == true)
        """)

    def test_terramancer_fixed_position_spectator_isolation_and_deep_fault(self):
        lua = build_seq_d_harness(REPO_ROOT)
        lua.execute("""
            local trm = xi.overlords.terramancer
            local p = makeEntity({ id = 7, isPC = true, job = xi.job.GEO, lvl = 75, dist = 12 })
            p:setCharVar('OX_SPEC_GEO', 3)
            local mobA = makeEntity({ id = 106, isMob = true, alive = true, zone = 100 })
            local mobB = makeEntity({ id = 107, isMob = true, alive = true, zone = 100 })

            -- Place Deep Fault on mobA at (10, 0, 10); reject duplicate placement without cost
            local f = assert(trm.placeFault(p, mobA, 'deep', { x = 10, y = 0, z = 10 }, { spawnGen = 1 }))
            local dup, dupErr = trm.placeFault(p, mobA, 'shallow', { x = 10, y = 0, z = 10 }, { spawnGen = 1 })
            assert(dup == nil and dupErr == 'fault_already_active')

            -- Advance +4s: spectator mobB on marker takes 0; mobA moved >3y away takes 0
            _TEST_NOW = _TEST_NOW + 4
            local dSpec, iSpec = trm.resolveFault(p, mobB, { x = 10, y = 0, z = 10 }, 100, { spawnGen = 1 })
            assert(dSpec == 0 and iSpec.hit == false)

            -- Place new Deep Fault after 8s recast; stationary mobA takes 3.6x at Lv75 = 360
            _TEST_NOW = _TEST_NOW + 5
            assert(trm.placeFault(p, mobA, 'deep', { x = 10, y = 0, z = 10 }, { spawnGen = 1 }) ~= nil)
            _TEST_NOW = _TEST_NOW + 4
            local dmg, info = trm.resolveFault(p, mobA, { x = 12, y = 1, z = 11 }, 100, { spawnGen = 1 })
            assert(dmg == 360 and info.hit == true)
        """)


if __name__ == '__main__':
    unittest.main()
