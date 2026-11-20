"""Verify corridor geometry, strongest coverage, and short modifier leases."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/geo_diviner_specs.lua"
PATCH = ROOT / "patches/0070-diviner-native-actions.patch"


class DivinerNativeTests(unittest.TestCase):
    def test_native_spell_and_exact_instance_gates(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("m_PSpell->setValidTarget(TARGET_SELF);", patch)
        self.assertIn("m_PSpell->setStatusEffect(std::nullopt);", patch)
        self.assertIn("m_divinerCast == diviner::isActive(caster)", patch)
        self.assertIn("m_divinerAbility != currentDiviner", patch)
        self.assertIn("id == ABILITY_ECLIPTIC_ATTRITION && level >= 30", patch)
        self.assertIn("m_PBaseEntity->entityId().instanceRunId", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class DivinerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            now, overrides, entities = 100, {}, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
            }) do package.preload[name] = function() return {} end end
            package.preload['modules/custom/lua/soulspire_soul_actions'] = function()
                return { register = function(_, data) catalog = data end }
            end
            xi = {
                job = { GEO = 21 }, mod = { ACC = 1, MACC = 2, GEOMANCY_SKILL = 3, HPP = 4 },
                msg = { basic = { MAGIC_UNABLE_TO_CAST = 17, NONE = 0, UNABLE_TO_USE_JA = 87 } },
                soulspire = { nowSec = function() return now end,
                    spec = { is = function(p, _, k) return p.key == k end,
                        registerCrystal = function(_, data) crystal = data end },
                    hud = { registerProvider = function(_, fn) hud = fn end },
                },
            }
            function actor(id)
                local entity = {
                    key = 'diviner', level = 10, zone = 1, battle = 0, instance = 0, vars = {}, mods = {}, alive = true,
                    pos = { x = 0, y = 0, z = 0 }, timers = {}, listeners = {}, party = {},
                    isPC = function() return true end, isAlive = function(self) return self.alive end,
                    getID = function() return id end, getZoneID = function(self) return self.zone end,
                    getBattleID = function(self) return self.battle end, getCombatInstanceRunId = function(self) return self.instance end,
                    getMainJob = function() return 21 end, getMainLvl = function(self) return self.level end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end,
                    getPos = function(self) return { x = self.pos.x, y = self.pos.y, z = self.pos.z } end,
                    getParty = function(self) return self.party end,
                    timer = function(self, delay, fn) self.timers[delay] = fn end,
                    sendSoulSpellList = function() end,
                    addMod = function(self, mod, d) self.mods[mod] = (self.mods[mod] or 0) + d end,
                    addListener = function(self, _, k, callback) self.listeners[k] = callback end,
                    removeListener = function(self, k) self.listeners[k] = nil end,
                }
                entities[id] = entity
                return entity
            end
            GetPlayerByID = function(id) return entities[id] end
            super = function() return 321 end
            spell = { setMsg = function() end }
            a, b, ally, stranger = actor(1), actor(2), actor(3), actor(4)
            a.party, b.party = { a, ally }, { b, ally }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            crystal.onApply(a)
            crystal.onApply(b)
            lay = overrides['xi.actions.spells.geomancy.indi-precision.onSpellCast']
            castCheck = overrides['xi.actions.spells.geomancy.indi-precision.onMagicCastingCheck']
            shift = overrides['xi.actions.abilities.ecliptic_attrition.onUseAbility']
            recall = overrides['xi.actions.abilities.full_circle.onUseAbility']
        """)

    def test_projection_endcaps_min_max_and_floor(self):
        self.lua.execute("""
            local inside = xi.soulspire.diviner.isInside
            local anchor = {x=0,y=0,z=0}
            assert(not inside(anchor, {x=2.99,y=0,z=0}, anchor, 2))
            assert(inside(anchor, {x=3,y=0,z=0}, {x=5,y=0,z=0}, 2))
            assert(not inside(anchor, {x=3,y=0,z=0}, {x=5.1,y=0,z=0}, 2))
            assert(inside(anchor, {x=15,y=3,z=0}, {x=7.5,y=4.5,z=2.5}, 2.5))
            assert(not inside(anchor, {x=15,y=3,z=0}, {x=7.5,y=4.6,z=2.5}, 2.5))
            assert(not inside(anchor, {x=15.1,y=0,z=0}, anchor, 2))
            assert(not inside(anchor, {x=6,y=3.1,z=0}, anchor, 2))
        """)

    def test_level_ten_party_only_and_live_movement(self):
        self.lua.execute("""
            assert(castCheck(a, ally, spell) == 17 and castCheck(a, a, spell) == 0)
            lay(a, a, spell)
            assert(hud(a).live == 0)
            a.pos.x, ally.pos.x, stranger.pos.x = 10, 5, 5
            a.timers[250](a)
            assert(hud(a).live == 1 and hud(a).count == 2)
            assert(ally.mods[1] == 12 and ally.mods[2] == 12 and stranger.mods[1] == nil)
            ally.instance = 1
            a.timers[250](a)
            assert(ally.mods[1] == 0 and ally.mods[2] == 0)
            ally.instance = 0
            a.timers[250](a)
            assert(ally.mods[1] == 12)
            now = 102
            ally.timers[500](ally)
            assert(ally.mods[1] == 0)
        """)

    def test_strongest_fallback_shift_lifetime_and_rapid_teardown(self):
        self.lua.execute("""
            b.level = 75
            lay(a, a, spell)
            lay(b, b, spell)
            ally.pos.x, a.pos.x, b.pos.x = 5, 10, 10
            a.timers[250](a)
            b.timers[250](b)
            assert(ally.mods[1] == 35 and ally.mods[2] == 35)
            now = 105
            a.timers[250](a)
            shift(b, b)
            assert(ally.mods[1] == 12 and hud(b).duration == 35 and hud(b).live == 0)
            b.pos.x = 4
            b.timers[250](b)
            assert(ally.mods[1] == 35)
            recall(b, b)
            assert(ally.mods[1] == 12)
            a.listeners.OX_DIV_CLEAR(a)
            assert(ally.mods[1] == 0)
            crystal.onRemove(a)
            a.key = 'verdant'
            assert(castCheck(a, a, spell) == 321 and catalog.spell[783].mpCost == 0)
        """)
