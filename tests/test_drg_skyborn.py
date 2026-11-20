"""Verify Skyborn's cold-start threat, timed guard, and landing ward."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/drg_skyborn_specs.lua"
PATCH = ROOT / "patches/0062-skyborn-native-actions.patch"


class SkybornNativeTests(unittest.TestCase):
    def test_guard_clone_is_self_only_and_scoped(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("m_skybornAbility && m_abilityId == skyborn::Guard", patch)
        self.assertIn("m_PAbility->setAOE(0)", patch)
        self.assertIn("m_PAbility->setRange(15)", patch)
        self.assertIn("!skyborn::isKitAbility(PAbility->getID())", patch)
        self.assertIn("xi::SkillType::Polearm", patch)
        lua = MODULE.read_text(encoding="utf-8")
        self.assertNotIn("setUntargetable", lua)
        self.assertNotIn("resetEnmity", lua)
        self.assertNotIn("super_jump", lua)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class SkybornRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, online = 100, {}, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({ 'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player' }) do
                package.preload[name] = function() return {} end
            end
            xi = {
                job = { DRG = 14 }, slot = { MAIN = 0 }, skill = { POLEARM = 8 },
                mod = { POLEARM = 1, HPP = 2, ENMITY = 3, DMG = 4 },
                attackType = { PHYSICAL = 1, MAGICAL = 2, RANGED = 3, BREATH = 4 },
                msg = { channel = { SYSTEM_3 = 29 }, basic = { NONE = 0, UNABLE_TO_USE_JA = 87 } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            function GetMobByID(id) return online[id] end
            function actor(id, mob)
                local e = { key = 'skyborn', level = 10, weapon = 8, zone = 1, vars = {}, timers = {},
                    isPC = function() return not mob end, isMob = function() return mob == true end,
                    isAlive = function() return true end, getID = function() return id end,
                    getName = function() return 'Enemy' end, getZoneID = function(self) return self.zone end,
                    getBattleID = function() return 0 end, getInstance = function() return nil end,
                    getMainJob = function() return 14 end, getMainLvl = function(self) return self.level end,
                    getWeaponSkillType = function(self) return self.weapon end, getMaxHP = function() return 1000 end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end,
                    sendSoulSpellList = function() end,
                    checkDistance = function(_, target) return target.distance or 10 end,
                    getTarget = function(self) return self.target end, printToPlayer = function() end,
                    timer = function(self, _, fn) table.insert(self.timers, fn) end,
                    addEnmity = function(self, _, ce, ve) self.ce, self.ve = (self.ce or 0) + ce, (self.ve or 0) + ve end,
                }
                if mob then online[id] = e end
                return e
            end
            player, enemy, other = actor(1), actor(2, true), actor(3, true)
            player.target = enemy
            ability = { setRecast = function(self, n) self.recast = n end, setCE = function() end, setVE = function() end, setRange = function() end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            cry = overrides['xi.actions.abilities.jump.onUseAbility']
            checkCry = overrides['xi.actions.abilities.jump.onAbilityCheck']
            guard = overrides['xi.actions.abilities.ancient_circle.onUseAbility']
            damage = xi.soulspire.onPreTakeDamage
        """)

    def test_level_ten_threat_and_one_hit_guard(self):
        self.lua.execute("""
            enemy.distance = 16
            assert(checkCry(player, enemy, ability) == 87)
            enemy.distance = 15
            assert(checkCry(player, enemy, ability) == 0 and ability.recast == 16)
            cry(player, enemy, ability)
            assert(enemy.ce == 200 and enemy.ve == 700 and hud(player).cry_cd == 16)
            guard(player, player, ability)
            assert(hud(player).guard_ms == 1500)
            assert(damage(player, 100, enemy, 0) == 100)
            assert(damage(player, 100, enemy, 2) == 100)
            assert(damage(player, 100, enemy, 1) == 65)
            assert(damage(player, 100, enemy, 1) == 100 and hud(player).ward_hp == 0)
            assert(enemy.ce == 300 and enemy.ve == 1000)
            player.timers[1](player)
            assert(enemy.ce == 300 and enemy.ve == 1000)
        """)

    def test_landing_ward_and_target_change_at_level_thirty(self):
        self.lua.execute("""
            player.level = 30
            guard(player, player, ability)
            player.target = other
            enemy.vars.OX_SCR_ACTION = 2
            assert(damage(player, 100, enemy, 2) == 60)
            assert(enemy.ce == 100 and enemy.ve == 300 and other.ce == nil)
            assert(hud(player).ward_hp == 50 and hud(player).ward_ms == 5000)
            assert(damage(player, 20, enemy, 1) == 0 and hud(player).ward_hp == 30)
            assert(damage(player, 50, enemy, 1) == 20 and hud(player).ward_hp == 0)
            guard(player, player, ability)
            now = 102
            player.timers[2](player)
            assert(other.ce == 100 and hud(player).ward_hp == 0)
        """)

    def test_guard_window_wrap_and_soul_cleanup(self):
        self.lua.execute("""
            now = 4294967
            guard(player, player, ability)
            assert(hud(player).guard_ms == 1500)
            now = now + 0.5
            assert(hud(player).guard_ms == 1000 and damage(player, 100, enemy, 1) == 65)
            guard(player, player, ability)
            crystal.onRemove(player)
            player.timers[2](player)
            assert(enemy.ce == 100 and hud(player).guard_ms == 0)
            player.key = 'lancer'
            assert(cry(player, enemy, ability) == 123)
        """)
