"""Sequence B unit and regression tests for staged THF (Trickster, Bandit, Phantom)
and BST (Untamed) Souls.

Executes the real Lua modules via `lupa` against a lightweight LandSandBoat mock
environment to verify positive, negative, cleanup, level-sync, cold-start threat,
and non-destructive additive registration contracts.
"""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

REPO_ROOT = Path(__file__).resolve().parents[1]
INIT_APPEND = REPO_ROOT / 'modules' / 'init.append.txt'
THF_SPECS = REPO_ROOT / 'modules' / 'custom' / 'lua' / 'thf_specs.lua'
BST_UNTAMED = REPO_ROOT / 'modules' / 'custom' / 'lua' / 'bst_untamed.lua'


def build_lua_harness(repo_root: Path):
    """Create a LuaRuntime with minimal LandSandBoat globals and real overlords_job_specs."""
    lua = LuaRuntime(unpack_returned_tuples=True)
    escaped = str(repo_root).replace('\\', '/')
    lua.execute(f"""
        package.path = '{escaped}/?.lua;' .. package.path
        _TEST_NOW = 1000
        function getMonotonicSeconds() return _TEST_NOW end

        -- Stub module_utils and player global before requiring custom modules
        package.loaded['modules/module_utils'] = true
        package.loaded['scripts/globals/player'] = true

        Module = {{}}
        function Module:new(name)
            return {{
                name = name,
                overrides = {{}},
                addOverride = function(self, target, fn)
                    self.overrides[target] = fn
                end,
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
            skill = {{
                HAND_TO_HAND = 1, DAGGER = 2, SWORD = 3, GREAT_SWORD = 4,
                AXE = 5, GREAT_AXE = 6, KATANA = 9, MARKSMANSHIP = 26,
            }},
            effect = {{ ATTACK_DOWN = 147, DEFENSE_DOWN = 149 }},
            attackType = {{ PHYSICAL = 1, MAGICAL = 2, RANGED = 3, BREATH = 4 }},
            msg = {{ basic = {{ HIT_MISS = 15, SKILL_MISS = 188, CANNOT_ON_THAT_TARG = 246, TOO_FAR_AWAY = 78 }} }},
            jobAbility = {{
                STEAL = 41, SNEAK_ATTACK = 44, TRICK_ATTACK = 76,
                FIGHT = 69, REWARD = 78, CALL_BEAST = 85, READY = 251, BESTIAL_LOYALTY = 387,
            }},
            mod = {{
                DAGGER = 1, ACC = 2, DEX = 3, SUBTLE_BLOW = 4, ENMITY = 5,
                ATT = 6, CRITHITRATE = 7, STORETP = 8, EVA = 9, AGI = 10,
                HPP = 11, DMG = 12, AXE = 13, GREAT_AXE = 14, DOUBLE_ATTACK = 15,
            }},
            player = {{ onGameIn = function() end }},
            pet = {{ spawnPet = function() end }},
            actions = {{ abilities = {{ steal = {{ onAbilityCheck = function() return 0, 0 end, onUseAbility = function() return 0 end }} }} }},
        }}

        require('modules/custom/lua/overlords_job_specs')

        -- Helper to construct mock PC / Mob / Pet entities
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
                _weapon = opts.weapon or xi.skill.DAGGER,
                _tp = opts.tp or 0,
                _dist = opts.dist or 3,
                _pet = opts.pet,
                _master = opts.master,
                _target = opts.target,
                _hasJug = opts.hasJug ~= false,
                _vars = {{}},
                _charVars = {{}},
                _effects = {{}},
                _listeners = {{}},
                _mods = {{}},
                _enmity = {{}},
            }}
            function e:getID() return self._id end
            function e:isPC() return self._isPC end
            function e:isMob() return self._isMob end
            function e:isAlive() return self._alive end
            function e:getMainJob() return self._job end
            function e:getMainLvl() return self._lvl end
            function e:getZoneID() return self._zone end
            function e:getWeaponSkillType() return self._weapon end
            function e:getLocalVar(k) return self._vars[k] or 0 end
            function e:setLocalVar(k, v) self._vars[k] = v end
            function e:getCharVar(k) return self._charVars[k] or 0 end
            function e:setCharVar(k, v) self._charVars[k] = v end
            function e:addTP(v) self._tp = self._tp + v end
            function e:getTP() return self._tp end
            function e:checkDistance() return self._dist end
            function e:getPet() return self._pet end
            function e:hasJugPet() return self._hasJug end
            function e:getMaster() return self._master end
            function e:getTarget() return self._target end
            function e:hasStatusEffect(id) return self._effects[id] ~= nil end
            function e:addStatusEffect(id, params) self._effects[id] = params end
            function e:addMod(m, v) self._mods[m] = (self._mods[m] or 0) + v end
            function e:delMod(m, v) self._mods[m] = (self._mods[m] or 0) - v end
            function e:addEnmity(actor, ce, ve)
                self._enmity[#self._enmity + 1] = {{ actor = actor, ce = ce, ve = ve }}
            end
            function e:addListener(ev, id, fn)
                self._listeners[ev] = self._listeners[ev] or {{}}
                self._listeners[ev][id] = fn
            end
            function e:removeListener(id)
                for _, map in pairs(self._listeners) do
                    map[id] = nil
                end
            end
            function e:trigger(ev, ...)
                local map = self._listeners[ev] or {{}}
                for _, fn in pairs(map) do
                    fn(...)
                end
            end
            return e
        end
    """)
    return lua


