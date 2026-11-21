"""Check Untamed's starter summon, bilateral TP, and native command gating."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/bst_untamed_specs.lua"
PATCH = ROOT / "patches/0065-untamed-native-actions.patch"


class UntamedNativeTests(unittest.TestCase):
    def test_foot_kick_is_the_only_pack_skill(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertEqual(patch.count("addPetAbility(PChar, ABILITY_FOOT_KICK - ABILITY_HEALING_RUBY)"), 1)
        self.assertIn("xi::Job::BST, 10, 3, 30s", patch)
        self.assertIn("PPet->getPetType() == PET_TYPE::JUG_PET && PetID == PETID_HARE_FAMILIAR", patch)
        self.assertIn("m_untamedAbility != currentUntamed", patch)
        self.assertIn("PSpell->getSpellGroup() != SPELLGROUP_TRUST", patch)
        self.assertIn("xi::SkillType::GreatAxe", patch)

    def test_module_does_not_require_nonexistent_globals_utils(self):
        self.assertNotIn("scripts/globals/utils", MODULE.read_text(encoding="utf-8"))


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class UntamedRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            now, overrides = 100, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
                'scripts/globals/pets',
            }) do package.preload[name] = function() return {} end end
            package.preload['modules/custom/lua/soulspire_soul_actions'] = function()
                return { register = function(_, data) catalog = data end }
            end
            xi = {
                job = { BST = 9 }, skill = { AXE = 5, GREAT_AXE = 6 }, slot = { MAIN = 0 },
                petId = { HARE_FAMILIAR = 22 },
                mod = { ACC = 1, ATT = 2, DOUBLE_ATTACK = 3, AXE = 4, GREAT_AXE = 5, STORETP = 6, STR = 7 },
                msg = { basic = { UNABLE_TO_USE_JA = 87, HIT_MISS = 15, JA_DAMAGE = 77 } },
                attackType = { PHYSICAL = 1 }, damageType = { SLASHING = 1 },
                pet = { spawnPet = function(p, id) p.pet = actor(22, false, true); p.pet.kind = id end },
                soulspire = { nowSec = function() return now end,
                    spec = { is = function(p, _, k) return p.key == k end,
                        registerCrystal = function(_, data) crystal = data end },
                    hud = { registerProvider = function(_, fn) hud = fn end },
                },
                combat = {
                    physicalHitRate = { getPhysicalHitRate = function() return 1 end },
                    physical = { calculateMeleePDIF = function() return 1 end },
                    damage = { calculateDamageAdjustment = function() return 1 end, physicalElementSDT = function() return 1 end },
                },
            }
            utils = { clamp = function(d) return d end, handlePhalanx = function(_, d) return d end,
                handleStoneskin = function(_, d) return d end }
            function actor(id, mob, pet)
                return {
                    key = 'untamed', level = 10, weapon = 5, zone = 1, tp = 0, hp = 100, vars = {}, mods = {}, listeners = {},
                    isPC = function() return not mob and not pet end, isMob = function() return mob == true end,
                    isAlive = function(self) return self.hp > 0 end, getID = function() return id end,
                    getZoneID = function(self) return self.zone end, getMainJob = function() return 9 end,
                    getMainLvl = function(self) return self.level end, getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end, getPetID = function(self) return self.kind end,
                    getPet = function(self) return self.pet end, hasJugPet = function(self) return self.pet ~= nil end,
                    getTP = function(self) return self.tp end, addTP = function(self, n) self.tp = math.min(3000, self.tp + n) end,
                    getTarget = function(self) return self.target end, getWeaponSkillType = function(self) return self.weapon end,
                    addMod = function(self, k, v) self.mods[k] = (self.mods[k] or 0) + v end,
                    addListener = function(self, _, k, fn) self.listeners[k] = fn end,
                    removeListener = function(self, k) self.listeners[k] = nil end,
                    despawnPet = function(self) self.pet = nil end, sendSoulSpellList = function() end,
                    getWeaponDmg = function() return 10 end, getStat = function() return 16 end,
                    checkDamageCap = function(_, d) return d end, getHP = function(self) return self.hp end,
                    takeDamage = function(self, d) self.hp = math.max(0, self.hp - d) end,
                    updateEnmityFromDamage = function() end,
                }
            end
            p, enemy = actor(1), actor(2, true)
            super = function() return 321 end
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            crystal.onApply(p)
            call = overrides['xi.actions.abilities.call_beast.onUseAbility']
            callCheck = overrides['xi.actions.abilities.call_beast.onAbilityCheck']
            rend = overrides['xi.actions.abilities.charm.onUseAbility']
            kick = overrides['xi.actions.abilities.pets.foot_kick.onPetAbility']
            call(p)
            beast = p.pet
            p.target, beast.target = enemy, enemy
        """)

    def test_level_ten_rend_and_ready_are_independent(self):
        self.lua.execute("""
            assert(beast.kind == 22 and beast.mods[1] == 10)
            assert(callCheck(p) == 87)
            assert(rend(p, enemy) > 0 and beast.tp == 125)
            assert(hud(p).shared == 1 and hud(p).to_pet == 8)
            assert(rend(p, enemy) > 0 and beast.tp == 125)
            super = function(target) target:takeDamage(1); return 1 end
            assert(kick(enemy, beast, nil, p) == 1 and p.tp == 75)
            assert(hud(p).to_master == 8)
            kick(enemy, beast, nil, p)
            assert(p.tp == 75)
        """)

    def test_target_damage_weapon_and_lifecycle_guards(self):
        self.lua.execute("""
            local ws = p.listeners.OX_UNT_AXE_WS
            ws(p, enemy, nil, 1000, nil, 0)
            assert(beast.tp == 0)
            p.target = actor(3, true)
            ws(p, enemy, nil, 1000, nil, 1)
            assert(beast.tp == 0)
            p.target, p.weapon = enemy, 3
            ws(p, enemy, nil, 1000, nil, 1)
            assert(beast.tp == 0)
            p.weapon, p.level = 6, 75
            ws(p, enemy, nil, 1000, nil, 1)
            assert(beast.tp == 275)
            super = function() return 100 end
            kick(enemy, beast, nil, p)
            assert(p.tp == 0)
            crystal.onApply(p)
            assert(beast.mods[1] == 40)
            crystal.onRemove(p)
            assert(p.pet == nil and beast.mods[1] == 0 and p.listeners.OX_UNT_AXE_WS == nil)
            p.key = 'alphawarden'
            super = function() return 321 end
            assert(call(p) == 321 and rend(p, enemy) == 321)
        """)

    def test_later_unlock(self):
        self.lua.execute("""
            assert(#crystal.extraAbilities(p, 9) == 0)
            assert(crystal.extraAbilities(p, 10)[8] == 672)
            assert(crystal.extraAbilities(p, 30)[9] == 387)
            assert(catalog.ability[672].name == 'Raking Kick')
        """)
