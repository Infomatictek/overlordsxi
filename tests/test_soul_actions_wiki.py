"""Automated validation tests for SoulspireXI Soul Action Wiki integration."""
from __future__ import annotations

import importlib.util
import json
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def _load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


saw = _load_module("soul_actions_wiki_test_mod", REPO_ROOT / "scripts" / "soul_actions_wiki.py")


class SoulActionWikiValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.roster = saw.build_soul_roster(REPO_ROOT)

    def test_roster_covers_all_66_souls_and_legacy_aliases(self):
        self.assertEqual(len(self.roster["souls"]), 66)
        for raw, expected in (
            ("shinobi", "kurogane"),
            ("kurogane", "kurogane"),
            ("aegistemplar", "defender"),
            ("defender", "defender"),
            ("soulbeast", "alphawarden"),
            ("gladiator", "spartan"),
            ("marionettist", "vanguard"),
            ("caller", "celestial"),
        ):
            canonical, entry = saw.resolve_soul_key(raw, self.roster)
            self.assertEqual(canonical, expected, f"Failed alias resolution for {raw}")
            self.assertIsNotNone(entry)

    def test_duplicate_ids_detected_including_across_aliases(self):
        tsv = "\n".join(
            [
                "shinobi\tspell\t338\tShadow Squadron: Ichi\tSummon 2 offensive shadow clones. 20s recast.",
                "kurogane\tspell\t338\tShadow Squadron: Ichi\tDuplicate via legacy alias. 20s recast.",
            ]
        )
        rows, errors = saw.parse_soul_actions_tsv(tsv, self.roster)
        self.assertEqual(len(rows), 1)
        self.assertTrue(any("duplicate action ID" in e for e in errors))

        vis = "\n".join(
            [
                "shinobi\tspell\t338\t10\tunlock",
                "kurogane\tspell\t338\t10\tunlock",
            ]
        )
        vrows, verrors = saw.parse_visibility_tsv(vis, self.roster)
        self.assertEqual(len(vrows), 1)
        self.assertTrue(any("duplicate visibility ID" in e for e in verrors))

    def test_missing_soul_mapping_detected(self):
        tsv = "nonexistent_soul\tspell\t338\tTest Action\tTest description."
        _, errors = saw.parse_soul_actions_tsv(tsv, self.roster)
        self.assertTrue(any("missing Soul mapping" in e for e in errors))

        vis = "nonexistent_soul\tspell\t338\t10\tunlock"
        _, verrors = saw.parse_visibility_tsv(vis, self.roster)
        self.assertTrue(any("missing Soul mapping" in e for e in verrors))

    def test_invalid_unlock_levels_rejected(self):
        vis = "\n".join(
            [
                "shinobi\tspell\t338\t0\tunlock",
                "shinobi\tspell\t339\t76\tunlock",
                "shinobi\tspell\t320\tabc\tunlock",
            ]
        )
        rows, errors = saw.parse_visibility_tsv(vis, self.roster)
        self.assertEqual(len(rows), 0)
        self.assertEqual(len(errors), 3)

    def test_unsupported_action_for_planned_soul_rejected(self):
        # THF:trickster is currently planned
        tsv = "trickster\tspell\t100\tPhantom Trick\tPrototype ability."
        actions, parse_errors = saw.parse_soul_actions_tsv(tsv, self.roster)
        self.assertEqual(parse_errors, [])
        _, audit = saw.integrate_soul_actions(
            jobs=[],
            job_meta={},
            roster=self.roster,
            launcher_actions=actions,
            launcher_visibility=[],
        )
        self.assertTrue(any("prototype mechanics cannot be published" in e for e in audit["errors"]))

    def test_unlock_level_mismatch_and_stale_description_detected(self):
        tsv = "\n".join(
            [
                "shinobi\tspell\t339\tShadow Squadron: Ni\tSummon 4 offensive shadow clones. 99s recast.",
            ]
        )
        vis = "shinobi\tspell\t339\t30\tunlock"
        actions, p_err = saw.parse_soul_actions_tsv(tsv, self.roster)
        vis_rows, v_err = saw.parse_visibility_tsv(vis, self.roster)
        self.assertEqual(p_err, [])
        self.assertEqual(v_err, [])

        jobs = [
            {
                "jobKey": "NIN",
                "jobId": 13,
                "jobName": "Ninja",
                "color": "#f43f5e",
                "crystals": [
                    {
                        "id": 1,
                        "key": "kurogane",
                        "name": "Shinobi",
                        "role": "Damage",
                        "reqLevel": 10,
                        "description": "Shinobi test",
                        "highlights": [],
                        "passiveMods": [],
                        "customAbilities": [],
                        "customTraits": [],
                    }
                ],
            }
        ]
        kit_spells = {
            "shinobi": {
                "339": {
                    "id": 339,
                    "name": "Shadow Squadron: Ni",
                    "script": "utsusemi_ni",
                    "unlockLvl": 37,
                    "castMs": 1200,
                    "recastSec": 30,
                    "summonCount": 3,
                }
            }
        }
        _, audit = saw.integrate_soul_actions(
            jobs=jobs,
            job_meta={"NIN": {"id": 13, "name": "Ninja", "color": "#f43f5e"}},
            roster=self.roster,
            kit_spells_by_soul=kit_spells,
            server_spell_grants={"kurogane": {339: 37}},
            launcher_actions=actions,
            launcher_visibility=vis_rows,
        )
        self.assertTrue(any("Unlock level mismatch" in e for e in audit["errors"]))
        self.assertTrue(any("Stale description recast" in e for e in audit["errors"]))
        self.assertTrue(any("Stale description summon count" in e for e in audit["errors"]))

    def test_vanilla_spell_name_leakage_rejected(self):
        tsv = "shinobi\tspell\t338\tShadow Squadron (Utsusemi: Ichi)\tSummon 2 clones via Utsusemi: Ichi. 20s recast."
        actions, _ = saw.parse_soul_actions_tsv(tsv, self.roster)
        jobs = [
            {
                "jobKey": "NIN",
                "jobId": 13,
                "jobName": "Ninja",
                "color": "#f43f5e",
                "crystals": [
                    {
                        "id": 1,
                        "key": "kurogane",
                        "name": "Shinobi",
                        "role": "Damage",
                        "reqLevel": 10,
                        "description": "Shinobi test",
                        "highlights": [],
                        "passiveMods": [],
                        "customAbilities": [],
                        "customTraits": [],
                    }
                ],
            }
        ]
        kit_spells = {
            "shinobi": {
                "338": {
                    "id": 338,
                    "name": "Shadow Squadron: Ichi",
                    "script": "utsusemi_ichi",
                    "unlockLvl": 10,
                    "castMs": 1500,
                    "recastSec": 20,
                    "summonCount": 2,
                }
            }
        }
        _, audit = saw.integrate_soul_actions(
            jobs=jobs,
            job_meta={"NIN": {"id": 13, "name": "Ninja", "color": "#f43f5e"}},
            roster=self.roster,
            kit_spells_by_soul=kit_spells,
            server_spell_grants={"kurogane": {338: 10}},
            launcher_actions=actions,
            launcher_visibility=[],
        )
        self.assertTrue(any("Vanilla spell name leakage" in e for e in audit["errors"]))

    def test_unsupported_spell_and_ability_ids_rejected(self):
        tsv = "\n".join(
            [
                "shinobi\tspell\t999\tFake Spell\tNot granted by server.",
                "shinobi\tability\t1500\tFake Ability\tNot registered by server.",
            ]
        )
        actions, _ = saw.parse_soul_actions_tsv(tsv, self.roster)
        jobs = [
            {
                "jobKey": "NIN",
                "jobId": 13,
                "jobName": "Ninja",
                "color": "#f43f5e",
                "crystals": [
                    {
                        "id": 1,
                        "key": "kurogane",
                        "name": "Shinobi",
                        "role": "Damage",
                        "reqLevel": 10,
                        "description": "Shinobi test",
                        "highlights": [],
                        "passiveMods": [],
                        "customAbilities": [],
                        "customTraits": [],
                    }
                ],
            }
        ]
        _, audit = saw.integrate_soul_actions(
            jobs=jobs,
            job_meta={"NIN": {"id": 13, "name": "Ninja", "color": "#f43f5e"}},
            roster=self.roster,
            launcher_actions=actions,
            launcher_visibility=[],
        )
        self.assertTrue(any("Unsupported spell action" in e for e in audit["errors"]))
        self.assertTrue(any("Unsupported ability action" in e for e in audit["errors"]))

    def test_generated_site_data_shinobi_actions_and_66_souls(self):
        data_path = REPO_ROOT / "site" / "data.json"
        if not data_path.is_file():
            self.skipTest("site/data.json not present")
        data = json.loads(data_path.read_text(encoding="utf-8"))
        self.assertEqual(data["stats"]["totalCanonicalSouls"], 66)
        self.assertEqual(data["stats"]["totalCrystalSpecs"], 66)
        self.assertEqual(data["soulActionAudit"]["errorCount"], 0)

        nin = next(j for j in data["jobSpecs"] if j["jobKey"] == "NIN")
        shinobi = next(c for c in nin["crystals"] if c["key"] == "kurogane")
        self.assertEqual(shinobi["name"], "Shinobi")
        self.assertEqual(shinobi["actionKey"], "shinobi")
        self.assertIn("kurogane", shinobi["aliases"])
        self.assertIn("shinobi", shinobi["aliases"])
        self.assertEqual(shinobi["guide"]["sourceFile"], "docs/guides/shinobi.md")
        self.assertTrue(shinobi["guide"]["hasHandwrittenGuide"])

        actions_by_name = {a["name"]: a for a in shinobi["soulActions"]}
        expected_levels = {
            "Shadow Squadron: Ichi": 10,
            "False Assault": 10,
            "Mirror Step": 10,
            "Crosscut": 10,
            "Shadow Pin": 30,
            "Shadow Squadron: Ni": 37,
            "Thunder Relay": 50,
            "Final Mirage": 70,
            "Shadow Legion": 10,
            "Phantom Assault": 10,
        }
        for name, lvl in expected_levels.items():
            self.assertIn(name, actions_by_name, f"Missing Shinobi action: {name}")
            self.assertEqual(actions_by_name[name]["unlockLevel"], lvl)

        # Ensure zero vanilla spell names appear in Shinobi's action names/descriptions
        forbidden = ("Utsusemi", "Katon", "Hyoton", "Huton", "Doton", "Raiton", "Suiton")
        for act in shinobi["soulActions"]:
            blob = f"{act['name']} {act['description']}"
            for vname in forbidden:
                self.assertNotIn(vname.lower(), blob.lower(), f"Vanilla name '{vname}' leaked in {act['name']}")


if __name__ == "__main__":
    unittest.main()
