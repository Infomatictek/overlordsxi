"""Verify Scourge curse selection, immunity wards and classified action hooks."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/drk_scourge_specs.lua"
PATCH = ROOT / "patches/0057-scourge-native-actions.patch"


class ScourgeNativeTests(unittest.TestCase):
    def test_native_kit_and_action_categories(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("m_scourgeCast == scourge::isActive(caster)", patch)
        self.assertIn("PAbility->getID() != scourge::Rite", patch)
        self.assertIn("m_PAbility->setAOE(0)", patch)
        self.assertEqual(patch.count("category(*this, scourge::PhysicalMove)"), 2)
        self.assertEqual(patch.count("category(*this, scourge::Spell)"), 1)
        self.assertIn("scourge.reduceSelfHeal(mob, target, healAmount)", patch)
        self.assertIn("scourge.reduceSelfHeal(caster, target, final)", patch)
        self.assertIn("case SpellID::Absorb_MND:\n+            return 30;", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class ScourgeRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, online = 100, {}, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
                'scripts/globals/spells/damage_spell', 'scripts/combat/basic/magic_hit_rate',
            }) do
                package.preload[name] = function() return {} end
            end
            xi = {
                job = { DRK = 8 }, skill = { DARK_MAGIC = 43 }, element = { DARK = 8 },
                mod = { MACC = 1, MPP = 2, HPP = 3, INT = 4 }, recast = { MAGIC = 0 },
                magic = { spellGroup = { BLACK = 2 } }, attackType = { PHYSICAL = 1, MAGICAL = 2, RANGED = 3 },
                msg = { channel = { SYSTEM_3 = 29 }, basic = { NONE = 0, MAGIC_RESIST = 85,
                    MAGIC_UNABLE_TO_CAST = 17, UNABLE_TO_USE_JA = 87, JA_RECOVERS_MP = 451 } },
                combat = { magicHitRate = { calculateResistRate = function(_, target) return target.resist or 1 end } },
                spells = { damage = {
                    calculateNullification = function(target) return target.immune and 0 or 1 end,
                    calculateAbsorption = function() return 1 end,
                } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            function GetPlayerByID(id) return online[id] end
            function actor(id, mob)
                local e = { key = 'scourge', level = 10, mp = 20, vars = {}, party = {}, recasts = {},
                    isPC = function() return not mob end, isMob = function() return mob == true end,
                    isAlive = function() return true end, getID = function() return id end,
                    getName = function() return 'Enemy' end, getZoneID = function() return 1 end,
                    getMainJob = function() return 8 end, getMainLvl = function(self) return self.level end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end,
                    sendSoulSpellList = function() end, getParty = function(self) return self.party end,
                    getTarget = function(self) return self.target end, printToPlayer = function() end,
                    addRecast = function(self, _, spell, duration) self.recasts[spell] = duration end,
                    getMP = function(self) return self.mp end, getMaxMP = function() return 100 end,
                    addMP = function(self, n) self.mp = self.mp + n end,
                }
                if not mob then online[id] = e end
                return e
            end
            function spell(id)
                return { getID = function() return id end, setMsg = function(self, msg) self.msg = msg end }
            end
            ability = { setRecast = function(self, n) self.recast = n end, setCE = function() end, setVE = function() end }
            player, ally, outsider, rival, enemy = actor(1), actor(2), actor(3), actor(4), actor(9, true)
            player.party, player.target, rival.target = { ally }, enemy, enemy
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            local root = 'xi.actions.spells.black.'
            wither = overrides[root .. 'absorb-str.onSpellCast']
            ash = overrides[root .. 'bio.onSpellCast']
            famine = overrides[root .. 'absorb-mnd.onSpellCast']
            famineCheck = overrides[root .. 'absorb-mnd.onMagicCastingCheck']
            ashCheck = overrides[root .. 'bio.onMagicCastingCheck']
            damage = xi.soulspire.onPreTakeDamage
            heal = xi.soulspire.scourge.reduceSelfHeal
            riteCheck = overrides['xi.actions.abilities.arcane_circle.onAbilityCheck']
            rite = overrides['xi.actions.abilities.arcane_circle.onUseAbility']
            w, a, f = spell(266), spell(230), spell(271)
        """)

    def test_one_curse_resist_and_damage_category(self):
        self.lua.execute("""
            assert(famineCheck(player, enemy, f) == 17)
            wither(player, enemy, w)
            assert(hud(player).curse_kind == 1 and hud(player).curse_rem == 24)
            assert(ashCheck(player, enemy, a) == 17 and player.recasts[230] == 12)
            assert(riteCheck(player, player, ability) == 0 and ability.recast == 24)
            assert(rite(player, player, ability) == 14 and player.mp == 34)
            assert(damage(ally, 100, enemy, 1) == 100)
            enemy.vars.OX_SCR_ACTION = 1
            assert(damage(ally, 100, enemy, 1) == 92 and damage(ally, 100, enemy, 2) == 100)
            enemy.immune = true
            wither(rival, enemy, w)
            assert(hud(player).ward_rem == 0 and hud(player).curse_rem == 24)
            enemy.immune = false
            now, enemy.resist = 112, 0.25
            ash(player, enemy, a)
            assert(a.msg == 85 and hud(player).curse_kind == 1)
            enemy.resist = 0.5
            ash(rival, enemy, a)
            assert(hud(player).curse_kind == 2 and hud(player).curse_rem == 12)
            assert(damage(ally, 100, enemy, 1) == 100)
            enemy.vars.OX_SCR_ACTION = 2
            assert(damage(ally, 100, enemy, 2) == 92)
            rival.key = 'reaper'
            assert(damage(ally, 100, enemy, 2) == 100)
        """)

    def test_immune_fallback_is_party_scoped_and_single_use(self):
        self.lua.execute("""
            enemy.immune = true
            ash(player, enemy, a)
            assert(a.msg == 85 and hud(player).ward_kind == 2)
            ash(rival, enemy, a)
            assert(enemy.vars.OX_SCR_WARD_OWNER == 1)
            enemy.vars.OX_SCR_ACTION = 2
            assert(damage(outsider, 100, enemy, 2) == 100)
            assert(damage(ally, 100, enemy, 1) == 100)
            assert(damage(ally, 100, enemy, 2) == 96)
            assert(damage(ally, 100, enemy, 2) == 100 and hud(player).ward_rem == 0)
            now = 112
            ash(player, enemy, a)
            assert(hud(player).ward_rem == 0)
            now = 124
            ash(player, enemy, a)
            assert(hud(player).ward_rem == 8)
            now = 132
            assert(damage(ally, 100, enemy, 2) == 100)
        """)

    def test_famine_progression_and_standard_self_healing_only(self):
        self.lua.execute("""
            player.level = 75
            assert(famineCheck(player, enemy, f) == 0)
            famine(player, enemy, f)
            assert(heal(enemy, enemy, 100) == 100)
            enemy.vars.OX_SCR_ACTION = 1
            assert(heal(enemy, enemy, 100) == 70)
            assert(heal(enemy, ally, 100) == 100)
            player.key = 'dreadnought'
            assert(heal(enemy, enemy, 100) == 100)
            assert(famine(player, enemy, f) == 123)
        """)
