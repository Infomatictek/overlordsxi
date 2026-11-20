"""Exercise Arcane Archer's native hit and atomic, party-scoped mark."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/rng_arcane_archer_specs.lua"
PATCH = ROOT / "patches/0059-arcane-archer-native-actions.patch"


class ArcaneArcherNativeTests(unittest.TestCase):
    def test_bow_source_and_eligible_followups(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("RangedSoulShot::Attunement", patch)
        self.assertIn('triggerListener("SOUL_ATTUNEMENT_ARROW_LAND"', patch)
        self.assertIn("enemy->health.hp < hpBefore", patch)
        self.assertIn("const auto singleShot = sightline || attunement", patch)
        self.assertIn("const bool recycleProc = !singleShot", patch)
        self.assertIn("arcane.reserve(caster, target, spellElement, finalDamage, 'spell', ordinaryDamage)", patch)
        self.assertIn("arcane.reserve(actor, target, skillchainElement, finalDamage, 'chain')", patch)
        self.assertIn("attack.weaponType == xi.skill.ARCHERY", patch)
        self.assertIn("if elementalDamage > 0 then calcParams.arcaneElement", patch)
        self.assertIn('target:getHP()) end', patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class ArcaneArcherRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, online = 100, {}, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({ 'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player' }) do
                package.preload[name] = function() return {} end
            end
            xi = {
                job = { RNG = 11 }, mod = { ARCHERY = 1, RACC = 2, MACC = 3 },
                msg = { basic = { NONE = 0 }, channel = { SYSTEM_3 = 29 } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            function GetPlayerByID(id) return online[id] end
            function actor(id, kind)
                local e = { key = 'arcanearcher', level = 10, zone = 1, vars = {}, party = {}, listeners = {},
                    isPC = function() return kind == 'pc' end, isMob = function() return kind == 'mob' end,
                    isPet = function() return kind == 'pet' end, isAlive = function() return true end,
                    getID = function() return id end, getZoneID = function(self) return self.zone end,
                    getMainJob = function() return 11 end, getMainLvl = function(self) return self.level end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end,
                    removeListener = function(self, k) self.listeners[k] = nil end,
                    addListener = function(self, _, k, f) self.listeners[k] = f end,
                    sendSoulSpellList = function() end, getParty = function(self) return self.party end,
                    getMaster = function(self) return self.master end,
                    getTarget = function(self) return self.target end, printToPlayer = function() end,
                }
                if kind == 'pc' then online[id] = e end
                return e
            end
            player, ally, outsider, rival = actor(1, 'pc'), actor(2, 'pc'), actor(3, 'pc'), actor(4, 'pc')
            enemy, other, pet = actor(9, 'mob'), actor(10, 'mob'), actor(11, 'pet')
            player.party, player.target, pet.master = { player, ally }, enemy, ally
            ability = { setRecast = function(self, n) self.recast = n end, setCE = function() end, setVE = function() end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            crystal.onApply(player)
            crystal.onApply(rival)
            land = player.listeners.OX_ACA_ARROW_LAND
            reserve, finish = xi.soulspire.arcaneArcher.reserve, xi.soulspire.arcaneArcher.finish
        """)

    def test_party_element_and_atomic_claim(self):
        self.lua.execute("""
            land(player, enemy, 1)
            assert(hud(player).mark_rem == 10 and hud(player).mark_element == 1)
            assert(reserve(outsider, enemy, 1, 100, 'spell') == 100)
            assert(reserve(ally, enemy, 2, 100, 'spell') == 100)
            assert(reserve(ally, enemy, 1, 100, 'dot') == 100)
            assert(reserve(player, enemy, 1, 100, 'bow') == 100)
            local damage, claim = reserve(ally, enemy, 1, 150, 'spell', 100)
            assert(damage == 162 and claim ~= nil)
            assert(reserve(pet, enemy, 1, 100, 'chain') == 100)
            finish(enemy, claim, 0)
            local petDamage, petClaim = reserve(pet, enemy, 1, 100, 'chain')
            assert(petDamage == 112 and petClaim ~= nil)
            finish(enemy, petClaim, 112)
            assert(reserve(ally, enemy, 1, 100, 'chain') == 100 and hud(player).mark_rem == 0)
        """)

    def test_solo_half_bonus_replacement_and_scope(self):
        self.lua.execute("""
            player.party = { player }
            player.level = 75
            land(player, enemy, 1)
            assert(hud(player).mark_rem == 14)
            local damage, claim = reserve(player, enemy, 1, 100, 'bow')
            assert(damage == 110 and claim ~= nil)
            land(rival, enemy, 1)
            finish(enemy, claim, 110)
            assert(reserve(rival, enemy, 1, 100, 'bow') == 106)
            land(rival, other, 1)
            assert(reserve(rival, enemy, 1, 100, 'bow') == 100)
            assert(reserve(rival, other, 1, 100, 'bow') == 106)
            now = 110
            assert(reserve(rival, other, 1, 100, 'bow') == 100)
            crystal.onRemove(player)
            assert(player.listeners.OX_ACA_ARROW_LAND == nil)
        """)

    def test_selection_starts_at_level_ten_and_does_not_change_an_existing_mark(self):
        self.lua.execute("""
            assert(#crystal.extraAbilities(player, 10) == 3 and #crystal.extraAbilities(player, 9) == 0)
            local back = overrides['xi.actions.abilities.camouflage.onUseAbility']
            local forward = overrides['xi.actions.abilities.sharpshot.onUseAbility']
            local check = overrides['xi.actions.abilities.sharpshot.onAbilityCheck']
            assert(check(player, player, ability) == 0 and ability.recast == 1)
            land(player, enemy, 1)
            back(player, player, ability)
            assert(hud(player).element == 6 and hud(player).mark_element == 1)
            forward(player, player, ability)
            assert(hud(player).element == 1)
            player.key = 'sniper'
            assert(forward(player, player, ability) == 123 and hud(player).mark_rem == 0)
        """)
