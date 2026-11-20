"""Automated Stage A regression tests for OverlordsXI Soul Proving Grounds."""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import proving_grounds_benchmark as pgb  # noqa: E402


class ProvingGroundsStageATests(unittest.TestCase):
    def test_canonical_66_souls_and_no_freelancer(self):
        souls = pgb.load_canonical_souls()
        self.assertEqual(len(souls), 66)
        jobs = {s["job"] for s in souls}
        self.assertEqual(len(jobs), 22)
        for s in souls:
            self.assertNotEqual((s["job"], s["soul_key"]), ("DNC", "freelancer"))
            self.assertIn(s["tier"], pgb.TIER_OFFENSE)

    def test_stage_a_formula_suite_passes_and_is_explicitly_labeled(self):
        report = pgb.run_stage_a_formula_suite()
        self.assertEqual(report["test_mode"], "formula")
        self.assertEqual(report["combat_execution"], "NO_REAL_COMBAT_EXECUTED")
        self.assertTrue(report["passed"], msg=json.dumps(report["checks"], indent=2))
        self.assertEqual(report["total_checks"], 10)
        self.assertEqual(report["passed_checks"], 10)

    def test_shared_lua_registry_loads_in_luajit(self):
        info = pgb.inspect_lua_registry_via_luajit()
        if not info.get("available"):
            self.skipTest(info.get("reason", "libluajit_64.dll unavailable"))
        self.assertEqual(info["schemaVersion"], "1.0.0")
        self.assertEqual(info["arenaZoneId"], 210)
        self.assertEqual(info["levels"], [10, 30, 50, 75])
        self.assertFalse(info["plus8Baseline"])
        self.assertTrue(info["plus8Extreme"])
        self.assertEqual(info["sampleGearProfile"], "accessible_lv10")

        npc_by_id = {a["id"]: a for a in info["npcArchetypes"]}
        self.assertEqual(
            set(npc_by_id.keys()),
            {"physical_bruiser", "magic_caster", "aoe_boss", "training_dummy"},
        )
        # Physical Bruiser must never have magic casting enabled.
        self.assertTrue(npc_by_id["physical_bruiser"]["autoAttack"])
        self.assertFalse(npc_by_id["physical_bruiser"]["magicCasting"])
        self.assertTrue(npc_by_id["physical_bruiser"]["mobAbility"])
        # Magic Caster must have magic casting enabled and mob abilities disabled.
        self.assertTrue(npc_by_id["magic_caster"]["magicCasting"])
        self.assertFalse(npc_by_id["magic_caster"]["mobAbility"])
        # AoE Boss must have mob abilities enabled and magic disabled.
        self.assertTrue(npc_by_id["aoe_boss"]["mobAbility"])
        self.assertFalse(npc_by_id["aoe_boss"]["magicCasting"])
        # Training Dummy must have all offensive actions disabled.
        self.assertFalse(npc_by_id["training_dummy"]["autoAttack"])
        self.assertFalse(npc_by_id["training_dummy"]["magicCasting"])
        self.assertFalse(npc_by_id["training_dummy"]["mobAbility"])

    def test_balance_matrix_separates_plus8_extreme_challenge(self):
        matrix = pgb.build_balance_test_matrix()
        self.assertEqual(matrix["canonical_soul_count"], 66)
        self.assertEqual(matrix["archetype_count"], 6)
        self.assertEqual(matrix["scenario_templates_count"], 6 * 4 * 3)
        self.assertEqual(matrix["standard_baseline_pairs"], 66 * 6 * 4 * 2)
        self.assertEqual(matrix["extreme_challenge_pairs"], 66 * 6 * 4 * 1)
        for sc in matrix["scenarios"]:
            if sc["difficulty"] == "boss_plus_8":
                self.assertFalse(sc["standard_baseline"])
                self.assertTrue(sc["extreme_challenge"])
            # Accessible gear must match player bracket, never Lv75 for Lv10.
            self.assertEqual(sc["gear_profile"], f"accessible_lv{sc['player_level']}")

    def test_init_append_registration_order(self):
        lines = [
            ln.strip()
            for ln in (REPO_ROOT / "modules" / "init.append.txt").read_text(encoding="utf-8-sig").splitlines()
            if ln.strip() and not ln.strip().startswith("--")
        ]
        boss_idx = lines.index("custom/lua/boss_like_combat_and_exp.lua")
        reg_idx = lines.index("custom/lua/overlords_proving_grounds_registry.lua")
        tel_idx = lines.index("custom/lua/overlords_proving_grounds_telemetry.lua")
        lite_idx = lines.index("custom/lua/overlords_proving_grounds_lite.lua")
        self.assertLess(boss_idx, reg_idx)
        self.assertLess(reg_idx, tel_idx)
        self.assertLess(tel_idx, lite_idx)

    def test_jsonl_summarizer_flags_low_sample_size_and_safety_violations(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "runs.jsonl"
            sample = {
                "run_id": "pg_test_1",
                "soul_key": "berserker",
                "role": "Damage",
                "boss_type": "physical_bruiser",
                "boss_level": 10,
                "test_mode": "automated_real",
                "outcome": "victory",
                "metrics": {
                    "offense": {"sustained_dps": 18.5},
                    "safety": {"progression_clean": True, "exp_points_observed": 0},
                },
            }
            p.write_text(json.dumps(sample) + "\n", encoding="utf-8")
            summary = pgb.summarize_jsonl_runs(p)
            self.assertEqual(summary["total_runs"], 1)
            self.assertFalse(summary["statistically_meaningful"])
            self.assertEqual(len(summary["performed_well"]), 1)
            self.assertEqual(len(summary["balance_concerns"]), 0)


if __name__ == "__main__":
    unittest.main()
