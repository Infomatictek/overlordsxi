"""Test Royal Tactician orders, cast outcomes and timed modifier cleanup."""
import unittest
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/rdm_royal_tactician_specs.lua"
PATCH = ROOT / "patches/0051-royal-tactician-native-actions.patch"


class RoyalTacticianNativeTests(unittest.TestCase):
    def test_refund_uses_actual_completed_mp_and_current_issuer(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("IssueOrder = 275", patch)
        self.assertIn("m_actualMpSpent > 0 && m_flags == 0 && !IsInstantCast()", patch)
        self.assertIn("m_actualMpSpent * percent / 100", patch)
        self.assertIn("caster->PParty != owner->PParty", patch)
        self.assertIn('SetLocalVar("OX_RYT_ORDER_KIND", 0)', patch)
        self.assertIn("m_PLuaSpell->getMessage()", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class RoyalTacticianRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, players, party = 100, {}, {}, {}
            Module = { new = function() return { addOverride = function(_, path, fn) overrides[path] = fn end } end }
            for _, key in ipairs({ 'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player' }) do
                package.preload[key] = function() return {} end
            end
            xi = {
                job = { RDM = 5 }, mod = { ACC = 1, STORETP = 2, MACC = 3, MPP = 4 },
                msg = { basic = { UNABLE_TO_USE_JA = 87, CANNOT_CAST_SPELL = 1, MAGIC_RESIST = 2,
                    MAGIC_COMPLETE_RESIST = 3, MAGIC_NO_EFFECT = 4 } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            GetPlayerByID = function(id) return players[id] end
            function actor(id, key, level)
                local player = {
                    id = id, key = key, level = level, vars = {}, mods = {},
                    isPC = function() return true end, isAlive = function() return true end,
                    getMainJob = function() return 5 end,
                    getMainLvl = function(self) return self.level end,
                    getID = function(self) return self.id end,
                    getZoneID = function() return 5 end,
                    getParty = function() return party end,
                    getACC = function(self) return 100 + (self.mods[1] or 0) end,
                    checkDistance = function() return 5 end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end,
                    sendSoulSpellList = function() end,
                    addMod = function(self, mod, value) self.mods[mod] = (self.mods[mod] or 0) + value end,
                    delMod = function(self, mod, value) self.mods[mod] = self.mods[mod] - value end,
                    timer = function(self, wait, callback) self.callback = callback end,
                }
                players[id] = player
                party[#party + 1] = player
                return player
            end
            first, second, ally = actor(1, 'royaltactician', 10), actor(2, 'royaltactician', 75), actor(3, 'scarletweaver', 10)
            mob = { isMob = function() return true end }
            spell = { msg = 5, getMessage = function(self) return self.msg end }
            ability = {
                setRecast = function(self, seconds) self.recast = seconds end,
                setRange = function() end, setCE = function() end, setVE = function() end,
            }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            advance = overrides['xi.actions.spells.white.slow.onSpellCast']
            recompose = overrides['xi.actions.spells.black.blind.onSpellCast']
            repeatOrder = overrides['xi.actions.spells.black.dispel.onSpellCast']
            check = overrides['xi.actions.abilities.spontaneity.onAbilityCheck']
            issue = overrides['xi.actions.abilities.spontaneity.onUseAbility']
        """)

    def test_latest_order_repeat_and_resist_fallback(self):
        self.lua.execute("""
            assert(crystal.extraAbilities(first, 10)[1] == 275)
            advance(first, mob, spell)
            assert(hud(first).pending == 1)
            recompose(first, mob, spell)
            assert(hud(first).pending == 2 and hud(first).pending_rem == 6)
            assert(check(first, ally, ability) == 0 and ability.recast == 18)
            issue(first, ally, ability)
            assert(ally.vars.OX_RYT_ORDER_PCT == 15 and ally.vars.OX_RYT_ORDER_KIND == 2)
            assert(check(first, ally, ability) == 87)
            ally.callback(ally)
            now, first.level = 120, 50
            repeatOrder(first, mob, spell)
            assert(hud(first).pending == 2)
            spell.msg = xi.msg.basic.MAGIC_RESIST
            advance(first, mob, spell)
            assert(hud(first).pending == 1 and hud(first).half == 1)
            recompose(first, mob, spell)
            assert(hud(first).pending == 1 and hud(first).fallback_cd == 24)
            spell.msg = xi.msg.basic.MAGIC_NO_EFFECT
            recompose(first, mob, spell)
            assert(hud(first).pending == 1)
        """)

    def test_strongest_advance_cleanup_and_soul_scope(self):
        self.lua.execute("""
            spell.msg = xi.msg.basic.MAGIC_RESIST
            advance(first, mob, spell)
            assert(hud(first).pending == 0)
            spell.msg = 5
            advance(first, mob, spell)
            issue(first, ally, ability)
            assert(ally.mods[1] == 10)
            local oldCallback = ally.callback
            advance(second, mob, spell)
            assert(check(second, ally, ability) == 0)
            issue(second, ally, ability)
            assert(ally.mods[1] == 15 and ally.mods[2] == 8)
            oldCallback(ally)
            assert(ally.mods[1] == 15 and ally.mods[2] == 8)
            crystal.onRemove(second)
            assert(ally.mods[1] == 0 and ally.mods[2] == 0)
            advance(ally, mob, spell)
            assert(hud(ally).pending == 0 and check(ally, first, ability) == 123)
        """)