class SequenceBLoaderOrderTests(unittest.TestCase):
    def test_init_append_loads_thf_and_untamed_after_core_and_bst_specs(self):
        lines = [line.strip() for line in INIT_APPEND.read_text(encoding='utf-8').splitlines()]
        idx_job_specs = lines.index('custom/lua/overlords_job_specs.lua')
        idx_bst_specs = lines.index('custom/lua/bst_specs.lua')
        idx_hud = lines.index('custom/lua/overlords_soul_hud.lua')
        idx_thf = lines.index('custom/lua/thf_specs.lua')
        idx_untamed = lines.index('custom/lua/bst_untamed.lua')

        self.assertGreater(idx_thf, idx_job_specs)
        self.assertGreater(idx_untamed, idx_bst_specs)
        self.assertGreater(idx_thf, idx_hud)
        self.assertGreater(idx_untamed, idx_hud)


@unittest.skipIf(LuaRuntime is None, 'lupa not installed')
class SequenceBLuaBehaviorTests(unittest.TestCase):
    def test_additive_registration_preserves_alpha_warden(self):
        lua = build_lua_harness(REPO_ROOT)
        lua.execute("""
            local spec = xi.overlords.spec
            -- Pre-register Alpha Warden (simulating bst_specs.lua loading first)
            spec.registerJob(xi.job.BST, 'BST', {
                { id = 2, key = 'alphawarden', name = 'Alpha Warden', role = 'Tank' },
            })
            dofile('""" + str(BST_UNTAMED).replace('\\', '/') + """')
            dofile('""" + str(THF_SPECS).replace('\\', '/') + """')

            -- Alpha Warden must remain intact alongside Untamed
            assert(spec.resolve(xi.job.BST, 'alphawarden') ~= nil)
            assert(spec.resolve(xi.job.BST, 2).key == 'alphawarden')
            assert(spec.resolve(xi.job.BST, 'untamed') ~= nil)
            assert(spec.resolve(xi.job.BST, 1).key == 'untamed')

            -- All 3 THF Souls registered at branches 1, 2, 3
            assert(spec.resolve(xi.job.THF, 1).key == 'trickster')
            assert(spec.resolve(xi.job.THF, 2).key == 'bandit')
            assert(spec.resolve(xi.job.THF, 3).key == 'phantom')
        """)

    def test_trickster_hit_gate_brackets_no_overwrite_and_cleanup(self):
        lua = build_lua_harness(REPO_ROOT)
        lua.execute(f"dofile('{str(THF_SPECS).replace(chr(92), '/')}')")
        lua.execute("""
            local spec = xi.overlords.spec
            local entry = assert(spec.resolve(xi.job.THF, 'trickster'))
            assert(entry.extraAbilities[1] == xi.jobAbility.TRICK_ATTACK)

            local p = makeEntity({ id = 10, isPC = true, job = xi.job.THF, lvl = 10, weapon = xi.skill.DAGGER })
            p:setCharVar('OX_SPEC_THF', 1)
            entry.onApply(p)

            local mob = makeEntity({ id = 200, isMob = true, alive = true })

            -- Missed WS (damage = 0): no debuff, ICD NOT consumed
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, { getMsg = function() return xi.msg.basic.SKILL_MISS end }, 0)
            assert(not mob:hasStatusEffect(xi.effect.ATTACK_DOWN))

            -- Immediate landed WS succeeds at Lv10 (5% power, 16s duration)
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 120)
            assert(mob:hasStatusEffect(xi.effect.ATTACK_DOWN))
            assert(mob._effects[xi.effect.ATTACK_DOWN].power == 5)
            assert(mob._effects[xi.effect.ATTACK_DOWN].duration == 16)

            -- Stronger existing Attack Down is NOT overwritten and does NOT consume ICD
            _TEST_NOW = _TEST_NOW + 25
            mob._effects[xi.effect.ATTACK_DOWN] = { power = 20, duration = 60 }
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 150)
            assert(mob._effects[xi.effect.ATTACK_DOWN].power == 20)

            -- Clear existing debuff and test Lv70 bracket immediately (proving ICD wasn't wasted)
            mob._effects[xi.effect.ATTACK_DOWN] = nil
            p._lvl = 70
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 300)
            assert(mob._effects[xi.effect.ATTACK_DOWN].power == 12)

            -- Level sync below 10 disables trigger
            _TEST_NOW = _TEST_NOW + 25
            mob._effects[xi.effect.ATTACK_DOWN] = nil
            p._lvl = 9
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 90)
            assert(not mob:hasStatusEffect(xi.effect.ATTACK_DOWN))

            -- Cleanup removes listener
            p._lvl = 75
            entry.onRemove(p)
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 300)
            assert(not mob:hasStatusEffect(xi.effect.ATTACK_DOWN))
        """)

    def test_bandit_hit_gate_defense_down_weapon_gate_and_brackets(self):
        lua = build_lua_harness(REPO_ROOT)
        lua.execute(f"dofile('{str(THF_SPECS).replace(chr(92), '/')}')")
        lua.execute("""
            local spec = xi.overlords.spec
            local entry = assert(spec.resolve(xi.job.THF, 'bandit'))
            assert(entry.extraAbilities[1] == xi.jobAbility.SNEAK_ATTACK)

            local p = makeEntity({ id = 11, isPC = true, job = xi.job.THF, lvl = 10, weapon = xi.skill.DAGGER })
            p:setCharVar('OX_SPEC_THF', 2)
            entry.onApply(p)
            local mob = makeEntity({ id = 201, isMob = true, alive = true })

            -- No Defense Down: 0 TP refund
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 100)
            assert(p:getTP() == 0)

            -- Defense Down present, but WS missed: 0 TP refund, ICD NOT consumed
            mob:addStatusEffect(xi.effect.DEFENSE_DOWN, { power = 10, duration = 60 })
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 0)
            assert(p:getTP() == 0)

            -- Marksmanship WS never triggers refund
            p._weapon = xi.skill.MARKSMANSHIP
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 100)
            assert(p:getTP() == 0)

            -- Landed Dagger WS refunds +75 TP at Lv10
            p._weapon = xi.skill.DAGGER
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 100)
            assert(p:getTP() == 75)

            -- Within 12s ICD: no second refund
            _TEST_NOW = _TEST_NOW + 5
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 100)
            assert(p:getTP() == 75)

            -- After 12s ICD at Lv75: refunds +150 TP
            _TEST_NOW = _TEST_NOW + 10
            p._lvl = 75
            p:trigger('WEAPONSKILL_USE', p, mob, 1, 1000, nil, 250)
            assert(p:getTP() == 225)
        """)

    def test_phantom_cold_start_dare_unavoidable_guard_and_evade_threat(self):
        lua = build_lua_harness(REPO_ROOT)
        lua.execute(f"dofile('{str(THF_SPECS).replace(chr(92), '/')}')")
        lua.execute("""
            local spec = xi.overlords.spec
            local entry = assert(spec.resolve(xi.job.THF, 'phantom'))
            assert(entry.extraAbilities[1] == xi.jobAbility.STEAL)

            local p = makeEntity({ id = 12, isPC = true, job = xi.job.THF, lvl = 10, weapon = xi.skill.DAGGER, tp = 0 })
            p:setCharVar('OX_SPEC_THF', 3)
            entry.onApply(p)
            local mob = makeEntity({ id = 202, isMob = true, alive = true })

            -- Range gate: >15y rejected
            p._dist = 16
            assert(xi.overlords.thf.executePhantomsDare(p, mob, nil) == false)
            assert(#mob._enmity == 0)

            -- Cold-start Dare at Lv10 (0 TP, no /WAR, <=15y): +180 CE / +650 VE + 6s 8% guard
            p._dist = 10
            assert(xi.overlords.thf.executePhantomsDare(p, mob, nil) == true)
            assert(#mob._enmity == 1 and mob._enmity[1].ce == 180 and mob._enmity[1].ve == 650)

            -- Normal PHYSICAL melee hit NEVER consumes Dare's unavoidable guard
            local phys = xi.overlords.onPreTakeDamage(p, 100, mob, xi.attackType.PHYSICAL, 0)
            assert(phys == 100)

            -- Landed MAGICAL hit consumes the 8% guard once (100 -> 92)
            local mag1 = xi.overlords.onPreTakeDamage(p, 100, mob, xi.attackType.MAGICAL, 0)
            assert(mag1 == 92)
            -- Second MAGICAL hit is unreduced (guard consumed)
            local mag2 = xi.overlords.onPreTakeDamage(p, 100, mob, xi.attackType.MAGICAL, 0)
            assert(mag2 == 100)

            -- Evade threat: HIT_MISS grants +30 CE / +85 VE at Lv10 with 2s ICD
            p:trigger('ATTACKED', p, mob, { getMsg = function() return xi.msg.basic.HIT_MISS end })
            assert(#mob._enmity == 2 and mob._enmity[2].ce == 30 and mob._enmity[2].ve == 85)

            -- Within 2s ICD: no second evade threat
            _TEST_NOW = _TEST_NOW + 1
            p:trigger('ATTACKED', p, mob, { getMsg = function() return xi.msg.basic.HIT_MISS end })
            assert(#mob._enmity == 2)

            -- Non-miss message (e.g. shadow absorb / hit = 1) never triggers evade threat
            _TEST_NOW = _TEST_NOW + 5
            p:trigger('ATTACKED', p, mob, { getMsg = function() return 1 end })
            assert(#mob._enmity == 2)

            -- Cleanup clears guard and listener
            _TEST_NOW = _TEST_NOW + 20
            p._lvl = 75
            assert(xi.overlords.thf.executePhantomsDare(p, mob, nil) == true)
            entry.onRemove(p)
            assert(xi.overlords.onPreTakeDamage(p, 100, mob, xi.attackType.BREATH, 0) == 100)
        """)

    def test_untamed_bilateral_sync_reverse_order_negative_cases_and_resummon_cleanup(self):
        lua = build_lua_harness(REPO_ROOT)
        lua.execute(f"dofile('{str(BST_UNTAMED).replace(chr(92), '/')}')")
        lua.execute("""
            local spec = xi.overlords.spec
            local entry = assert(spec.resolve(xi.job.BST, 'untamed'))
            assert(#entry.extraAbilities == 5)

            local mobA = makeEntity({ id = 301, isMob = true, alive = true, zone = 100 })
            local mobB = makeEntity({ id = 302, isMob = true, alive = true, zone = 100 })
            local master = makeEntity({ id = 20, isPC = true, job = xi.job.BST, lvl = 10, weapon = xi.skill.AXE, target = mobA, zone = 100 })
            local pet1 = makeEntity({ id = 500, isMob = false, alive = true, master = master, target = mobA, zone = 100 })
            master._pet = pet1
            master:setCharVar('OX_SPEC_BST', 1)
            entry.onApply(master)

            -- Pet mods applied once (Lv10: ACC+10, ATT+15, DA+3)
            assert(pet1._mods[xi.mod.ACC] == 10 and pet1._mods[xi.mod.ATT] == 15 and pet1._mods[xi.mod.DOUBLE_ATTACK] == 3)

            -- Reverse order: Pet offensive Ready lands FIRST on shared target -> +75 master TP (Lv10)
            pet1:trigger('WEAPONSKILL_USE', pet1, mobA, 10, 1000, nil, 80)
            pet1:trigger('WEAPONSKILL_STATE_EXIT', pet1, 10, true)
            assert(master:getTP() == 75)

            -- Master landed WS on SAME target -> +125 pet TP (independent 8s ICD!)
            master:trigger('WEAPONSKILL_USE', master, mobA, 1, 1000, nil, 120)
            assert(pet1:getTP() == 125)

            -- Negative cases after ICD expires:
            _TEST_NOW = _TEST_NOW + 10
            -- 1. Zero-damage Ready gives 0 master TP and does NOT consume ICD
            pet1:trigger('WEAPONSKILL_USE', pet1, mobA, 10, 1000, nil, 0)
            pet1:trigger('WEAPONSKILL_STATE_EXIT', pet1, 10, true)
            assert(master:getTP() == 75)

            -- 2. Canceled Ready gives 0 master TP
            pet1:trigger('WEAPONSKILL_USE', pet1, mobA, 10, 1000, nil, 90)
            pet1:trigger('WEAPONSKILL_STATE_EXIT', pet1, 10, false)
            assert(master:getTP() == 75)

            -- 3. Target mismatch (pet hits mobB while master targets mobA) gives 0 master TP
            pet1:trigger('WEAPONSKILL_USE', pet1, mobB, 10, 1000, nil, 90)
            pet1:trigger('WEAPONSKILL_STATE_EXIT', pet1, 10, true)
            assert(master:getTP() == 75)

            -- 4. Master missed WS gives 0 pet TP and leaves ICD ready
            master:trigger('WEAPONSKILL_USE', master, mobA, 1, 1000, nil, 0)
            assert(pet1:getTP() == 125)

            -- 5. Immediate valid landed master WS at Lv75 succeeds (+275 pet TP)
            master._lvl = 75
            master:trigger('WEAPONSKILL_USE', master, mobA, 1, 1000, nil, 300)
            assert(pet1:getTP() == 400)

            -- 6. Dismiss & resummon reusing same pet entity ID 500: no duplicate mods or leaked hit state
            xi.overlords.bstUntamed.clearPetMods(pet1)
            assert(pet1._mods[xi.mod.ACC] == 0)
            local pet2 = makeEntity({ id = 500, isMob = false, alive = true, master = master, target = mobA, zone = 100 })
            master._pet = pet2
            xi.overlords.bstUntamed.attachPet(master, pet2)
            assert(pet2._mods[xi.mod.ACC] == 40 and pet2._mods[xi.mod.ATT] == 60)

            -- Cleanup removes mods cleanly
            entry.onRemove(master)
            assert(pet2._mods[xi.mod.ACC] == 0)
        """)


if __name__ == '__main__':
    unittest.main()
