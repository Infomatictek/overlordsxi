"""Test Oathbreaker's vow lock, offensive payoffs and actual-loss trigger."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/pld_oathbreaker_specs.lua"
PATCH = ROOT / "patches/0055-oathbreaker-native-actions.patch"


class OathbreakerNativeTests(unittest.TestCase):
    def test_actual_loss_and_scoped_actions(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("const auto hpLost = hpBefore - health.hp", patch)
        self.assertIn('triggerListener("SOUL_DIRECT_HP_LOSS", this, attacker, hpLost)', patch)
        self.assertIn("return id == 46 || id == 48 || id == 255", patch)
        self.assertIn("PSpell->getID() == SpellID::Banish", patch)
        self.assertIn("oathbreaker::condemnBonus(character)", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class OathbreakerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, listeners = 100, {}, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
                'scripts/combat/physical_hit_rate', 'scripts/combat/physical_utilities', 'scripts/combat/basic/damage_multipliers',
            }) do
                package.preload[name] = function() return {} end
            end
            xi = {
                job = { PLD = 7 }, slot = { MAIN = 0 }, skill = { GREAT_SWORD = 4 },
                mod = { GREAT_SWORD = 1, STR = 2, ACC = 3, ATT = 4 },
                attackType = { PHYSICAL = 1 }, damageType = { SLASHING = 2 },
                msg = { basic = { UNABLE_TO_USE_JA = 87, HIT_MISS = 15, JA_DAMAGE = 110 } },
                combat = {
                    physicalHitRate = { getPhysicalHitRate = function() return 1 end },
                    physical = { calculateMeleePDIF = function() return 1 end },
                    damage = { calculateDamageAdjustment = function() return 1 end, physicalElementSDT = function() return 1 end },
                },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            utils = {
                handlePhalanx = function(_, d) return d end, handleStoneskin = function(_, d) return d end,
                clamp = function(d, lo, hi) return math.max(lo, math.min(d, hi)) end,
            }
            super = function() return 123 end
            player = {
                key = 'oathbreaker', level = 10, weapon = 4, enmity = false, vars = {},
                isPC = function() return true end, getMainJob = function() return 7 end,
                getMainLvl = function(self) return self.level end,
                getWeaponSkillType = function(self) return self.weapon end,
                getMaxHP = function() return 1000 end,
                isEngaged = function() return false end, hasEnmity = function(self) return self.enmity end,
                getLocalVar = function(self, k) return self.vars[k] or 0 end,
                setLocalVar = function(self, k, v) self.vars[k] = v end,
                addListener = function(_, _, key, fn) listeners[key] = fn end,
                removeListener = function(_, key) listeners[key] = nil end,
                sendSoulSpellList = function() end,
                checkDistance = function(_, target) return target.distance end,
                getWeaponDmg = function() return 20 end, getStat = function() return 20 end,
                getTarget = function(self) return self.target end,
            }
            function mob(id)
                return { life = 1000, distance = 3, isMob = function() return true end,
                    isAlive = function(self) return self.life > 0 end, getID = function() return id end,
                    getHP = function(self) return self.life end, checkDamageCap = function(_, d) return d end,
                    takeDamage = function(self, d) self.life = self.life - d end,
                    updateEnmityFromDamage = function(self, _, d) self.damageEnmity = d end,
                }
            end
            enemy, other = mob(9), mob(10)
            player.target = enemy
            ability = {
                setRecast = function(self, sec) self.recast = sec end,
                setRange = function() end, setCE = function() end, setVE = function() end,
            }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))

    def test_vow_lock_retaliation_and_target_mismatch(self):
        self.lua.execute("""
            crystal.onApply(player)
            local check = overrides['xi.actions.abilities.divine_emblem.onAbilityCheck']
            local absolve = overrides['xi.actions.abilities.divine_emblem.onUseAbility']
            local reckon = overrides['xi.actions.abilities.shield_bash.onUseAbility']
            assert(hud(player).vow == 1 and xi.soulspire.onPreTakeDamage(player, 100, enemy, 1) == 110)
            player.enmity = true
            assert(check(player, player, ability) == 87)
            player.enmity = false
            assert(check(player, player, ability) == 0 and ability.recast == 5)
            absolve(player, player, ability)
            assert(hud(player).vow == 2 and xi.soulspire.onPreTakeDamage(player, 100, enemy, 1) == 100)
            local hpLoss = listeners.OX_OTB_TAKE_HP
            hpLoss(player, enemy, 79)
            assert(hud(player).retaliate_rem == 0)
            hpLoss(player, enemy, 80)
            assert(hud(player).retaliate_rem == 5)
            assert(reckon(player, other, ability) == 37 and hud(player).retaliate_rem == 5)
            math.random = function() return 0.5 end
            assert(reckon(player, enemy, ability) == 75 and hud(player).retaliate_rem == 0)
            crystal.onRemove(player)
            assert(listeners.OX_OTB_TAKE_HP == nil)
        """)

    def test_reckoning_validates_weapon_and_range(self):
        self.lua.execute("""
            local check = overrides['xi.actions.abilities.shield_bash.onAbilityCheck']
            player.weapon = 3
            assert(check(player, enemy, ability) == 87)
            player.weapon, enemy.distance = 4, 5
            assert(check(player, enemy, ability) == 87)
            enemy.distance = 4
            assert(check(player, enemy, ability) == 0 and ability.recast == 18)
            player.key = 'defender'
            assert(check(player, enemy, ability) == 123)
        """)
