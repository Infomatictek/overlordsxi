"""Exercise Channeler links, Soul scoping and native reservation boundaries."""
import unittest
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/blm_channeler_specs.lua"
PATCH = ROOT / "patches/0049-channeler-native-actions.patch"


class ChannelerNativeTests(unittest.TestCase):
    def test_native_reservation_cost_and_cleanup(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("ConduitLink = 273", patch)
        self.assertIn("nativeId >= 204 && nativeId <= 215", patch)
        self.assertIn("m_astromancerCast && astromancer::spellProfile(m_spellId).ancient", patch)
        self.assertIn("m_castTime <= 0ms || IsInstantCast()", patch)
        self.assertIn("GetSpell(), m_flags, m_linkSavings", patch)
        self.assertIn("channeler::discountedCost(cost, m_linkSavings)", patch)
        self.assertIn("finishLink(true)", patch)
        self.assertIn("finishLink(false)", patch)
        self.assertIn("owner && completed && m_actualMpSpent > 0", patch)
        self.assertIn("owner->PParty != recipient->PParty", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class ChannelerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, actors, members = 100, {}, {}, {}
            Module = { new = function() return {
                addOverride = function(_, path, fn) overrides[path] = fn end,
            } end }
            for _, key in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
            }) do
                package.preload[key] = function() return {} end
            end
            xi = {
                job = { BLM = 4 }, mod = { MPP = 1, MACC = 2, HPP = 3 },
                msg = { basic = { UNABLE_TO_USE_JA = 87, CANNOT_CAST_SPELL = 1 } },
                soulspire = {
                    nowSec = function() return now end,
                    spec = {
                        is = function(p, _, key) return p.key == key end,
                        registerCrystal = function(_, entry) crystal = entry end,
                    },
                    hud = { registerProvider = function(_, fn) hud = fn end },
                },
            }
            super = function() return 123 end
            GetPlayerByID = function(id) return actors[id] end
            function actor(id, key, level, inParty)
                local player = {
                    id = id, key = key, level = level, distance = 10, mp = 100, vars = {},
                    isPC = function() return true end,
                    isAlive = function() return true end,
                    getMainJob = function() return 4 end,
                    getMainLvl = function(self) return self.level end,
                    getID = function(self) return self.id end,
                    getZoneID = function() return 5 end,
                    getParty = function() return members end,
                    checkDistance = function(_, target) return target.distance end,
                    getMP = function(self) return self.mp end,
                    getMaxMP = function() return 200 end,
                    addMP = function(self, delta) self.mp = self.mp + delta end,
                    getLocalVar = function(self, name) return self.vars[name] or 0 end,
                    setLocalVar = function(self, name, value) self.vars[name] = value end,
                    sendSoulSpellList = function() end,
                }
                actors[id] = player
                if inParty then members[#members + 1] = player end
                return player
            end
            weak = actor(1, 'channeler', 10, true)
            strong = actor(2, 'channeler', 75, true)
            ally = actor(3, 'astromancer', 50, true)
            stranger = actor(4, 'astromancer', 50, false)
            ability = {
                setRecast = function(self, n) self.recast = n end,
                setRange = function(self, n) self.range = n end,
                setCE = function() end, setVE = function() end,
            }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            check = overrides['xi.actions.abilities.manawell.onAbilityCheck']
            use = overrides['xi.actions.abilities.manawell.onUseAbility']
        """)

    def test_solo_level_ten_and_scope(self):
        self.lua.execute("""
            assert(crystal.extraAbilities(weak, 10)[1] == 273 and #crystal.extraAbilities(weak, 9) == 0)
            assert(check(weak, strong, ability) == 87 and check(weak, stranger, ability) == 87)
            assert(check(ally, weak, ability) == 123)
            assert(check(weak, weak, ability) == 0 and ability.recast == 24)
            use(weak, weak, ability)
            assert(weak.mp == 100 and weak.vars.OX_CHN_CAST_SAVE == 0)
            assert(weak.vars.OX_CHN_MP_SAVE == 15 and weak.vars.OX_CHN_MP_RELAY == 0)
            assert(hud(weak).link_rem == 8)
            now = now + 8
            assert(hud(weak).link_rem == 0)
            crystal.onRemove(weak)
            assert(weak.vars.OX_CHN_OWNER == 0)
        """)

    def test_allied_progression_strongest_and_reserved_link(self):
        self.lua.execute("""
            assert(check(weak, ally, ability) == 0 and ability.range == 15)
            use(weak, ally, ability)
            assert(weak.mp == 84 and ally.vars.OX_CHN_CAST_SAVE == 20)
            ally:setLocalVar('OX_CHN_RESERVED', now + 1)
            assert(check(strong, ally, ability) == 87)
            now = now + 2
            ally.distance = 18
            assert(check(strong, ally, ability) == 0 and ability.range == 20)
            use(strong, ally, ability)
            assert(weak.vars.OX_CHN_RECIPIENT == 0 and ally.vars.OX_CHN_OWNER == strong.id)
            assert(strong.mp == 84 and ally.vars.OX_CHN_CAST_SAVE == 30)
            assert(ally.vars.OX_CHN_MP_SAVE == 25 and ally.vars.OX_CHN_MP_RELAY == 5)
            assert(check(weak, ally, ability) == 87)
            crystal.onRemove(strong)
            assert(ally.vars.OX_CHN_OWNER == 0 and ally.vars.OX_CHN_LINK_UNTIL == 0)
        """)
