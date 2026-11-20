"""Automated Stage A, Level-Sync Contract & Historical Analyzer tests for Soul Proving Grounds."""
from __future__ import annotations

import csv
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
        self.assertEqual(info["schemaVersion"], "2.0.0")
        self.assertEqual(info["arenaZoneId"], 210)
        self.assertEqual(info["npcPos"]["x"], -5)
        self.assertEqual(info["npcPos"]["z"], 5)
        self.assertEqual(info["levels"], [10, 30, 50, 75])
        self.assertEqual(info["difficultyOrder"], ["even_match", "very_tough", "incredibly_tough", "extreme"])
        self.assertEqual(info["maxBossLevel"], 83)
        self.assertFalse(info["plus8Baseline"])
        self.assertTrue(info["plus8Extreme"])
        self.assertEqual(info["sampleGearProfile"], "accessible_lv10")

        npc_by_id = {a["id"]: a for a in info["npcArchetypes"]}
        self.assertEqual(
            set(npc_by_id.keys()),
            {"physical_bruiser", "magic_caster", "aoe_boss", "training_dummy"},
        )
        self.assertTrue(npc_by_id["physical_bruiser"]["autoAttack"])
        self.assertFalse(npc_by_id["physical_bruiser"]["magicCasting"])
        self.assertTrue(npc_by_id["magic_caster"]["magicCasting"])
        self.assertFalse(npc_by_id["magic_caster"]["mobAbility"])
        self.assertTrue(npc_by_id["aoe_boss"]["mobAbility"])
        self.assertFalse(npc_by_id["aoe_boss"]["magicCasting"])
        self.assertFalse(npc_by_id["training_dummy"]["autoAttack"])

    def test_balance_matrix_separates_plus8_extreme_and_supports_above_75_bosses(self):
        matrix = pgb.build_balance_test_matrix()
        self.assertEqual(matrix["canonical_soul_count"], 66)
        self.assertEqual(matrix["archetype_count"], 6)
        self.assertEqual(matrix["difficulty_count"], 4)
        self.assertEqual(matrix["scenario_templates_count"], 6 * 4 * 4)
        self.assertEqual(matrix["standard_baseline_pairs"], 66 * 6 * 4 * 3)
        self.assertEqual(matrix["extreme_challenge_pairs"], 66 * 6 * 4 * 1)
        boss_levels = {sc["boss_level"] for sc in matrix["scenarios"]}
        self.assertIn(78, boss_levels)  # Lv75 + 3
        self.assertIn(80, boss_levels)  # Lv75 + 5
        self.assertIn(83, boss_levels)  # Lv75 + 8
        for sc in matrix["scenarios"]:
            if sc["difficulty"] == "extreme":
                self.assertFalse(sc["standard_baseline"])
                self.assertTrue(sc["extreme_challenge"])
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

    def test_summarizer_excludes_invalid_level_sync_and_plus8_extreme_runs(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "runs.jsonl"
            valid_run = {
                "run_id": "pg_valid_1",
                "soul_key": "berserker",
                "role": "Damage",
                "original_character_level": 75,
                "effective_combat_level": 10,
                "boss_type": "physical_bruiser",
                "boss_level": 13,
                "difficulty": "very_tough",
                "boss_preset": "normal",
                "gear_profile": "accessible_lv10",
                "combat_started": True,
                "extreme_challenge": False,
                "level_sync": {"valid": True},
                "valid_for_balance": True,
                "test_mode": "automated_real",
                "outcome": "victory",
                "metrics": {
                    "offense": {"sustained_dps": 18.5},
                    "safety": {"progression_clean": True, "exp_points_observed": 0},
                },
            }
            invalid_sync_run = {
                **valid_run,
                "run_id": "pg_invalid_sync",
                "level_sync": {"valid": False, "warnings": ["effective_level_mismatch"]},
                "valid_for_balance": False,
                "warnings": ["invalid_level_sync"],
                "metrics": {
                    "offense": {"sustained_dps": 999.0},
                    "safety": {"progression_clean": True, "exp_points_observed": 0},
                },
            }
            extreme_run = {
                **valid_run,
                "run_id": "pg_extreme_8",
                "boss_level": 18,
                "difficulty": "extreme",
                "extreme_challenge": True,
                "valid_for_balance": False,
                "metrics": {
                    "offense": {"sustained_dps": 2.0},
                    "safety": {"progression_clean": True, "exp_points_observed": 0},
                },
            }
            p.write_text(
                "\n".join(json.dumps(r) for r in (valid_run, invalid_sync_run, extreme_run)) + "\n",
                encoding="utf-8",
            )
            summary = pgb.summarize_jsonl_runs(p)
            self.assertEqual(summary["total_runs"], 3)
            self.assertEqual(summary["included_for_balance"], 1)
            self.assertEqual(summary["excluded"]["invalid_level_sync"], 1)
            self.assertEqual(summary["excluded"]["extreme_plus8_non_baseline"], 1)
            # Only the valid baseline DPS (18.5) may enter bucket averages
            self.assertEqual(list(summary["bucket_avg_dps"].values()), [18.5])

    def test_historical_timeline_compare_feedback_and_csv_export(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            (base / "events").mkdir()
            (base / "snapshots").mkdir()
            (base / "feedback").mkdir()

            run1 = {
                "run_id": "pg_run_a",
                "timestamp_utc": "2026-11-20T01:00:00Z",
                "test_mode": "manual",
                "soul_key": "berserker",
                "job": "WAR",
                "tier": "Damage",
                "original_character_level": 75,
                "effective_combat_level": 10,
                "boss_type": "physical_bruiser",
                "actual_boss_level": 13,
                "level_gap": 3,
                "difficulty": "very_tough",
                "boss_preset": "normal",
                "gear_profile": "accessible_lv10",
                "outcome": "victory",
                "prep_duration_sec": 30.0,
                "encounter_duration_sec": 10.0,
                "combat_started": True,
                "extreme_challenge": False,
                "valid_for_balance": True,
                "level_sync": {"valid": True},
                "metrics": {
                    "offense": {"total_damage": 200, "player_damage": 200, "pet_and_clone_damage": 0, "sustained_dps": 20.0, "burst_dps_10s": 20.0},
                    "defense": {"actual_incoming_damage": 150},
                    "healing": {"effective_healing": 0},
                    "threat": {"enmity_generation": 900},
                    "safety": {"progression_clean": True, "exp_points_observed": 0},
                },
            }
            run2_mismatch = {**run1, "run_id": "pg_run_b", "gear_profile": "accessible_lv75", "effective_combat_level": 75}
            (base / "runs.jsonl").write_text(json.dumps(run1) + "\n" + json.dumps(run2_mismatch) + "\n", encoding="utf-8")

            snaps = [
                {"run_id": "pg_run_a", "combat_sec": s, "combat_ms": s * 1000,
                 "players": [{"hp": 300 - s * 10, "mp": 0, "tp": s * 100}],
                 "boss": {"hp_pct": max(0, 100 - s * 10)},
                 "pets_and_clones": [],
                 "interval": {"damage_dealt": 30 if s < 5 else 5, "player_damage": 30 if s < 5 else 5, "pet_clone_damage": 0, "damage_received": 15, "healing_done": 0}}
                for s in range(10)
            ]
            (base / "snapshots" / "pg_run_a.jsonl").write_text("\n".join(json.dumps(x) for x in snaps) + "\n", encoding="utf-8")
            events = [
                {"run_id": "pg_run_a", "seq": 1, "combat_ms": 2000, "category": "defense", "event_type": "damage_spike", "value": 95},
                {"run_id": "pg_run_a", "seq": 2, "combat_ms": 4000, "category": "pet", "event_type": "pet_death", "value": 0},
            ]
            (base / "events" / "pg_run_a.jsonl").write_text("\n".join(json.dumps(x) for x in events) + "\n", encoding="utf-8")

            fb = pgb.add_feedback_to_run("pg_run_a", "damage_felt_weak", "DPS fell off at 5s", base)
            self.assertTrue(fb["ok"])

            bundle = pgb.load_run_bundle("pg_run_a", base)
            analysis = pgb.analyze_run_timeline(bundle, rolling_window=5)
            self.assertEqual(analysis["interval_count"], 10)
            self.assertEqual(len(analysis["damage_spikes"]), 1)
            self.assertTrue(len(analysis["sudden_dps_drops"]) > 0)
            self.assertEqual(len(analysis["pet_clone_lifecycle_events"]), 1)
            ascii_out = pgb.render_ascii_timeline(analysis)
            self.assertIn("DPS fell off at 5s", ascii_out)

            cmp_res = pgb.compare_runs(["pg_run_a", "pg_run_b"], base)
            self.assertTrue(cmp_res["ok"])
            self.assertFalse(cmp_res["comparable"])
            self.assertTrue(len(cmp_res["condition_mismatches"]) >= 2)

            csv_runs = base / "runs.csv"
            pgb.export_runs_csv([run1], csv_runs)
            with csv_runs.open("r", encoding="utf-8") as fh:
                rows = list(csv.DictReader(fh))
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["original_character_level"], "75")
            self.assertEqual(rows[0]["effective_combat_level"], "10")

            csv_tl = base / "tl.csv"
            pgb.export_timeline_csv(analysis, csv_tl)
            self.assertTrue(csv_tl.is_file() and csv_tl.stat().st_size > 0)


if __name__ == "__main__":
    unittest.main()
