"""Static regression tests for the Soul Weapon Configuration System."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
WEAPON_CONFIG_LUA = ROOT / "modules/custom/lua/soulspire_weapon_config.lua"
BRD_SPECS_LUA = ROOT / "modules/custom/lua/brd_specs.lua"
JOB_SPECS_LUA = ROOT / "modules/custom/lua/soulspire_job_specs.lua"
RUNTIME_LUA = ROOT / "modules/custom/lua/soulspire_job_spec_runtime.lua"
INIT_APPEND = ROOT / "modules/init.append.txt"
PATCH_0073 = ROOT / "patches/0073-soul-weapon-config.patch"
LUA_TEST_SUITE = ROOT / "tests/lua/soul_weapon_config.lua"
DESIGN_DOC = ROOT / "docs/soul-weapon-configuration-system.md"


class SoulWeaponConfigStaticTests(unittest.TestCase):
    def test_module_registered_in_init_append_before_specs(self):
        lines = [line.strip() for line in INIT_APPEND.read_text(encoding="utf-8").splitlines() if line.strip()]
        self.assertIn("custom/lua/soulspire_weapon_config.lua", lines)
        idx_job_specs = lines.index("custom/lua/soulspire_job_specs.lua")
        idx_weapon_cfg = lines.index("custom/lua/soulspire_weapon_config.lua")
        idx_brd_specs = lines.index("custom/lua/brd_specs.lua")
        self.assertLess(idx_job_specs, idx_weapon_cfg)
        self.assertLess(idx_weapon_cfg, idx_brd_specs)

    def test_weapon_config_schema_and_phase4_scope_guards(self):
        src = WEAPON_CONFIG_LUA.read_text(encoding="utf-8")
        for symbol in [
            "WC.RESULT",
            "WC.MODE",
            "WC.register",
            "WC.getActiveConfig",
            "WC.evaluatePair",
            "WC.reconcileEquipment",
            "WC.hasNativeDualWield",
            "dual_1h",
            "twohand_shield",
            "dual_2h",
        ]:
            self.assertIn(symbol, src)

        # Phase 5 modes must stay opt-in (never auto-enabled globally)
        self.assertIn("if pairing.enabled ~= true and cfg.allowAdvancedModes ~= true then", src)
        # BRD Adventurer is registered as Dagger/Sword dual_1h
        self.assertIn("WC.register(xi.job.BRD, 'adventurer'", src)
        self.assertIn("restrictSoulDualWieldToPairings = true", src)

    def test_brd_adventurer_declares_weapon_config(self):
        brd_src = BRD_SPECS_LUA.read_text(encoding="utf-8")
        self.assertIn("require('modules/custom/lua/soulspire_weapon_config')", brd_src)
        self.assertIn("weaponConfig", brd_src)
        self.assertIn("mode = 'dual_1h'", brd_src)

    def test_reconciliation_wired_into_spec_lifecycle(self):
        job_specs_src = JOB_SPECS_LUA.read_text(encoding="utf-8")
        runtime_src = RUNTIME_LUA.read_text(encoding="utf-8")
        self.assertIn("xi.soulspire.weaponConfig.reconcileEquipment(player)", job_specs_src)
        self.assertIn("xi.soulspire.weaponConfig.reconcileEquipment(player)", runtime_src)

    def test_patch_0073_exposes_authoritative_cpp_hooks_without_touching_spells(self):
        patch_src = PATCH_0073.read_text(encoding="utf-8")
        self.assertIn("EvaluateSoulWeaponPair", patch_src)
        self.assertIn("xi.overlords.weaponConfig.evaluatePair", patch_src)
        self.assertIn("CLuaBaseEntity::checkValidEquipment", patch_src)
        self.assertIn("charutils::CheckValidEquipment(PChar, false)", patch_src)
        # Must never modify spell authorization hooks
        self.assertNotIn("CanUseSpell", patch_src)
        self.assertNotIn("0x0aa_magic_data", patch_src)

    def test_real_engine_suite_and_doc_cover_required_deliverables(self):
        suite = LUA_TEST_SUITE.read_text(encoding="utf-8")
        self.assertIn("ITEM_WIND_KNIFE_P1", suite)
        self.assertIn("ITEM_ONION_SWORD", suite)
        self.assertIn("ITEM_ASH_CLUB_P1", suite)
        self.assertIn("MELEE_SWING_HIT", suite)
        self.assertIn("musician", suite)
        self.assertIn("spartan", suite)

        doc = DESIGN_DOC.read_text(encoding="utf-8")
        self.assertIn("Phase 1 Audit", doc)
        self.assertIn("Phase 2", doc)
        self.assertIn("Phase 3", doc)
        self.assertIn("Dual Two-Handed", doc)
        self.assertIn("Two-Handed + Shield", doc)
        self.assertIn("Manual In-Game Verification Checklist", doc)


if __name__ == "__main__":
    unittest.main()
