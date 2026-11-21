"""Static regression tests for Soul spell authorization, Terramancer/Shinobi mappings, and ASCII safety."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
TERRAMANCER_LUA = ROOT / "modules/custom/lua/geo_terramancer_specs.lua"
TERRAMANCER_PATCH = ROOT / "patches/0069-terramancer-native-actions.patch"
NIN_LUA = ROOT / "modules/custom/lua/nin_specs.lua"
REAL_ENGINE_SUITE = ROOT / "tests/lua/soul_spell_authorization.lua"


class SoulSpellAuthorizationStaticTests(unittest.TestCase):
    def test_terramancer_lua_and_patch_align_on_spell_ids_and_ascii_descriptions(self):
        lua_src = TERRAMANCER_LUA.read_text(encoding="utf-8")
        patch_src = TERRAMANCER_PATCH.read_text(encoding="utf-8")

        self.assertIn("[159] = { script = 'stone', name = 'Stone Chip'", lua_src)
        self.assertIn("[160] = { script = 'stone_ii', name = 'Shallow Fault'", lua_src)
        self.assertIn("[161] = { script = 'stone_iii', name = 'Deep Fault'", lua_src)
        self.assertNotIn("\u2019", lua_src, "Terramancer Lua descriptions must use ASCII apostrophes")

        self.assertIn("case SpellID::Stone:", patch_src)
        self.assertIn("case SpellID::Stone_II:", patch_src)
        self.assertIn("case SpellID::Stone_III:", patch_src)
        self.assertIn("terramancer::isActive(this)", patch_src)
        self.assertIn("terramancer::spellLevel(spellId)", patch_src)

    def test_shinobi_unlock_levels_gate_utsusemi_ni_at_lv37(self):
        nin_src = NIN_LUA.read_text(encoding="utf-8")
        self.assertIn("[338] = { script = 'utsusemi_ichi', name = 'Shadow Squadron: Ichi', unlockLvl = 10", nin_src)
        self.assertIn("[339] = { script = 'utsusemi_ni',   name = 'Shadow Squadron: Ni',   unlockLvl = 37", nin_src)
        self.assertIn("m:addOverride('xi.spells.canUseSpellOverride'", nin_src)

    def test_real_engine_regression_suite_covers_all_required_scenarios(self):
        suite = REAL_ENGINE_SUITE.read_text(encoding="utf-8")
        self.assertIn("Stone Chip (159)", suite)
        self.assertIn("Shallow Fault (160)", suite)
        self.assertIn("Deep Fault (161", suite)
        self.assertIn("Utsusemi: Ni (339)", suite)
        self.assertIn("WAR20/NIN10", suite)
        self.assertIn("Vanilla Cure (1)", suite)


if __name__ == "__main__":
    unittest.main()
