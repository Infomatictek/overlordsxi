"""Verify Archivist's exact native action records and party-page arbitration."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/sch_archivist_specs.lua"
PATCH = ROOT / "patches/0064-archivist-native-actions.patch"


class ArchivistNativeTests(unittest.TestCase):
    def test_action_scope_and_spawn_generation(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn('SetLocalVar("OX_ARC_ACTION", id)', patch)
        self.assertIn('SetLocalVar("OX_ARC_CATEGORY", 0)', patch)
        self.assertIn("CBattleEntity::Spawn();\n+    SetLocalVar(\"OX_ARC_SPAWN\", archivist::nextSpawn());", patch)
        self.assertEqual(patch.count('triggerListener("SOUL_ARCHIVIST_ACTION_COMPLETED"'), 3)
        self.assertIn("entry->getID() != SpellID::Death", patch)
        self.assertIn('GetLocalVar("OX_ARC_FILE_APPLIED") == 1 ? 15s : 0s', patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class ArchivistRuntimeTests(unittest.TestCase):
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
                job = { SCH = 20 }, mod = { MPP = 1, MACC = 2, HPP = 3 },
                msg = { channel = { SYSTEM_3 = 29 }, basic = { NONE = 0, MAGIC_NO_EFFECT = 75, MAGIC_UNABLE_TO_CAST = 17, UNABLE_TO_USE_JA = 87 } },
                attackType = { PHYSICAL = 1, MAGICAL = 2, RANGED = 3, BREATH = 4 },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            function GetPlayerByID(id) return online[id] end
            function actor(id, mob)
                local e = { key = 'archivist', level = 10, zone = 1, vars = {}, party = {}, timers = {}, listeners = {},
                    isPC = function() return not mob end, isMob = function() return mob == true end,
                    isAlive = function() return true end, getID = function() return id end,
                    getName = function() return 'Target' end, getZoneID = function(self) return self.zone end,
                    getBattleID = function(self) return self.battle or 0 end,
                    getMainJob = function() return 20 end, getMainLvl = function(self) return self.level end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end,
                    sendSoulSpellList = function() end, getParty = function(self) return self.party end,
                    checkDistance = function(_, target) return target.distance or 10 end, printToPlayer = function() end,
                    timer = function(self, _, fn) table.insert(self.timers, fn) end,
                    addListener = function(self, _, name, fn) self.listeners[name] = fn end,
                    removeListener = function(self, name) self.listeners[name] = nil end,
                }
                if not mob then online[id] = e end
                return e
            end
            player, rival, ally, outsider, enemy = actor(1), actor(2), actor(3), actor(4), actor(9, true)
            player.party, rival.party = { ally }, { ally }
            enemy.vars.OX_ARC_SPAWN = 1
            ability = { setRecast = function(self, n) self.recast = n end, setCE = function() end, setVE = function() end }
            spell = { setMsg = function(self, msg) self.msg = msg end }
            function completion(category, id, name)
                local pending = {}
                for _, fn in pairs(enemy.listeners) do pending[#pending + 1] = fn end
                for _, fn in ipairs(pending) do fn(enemy, category, id, name) end
            end
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            record = overrides['xi.actions.abilities.modus_veritas.onUseAbility']
            index = overrides['xi.actions.abilities.sublimation.onUseAbility']
            check = overrides['xi.actions.spells.white.sandstorm.onMagicCastingCheck']
            file = overrides['xi.actions.spells.white.sandstorm.onSpellCast']
            damage = xi.soulspire.onPreTakeDamage
            function arm(player, id, name)
                record(player, enemy, ability)
                completion(1, id, name)
            end
            function resolve(seq, cat, id)
                enemy.vars.OX_ARC_SEQUENCE, enemy.vars.OX_ARC_CATEGORY, enemy.vars.OX_ARC_ACTION = seq, cat, id
                return damage(ally, 100, enemy, 2)
            end
        """)

    def test_exact_action_and_highest_page_across_multihit(self):
        self.lua.execute("""
            rival.level = 75
            record(player, enemy, ability)
            record(rival, enemy, ability)
            completion(1, 12, 'fire_one')
            assert(hud(player).entries == 1 and hud(rival).entries == 1)
            assert(check(player, outsider, spell) == 17)
            assert(check(player, ally, spell) == 0 and check(rival, ally, spell) == 0)
            file(player, ally, spell); file(rival, ally, spell)
            assert(hud(player).page_rem == 20 and hud(rival).page_rem == 25)
            assert(resolve(1, 1, 13) == 100)
            assert(resolve(2, 2, 12) == 100)
            assert(resolve(3, 1, 12) == 70)
            assert(resolve(3, 1, 12) == 70 and hud(player).page_rem == 20)
            assert(resolve(4, 1, 12) == 80 and hud(player).page_rem == 0)
        """)

    def test_index_and_spawn_isolation(self):
        self.lua.execute("""
            player.level = 50
            arm(player, 12, 'fire_one')
            arm(player, 13, 'fire_two')
            assert(hud(player).entries == 2 and hud(player).record == 'Fire Two')
            index(player, player, ability)
            assert(hud(player).record == 'Fire One')
            assert(check(player, ally, spell) == 0)
            file(player, ally, spell)
            enemy.vars.OX_ARC_SPAWN = 2
            assert(resolve(1, 1, 12) == 100 and hud(player).page_rem == 20)
            crystal.onRemove(player)
            assert(hud(player).entries == 0 and hud(player).page_rem == 0)
            player.key = 'medic'
            assert(check(player, ally, spell) == 123)
        """)

    def test_sample_and_record_expire(self):
        self.lua.execute("""
            record(player, enemy, ability)
            now = 112
            completion(1, 12, 'fire_one')
            assert(hud(player).entries == 0 and check(player, player, spell) == 17)
            arm(player, 12, 'fire_one')
            assert(check(player, player, spell) == 0)
            now = 172
            file(player, player, spell)
            assert(spell.msg == 75 and player.vars.OX_ARC_FILE_APPLIED == nil)
        """)
