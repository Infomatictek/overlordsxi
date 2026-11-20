"""Verify Herald's party snapshot, elemental claims, and shared pet accounting."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/smn_herald_specs.lua"
PATCH = ROOT / "patches/0068-herald-native-actions.patch"


class HeraldNativeTests(unittest.TestCase):
    def test_settlement_targets_real_spells_weaponskills_and_pets(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("heraldPactID != 0 && heraldPactID == PAbility->getID()", patch)
        self.assertIn("herald.reserve(caster, target, spellElement, finalDamage, ordinaryDamage)", patch)
        self.assertIn("herald.finish(accord, hpBefore - target:getHP())", patch)
        self.assertIn("herald.reserve(attacker, defender, element, finaldmg)", patch)
        self.assertEqual(patch.count("damage = herald::settlePetDamage("), 2)
        self.assertNotIn("combat/skillchain.lua", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class HeraldRuntimeTests(unittest.TestCase):
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
                mobskills = { shadowBehavior = { IGNORE_SHADOWS = 1 },
                    mobMagicalMove = function(_, _, _, _, params)
                        return { damage = 100, attackType = params.attackType, damageType = params.damageType }
                    end,
                    processDamage = function(actor, target, _, _, info)
                        info.damage = xi.soulspire.herald.preparePetClaim(actor, target, info.damageType - 8, info.damage)
                        return true
                    end,
                },
                job_utils = { summoner = { onUseBloodPact = function(_, _, skill, p)
                    p.mp = p.mp - xi.soulspire.herald.pactCost(p, skill)
                end } },
                soulspire = { nowSec = function() return now end,
                    spec = { is = function(p, _, k) return p.key == k end,
                        registerCrystal = function(_, data) crystal = data end },
                    hud = { registerProvider = function(_, fn) hud = fn end },
                },
            }
            function actor(id, tag)
                local entity = {
                    key = 'herald', level = 10, zone = 1, battle = 0, vars = {}, party = {}, mp = 100, hp = 1000, alive = true,
                    isPC = function() return tag == 'player' end, isMob = function() return tag == 'mob' end,
                    isPet = function() return tag == 'pet' end, getMaster = function(self) return self.owner end,
                    isAlive = function(self) return self.alive end, getID = function() return id end,
                    getZoneID = function(self) return self.zone end, getBattleID = function(self) return self.battle end,
                    getMainJob = function() return 15 end, getMainLvl = function(self) return self.level end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end, getPetID = function(self) return self.kind end,
                    getPet = function(self) return self.pet end, getParty = function(self) return self.party end,
                    checkDistance = function(_, target) return target.distance or 10 end,
                    getMP = function(self) return self.mp end, getMaxMP = function() return 100 end,
                    delMP = function(self, n) self.mp = self.mp - n end,
                    checkDamageCap = function(self, n) return math.min(self.cap or 99999, n) end,
                    timer = function(self, _, fn) self.expire = fn end,
                    despawnPet = function(self) self.pet = nil end, sendSoulSpellList = function() end,
                    takeDamage = function(self, n) self.hp = self.hp - n end,
                }
                entities[id] = entity
                return entity
            end
            GetPlayerByID = function(id) return entities[id] end
            super = function() return 321 end
            p, ally, far, enemy = actor(1, 'player'), actor(2, 'player'), actor(3, 'player'), actor(4, 'mob')
            pet = actor(10, 'pet')
            pet.kind, pet.owner, p.pet, far.distance = 10, p, pet, 16
            p.party = { p, ally, far }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            crystal.onApply(p)
            accord = overrides['xi.actions.abilities.avatars_favor.onUseAbility']
            rage = overrides['xi.actions.abilities.pets.fire_ii.onPetAbility']
            h = xi.soulspire.herald
        """)

    def test_snapshot_owner_pet_and_ally_each_have_independent_claims(self):
        self.lua.execute("""
            accord(p, p)
            assert(p.mp == 92 and hud(p).ready == 2 and hud(p).window == 8 and hud(p).element == 'Fire')
            assert(h.reserve(far, enemy, 1, 100) == 100)
            assert(h.reserve(ally, enemy, 2, 100) == 100)
            ally.distance = 25
            local boosted, allyClaim = h.reserve(ally, enemy, 1, 120, 100)
            assert(boosted == 128)
            h.finish(allyClaim, 0)
            assert(hud(p).ready == 2)
            boosted, allyClaim = h.reserve(ally, enemy, 1, 100)
            h.finish(allyClaim, boosted)
            pet.vars.OX_HLD_PET_SCOPE = 1
            local hp = enemy.hp
            assert(rage(enemy, pet, 545, p) == 108 and p.mp == 84)
            h.finishPetClaim(pet, enemy, hp - enemy.hp)
            assert(hud(p).ready == 0 and h.reserve(p, enemy, 1, 100) == 100)
        """)

    def test_same_element_refresh_does_not_restore_claim(self):
        self.lua.execute("""
            accord(p, p)
            local damage, claim = h.reserve(ally, enemy, 1, 100)
            h.finish(claim, damage)
            accord(p, p)
            assert(h.reserve(ally, enemy, 1, 100) == 100)
            local second = actor(11, 'player')
            local envoy = actor(12, 'pet')
            envoy.kind, envoy.owner, second.pet, second.party = 10, second, envoy, { second, ally }
            crystal.onApply(second)
            accord(second, second)
            assert(h.reserve(ally, enemy, 1, 100) == 100)
            assert(hud(second).ready == 1)
        """)

    def test_restrictions_expiry_and_avatar_death(self):
        self.lua.execute("""
            p.level = 75
            accord(p, p)
            assert(hud(p).window == 10 and hud(p).pct == 12)
            p.party = { p }
            assert(h.reserve(ally, enemy, 1, 100) == 100)
            enemy.cap = 100
            assert(h.reserve(p, enemy, 1, 100) == 100 and hud(p).ready == 1)
            pet.alive = false
            assert(h.reserve(p, enemy, 1, 100) == 100 and hud(p).window == 0)
            pet.alive = true
            now = 111
            assert(hud(p).window == 0)
            crystal.onRemove(p)
            assert(p.pet == nil and h.pactCost(p, 545) == nil)
            assert(catalog.spell[302].unlockLvl == 30 and catalog.spell[303].unlockLvl == 50)
        """)
