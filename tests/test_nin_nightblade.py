"""Verify Nightblade's exact-action seals, retry and support progression."""
from pathlib import Path
import unittest

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/nin_nightblade_specs.lua"
PATCH = ROOT / "patches/0060-nightblade-native-actions.patch"


class NightbladeNativeTests(unittest.TestCase):
    def test_one_telegraph_sequence_and_no_tool_cost(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("m_flags |= MAGICFLAGS_IGNORE_TOOLS", patch)
        self.assertIn("nightblade::beginTell(*m_PEntity, nightblade::Spell", patch)
        self.assertIn("nightblade::beginTell(*m_PEntity, nightblade::Technique", patch)
        self.assertIn('GetLocalVar("OX_NGB_INTERRUPT_SEQ") == m_nightbladeTell', patch)
        self.assertIn("m_spellId != SpellID::Death", patch)
        self.assertIn('callGlobal<void>("xi.soulspire.nightblade.onNonPhysicalTelegraph"', patch)
        self.assertIn("nightblade::endTell(*m_PEntity, m_nightbladeTell)", patch)
        self.assertIn('action.recast = std::chrono::seconds(GetLocalVar("OX_NGB_CAST_RECAST"))', patch)


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class NightbladeRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now, overrides, online = 100, {}, {}
            Module = { new = function() return { addOverride = function(_, p, fn) overrides[p] = fn end } end }
            for _, name in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs', 'scripts/globals/player',
                'scripts/globals/spells/damage_spell', 'scripts/combat/basic/magic_hit_rate',
            }) do
                package.preload[name] = function() return {} end
            end
            xi = {
                job = { NIN = 13 }, skill = { NINJUTSU = 39 },
                mod = { NINJUTSU = 1, MACC = 2, INT = 3 }, recast = { MAGIC = 0 },
                magic = { spellGroup = { NINJUTSU = 4 } }, attackType = { PHYSICAL = 1, MAGICAL = 2, RANGED = 3 },
                msg = { channel = { SYSTEM_3 = 29 }, basic = { NONE = 0, MAGIC_NO_EFFECT = 75,
                    MAGIC_UNABLE_TO_CAST = 17, UNABLE_TO_USE_JA = 87 } },
                combat = { magicHitRate = { calculateResistRate = function(_, target) return target.resist or 1 end } },
                spells = { damage = { useDamageSpell = function() return 44 end } },
                soulspire = { nowSec = function() return now end, spec = {
                    is = function(p, _, key) return p.key == key end,
                    registerCrystal = function(_, entry) crystal = entry end,
                }, hud = { registerProvider = function(_, fn) hud = fn end } },
            }
            super = function() return 123 end
            function GetPlayerByID(id) return online[id] end
            function actor(id, mob)
                local e = { key = 'nightblade', level = 10, vars = {}, recasts = {},
                    isPC = function() return not mob end, isMob = function() return mob == true end,
                    isAlive = function() return true end, getID = function() return id end, getZoneID = function() return 1 end,
                    getMainJob = function() return 13 end, getMainLvl = function(self) return self.level end,
                    getLocalVar = function(self, k) return self.vars[k] or 0 end,
                    setLocalVar = function(self, k, v) self.vars[k] = v end,
                    sendSoulSpellList = function() end, checkDistance = function(_, target) return target.distance or 10 end,
                    getTarget = function(self) return self.target end, printToPlayer = function() end,
                    addRecast = function(self, _, spellID, duration) self.recasts[spellID] = duration end,
                }
                if not mob then online[id] = e end
                return e
            end
            function makeSpell(id)
                return { getID = function() return id end, getElement = function() return 2 end,
                    setMsg = function(self, msg) self.msg = msg end }
            end
            ability = { setRecast = function(self, n) self.recast = n end, setCE = function() end, setVE = function() end }
            player, rival, enemy = actor(1), actor(2), actor(3, true)
            player.target, rival.target = enemy, enemy
            sever, blunt = makeSpell(341), makeSpell(344)
            function tell(kind, seq, interruptible)
                enemy.vars.OX_NGB_TELL, enemy.vars.OX_NGB_SEQUENCE = kind, seq
                enemy.vars.OX_NGB_INTERRUPTIBLE, enemy.vars.OX_NGB_SEALED_SEQ = interruptible or 0, 0
            end
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))
        self.lua.execute("""
            local root = 'xi.actions.spells.ninjutsu.'
            severCheck, severCast = overrides[root .. 'jubaku_ichi.onMagicCastingCheck'], overrides[root .. 'jubaku_ichi.onSpellCast']
            bluntCheck, bluntCast = overrides[root .. 'hojo_ichi.onMagicCastingCheck'], overrides[root .. 'hojo_ichi.onSpellCast']
            flare = overrides[root .. 'katon_ichi.onSpellCast']
            quickCheck, quick = overrides['xi.actions.abilities.innin.onAbilityCheck'], overrides['xi.actions.abilities.innin.onUseAbility']
            damage = xi.soulspire.onPreTakeDamage
        """)

    def test_wrong_tell_and_late_sequence_never_interrupt(self):
        self.lua.execute("""
            tell(2, 1)
            assert(severCheck(player, enemy, sever) == 17 and hud(player).seal_cd == 3)
            assert(player.recasts[341] == 3 and player.recasts[344] == 3)
            now = 103
            tell(1, 2, 1)
            assert(severCheck(player, enemy, sever) == 0)
            tell(1, 3, 1)
            severCast(player, enemy, sever)
            assert(player.vars.OX_NGB_CAST_RECAST == 3 and sever.msg == 75)
            assert(enemy:getLocalVar('OX_NGB_INTERRUPT_SEQ') == 0)
            assert(flare(player, enemy, makeSpell(320)) == 44)
        """)

    def test_interrupt_and_fallback_exact_action_scope(self):
        self.lua.execute("""
            tell(1, 4, 1)
            assert(severCheck(player, enemy, sever) == 0)
            severCast(player, enemy, sever)
            assert(enemy.vars.OX_NGB_INTERRUPT_SEQ == 4 and hud(player).seal_cd == 20)
            assert(severCheck(rival, enemy, sever) == 17 and rival.recasts[341] == nil)
            now = 109
            assert(severCheck(rival, enemy, sever) == 17)
            tell(1, 5)
            now, player.level = 121, 75
            assert(severCheck(player, enemy, sever) == 0)
            severCast(player, enemy, sever)
            assert(player.vars.OX_NGB_CAST_RECAST == 18)
            assert(damage(player, 100, enemy, 2) == 100)
            enemy.vars.OX_SCR_ACTION = 2
            assert(damage(player, 100, enemy, 2) == 88 and damage(player, 100, enemy, 1) == 100)
            player.key = 'kagemusha'
            assert(damage(player, 100, enemy, 2) == 100 and severCheck(player, enemy, sever) == 123)
        """)

    def test_blunt_result_and_quick_charge_recovery(self):
        self.lua.execute("""
            assert(quickCheck(player, player, ability) == 87)
            player.level = 30
            assert(quickCheck(player, player, ability) == 0 and ability.recast == 45)
            quick(player, player, ability)
            tell(2, 7)
            assert(bluntCheck(player, enemy, blunt) == 0)
            bluntCast(player, enemy, blunt)
            assert(hud(player).quick_rem == 0)
            enemy.vars.OX_SCR_ACTION = 1
            assert(damage(player, 100, enemy, 2) == 100)
            xi.soulspire.nightblade.onNonPhysicalTelegraph(enemy, 7)
            assert(hud(player).seal_cd == 3 and hud(player).quick_rem == 8)
            now = 103
            tell(2, 8)
            bluntCheck(player, enemy, blunt)
            bluntCast(player, enemy, blunt)
            assert(damage(player, 100, enemy, 1) == 87)
            assert(enemy.vars.OX_NGB_PHYSICAL_SEQ == 8 and hud(player).quick_rem == 0)
        """)
