"""Exercise Reaper's personal finishing window and native action contract."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/drk_reaper_specs.lua"
PATCH = ROOT / "patches/0056-reaper-native-actions.patch"


class ReaperNativeTests(unittest.TestCase):
    def test_native_events_and_action_isolation(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn('attacker->GetLocalVar("OX_RPR_ACTION") == 1', patch)
        self.assertEqual(patch.count("const reaper::ObserveEnemyAction observe(*this)"), 3)
        self.assertIn("rounds >= 6", patch)
        self.assertIn("m_reaperCast == reaper::isActive(caster)", patch)
        self.assertIn("PAbility->getID() != reaper::Finality", patch)
        self.assertIn("m_PSpell->setMPCost(12)", patch)
        self.assertIn("xi::SkillType::Scythe", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class ReaperRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides = 100, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
                'scripts/globals/spells/damage_spell', 'scripts/combat/basic/magic_hit_rate',
                'scripts/combat/physical_hit_rate', 'scripts/combat/physical_utilities', 'scripts/combat/basic/damage_multipliers',
            }) do
                package.preload[name] = function() return {} end
            end
            local function unit() return 1 end
            xi = {
                job = { DRK = 8 }, slot = { MAIN = 0 }, skill = { SCYTHE = 7, DARK_MAGIC = 43 },
                mod = { SCYTHE = 1, STR = 2, ACC = 3, ATT = 4, INT = 5 },
                element = { DARK = 8 }, magic = { spellGroup = { BLACK = 2 } },
                attackType = { PHYSICAL = 1, MAGICAL = 2 }, damageType = { SLASHING = 2, DARK = 13 },
                msg = { basic = { UNABLE_TO_USE_JA = 87, HIT_MISS = 15, JA_DAMAGE = 110, MAGIC_DMG = 2, MAGIC_RESIST = 85 } },
                combat = {
                    physicalHitRate = { getPhysicalHitRate = function() return hitRate end },
                    physical = { calculateMeleePDIF = unit }, magicHitRate = { calculateResistRate = unit },
                    damage = { calculateDamageAdjustment = unit, physicalElementSDT = unit, magicalElementSDT = unit },
                },
                spells = { damage = { calculateNullification = unit, calculateAbsorption = unit, calculateAdditionalResistTier = unit } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            local function identity(_, d) return d end
            utils = {
                handlePhalanx = identity, handleStoneskin = identity, handleOneForAll = identity,
                clamp = function(d, lo, hi) return math.max(lo, math.min(d, hi)) end,
            }
            super = function() return 123 end
            hitRate = 1
            function character()
                return {
                    key = 'reaper', level = 10, weapon = 7, vars = {},
                    isPC = function() return true end, getMainJob = function() return 8 end,
                    getMainLvl = function(self) return self.level end,
                    getWeaponSkillType = function(self) return self.weapon end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end,
                    sendSoulSpellList = function() end,
                    checkDistance = function(_, target) return target.distance end,
                    getWeaponDmg = function() return 20 end, getStat = function() return 20 end,
                    getSkillLevel = function() return 28 end, getTarget = function(self) return self.target end,
                }
            end
            function mob(id)
                return { life = 1000, distance = 4, vars = {}, isMob = function() return true end,
                    isAlive = function(self) return self.life > 0 end, getID = function() return id end,
                    getHP = function(self) return self.life end, getHPP = function(self) return self.life / 10 end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    checkDamageCap = function(_, d) return d end, handleAfflatusMiseryDamage = function() end,
                    takeDamage = function(self, d) self.life = self.life - d end,
                    takeSpellDamage = function(self, _, _, d) self.life = self.life - d end,
                    updateEnmityFromDamage = function() end,
                }
            end
            player, teammate, enemy, other = character(), character(), mob(9), mob(10)
            player.target, teammate.target = enemy, enemy
            ability = { setRecast = function(self, sec) self.recast = sec end,
                setRange = function() end, setCE = function() end, setVE = function() end }
            spell = { setMsg = function(self, msg) self.msg = msg end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            check = overrides['xi.actions.abilities.weapon_bash.onAbilityCheck']
            finish = overrides['xi.actions.abilities.weapon_bash.onUseAbility']
            toll = overrides['xi.actions.spells.black.drain.onSpellCast']
        """)

    def test_opening_is_target_specific_and_personal(self):
        self.lua.execute("""
            assert(check(player, enemy, ability) == 0 and ability.recast == 16)
            enemy.vars.OX_RPR_OPEN_UNTIL = 105
            enemy.vars.OX_RPR_ROUNDS = 2
            assert(hud(player).recovery == 5 and hud(player).enemy_rounds == 2)
            assert(finish(player, other, ability) == 32)
            hitRate = 0
            assert(finish(player, enemy, ability) == 0 and hud(player).finality_cd == 16)
            assert(hud(player).recovery == 5)
            hitRate = 1
            assert(finish(player, enemy, ability) == 57 and hud(player).recovery == 0)
            assert(hud(teammate).recovery == 5 and finish(teammate, enemy, ability) == 57)
        """)

    def test_low_hp_progression_and_grave_toll(self):
        self.lua.execute("""
            assert(toll(player, enemy, spell) == 19 and spell.msg == 2)
            enemy.vars.OX_RPR_OPEN_UNTIL = 105
            assert(toll(player, enemy, spell) == 28 and hud(player).recovery == 5)
            player.level, enemy.life = 75, 240
            assert(finish(player, enemy, ability) == 90)
            now = 105
            assert(hud(teammate).recovery == 0)
            player.key = 'dreadnought'
            assert(toll(player, enemy, spell) == 123 and check(player, enemy, ability) == 123)
        """)
