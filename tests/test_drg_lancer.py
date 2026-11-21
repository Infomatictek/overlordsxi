"""Verify Lancer's launch lanes, safe landing contract and jump follow-up."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/drg_lancer_specs.lua"
PATCH = ROOT / "patches/0061-lancer-native-vault.patch"


class LancerNativeTests(unittest.TestCase):
    def test_native_terrain_and_exact_ability_path(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("player->CanSeeTarget(target)", patch)
        self.assertIn("player->entityId().instanceRunId != target->entityId().instanceRunId", patch)
        self.assertIn("mesh->findClosestValidPoint", patch)
        self.assertIn("mesh->moveAlongSurface", patch)
        self.assertIn("player->CanSeeTarget(reached)", patch)
        self.assertIn("PAbility->getID() == lancer::Vault", patch)
        self.assertIn("action.recast = PAbility->getRecastTime()", patch)
        self.assertIn("params.lancerFollowup = lancer.jumpBonus(player, target)", patch)
        self.assertIn("hpBefore > defender:getHP()", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class LancerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, accuracy = 100, {}, 1
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
                'scripts/combat/physical_hit_rate', 'scripts/combat/physical_utilities', 'scripts/combat/basic/damage_multipliers',
            }) do
                package.preload[name] = function() return {} end
            end
            local function unit() return 1 end
            xi = {
                job = { DRG = 14 }, slot = { MAIN = 0 }, skill = { POLEARM = 8 },
                mod = { POLEARM = 1, STR = 2, ACC = 3, ATT = 4 },
                attackType = { PHYSICAL = 1 }, damageType = { PIERCING = 1 },
                msg = { channel = { SYSTEM_3 = 29 },
                    basic = { NONE = 0, HIT_MISS = 15, UNABLE_TO_USE_JA = 87, JA_DAMAGE = 110, JA_RECOVERS_HP = 102 } },
                combat = {
                    physicalHitRate = { getPhysicalHitRate = function() return accuracy end },
                    physical = { calculateMeleePDIF = unit }, damage = { physicalElementSDT = unit },
                },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            local function identity(_, d) return d end
            utils = { handlePhalanx = identity, handleStoneskin = identity,
                clamp = function(d, lo, hi) return math.max(lo, math.min(d, hi)) end }
            super = function() return 123 end
            player = { key = 'lancer', level = 10, weapon = 8, vars = {},
                isPC = function() return true end, getMainJob = function() return 14 end,
                getMainLvl = function(self) return self.level end,
                getLocalVar = function(self, k) return self.vars[k] or 0 end,
                setLocalVar = function(self, k, v) self.vars[k] = v end,
                getWeaponSkillType = function(self) return self.weapon end, getWeaponDmg = function() return 20 end,
                getStat = function() return 20 end, checkDistance = function(_, enemy) return enemy.distance end,
                getLancerLanding = function(self) return self.landing end,
                setPos = function(self, x, y, z) self.moved = { x, y, z } end,
                getPet = function(self) return self.pet end, despawnPet = function(self) self.pet = nil end,
                getTarget = function(self) return self.target end, printToPlayer = function() end,
                sendSoulSpellList = function() end,
            }
            function mob(id)
                return { life = 1000, distance = 6, isMob = function() return true end,
                    isAlive = function(self) return self.life > 0 end, getID = function() return id end,
                    getHP = function(self) return self.life end, checkDamageCap = identity,
                    physicalDmgTaken = function(self, d) return self.absorbs and -d or d end,
                    addHP = function(self, d) self.life = self.life + d; return d end,
                    takeDamage = function(self, d) self.life = self.life - d end,
                    updateEnmityFromDamage = function(self, _, d) self.lastEnmity = d end,
                }
            end
            player.target, other = mob(9), mob(10)
            enemy = player.target
            ability = { setRecast = function(self, sec) self.recast = sec end, setMsg = function() end,
                setRange = function() end, setCE = function() end, setVE = function() end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            check = overrides['xi.actions.abilities.high_jump.onAbilityCheck']
            vault = overrides['xi.actions.abilities.high_jump.onUseAbility']
            jump = xi.soulspire.lancer
        """)

    def test_range_blocked_and_level_ten_lanes(self):
        self.lua.execute("""
            enemy.distance = 3.99
            assert(check(player, enemy, ability) == 87)
            enemy.distance = 12.01
            assert(check(player, enemy, ability) == 87)
            enemy.distance = 4
            assert(check(player, enemy, ability) == 0)
            assert(vault(player, enemy, ability) == 0 and ability.recast == 3 and player.moved == nil)
            assert(enemy.life == 1000 and hud(player).vault_cd == 3)
            player.landing = { x = 5, y = 0, z = 3 }
            enemy.distance = 7
            assert(vault(player, enemy, ability) == 40 and ability.recast == 18)
            assert(player.moved[1] == 5 and enemy.lastEnmity == 40)
            enemy.distance = 7.01
            assert(vault(player, enemy, ability) == 55 and jump.jumpBonus(player, enemy) == 0)
        """)

    def test_followup_scope_miss_absorb_and_cleanup(self):
        self.lua.execute("""
            player.level, enemy.distance = 75, 10
            player.landing = { x = 5, y = 0, z = 3 }
            accuracy = 0
            assert(vault(player, enemy, ability) == 0 and jump.jumpBonus(player, enemy) == 0)
            accuracy, enemy.absorbs = 1, true
            assert(vault(player, enemy, ability) == 70 and jump.jumpBonus(player, enemy) == 0)
            enemy.absorbs = false
            assert(vault(player, enemy, ability) == 70 and jump.jumpBonus(player, enemy) == 20)
            assert(jump.jumpBonus(player, other) == 0 and hud(player).followup == 5)
            jump.finishJump(player)
            assert(hud(player).followup == 0)
            player.pet = {}
            crystal.onApply(player)
            assert(player.pet == nil and crystal.extraAbilities(player, 10)[2] == 67)
            player.key = 'wyvernheart'
            assert(vault(player, enemy, ability) == 123 and jump.jumpBonus(player, enemy) == 0)
        """)
