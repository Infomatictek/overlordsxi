"""Unit tests for OverlordsXI CI tooling: Soul coverage audit & Wiki data generator."""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parent.parent


def _load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


audit_mod = _load_module("audit_soul_coverage", REPO_ROOT / "tools" / "audit_soul_coverage.py")
wiki_mod = _load_module("generate_site_data", REPO_ROOT / "scripts" / "generate-site-data.py")


def _build_synthetic_repo(tmp: Path, *, extra_lua: dict[str, str] | None = None, init_lines: list[str] | None = None):
    """Build a minimal 22-job (66 canonical + 1 retired freelancer) synthetic repo."""
    lua_dir = tmp / "modules" / "custom" / "lua"
    lua_dir.mkdir(parents=True, exist_ok=True)
    jobs = [
        "WAR", "MNK", "WHM", "BLM", "RDM", "THF", "PLD", "DRK", "BRD", "RNG", "SAM",
        "NIN", "DRG", "BLU", "COR", "DNC", "SCH", "BST", "SMN", "PUP", "RUN", "GEO",
    ]
    blocks = []
    for job in jobs:
        entries = []
        if job == "DNC":
            entries.append("        { id = 'freelancer', name = 'Freelancer', abr = 'FRL', role = 'Support' },")
        for idx in range(1, 4):
            sid = f"{job.lower()}soul{idx}"
            entries.append(f"        {{ id = '{sid}', name = '{job} Soul {idx}', abr = '{job}', role = 'Damage' }},")
        blocks.append(f"    {job} =\n    {{\n" + "\n".join(entries) + "\n    },")
    catalog_lua = (
        "local spec = {}\n"
        "spec.JOB_SPECS =\n{\n"
        + "\n".join(blocks)
        + "\n}\n"
        "local KEY_ALIASES =\n{\n    waralias = 'warsoul1',\n}\n"
        "return spec\n"
    )
    (lua_dir / "overlords_job_specs.lua").write_text(catalog_lua, encoding="utf-8")

    default_init = ["custom/lua/overlords_job_specs.lua"]
    for rel, content in (extra_lua or {}).items():
        p = lua_dir / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
        default_init.append(f"custom/lua/{rel}")

    lines = default_init if init_lines is None else init_lines
    (tmp / "modules" / "init.append.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


class SoulCoverageAuditTests(unittest.TestCase):
    def test_real_repo_strict_passes(self):
        report = audit_mod.analyze(REPO_ROOT, baseline_path=REPO_ROOT / "tools" / "soul_coverage_baseline.json")
        self.assertEqual(report["canonical_count"], 66)
        self.assertEqual(report["retired_legacy"], ["DNC:freelancer"])
        self.assertEqual(report["errors"], [])
        self.assertGreaterEqual(report["counts"]["implemented"], 41)
        self.assertEqual(report["counts"]["incomplete"], 0)
        self.assertEqual(sum(report["counts"].values()), 66)

    def test_planned_and_name_references_do_not_count_as_implemented(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            _build_synthetic_repo(
                tmp,
                extra_lua={
                    "refs.lua": "-- warsoul2 mentioned in comment\nlocal s = 'warsoul2'\n",
                    "war_specs.lua": (
                        "local KEY1 = 'warsoul1'\n"
                        "spec.registerCrystal(xi.job.WAR, { id = 1, key = KEY1, mods = function() return {} end })\n"
                    ),
                },
            )
            report = audit_mod.analyze(tmp)
            self.assertEqual(report["errors"], [])
            by_id = {f"{r['job']}:{r['soul']}": r for r in report["rows"]}
            self.assertEqual(by_id["WAR:warsoul1"]["status"], "implemented")
            self.assertEqual(by_id["WAR:warsoul2"]["status"], "planned")
            self.assertEqual(by_id["WAR:warsoul2"]["notes"], "referenced-in-lua")
            self.assertEqual(by_id["WAR:warsoul3"]["status"], "planned")
            self.assertEqual(by_id["WAR:warsoul3"]["notes"], "catalog-only")

    def test_dynamic_loop_registration_detected(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            _build_synthetic_repo(
                tmp,
                extra_lua={
                    "dyn_specs.lua": (
                        "local SPECS = {\n"
                        "  { id = 1, key = 'warsoul1', mods = function() return {} end },\n"
                        "  { id = 2, key = 'warsoul2', extraAbilities = { 100 } },\n"
                        "}\n"
                        "for _, entry in ipairs(SPECS) do\n"
                        "  spec.registerCrystal(xi.job.WAR, entry)\n"
                        "end\n"
                    ),
                },
            )
            report = audit_mod.analyze(tmp)
            self.assertEqual(report["errors"], [])
            by_id = {f"{r['job']}:{r['soul']}": r for r in report["rows"]}
            self.assertEqual(by_id["WAR:warsoul1"]["status"], "implemented")
            self.assertEqual(by_id["WAR:warsoul2"]["status"], "implemented")

    def test_duplicate_registration_fails(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            _build_synthetic_repo(
                tmp,
                extra_lua={
                    "war_a.lua": "spec.registerCrystal(xi.job.WAR, { id = 1, key = 'warsoul1', mods = function() return {} end })\n",
                    "war_b.lua": "spec.registerCrystal(xi.job.WAR, { id = 1, key = 'waralias', mods = function() return {} end })\n",
                },
            )
            report = audit_mod.analyze(tmp)
            self.assertTrue(any("Duplicate Soul registration for WAR:warsoul1" in e for e in report["errors"]))

    def test_retired_freelancer_registration_fails(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            _build_synthetic_repo(
                tmp,
                extra_lua={
                    "dnc_bad.lua": "spec.registerCrystal(xi.job.DNC, { id = 1, key = 'freelancer', mods = function() return {} end })\n",
                },
            )
            report = audit_mod.analyze(tmp)
            self.assertTrue(any("Retired legacy Soul DNC:freelancer" in e for e in report["errors"]))

    def test_missing_dependency_and_unlisted_module_fail(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            _build_synthetic_repo(
                tmp,
                extra_lua={
                    "war_specs.lua": (
                        "require('modules/custom/lua/does_not_exist')\n"
                        "spec.registerCrystal(xi.job.WAR, { id = 1, key = 'warsoul1', mods = function() return {} end })\n"
                    ),
                },
                init_lines=["custom/lua/overlords_job_specs.lua"],
            )
            report = audit_mod.analyze(tmp)
            self.assertTrue(any("requires missing module" in e for e in report["errors"]))
            self.assertTrue(any("not listed in modules/init.append.txt" in e for e in report["errors"]))
            by_id = {f"{r['job']}:{r['soul']}": r for r in report["rows"]}
            self.assertEqual(by_id["WAR:warsoul1"]["status"], "incomplete")

    def test_baseline_regression_fails(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            _build_synthetic_repo(tmp)
            baseline = tmp / "baseline.json"
            baseline.write_text(json.dumps({"implemented": ["WAR:warsoul1"]}), encoding="utf-8")
            report = audit_mod.analyze(tmp, baseline_path=baseline)
            self.assertTrue(any("Regression: previously implemented Soul WAR:warsoul1" in e for e in report["errors"]))


class WikiGeneratorValidationTests(unittest.TestCase):
    def test_validate_generated_wiki_files_valid(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            payload = {
                "generatedAt": "2026-11-19T00:00:00Z",
                "repo": "Infomatictek/overlordsxi",
                "launcherRepo": "Infomatictek/overlordsxi-launcher",
                "stats": {"totalCrystalSpecs": 1, "totalWeaponskills": 1},
                "serverRules": {},
                "jobSpecs": [{"jobKey": "WAR", "crystals": [{"key": "commander"}]}],
                "weaponskills": [{"id": 1, "name": "Fast Blade"}],
                "commands": [],
                "patches": [],
                "commits": [],
            }
            jtxt = json.dumps(payload)
            jp = tmp / "data.json"
            jsp = tmp / "data.js"
            jp.write_text(jtxt, encoding="utf-8")
            jsp.write_text(f"window.OVERLORDS_DATA = {jtxt};\n", encoding="utf-8")
            parsed = wiki_mod.validate_generated_wiki_files(jp, jsp)
            self.assertEqual(parsed["stats"]["totalCrystalSpecs"], 1)

    def test_validate_generated_wiki_files_rejects_corrupt_json_and_js(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            jp = tmp / "data.json"
            jsp = tmp / "data.js"
            jp.write_text("{bad json", encoding="utf-8")
            jsp.write_text("window.OVERLORDS_DATA = {};\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                wiki_mod.validate_generated_wiki_files(jp, jsp)

            valid = {
                "generatedAt": "2026-11-19T00:00:00Z",
                "repo": "Infomatictek/overlordsxi",
                "launcherRepo": "Infomatictek/overlordsxi-launcher",
                "stats": {"totalCrystalSpecs": 1, "totalWeaponskills": 1},
                "serverRules": {},
                "jobSpecs": [{"jobKey": "WAR"}],
                "weaponskills": [{"id": 1}],
                "commands": [],
                "patches": [],
                "commits": [],
            }
            jp.write_text(json.dumps(valid), encoding="utf-8")
            jsp.write_text("window.OVERLORDS_DATA = {\"mismatch\":true};\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                wiki_mod.validate_generated_wiki_files(jp, jsp)

    def test_require_lua_fails_when_lua_missing(self):
        with mock.patch.object(wiki_mod, "find_lua_binary", return_value=None):
            rc = wiki_mod.main(["--require-lua", "--validate-only"])
            self.assertEqual(rc, 1)


if __name__ == "__main__":
    unittest.main()
