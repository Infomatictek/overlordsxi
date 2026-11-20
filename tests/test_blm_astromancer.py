"""Verify Astromancer's native action and shared Saturation contracts."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/blm_astromancer_specs.lua"
PATCH = ROOT / "patches/0048-astromancer-native-actions.patch"


class AstromancerNativeTests(unittest.TestCase):
    def test_native_grants_and_damage_commit(self):
        patch = PATCH.read_text(encoding="utf-8")
        lua = MODULE.read_text(encoding="utf-8")
        self.assertIn("{ 169, 'water',    'Tsunami'", lua)
        self.assertIn("case SpellID::Stone_II:  return { 10,   0, 16, 18, true }", patch)
        self.assertIn("return { 50, 0, 22, 18, true };", patch)
        self.assertIn("(!profile.ancient || astromancer::ancientReady(this))", patch)
        self.assertIn("m_astromancerCast == astromancer::isActive(caster)", patch)
        self.assertIn("hpBefore - target:getHP()", patch)
        self.assertIn('SetLocalVar("OX_AST_SATURATION", 0)', patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class AstromancerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides = 100, {}
            super = function() return 123 end
            Module = { new = function() return {
                addOverride = function(_, name, fn) overrides[name] = fn end,
            } end }
            for _, key in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs',
                'scripts/globals/player', 'scripts/globals/spells/damage_spell',
            }) do
                package.preload[key] = function() return {} end
            end
            xi = {
                element = { FIRE = 1, ICE = 2, WIND = 3, EARTH = 4, THUNDER = 5, WATER = 6 },
                job = { BLM = 4 },
                mod = {
                    FIRE_RES_RANK = 1, ICE_RES_RANK = 2, WIND_RES_RANK = 3,
                    EARTH_RES_RANK = 4, THUNDER_RES_RANK = 5, WATER_RES_RANK = 6,
                    INT = 7, MATT = 8, MACC = 9, MPP = 10,
                },
                msg = { basic = { CANNOT_CAST_SPELL = 1, UNABLE_TO_USE_JA = 87 }, channel = { SYSTEM_3 = 1 } },
                soulspire = {
                    nowSec = function() return now end,
                    spec = {
                        is = function(p, _, key) return p.key == key end,
                        registerCrystal = function(_, entry) crystal = entry end,
                    },
                    hud = { registerProvider = function(_, fn) hud = fn end },
                },
            }
            function entity(id, isPC, key)
                return {
                    id = id, vars = {}, level = 10, mp = 50, nm = false, key = key, maxHP = 1000,
                    isPC = function() return isPC end, isMob = function() return not isPC end,
                    isAlive = function() return true end,
                    getID = function(self) return self.id end,
                    getZoneID = function() return 5 end,
                    getMainLvl = function(self) return self.level end,
                    getMainJob = function() return 4 end,
                    getMP = function(self) return self.mp end, getMaxMP = function() return 200 end,
                    addMP = function(self, mp) self.mp = self.mp + mp end,
                    isNM = function(self) return self.nm end,
                    getMaxHP = function(self) return self.maxHP end,
                    getMod = function(_, mod) return (mod == 2 or mod == 6) and -2 or 0 end,
                    getLocalVar = function(self, name) return self.vars[name] or 0 end,
                    setLocalVar = function(self, name, val) self.vars[name] = val end,
                    sendSoulSpellList = function() end,
                    printToPlayer = function(self, message) self.message = message end,
                    getTarget = function(self) return self.target end,
                }
            end
            p1, p2, other = entity(1, true, 'astromancer'), entity(2, true, 'astromancer'), entity(3, true, 'necromancer')
            boss, second = entity(4, false), entity(5, false)
            p1.target, p2.target = boss, boss
            spell = {
                id = 160, getID = function(self) return self.id end,
                setCastTime = function(self, time) self.time = time end,
                setElement = function(self, element) self.element = element end,
                setMsg = function(self, msg) self.msg = msg end,
            }
            ability = {
                setRecast = function(self, seconds) self.recast = seconds end,
                setCE = function() end, setVE = function() end,
            }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))

    def test_level_ten_alignment_and_recovery(self):
        self.lua.execute("""
            local api = xi.soulspire.blmAstromancerSpecs
            local check = overrides['xi.actions.spells.black.stone_ii.onMagicCastingCheck']
            local cast = overrides['xi.actions.spells.black.stone_ii.onSpellCast']
            assert(check(p1, boss, spell) == 0 and spell.time == 4500 and spell.element == 4)
            spell.id = 169
            api.onNukeDamage(p1, boss, spell, 0)
            assert(hud(p1).element == 4)
            api.onNukeDamage(p1, boss, spell, 10)
            assert(hud(p1).element == 6 and check(p1, boss, spell) == 0 and spell.element == 6)
            spell.id = 160
            assert(api.basePower(p1, spell.id, 78) == 20 and api.basePower(other, spell.id, 78) == 78)
            assert(cast(p1, boss, spell) == 123 and hud(p1).recovery_cd == 18)
            assert(cast(other, boss, spell) == 123 and other:getLocalVar('OX_AST_RECOVERY') == 0)
            assert(crystal.extraAbilities(p1, 10)[1] == 75)
            local gatherCheck = overrides['xi.actions.abilities.elemental_seal.onAbilityCheck']
            local gatherCast = overrides['xi.actions.abilities.elemental_seal.onUseAbility']
            assert(gatherCheck(p1, p1, ability) == 0 and ability.recast == 90)
            gatherCast(p1, p1, ability)
            assert(p1.mp == 70)
        """)

    def test_saturation_is_target_local_and_bonus_only(self):
        self.lua.execute("""
            local api = xi.soulspire.blmAstromancerSpecs
            assert(api.adjustDamage(p1, boss, spell, 100) == 300)
            api.onNukeDamage(p1, boss, spell, 0)
            assert(hud(p1).sat_rem == 0)
            api.onNukeDamage(p1, boss, spell, 300)
            assert(hud(p2).sat_rem == 20)
            assert(api.adjustDamage(p2, boss, spell, 100) == 120)
            assert(api.adjustDamage(p2, second, spell, 100) == 300)
            assert(api.adjustDamage(other, boss, spell, 100) == 100)
            now = now + 12
            api.onNukeDamage(p2, boss, spell, 120)
            assert(hud(p1).sat_rem == 8)
            now = now + 8
            assert(api.adjustDamage(p2, boss, spell, 100) == 300)
            spell.id, boss.nm = 214, true
            p1.level = 75
            assert(api.adjustDamage(p1, boss, spell, 100) == 130)
            boss.maxHP = 2000
            assert(api.adjustDamage(p1, boss, spell, 100) == 130)
        """)

    def test_survey_and_advanced_spell_levels(self):
        self.lua.execute("""
            local surveyCheck = overrides['xi.actions.spells.black.burn.onMagicCastingCheck']
            local surveyCast = overrides['xi.actions.spells.black.burn.onSpellCast']
            local ancientCheck = overrides['xi.actions.spells.black.flood.onMagicCastingCheck']
            assert(surveyCheck(p1, boss, spell) == 1)
            p1.level = 30
            assert(surveyCheck(p1, boss, spell) == 0 and spell.time == 1000)
            surveyCast(p1, boss, spell)
            assert(p1.message:find('Ice, Water', 1, true) and spell.msg == 0)
            assert(ancientCheck(p1, boss, spell) == 1)
            p1.level = 50
            assert(ancientCheck(p1, boss, spell) == 0 and spell.time == 7000)
        """)
