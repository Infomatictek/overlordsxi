"""Valkyrie action checks and native retry boundaries."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/whm_valkyrie_specs.lua"
PATCH = ROOT / "patches/0047-valkyrie-native-actions.patch"


class ValkyrieNativeBoundaryTests(unittest.TestCase):
    def test_scoped_job_abilities_and_damage_provenance(self):
        native = PATCH.read_text(encoding="utf-8")
        kit = MODULE.read_text(encoding="utf-8")
        self.assertIn("Wingmate = 273", native)
        self.assertIn("local WINGMATE = 273", kit)
        self.assertIn("Escort   = 275", native)
        self.assertIn("local ESCORT = 275", kit)
        self.assertIn("PAttacker->objtype == TYPE_MOB", native)
        self.assertIn("m_hostileInterrupt && m_PEntity->objtype == TYPE_PC", native)
        self.assertIn('GetLocalVar("OX_VLK_RETRY_SPELL") == static_cast<uint16>(m_spellId)', native)
        self.assertIn("m_actualMpSpent = -m_PEntity->addMP(-cost)", native)
        self.assertIn("m_actualMpSpent * m_valkyrieRefund / 100", native)
        self.assertIn("case 16833: // Bronze Spear", native)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class ValkyrieRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, members, actors = 100, {}, {}, {}
            Module = { new = function() return {
                addOverride = function(_, name, fn) overrides[name] = fn end,
            } end }
            for _, key in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
            }) do
                package.preload[key] = function() return {} end
            end
            xi = {
                job = { WHM = 3 }, slot = { MAIN = 0 }, skill = { POLEARM = 8 },
                mod = { POLEARM = 1, HPP = 2, MEVA = 3 },
                msg = { basic = { CANNOT_CAST_SPELL = 1, UNABLE_TO_USE_JA = 87 } },
                soulspire = {
                    nowSec = function() return now end,
                    spec = {
                        is = function(p, _, key) return p.key == key end,
                        registerCrystal = function(_, entry) crystal = entry end,
                    },
                    hud = { registerProvider = function(_, fn) hud = fn end },
                },
            }
            super = function() return 123 end
            GetPlayerByID = function(id) return actors[id] end
            function make(id, key, party)
                local player = {
                    id = id, key = key, level = 10, zone = 5, weapon = 8, distance = 10, alive = true, vars = {},
                    isPC = function() return true end,
                    isAlive = function(self) return self.alive end,
                    getMainJob = function() return 3 end,
                    getMainLvl = function(self) return self.level end,
                    getZoneID = function(self) return self.zone end,
                    getID = function(self) return self.id end,
                    getParty = function() return members end,
                    checkDistance = function(_, target) return target.distance end,
                    getWeaponSkillType = function(self) return self.weapon end,
                    getLocalVar = function(self, name) return self.vars[name] or 0 end,
                    setLocalVar = function(self, name, val) self.vars[name] = val end,
                    sendSoulSpellList = function() end,
                    getEquippedItem = function() return nil end,
                }
                actors[id] = player
                if party then members[#members + 1] = player end
                return player
            end
            player, second, ally, stranger = make(1, 'valkyrie', true), make(2, 'valkyrie', true),
                make(3, 'bishop', true), make(4, 'bishop', false)
            ability = {
                setRange = function(self, range) self.range = range end,
                setRecast = function(self, recast) self.recast = recast end,
                setCE = function() end, setVE = function() end,
            }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            checkWing = overrides['xi.actions.abilities.manawell.onAbilityCheck']
            useWing = overrides['xi.actions.abilities.manawell.onUseAbility']
            checkEscort = overrides['xi.actions.abilities.spontaneity.onAbilityCheck']
            useEscort = overrides['xi.actions.abilities.spontaneity.onUseAbility']
            function interrupt(target)
                target:setLocalVar('OX_VLK_INTERRUPT_SPELL', 28)
                target:setLocalVar('OX_VLK_INTERRUPT_UNTIL', now + 6)
            end
        """)

    def test_level_10_single_claim_and_invalid_targets(self):
        self.lua.execute("""
            assert(#crystal.extraAbilities(player, 10) == 2)
            assert(checkWing(player, stranger, ability) == 87)
            assert(checkWing(player, ally, ability) == 0 and ability.recast == 5)
            useWing(player, ally, ability)
            assert(checkWing(second, ally, ability) == 0)
            useWing(second, ally, ability)
            assert(checkEscort(player, ally, ability) == 87)
            interrupt(ally)
            assert(hud(player).interrupt_rem == 6)
            assert(checkEscort(player, ally, ability) == 0 and ability.recast == 25)
            useEscort(player, ally, ability)
            assert(checkEscort(second, ally, ability) == 87)
            assert(ally.vars.OX_VLK_RETRY_SPELL == 28 and ally.vars.OX_VLK_RETRY_REFUND == 0)
            assert(hud(player).retry_rem == 6 and hud(player).escort_cd == 25)
            crystal.onRemove(player)
            assert(ally.vars.OX_VLK_RETRY_UNTIL == 0 and hud(player).wingmate == 0)
            player.key = 'zealot'
            assert(checkWing(player, ally, ability) == 123)
        """)

    def test_progression_range_self_refund_and_expiry(self):
        self.lua.execute("""
            useWing(player, ally, ability)
            ally.distance = 19
            player.level = 30
            interrupt(ally)
            assert(checkEscort(player, ally, ability) == 87)
            ally.distance = 14
            assert(checkEscort(player, ally, ability) == 0)
            useEscort(player, ally, ability)
            assert(ally.vars.OX_VLK_RETRY_REFUND == 15)
            now = now + 7
            ally.distance, player.level = 19, 50
            interrupt(ally)
            assert(checkEscort(player, ally, ability) == 0 and ability.range == 20)
            assert(checkWing(player, player, ability) == 0)
            useWing(player, player, ability)
            assert(ally.vars.OX_VLK_RETRY_UNTIL == 0)
            player.level = 75
            interrupt(player)
            useEscort(player, player, ability)
            assert(player.vars.OX_VLK_RETRY_REFUND == 12)
            now = now + 6
            assert(hud(player).retry_rem == 0 and checkEscort(player, player, ability) == 87)
        """)
