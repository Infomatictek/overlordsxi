"""Exercise Zealot's Lua hooks and native action profile agreement."""
import re
import unittest
from pathlib import Path

try:
    from lupa import LuaRuntime
except ImportError:
    LuaRuntime = None

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/custom/lua/whm_zealot_specs.lua"
PATCH = ROOT / "patches/0046-zealot-native-actions.patch"


class ZealotIntegrationTests(unittest.TestCase):
    def test_spell_profile_and_native_ability_id(self):
        lua = MODULE.read_text(encoding="utf-8")
        patch = PATCH.read_text(encoding="utf-8")
        aliases = {
            "banish": "Banish", "banish_ii": "Banish_II",
            "banish_iii": "Banish_III", "holy": "Holy",
        }
        rows = re.findall(
            r"\[\d+\] = \{ script = '(\w+)'.*?unlockLvl = (\d+),.*?"
            r"recastSec = (\d+),\s*mpPercent = (\d+)",
            lua,
        )
        self.assertEqual(set(aliases), {row[0] for row in rows})
        for name, level, recast, mp_percent in rows:
            mp_pattern = mp_percent if name != "holy" else r"static_cast<uint8>\(level >= 70 \? 22 : 20\)"
            self.assertRegex(
                patch,
                rf"case SpellID::{aliases[name]}:\s+return \{{ {level}, {mp_pattern}, {recast} \}};",
            )
        self.assertIn("constexpr uint16 SealAbility = 74", patch)
        self.assertIn("local DIVINE_SEAL = 74", lua)
        self.assertIn("m_zealotCast == currentZealot", patch)
        self.assertIn("m_zealotAbility != currentZealot", patch)
        self.assertIn("trackStaffHit && damage > 0 && weaponSlot == SLOT_MAIN", patch)

    def test_loader_and_weapon_skill_policy(self):
        loader = (ROOT / "modules/init.append.txt").read_text()
        self.assertLess(loader.index("soulspire_soul_hud.lua"), loader.index(MODULE.name))
        profiles = (MODULE.parent / "soulspire_ws_spec_profiles.lua").read_text()
        self.assertRegex(profiles, r"zealot\s*= \{ \[S\.STAFF or 12\] = true \},")


@unittest.skipUnless(LuaRuntime, "Lupa is required for in-process Lua gameplay checks")
class ZealotRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(f"package.path = '{ROOT.as_posix()}/?.lua;' .. package.path")
        self.lua.execute("""
            now = 100
            overrides, vars, listeners = {}, {}, {}
            super = function() return 123, 456 end
            Module = { new = function() return {
                addOverride = function(_, name, fn) overrides[name] = fn end,
            } end }
            for _, key in ipairs({
                'modules/module_utils', 'modules/custom/lua/soulspire_job_specs',
                'scripts/globals/player', 'scripts/globals/spells/damage_spell',
            }) do
                package.preload[key] = function() return {} end
            end
            xi = {
                job = { WHM = 3 }, slot = { MAIN = 0 }, skill = { STAFF = 12 },
                mod = { STAFF = 1, ACC = 2, MND = 3, MATT = 4, MACC = 5 },
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
            player = {
                level = 10, weapon = 12, key = 'zealot', mp = 0, maxMP = 200,
                isPC = function() return true end,
                getMainJob = function() return 3 end,
                getMainLvl = function(self) return self.level end,
                getWeaponSkillType = function(self) return self.weapon end,
                getMaxMP = function(self) return self.maxMP end,
                getLocalVar = function(_, key) return vars[key] or 0 end,
                setLocalVar = function(_, key, value) vars[key] = value end,
                sendSoulSpellList = function() end,
                addListener = function(_, _, key, fn) listeners[key] = fn end,
                removeListener = function(_, key) listeners[key] = nil end,
                addMP = function(self, value)
                    self.mp = self.mp + value
                    return value
                end,
            }
            enemy = { isMob = function() return true end, getID = function() return 12 end }
            spell = {
                id = 28, getID = function(self) return self.id end,
                setCastTime = function(self, ms) self.ms = ms end,
            }
            ability = { setRecast = function(self, seconds) self.recast = seconds end }
        """)
        self.lua.execute(MODULE.read_text(encoding="utf-8"))

    def test_level_ten_loop_and_soul_switch(self):
        self.lua.execute("""
            crystal.onApply(player)
            assert(vars.OX_ZEALOT_ACTIVE == 1 and crystal.extraAbilities(player, 10)[1] == 74)
            assert(#crystal.extraAbilities(player, 9) == 0)
            local staffHit = listeners.OX_ZEALOT_COMMUNION
            staffHit(player, enemy)
            staffHit(player, enemy)
            assert(player.mp == 7 and hud(player).communion_cd == 3)
            now = 103
            player.weapon = 11
            staffHit(player, enemy)
            assert(player.mp == 7 and hud(player).staff == 0)
            player.weapon = 12
            assert(overrides['xi.actions.spells.white.banish.onMagicCastingCheck'](player, enemy, spell) == 0)
            assert(spell.ms == 2000)
            assert(overrides['xi.actions.abilities.divine_seal.onAbilityCheck'](player, player, ability) == 0)
            assert(ability.recast == 90)
            overrides['xi.actions.abilities.divine_seal.onUseAbility'](player, player, ability)
            assert(hud(player).seal_rem == 20 and hud(player).seal_cd == 90)
            local api = xi.soulspire.whmZealotSpecs
            assert(math.abs(api.damageMultiplier(player, spell) - 1.8) < 0.001)
            api.onNukeDamage(player, spell, 0)
            assert(hud(player).seal_rem == 20)
            api.onNukeDamage(player, spell, 18)
            assert(hud(player).seal_rem == 0 and api.damageMultiplier(player, spell) == 1.5)
            crystal.onRemove(player)
            player.key = 'bishop'
            assert(vars.OX_ZEALOT_ACTIVE == 0 and listeners.OX_ZEALOT_COMMUNION == nil)
            assert(api.damageMultiplier(player, spell) == 1)
            assert(overrides['xi.actions.spells.white.banish.onMagicCastingCheck'](player, enemy, spell) == 123)
            assert(overrides['xi.actions.abilities.divine_seal.onUseAbility'](player, player, ability) == 123)
        """)

    def test_progression_and_seal_expiration(self):
        self.lua.execute("""
            local sunbrand = overrides['xi.actions.spells.white.banish_ii.onMagicCastingCheck']
            assert(sunbrand(player, enemy, spell) == 1)
            player.level = 30
            assert(sunbrand(player, enemy, spell) == 0 and spell.ms == 2500)
            local lastLight = overrides['xi.actions.spells.white.holy.onMagicCastingCheck']
            assert(lastLight(player, enemy, spell) == 1)
            player.level, spell.id = 50, 21
            assert(lastLight(player, enemy, spell) == 0 and spell.ms == 3500)
            local api = xi.soulspire.whmZealotSpecs
            assert(api.damageMultiplier(player, spell) == 1.8)
            player.level = 75
            assert(api.damageMultiplier(player, spell) == 2)
            overrides['xi.actions.abilities.divine_seal.onUseAbility'](player, player, ability)
            now = now + 20
            assert(api.damageMultiplier(player, spell) == 2 and hud(player).seal_rem == 0)
            player.level = 9
            assert(api.damageMultiplier(player, spell) == 1)
        """)
