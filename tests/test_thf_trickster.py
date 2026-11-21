"""Test Trickster's native action entitlement and suppression lifecycle."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/thf_trickster_specs.lua"
PATCH = ROOT / "patches/0053-trickster-native-actions.patch"


class TricksterNativeTests(unittest.TestCase):
    def test_native_ability_and_family(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("PassTheBlame = 76", patch)
        self.assertIn("m_tricksterAbility != currentTrickster", patch)
        self.assertIn("m_tricksterCast == trickster::isActive(caster)", patch)
        self.assertIn("bandit::isActive(PChar) || trickster::isActive(PChar)", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class TricksterRuntimeTests(unittest.TestCase):
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
                job = { THF = 6 }, slot = { MAIN = 0 }, skill = { DAGGER = 2, SWORD = 3 },
                effect = { ATTACK_DOWN = 1, TRICK_ATTACK = 2 },
                mod = { DAGGER = 1, ACC = 2, DEX = 3, SUBTLE_BLOW = 4, ENMITY = 5 },
                msg = { basic = { UNABLE_TO_USE_JA = 87 } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            mob = {
                immune = false, isMob = function() return true end, isAlive = function() return true end,
                hasStatusEffect = function(self) return self.status ~= nil end,
                addStatusEffect = function(self, _, options)
                    if self.immune then return false end
                    self.status = options
                    return true
                end,
            }
            player = {
                key = 'trickster', level = 10, weapon = 2, vars = {},
                isPC = function() return true end,
                getMainJob = function() return 6 end,
                getMainLvl = function(self) return self.level end,
                getWeaponSkillType = function(self) return self.weapon end,
                getTarget = function() return mob end,
                getLocalVar = function(self, k) return self.vars[k] or 0 end,
                setLocalVar = function(self, k, v) self.vars[k] = v end,
                sendSoulSpellList = function() end,
                addListener = function(_, _, key, fn) listeners[key] = fn end,
                removeListener = function(_, key) listeners[key] = nil end,
                addStatusEffect = function(self, _, options) self.status = options end,
                delStatusEffectSilent = function(self) self.status = nil end,
                hasStatusEffect = function(self) return self.status ~= nil end,
            }
            ability = { setRecast = function(self, seconds) self.recast = seconds end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            crystal.onApply(player)
            hit = function(damage) listeners.OX_TRK_SUPPRESS_WS(player, mob, nil, 1000, nil, damage) end
        """)

    def test_solo_level_ten_and_failed_hits_keep_ready(self):
        self.lua.execute("""
            assert(crystal.extraAbilities(player, 10)[1] == 76)
            hit(0)
            assert(mob.status == nil and hud(player).suppress_cd == 0)
            mob.immune = true
            hit(100)
            assert(mob.status == nil and hud(player).suppress_cd == 0)
            mob.immune = false
            hit(100)
            assert(mob.status.power == 5 and mob.status.duration == 16 and hud(player).suppress_cd == 20)
            now, player.level = 120, 75
            hit(100)
            assert(mob.status.power == 5 and hud(player).suppress_cd == 0)
            mob.status = nil
            hit(100)
            assert(mob.status.power == 12)
        """)

    def test_positional_window_is_scoped_and_cleans_up(self):
        self.lua.execute("""
            local check = overrides['xi.actions.abilities.trick_attack.onAbilityCheck']
            local use = overrides['xi.actions.abilities.trick_attack.onUseAbility']
            player.weapon = 12
            assert(check(player, player, ability) == 87)
            player.weapon = 3
            assert(check(player, player, ability) == 0 and ability.recast == 35)
            assert(use(player, player, ability) == xi.effect.TRICK_ATTACK)
            assert(player.status.duration == 20 and hud(player).blame_ready == 1)
            crystal.onRemove(player)
            assert(player.status == nil and listeners.OX_TRK_SUPPRESS_WS == nil)
            player.key = 'bandit'
            assert(use(player, player, ability) == 123)
        """)
