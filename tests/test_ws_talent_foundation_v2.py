"""Regression & integrity tests for SoulspireXI WS Talent Foundation Pass 2.0."""
from __future__ import annotations

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "modules/custom/data/ws_eligibility_manifest.json"
CONTRACTS_PATH = ROOT / "modules/custom/data/ws_talent_contracts.json"


class WsTalentFoundationV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        cls.contracts = json.loads(CONTRACTS_PATH.read_text(encoding="utf-8"))

    def test_01_all_66_canonical_souls_in_manifest_and_contracts(self) -> None:
        self.assertEqual(self.manifest["canonical_soul_count"], 66)
        self.assertEqual(len(self.manifest["souls"]), 66)
        self.assertEqual(self.contracts["canonical_souls"], 66)
        self.assertEqual(set(self.manifest["souls"].keys()), set(self.contracts["by_soul_summary"].keys()))

    def test_02_significant_reduction_from_weapon_filtering(self) -> None:
        s = self.manifest["summary"]
        self.assertEqual(s["total_approved_soul_ws_combinations"], 1476)
        self.assertGreaterEqual(s["reduction_vs_equipable_pct"], 70.0)
        self.assertGreater(s["estimated_talent_defs_avoided"], 45000)

    def test_03_zero_contracts_generated_for_excluded_weapons(self) -> None:
        eligible_by_soul = {
            skey: set(entry["eligible_ws_ids"])
            for skey, entry in self.manifest["souls"].items()
        }
        for c in self.contracts["contracts"]:
            skey = c["soul"]
            ws_id = int(c["ws"])
            self.assertIn(ws_id, eligible_by_soul[skey], f"Excluded WS {ws_id} found for {skey}")

    def test_04_berserker_spartan_bladewheel_flintlock_weapon_identities(self) -> None:
        souls = self.manifest["souls"]
        self.assertEqual(souls["berserker"]["approved_weapon_families"], ["Great Axe", "Axe"])
        self.assertIn("Sword", souls["berserker"]["excluded_weapon_families"])
        self.assertEqual(souls["spartan"]["approved_weapon_families"], ["Polearm"])
        self.assertEqual(souls["bladewheel"]["approved_weapon_families"], ["Throwing", "Dagger"])
        self.assertIn("Sword", souls["bladewheel"]["excluded_weapon_families"])
        self.assertEqual(souls["flintlock"]["approved_weapon_families"], ["Marksmanship"])
        self.assertEqual(souls["kurogane"]["approved_weapon_families"], ["Katana"])
        self.assertEqual(souls["scarletweaver"]["approved_weapon_families"], ["Sword"])

    def test_05_every_contract_uses_registered_effect_taxonomy(self) -> None:
        taxonomy = self.contracts["effect_taxonomy"]
        self.assertGreaterEqual(len(taxonomy), 20)
        for et, meta in taxonomy.items():
            for field in ("phase", "trigger_event", "observable_via", "validation_rule", "failure_mode"):
                self.assertTrue(meta.get(field), f"Taxonomy {et} missing {field}")
        for c in self.contracts["contracts"]:
            self.assertTrue(c.get("id"))
            self.assertTrue(c.get("eff"), f"Contract {c.get('id')} has empty effects")
            for ef in c["eff"]:
                self.assertIn(ef["t"], taxonomy, f"Unknown effect_type {ef['t']} in {c['id']}")

    def test_06_all_66_souls_have_three_branch_coverage(self) -> None:
        for skey, summ in self.contracts["by_soul_summary"].items():
            br = summ["branches"]
            self.assertGreater(br.get("damage", 0), 0, f"{skey} missing damage branch")
            self.assertGreater(br.get("utility", 0), 0, f"{skey} missing utility branch")
            self.assertGreater(br.get("soul", 0), 0, f"{skey} missing soul branch")
            self.assertTrue(summ.get("soul_hook_id"), f"{skey} missing soul_hook_id")


if __name__ == "__main__":
    unittest.main()
