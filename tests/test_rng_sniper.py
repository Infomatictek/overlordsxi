"""Test Sniper's playable unlocks, native isolation, and ammo contract."""
from pathlib import Path
import re
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/rng_sniper_specs.lua"
PATCH = ROOT / "patches/0058-sniper-sightline.patch"


class SniperNativeTests(unittest.TestCase):
    def test_sightline_routes_only_its_ability_into_the_native_range_state(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("sniper::isActive(PChar) && abilityid == sniper::Sightline", patch)
        self.assertIn("Internal_RangedAttack(target, true)", patch)
        self.assertIn("PAbility->getID() != sniper::DeepSight", patch)
        self.assertIn("m_aimTime = m_deepSight ? 4s : 3s", patch)
        self.assertIn("m_sightline ? 1.0f : 0.3f", patch)
        self.assertIn("player->battleTarget() != m_originalBattleTarget", patch)
        self.assertIn("!player->CanSeeTarget(target)", patch)
        self.assertIn("IsValidTarget(target(), TARGET_ENEMY, m_errorMsg)", patch)
        self.assertIn("HasPreventActionEffect()", patch)

    def test_one_projectile_even_on_miss_and_none_on_cancellation(self):
        patch = PATCH.read_text(encoding="utf-8")
        for proc in ("Barrage", "Sange", "TripleShot", "DoubleShot"):
            self.assertRegex(patch, re.compile(r"^\+.*!sightline.*StatusEffect::" + proc, re.MULTILINE))
        self.assertIn("const bool recycleProc = !sightline", patch)
        self.assertIn("const auto released = !action.targets.empty()", patch)
        self.assertIn("const auto duration = released ? 12 : 3", patch)
        self.assertIn("weapon->getSubSkillType() == ammo->getSubSkillType()", patch)
        self.assertIn("sniper::damagePercent(GetMLevel(), deepSight)", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class SniperRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides = 100, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({ 'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player' }) do
                package.preload[name] = function() return {} end
            end
            xi = {
                job = { RNG = 11 }, mod = { MARKSMANSHIP = 1, RACC = 2, RATT = 3, AGI = 4 },
                msg = { basic = { NONE = 0, UNABLE_TO_USE_JA = 87 }, channel = { SYSTEM_3 = 29 } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            player = { key = 'sniper', level = 10, vars = {},
                isPC = function() return true end, getMainJob = function() return 11 end,
                getMainLvl = function(self) return self.level end,
                getLocalVar = function(self, key) return self.vars[key] or 0 end,
                setLocalVar = function(self, key, value) self.vars[key] = value end,
                sendSoulSpellList = function() end, printToPlayer = function() end,
            }
            ability = { setRecast = function(self, n) self.recast = n end, setCE = function() end, setVE = function() end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))

    def test_unlock_toggle_hud_and_scope(self):
        self.lua.execute("""
            local check = overrides['xi.actions.abilities.sharpshot.onAbilityCheck']
            local toggle = overrides['xi.actions.abilities.sharpshot.onUseAbility']
            assert(#crystal.extraAbilities(player, 9) == 0)
            assert(#crystal.extraAbilities(player, 10) == 1 and crystal.extraAbilities(player, 10)[1] == 57)
            assert(check(player, player, ability) == 87)
            player.level = 50
            assert(#crystal.extraAbilities(player, 50) == 2 and crystal.extraAbilities(player, 50)[2] == 59)
            assert(check(player, player, ability) == 0 and ability.recast == 5)
            crystal.onApply(player)
            toggle(player, player, ability)
            player.vars.OX_SNP_AIM_UNTIL = 104
            assert(hud(player).deep == 1 and hud(player).aim_rem == 4)
            now = 104
            player.vars.OX_SNP_RECAST_UNTIL = 116
            assert(hud(player).aim_rem == 0 and hud(player).shot_cd == 12)
            toggle(player, player, ability)
            assert(hud(player).deep == 0)
            crystal.onRemove(player)
            assert(player.vars.OX_SNP_ACTIVE == 0 and player.vars.OX_SNP_AIM_UNTIL == 0)
            player.key = 'huntsman'
            assert(toggle(player, player, ability) == 123 and check(player, player, ability) == 123)
        """)
