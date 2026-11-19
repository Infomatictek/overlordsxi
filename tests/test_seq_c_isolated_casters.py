"""Sequence C unit and cross-Soul negative tests for isolated casters:
Zealot (WHM 2), Astromancer (BLM 1), and Scarlet Weaver (RDM 3).

Includes cross-Soul negative tests for Bishop, Sage, Necromancer, Spellblade,
Crimson Duelist, and existing melee, plus non-destructive additive registration checks.
"""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

REPO_ROOT = Path(__file__).resolve().parents[1]
INIT_APPEND = REPO_ROOT / 'modules' / 'init.append.txt'
WHM_ZEALOT = REPO_ROOT / 'modules' / 'custom' / 'lua' / 'whm_zealot.lua'
BLM_ASTROMANCER = REPO_ROOT / 'modules' / 'custom' / 'lua' / 'blm_astromancer.lua'
RDM_SCARLET_WEAVER = REPO_ROOT / 'modules' / 'custom' / 'lua' / 'rdm_scarlet_weaver.lua'


def build_caster_harness(repo_root: Path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    escaped = str(repo_root).replace('\\', '/')
    lua.execute(f"""
        package.path = '{escaped}/?.lua;' .. package.path
        _TEST_NOW = 2000
        function getMonotonicSeconds() return _TEST_NOW end

        package.loaded['modules/module_utils'] = true
        package.loaded['scripts/globals/player'] = true

        Module = {{}}
        function Module:new(name)
            return {{
                name = name,
                overrides = {{}},
                addOverride = function(self, target, fn) self.overrides[target] = fn end,
            }}
        end

        xi = {{
            job = {{
                WAR = 1, MNK = 2, WHM = 3, BLM = 4, RDM = 5, THF = 6,
                PLD = 7, DRK = 8, BST = 9, BRD = 10, RNG = 11, SAM = 12,
                NIN = 13, DRG = 14, SMN = 15, BLU = 16, COR = 17, PUP = 18,
                DNC = 19, SCH = 20, GEO = 21, RUN = 22,
            }},
            slot = {{ MAIN = 0, SUB = 1 }},
            skill = {{ SWORD = 3, STAFF = 12, CLUB = 11, GREAT_SWORD = 4 }},
            magic = {{
                spell = {{
                    HOLY = 21, BANISH = 28, BANISH_II = 29, BANISH_III = 30,
                    FIRE = 144, BLIZZARD = 149, AERO = 154, STONE = 159, THUNDER = 164, WATER = 169,
                    FLARE = 204, FREEZE = 206, TORNADO = 208, QUAKE = 210, BURST = 212, FLOOD = 214,
                }},
            }},
            jobAbility = {{ DIVINE_SEAL = 74 }},
            mod = {{ STAFF = 1, ACC = 2, MND = 3, MATT = 4, MACC = 5, INT = 6, MPP = 7, SWORD = 8, DEX = 9 }},
            player = {{ onGameIn = function() end }},
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
                _weapon = opts.weapon or xi.skill.STAFF,
                _mp = opts.mp or 0,
                _maxMP = opts.maxMP or 400,
                _engaged = opts.engaged == true,
                _vars = {{}},
                _charVars = {{}},
                _listeners = {{}},
            }}
            function e:getID() return self._id end
            function e:isPC() return self._isPC end
            function e:isMob() return self._isMob end
            function e:isAlive() return self._alive end
            function e:getMainJob() return self._job end
            function e:getMainLvl() return self._lvl end
            function e:getZoneID() return self._zone end
            function e:getWeaponSkillType() return self._weapon end
            function e:getMaxMP() return self._maxMP end
            function e:addMP(v) self._mp = self._mp + v end
            function e:getMP() return self._mp end
            function e:isEngaged() return self._engaged end
            function e:getLocalVar(k) return self._vars[k] or 0 end
            function e:setLocalVar(k, v) self._vars[k] = v end
            function e:getCharVar(k) return self._charVars[k] or 0 end
            function e:setCharVar(k, v) self._charVars[k] = v end
            function e:addListener(ev, id, fn)
                self._listeners[ev] = self._listeners[ev] or {{}}
                self._listeners[ev][id] = fn
            end
            function e:removeListener(id)
                for _, map in pairs(self._listeners) do map[id] = nil end
            end
            return e
        end
    """)
    return lua


class SequenceCLoaderOrderTests(unittest.TestCase):
    def test_isolated_casters_load_after_existing_job_modules(self):
        lines = [line.strip() for line in INIT_APPEND.read_text(encoding='utf-8').splitlines()]
        self.assertGreater(lines.index('custom/lua/whm_zealot.lua'), lines.index('custom/lua/whm_specs.lua'))
        self.assertGreater(lines.index('custom/lua/blm_astromancer.lua'), lines.index('custom/lua/blm_specs.lua'))
        self.assertGreater(lines.index('custom/lua/rdm_scarlet_weaver.lua'), lines.index('custom/lua/rdm_specs.lua'))


@unittest.skipIf(LuaRuntime is None, 'lupa not installed')
class SequenceCLuaBehaviorTests(unittest.TestCase):
    def test_additive_registration_preserves_bishop_necromancer_crimsonduelist(self):
        lua = build_caster_harness(REPO_ROOT)
        lua.execute(f"""
            local spec = xi.overlords.spec
            spec.registerCrystal(xi.job.WHM, {{ id = 1, key = 'bishop', name = 'Bishop', role = 'Healer' }})
            spec.registerJob(xi.job.BLM, 'BLM', {{ {{ id = 3, key = 'necromancer', name = 'Necromancer', role = 'Tank' }} }})
            spec.registerJob(xi.job.RDM, 'RDM', {{ {{ id = 1, key = 'crimsonduelist', name = 'Crimson Duelist', role = 'Tank' }} }})

            dofile('{str(WHM_ZEALOT).replace(chr(92), '/')}')
            dofile('{str(BLM_ASTROMANCER).replace(chr(92), '/')}')
            dofile('{str(RDM_SCARLET_WEAVER).replace(chr(92), '/')}')

            assert(spec.resolve(xi.job.WHM, 'bishop') ~= nil and spec.resolve(xi.job.WHM, 'zealot') ~= nil)
            assert(spec.resolve(xi.job.BLM, 'necromancer') ~= nil and spec.resolve(xi.job.BLM, 'astromancer') ~= nil)
            assert(spec.resolve(xi.job.RDM, 'crimsonduelist') ~= nil and spec.resolve(xi.job.RDM, 'scarletweaver') ~= nil)
        """)

    def test_zealot_staff_communion_divine_seal_and_bishop_negative(self):
        lua = build_caster_harness(REPO_ROOT)
        lua.execute(f"""
            local spec = xi.overlords.spec
            spec.registerCrystal(xi.job.WHM, {{ id = 1, key = 'bishop', name = 'Bishop', role = 'Healer' }})
            dofile('{str(WHM_ZEALOT).replace(chr(92), '/')}')
        """)
        lua.execute("""
            local z = xi.overlords.zealot
            local mob = makeEntity({ id = 100, isMob = true, alive = true })

            local zealot = makeEntity({ id = 1, isPC = true, job = xi.job.WHM, lvl = 10, weapon = xi.skill.STAFF, maxMP = 200 })
            zealot:setCharVar('OX_SPEC_WHM', 2)

            -- Cross-Soul negative: Bishop (WHM 1) & existing melee WAR get 0 Staff Communion and 0 Zealot scaling
            local bishop = makeEntity({ id = 2, isPC = true, job = xi.job.WHM, lvl = 75, weapon = xi.skill.STAFF, maxMP = 800 })
            bishop:setCharVar('OX_SPEC_WHM', 1)
            assert(z.onStaffMeleeHit(bishop, mob, 50, {}) == 0)
            assert(z.resolveDivineDamage(bishop, mob, xi.magic.spell.BANISH, 100, true) == 100)

            -- Zealot Lv10: first landed regular main-hand staff hit restores floor(200 * 0.035) = 7 MP
            assert(z.onStaffMeleeHit(zealot, mob, 45, {}) == 7)
            -- Multiattack second hit in same round (within 2.5s lock) restores 0
            assert(z.onStaffMeleeHit(zealot, mob, 45, {}) == 0)

            -- Advance past 2.5s: WS, counter, offhand, additional effect, and 0 damage all restore 0
            _TEST_NOW = _TEST_NOW + 3
            assert(z.onStaffMeleeHit(zealot, mob, 150, { isWeaponSkill = true }) == 0)
            assert(z.onStaffMeleeHit(zealot, mob, 50, { isCounter = true }) == 0)
            assert(z.onStaffMeleeHit(zealot, mob, 50, { isOffhand = true }) == 0)
            assert(z.onStaffMeleeHit(zealot, mob, 50, { isAdditionalEffect = true }) == 0)
            assert(z.onStaffMeleeHit(zealot, mob, 0, {}) == 0)

            -- Lv70 Staff Communion restores floor(400 * 0.045) = 18 MP
            zealot._lvl = 70
            zealot._maxMP = 400
            assert(z.onStaffMeleeHit(zealot, mob, 80, {}) == 18)

            -- Divine Seal: survives cancellation, consumed on completed damaging Holy (Lv70 2.0x * 1.2 = 240)
            assert(z.activateDivineSeal(zealot) == true)
            local cancelDmg, cancelUsed = z.resolveDivineDamage(zealot, mob, xi.magic.spell.HOLY, 100, false)
            assert(cancelDmg == 0 and cancelUsed == false)
            local finalDmg, sealUsed = z.resolveDivineDamage(zealot, mob, xi.magic.spell.HOLY, 100, true)
            assert(finalDmg == 240 and sealUsed == true)
            -- Subsequent Holy without seal uses 2.0x only
            local nextDmg, nextUsed = z.resolveDivineDamage(zealot, mob, xi.magic.spell.HOLY, 100, true)
            assert(nextDmg == 200 and nextUsed == false)
        """)

    def test_astromancer_same_tick_saturation_boss_cap_respawn_and_cross_soul_negative(self):
        lua = build_caster_harness(REPO_ROOT)
        lua.execute(f"""
            local spec = xi.overlords.spec
            spec.registerCrystal(xi.job.SCH, {{ id = 2, key = 'sage', name = 'Sage', role = 'Damage' }})
            spec.registerCrystal(xi.job.RUN, {{ id = 1, key = 'spellblade', name = 'Spellblade', role = 'Damage' }})
            dofile('{str(BLM_ASTROMANCER).replace(chr(92), '/')}')
        """)
        lua.execute("""
            local ast = xi.overlords.astromancer
            local actions = require('modules/custom/lua/overlords_soul_actions')
            -- Verified Water->Tsunami uses Flood (214), never demo ID 1
            assert(actions.presentation('astromancer', 'spell', 214).name == 'Tsunami')
            assert(actions.presentation('astromancer', 'spell', 1) == nil)

            local a1 = makeEntity({ id = 10, isPC = true, job = xi.job.BLM, lvl = 75, zone = 100 })
            local a2 = makeEntity({ id = 11, isPC = true, job = xi.job.BLM, lvl = 75, zone = 100 })
            a1:setCharVar('OX_SPEC_BLM', 1)
            a2:setCharVar('OX_SPEC_BLM', 1)
            local boss1 = makeEntity({ id = 500, isMob = true, alive = true, zone = 100 })
            local boss2 = makeEntity({ id = 501, isMob = true, alive = true, zone = 100 })

            -- Probe default is earth; completing Water sets Invocation element to water
            assert(ast.getInvocationElement(a1) == 'earth')
            ast.recordProbeElement(a1, xi.magic.spell.WATER, true)
            assert(ast.getInvocationElement(a1) == 'water')

            -- Elemental Survey returns all tied minimum elements
            local sv = ast.surveyTarget(a1, boss1, { fire = 10, ice = -20, wind = 0, earth = -20, lightning = 5, water = 15 })
            assert(#sv.elements == 2 and sv.elements[1] == 'ice' and sv.elements[2] == 'earth')

            -- Same-tick resolution on boss1 (Lv75, 2.5x -> base 1000, rawBonus 1500, boss 3% of 40000 = 1200 cap)
            local d1, info1 = ast.resolveAncientImpact(a1, boss1, 1000, { completed = true, isBoss = true, encounterStartMaxHP = 40000, spawnGen = 1 })
            assert(d1 == 2200 and info1.saturated == false and info1.clampedBonus == 1200)
            local d2, info2 = ast.resolveAncientImpact(a2, boss1, 1000, { completed = true, isBoss = true, encounterStartMaxHP = 40000, spawnGen = 1 })
            assert(d2 == 1120 and info2.saturated == true) -- 1000 + floor(1200 * 0.10)

            -- Separate boss2 is unsaturated (advance a2 past 18s personal recovery)
            _TEST_NOW = _TEST_NOW + 19
            local d3, info3 = ast.resolveAncientImpact(a2, boss2, 1000, { completed = true, isBoss = false, spawnGen = 1 })
            assert(d3 == 2500 and info3.saturated == false)

            -- Respawn (new spawnGen = 2 on same mob ID 500) starts unsaturated
            _TEST_NOW = _TEST_NOW + 1
            local d4, info4 = ast.resolveAncientImpact(a1, boss1, 1000, { completed = true, isBoss = false, spawnGen = 2 })
            assert(d4 == 2500 and info4.saturated == false)

            -- Full resist (0 damage) starts personal recovery without claiming saturation
            _TEST_NOW = _TEST_NOW + 25
            local dZero, infoZero = ast.resolveAncientImpact(a1, boss1, 0, { completed = true, spawnGen = 3 })
            assert(dZero == 0 and infoZero.fullResist == true)
            assert(ast.isTargetSaturated(boss1, 3) == false)

            -- Cross-Soul negative: Sage and Spellblade pass through untouched
            local sage = makeEntity({ id = 20, isPC = true, job = xi.job.SCH, lvl = 75 })
            sage:setCharVar('OX_SPEC_SCH', 2)
            local spellblade = makeEntity({ id = 21, isPC = true, job = xi.job.RUN, lvl = 75 })
            spellblade:setCharVar('OX_SPEC_RUN', 1)
            local sd, sinfo = ast.resolveAncientImpact(sage, boss1, 500, { completed = true, spawnGen = 3 })
            assert(sd == 500 and sinfo.affected == false)
            local rbd, rbinfo = ast.resolveAncientImpact(spellblade, boss1, 500, { completed = true, spawnGen = 3 })
            assert(rbd == 500 and rbinfo.affected == false)
        """)

    def test_scarlet_weaver_yin_yang_isolation_and_cross_soul_negative(self):
        lua = build_caster_harness(REPO_ROOT)
        lua.execute(f"""
            local spec = xi.overlords.spec
            spec.registerJob(xi.job.RDM, 'RDM', {{ {{ id = 1, key = 'crimsonduelist', name = 'Crimson Duelist', role = 'Tank' }} }})
            spec.registerCrystal(xi.job.RUN, {{ id = 1, key = 'spellblade', name = 'Spellblade', role = 'Damage' }})
            dofile('{str(RDM_SCARLET_WEAVER).replace(chr(92), '/')}')
        """)
        lua.execute("""
            local sw = xi.overlords.scarletWeaver
            local entry = assert(xi.overlords.spec.resolve(xi.job.RDM, 'scarletweaver'))

            local rdm = makeEntity({ id = 30, isPC = true, job = xi.job.RDM, lvl = 10, weapon = xi.skill.SWORD })
            rdm:setCharVar('OX_SPEC_RDM', 3)
            entry.onApply(rdm)

            -- Defaults to Yang at Lv10 (+15% main-hand sword melee, 0% elemental spell)
            assert(sw.getAspect(rdm) == 'yang')
            assert(sw.applyYangMeleeDamage(rdm, 100, {}) == 115)
            assert(sw.applyYinSpellDamage(rdm, xi.magic.spell.FIRE, 100, {}) == 100)
            -- Enspell, WS, skillchain, additional attack, offhand receive neither multiplier
            assert(sw.applyYangMeleeDamage(rdm, 100, { isEnspell = true }) == 100)
            assert(sw.applyYangMeleeDamage(rdm, 100, { isWeaponSkill = true }) == 100)
            assert(sw.applyYangMeleeDamage(rdm, 100, { isSkillchain = true }) == 100)
            assert(sw.applyYangMeleeDamage(rdm, 100, { isAdditionalAttack = true }) == 100)
            assert(sw.applyYangMeleeDamage(rdm, 100, { isOffhand = true }) == 100)

            -- Free switch out of combat; same-aspect switch is a no-op
            local ok, reason = sw.setAspect(rdm, 'yang', { inCombat = false })
            assert(ok == true and reason == 'noop')
            ok, reason = sw.setAspect(rdm, 'yin', { inCombat = false })
            assert(ok == true and reason == 'switched' and sw.getAspect(rdm) == 'yin')

            -- In Yin at Lv75 (+25% eligible elemental spell, 0% sword melee)
            rdm._lvl = 75
            assert(sw.applyYinSpellDamage(rdm, xi.magic.spell.FIRE, 200, {}) == 250)
            assert(sw.applyYinSpellDamage(rdm, xi.magic.spell.FIRE, 200, { isEnspell = true }) == 200)
            assert(sw.applyYangMeleeDamage(rdm, 200, {}) == 200)

            -- Disallowed during cast/JA lock
            ok, reason = sw.setAspect(rdm, 'yang', { inCombat = true, inActionLock = true })
            assert(ok == false and reason == 'action_locked')

            -- In combat switch enforces 12s shared recast
            ok, reason = sw.setAspect(rdm, 'yang', { inCombat = true })
            assert(ok == true and reason == 'switched')
            ok, reason = sw.setAspect(rdm, 'yin', { inCombat = true })
            assert(ok == false and reason == 'on_recast')

            -- Cross-Soul negative: Crimson Duelist, Spellblade, and WAR melee never receive Yin/Yang
            local duelist = makeEntity({ id = 31, isPC = true, job = xi.job.RDM, lvl = 75, weapon = xi.skill.SWORD })
            duelist:setCharVar('OX_SPEC_RDM', 1)
            assert(sw.setAspect(duelist, 'yang', {}) == false)
            assert(sw.applyYangMeleeDamage(duelist, 200, {}) == 200)
            assert(sw.applyYinSpellDamage(duelist, xi.magic.spell.FIRE, 200, {}) == 200)

            local spellblade = makeEntity({ id = 32, isPC = true, job = xi.job.RUN, lvl = 75, weapon = xi.skill.GREAT_SWORD })
            spellblade:setCharVar('OX_SPEC_RUN', 1)
            assert(sw.applyYinSpellDamage(spellblade, xi.magic.spell.FIRE, 200, {}) == 200)

            -- Cleanup clears only Scarlet Weaver's state
            entry.onRemove(rdm)
            assert(sw.getAspect(rdm) == nil)
        """)


if __name__ == '__main__':
    unittest.main()
