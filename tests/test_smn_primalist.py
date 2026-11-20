"""Verify loaned avatars and the one-pact elemental Challenge."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/smn_primalist_specs.lua"
PATCH = ROOT / "patches/0067-primalist-native-actions.patch"


class PrimalistNativeTests(unittest.TestCase):
    def test_temporary_summons_and_native_matching_pact(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("primalist::spellLevel(this, PSpell->getID())", patch)
        self.assertIn("m_primalistCast == primalist::isActive(caster)", patch)
        self.assertIn("allowedPact != 0 && allowedPact == PAbility->getID()", patch)
        self.assertIn("pact - ABILITY_HEALING_RUBY", patch)
        self.assertIn("primalist.pactCost(player, ability:getID())", patch)
        self.assertNotIn("addSpell(", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class PrimalistRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            now, overrides, entities = 100, {}, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
                'scripts/globals/pets', 'scripts/globals/job_utils/summoner',
            }) do package.preload[name] = function() return {} end end
            package.preload['modules/custom/lua/soulspire_soul_actions'] = function()
                return { register = function(_, data) catalog = data end }
            end
            xi = {
                job = { SMN = 15 }, petId = { CARBUNCLE = 8, IFRIT = 10, TITAN = 11, LEVIATHAN = 12, GARUDA = 13, SHIVA = 14, RAMUH = 15 },
                element = { FIRE = 1, ICE = 2, WIND = 3, EARTH = 4, THUNDER = 5, WATER = 6, LIGHT = 7, DARK = 8 },
                mod = { SUMMONING_MAGIC_SKILL = 1, MPP = 2, PERPETUATION_REDUCTION = 3 },
                msg = { basic = { UNABLE_TO_USE_JA = 87, NONE = 0, USES_JA_TAKE_DAMAGE = 1 } },
                attackType = { MAGICAL = 2 }, damageType = { ELEMENTAL = 8 },
                action = { category = { PET_MOBABILITY_FINISH = 11 } },
                data = { element = { getElementalResistanceRankModifier = function(e) return e end } },
                mobskills = { shadowBehavior = { IGNORE_SHADOWS = 1 },
                    mobMagicalMove = function(_, _, _, _, params)
                        return { damage = 100, attackType = params.attackType, damageType = params.damageType }
                    end,
                    processDamage = function() return true end,
                },
                job_utils = { summoner = { onUseBloodPact = function(_, _, skill, p)
                    p.mp = p.mp - xi.soulspire.primalist.pactCost(p, skill)
                end } },
                soulspire = { nowSec = function() return now end,
                    spec = { is = function(p, _, k) return p.key == k end,
                        registerCrystal = function(_, data) crystal = data end },
                    hud = { registerProvider = function(_, fn) hud = fn end },
                },
            }
            function actor(id, tag)
                local entity = {
                    key = 'primalist', level = 10, zone = 1, battle = 0, vars = {}, mods = {}, char = {},
                    mp = 100, timers = {}, alive = true,
                    isPC = function() return tag == 'player' end, isMob = function() return tag == 'mob' end,
                    getMaster = function() end, isAlive = function(self) return self.alive end,
                    getID = function() return id end, getZoneID = function(self) return self.zone end,
                    getBattleID = function(self) return self.battle end, getMainJob = function() return 15 end,
                    getMainLvl = function(self) return self.level end, getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end, getPetID = function(self) return self.kind end,
                    getPet = function(self) return self.pet end, getMod = function(self, k) return self.mods[k] or 0 end,
                    getMP = function(self) return self.mp end, getCurrentAction = function(self) return self.state or 0 end,
                    getCharVar = function(self, k) return self.char[k] or 0 end,
                    setCharVar = function(self, k, v) self.char[k] = v end,
                    checkDistance = function() return 10 end,
                    timer = function(self, delay, fn) self.timers[delay] = fn end,
                    despawnPet = function(self) self.pet = nil end, sendSoulSpellList = function() end,
                    petAttack = function(self, target) self.pet.target = target end,
                    takeDamage = function(self, n, _, _, damageType) self.last, self.kind = n, damageType end,
                }
                entities[id] = entity
                return entity
            end
            GetMobByID = function(id) return entities[id] end
            super = function() return 321 end
            ability = { setMsg = function() end }
            p, enemy, alternate = actor(1, 'player'), actor(4, 'mob'), actor(5, 'mob')
            ifrit = actor(10, 'pet')
            ifrit.kind, p.pet = 10, ifrit
            enemy.vars.OX_ARC_SPAWN = 1
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            crystal.onApply(p)
            challenge = overrides['xi.actions.abilities.assault.onUseAbility']
            rage = overrides['xi.actions.abilities.pets.fire_ii.onPetAbility']
            lightRage = overrides['xi.actions.abilities.pets.meteorite.onPetAbility']
        """)

    def test_level_ten_matching_damage_and_one_pact_consumption(self):
        self.lua.execute("""
            assert(catalog.spell[296].unlockLvl == 10 and catalog.spell[298].unlockLvl == 10)
            assert(challenge(p, enemy) == 0 and ifrit.target == enemy and hud(p).match == 1)
            assert(rage(alternate, ifrit, 545, p) == 100 and hud(p).window == 12)
            assert(lightRage(enemy, ifrit, 516, p) == 0 and p.mp == 92)
            assert(rage(enemy, ifrit, 545, p) == 120 and p.mp == 84)
            assert(hud(p).window == 0 and enemy.kind == 9)
            assert(rage(enemy, ifrit, 545, p) == 100)
        """)

    def test_resistance_snapshot_spawn_and_expiry(self):
        self.lua.execute("""
            p.level, enemy.mods[1] = 75, 3
            challenge(p, enemy)
            assert(hud(p).window == 15 and hud(p).match == 0)
            assert(rage(enemy, ifrit, 545, p) == 100 and hud(p).window == 0)
            challenge(p, enemy)
            enemy.mods[1] = -2
            assert(hud(p).match == 1)
            enemy.vars.OX_ARC_SPAWN = 2
            assert(rage(enemy, ifrit, 545, p) == 100)
            challenge(p, enemy)
            now = 116
            assert(hud(p).window == 0 and rage(enemy, ifrit, 545, p) == 100)
            assert(rage(enemy, ifrit, 545, p) == 0)
        """)

    def test_avatar_identity_loan_choices_and_soul_switch(self):
        self.lua.execute("""
            p.level = 30
            crystal.onApply(p)
            assert(hud(p).choice == 'Shiva / Garuda')
            challenge(p, enemy)
            overrides['xi.actions.abilities.elemental_siphon.onUseAbility'](p, p, ability)
            assert(hud(p).choice == 'Ramuh / Garuda' and hud(p).window == 0)
            overrides['xi.actions.abilities.mana_cede.onUseAbility'](p, p, ability)
            assert(hud(p).choice == 'Ramuh / Shiva')
            assert(catalog.spell[303].unlockLvl == 30)
            crystal.onRemove(p)
            assert(p.pet == nil)
            p.key = 'celestial'
            assert(rage(enemy, ifrit, 545, p) == 321 and xi.soulspire.primalist.pactCost(p,545) == nil)
        """)
