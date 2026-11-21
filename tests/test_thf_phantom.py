"""Check Phantom's native opener, guard and genuine evasion path."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/thf_phantom_specs.lua"
PATCH = ROOT / "patches/0054-phantom-native-actions.patch"


class PhantomNativeTests(unittest.TestCase):
    def test_no_steal_side_effects_or_false_evades(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("Dare = 41", patch)
        self.assertIn("PAbility->getID() == ABILITY_STEAL && !phantom::isActive(this)", patch)
        self.assertIn("trackPhantomEvade && attack.GetAttackType() == PHYSICAL_ATTACK_TYPE::NORMAL", patch)
        self.assertIn('triggerListener("SOUL_MELEE_EVADE", PTarget, this)', patch)
        self.assertIn("case 16900: // Wakizashi", patch)
        self.assertIn("m_phantomAbility != currentPhantom", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class PhantomRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, listeners = 100, {}, {}
            Module = { new = function() return {
                addOverride = function(_, path, fn) overrides[path] = fn end,
            } end }
            for _, name in ipairs({ 'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player' }) do
                package.preload[name] = function() return {} end
            end
            xi = {
                job = { THF = 6 }, slot = { MAIN = 0 }, skill = { DAGGER = 2, KATANA = 9 },
                mod = { DAGGER = 1, EVA = 2, AGI = 3, HPP = 4, DMG = 5, ENMITY = 6 },
                attackType = { PHYSICAL = 1, MAGICAL = 2, BREATH = 3 },
                msg = { basic = { UNABLE_TO_USE_JA = 87, USES_JA = 100 } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            player = {
                key = 'phantom', level = 10, weapon = 2, vars = {},
                isPC = function() return true end,
                getMainJob = function() return 6 end,
                getMainLvl = function(self) return self.level end,
                getWeaponSkillType = function(self) return self.weapon end,
                checkDistance = function(_, target) return target.distance end,
                getLocalVar = function(self, k) return self.vars[k] or 0 end,
                setLocalVar = function(self, k, v) self.vars[k] = v end,
                addListener = function(_, _, key, fn) listeners[key] = fn end,
                removeListener = function(_, key) listeners[key] = nil end,
                sendSoulSpellList = function() end,
                getEquippedItem = function() return nil end,
            }
            mob = {
                distance = 14, ce = 0, ve = 0,
                isMob = function() return true end,
                isAlive = function() return true end,
                getID = function() return 3 end,
                addEnmity = function(self, _, ce, ve) self.ce = self.ce + ce; self.ve = self.ve + ve end,
            }
            ability = {
                setRecast = function(self, x) self.recast = x end,
                setRange = function(self, x) self.range = x end,
                setCE = function(self, x) self.ce = x end,
                setVE = function(self, x) self.ve = x end,
            }
            action = { messageID = function(self, id, msg) self.message = msg end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))

    def test_level_ten_cold_start_and_one_hit_guard(self):
        self.lua.execute("""
            crystal.onApply(player)
            assert(crystal.extraAbilities(player, 10)[1] == 41)
            local check = overrides['xi.actions.abilities.steal.onAbilityCheck']
            local use = overrides['xi.actions.abilities.steal.onUseAbility']
            assert(check(player, mob, ability) == 0)
            assert(ability.ce == 180 and ability.ve == 650 and ability.recast == 18 and ability.range == 15)
            use(player, mob, ability, action)
            local take = xi.soulspire.onPreTakeDamage
            assert(action.message == 100 and hud(player).guard_rem == 6)
            assert(take(player, 100, mob, xi.attackType.PHYSICAL) == 100)
            assert(hud(player).guard_rem == 6)
            assert(take(player, 100, mob, xi.attackType.MAGICAL) == 92 and hud(player).guard_rem == 0)
            assert(take(player, 100, mob, xi.attackType.BREATH) == 100)
            mob.distance = 16
            assert(check(player, mob, ability) == 87)
            now, player.level = 120, 75
            use(player, mob, ability, action)
            assert(take(player, 200, mob, xi.attackType.BREATH) == 170)
        """)

    def test_evasion_scaling_and_cleanup(self):
        self.lua.execute("""
            crystal.onApply(player)
            local evade = listeners.OX_PHN_EVADE
            evade(player, mob)
            evade(player, mob)
            assert(mob.ce == 30 and mob.ve == 85 and hud(player).evade_cd == 2)
            now, player.level, player.weapon = 102, 75, 12
            evade(player, mob)
            assert(mob.ce == 30)
            player.weapon = 9
            evade(player, mob)
            assert(mob.ce == 100 and mob.ve == 275)
            crystal.onRemove(player)
            assert(listeners.OX_PHN_EVADE == nil and hud(player).guard_rem == 0)
            player.key = 'bandit'
            assert(overrides['xi.actions.abilities.steal.onUseAbility'](player, mob, ability, action) == 123)
        """)
