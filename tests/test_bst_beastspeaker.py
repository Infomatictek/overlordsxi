"""Verify quarry choice, real pet delivery guards, and bounded party claims."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/bst_beastspeaker_specs.lua"
PATCH = ROOT / "patches/0066-beastspeaker-native-actions.patch"


class BeastspeakerNativeTests(unittest.TestCase):
    def test_only_native_regular_damage_paths_are_exposure_eligible(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("bool exposureClaimed = false;", patch)
        self.assertIn("POriginalTarget, &exposureClaimed);", patch)
        self.assertIn("realHits == 1 ? &exposureClaimed : nullptr", patch)
        self.assertIn("regularPhysical && PDefender->health.hp < hpBefore", patch)
        self.assertIn("!isRanged && PAttacker->objtype == TYPE_PET", patch)
        self.assertIn("m_beastspeakerAbility != currentBeastspeaker", patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class BeastspeakerRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
            now, overrides, entities = 100, {}, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player', 'scripts/globals/pets',
            }) do package.preload[name] = function() return {} end end
            package.preload['modules/custom/lua/soulspire_soul_actions'] = function()
                return { register = function(_, data) catalog = data end }
            end
            xi = {
                job = { BST = 9 }, petId = { FLOWERPOT_BILL = 28 }, mobFamily = { CRAB = 1 },
                damageType = { PIERCING = 1, SLASHING = 2, BLUNT = 3, HAND_TO_HAND = 4 },
                mod = { IMPACT_SDT = 1, SLASH_SDT = 2, PIERCE_SDT = 3, AXE = 4, ACC = 5 },
                msg = { basic = { UNABLE_TO_USE_JA = 87, NONE = 0 } },
                pet = { spawnPet = function(p, id) p.pet = actor(28, 'pet'); p.pet.kind = id end },
                soulspire = { nowSec = function() return now end,
                    spec = { is = function(p, _, k) return p.key == k end,
                        registerCrystal = function(_, data) crystal = data end },
                    hud = { registerProvider = function(_, fn) hud = fn end },
                },
            }
            function actor(id, tag)
                local entity = {
                    key = 'beastspeaker', level = 10, zone = 1, battle = 0, family = 1, vars = {}, mods = {},
                    timers = {}, party = {}, listeners = {}, alive = true,
                    isPC = function() return tag == 'player' end, isMob = function() return tag == 'mob' end,
                    getMaster = function(self) return self.master end, isAlive = function(self) return self.alive end,
                    getID = function() return id end, getZoneID = function(self) return self.zone end,
                    getBattleID = function(self) return self.battle end, getMainJob = function() return 9 end,
                    getMainLvl = function(self) return self.level end, getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end, getPetID = function(self) return self.kind end,
                    getPet = function(self) return self.pet end, hasJugPet = function(self) return self.pet ~= nil end,
                    getTarget = function(self) return self.target end, getFamily = function(self) return self.family end,
                    getMod = function(self, k) return self.mods[k] or 0 end, getParty = function(self) return self.party end,
                    checkDistance = function(self) return self.distance or 8 end,
                    addListener = function(self, _, k, fn) self.listeners[k] = fn end,
                    removeListener = function(self, k) self.listeners[k] = nil end,
                    timer = function(self, delay, fn) self.timers[delay] = fn end,
                    despawnPet = function(self) self.pet = nil end, sendSoulSpellList = function() end,
                }
                entities[id] = entity
                return entity
            end
            GetMobByID = function(id) return entities[id] end
            GetPlayerByID = function(id) return entities[id] end
            super = function() return 321 end
            ability = { setMsg = function() end }
            p, ally, outsider, enemy = actor(1, 'player'), actor(2, 'player'), actor(3, 'player'), actor(4, 'mob')
            p.party = { p, ally }
            enemy.vars.OX_ARC_SPAWN = 1
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            crystal.onApply(p)
            function run(ja, target)
                local prefix = 'xi.actions.abilities.' .. ja
                local result = overrides[prefix .. '.onAbilityCheck'](p, target, ability)
                if result ~= 0 then return result end
                return overrides[prefix .. '.onUseAbility'](p, target, ability)
            end
            assert(run('call_beast', p) == 0)
            pet = p.pet
            pet.target = enemy
            bsp = xi.soulspire.beastspeaker
        """)

    def test_starter_loop_only_bonuses_matching_party_members(self):
        self.lua.execute("""
            enemy.mods[2] = 1000
            assert(run('tame', enemy) == 87)
            assert(run('gauge', enemy) == 0 and hud(p).weakness == 'Slashing')
            assert(run('tame', enemy) == 0 and hud(p).pending == 6)
            bsp.onTrackerHit(actor(99, 'pet'), enemy, p)
            assert(hud(p).pending == 6 and bsp.bonus(ally, enemy, 2) == 0)
            bsp.onTrackerHit(pet, enemy, p)
            assert(hud(p).exposed == 8)
            assert(bsp.bonus(outsider, enemy, 2) == 0 and bsp.bonus(ally, enemy, 3) == 0)
            assert(bsp.bonus(ally, enemy, 2) == 8)
            assert(bsp.claim(ally, enemy, 2) and bsp.claim(ally, enemy, 2))
            assert(not bsp.claim(ally, enemy, 2) and bsp.bonus(p, enemy, 2) == 8)
            enemy.vars.OX_ARC_SPAWN = 2
            assert(bsp.bonus(p, enemy, 2) == 0)
        """)

    def test_unknown_fallback_manual_selection_and_cleanup(self):
        self.lua.execute("""
            p.level, enemy.family = 75, 5000
            assert(run('gauge', enemy) == 0 and hud(p).family == 'Unknown')
            assert(run('stay', p) == 0 and hud(p).weakness == 'Slashing')
            assert(run('tame', enemy) == 0)
            now = 107
            bsp.onTrackerHit(pet, enemy, p)
            assert(bsp.bonus(ally, enemy, 2) == 0)
            p.timers[6000](p)
            assert(p.vars.OX_BSP_PENDING == 0)
            assert(run('tame', enemy) == 0)
            bsp.onTrackerHit(pet, enemy, p)
            assert(bsp.bonus(ally, enemy, 2) == 6 and hud(p).exposed == 10)
            crystal.onRemove(p)
            assert(p.pet == nil and enemy.vars.OX_BSP_EXPOSED == 0 and bsp.bonus(ally, enemy, 2) == 0)
            p.key = 'untamed'
            assert(run('gauge', enemy) == 321)
        """)

    def test_observes_real_hostile_action_and_later_ability_unlock(self):
        self.lua.execute("""
            p.level = 30
            assert(run('gauge', enemy) == 0)
            enemy.listeners.OX_BSP_OBSERVE_1(enemy, 1, 54, 'stone_ii')
            assert(hud(p).learned == 'stone ii')
            assert(#crystal.extraAbilities(p, 10) == 6)
            assert(crystal.extraAbilities(p, 50)[7] == 73)
            assert(run('stay', p) == 87)
            assert(catalog.ability[54].name == 'Expose Quarry')
        """)
