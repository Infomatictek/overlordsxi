"""Static regression checks for provisional one-point WS Foundations.

These validate catalog coverage and mathematical proxies; they DO NOT replace
in-game damage tests, ranged/magic formula tests, or Lua engine integration.
"""
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = (ROOT / "modules/custom/lua/soulspire_ws_catalog.lua").read_text(encoding="utf-8")
FOUNDATION = (ROOT / "modules/custom/lua/soulspire_ws_foundations.lua").read_text(encoding="utf-8")
OVERRIDES = (ROOT / "modules/custom/lua/soulspire_ws_overrides.lua").read_text(encoding="utf-8")

ENTRY = re.compile(r"^\s*\[(\d+)\]\s*=\s*\n\s*\{", re.MULTILINE)
PROFILE = re.compile(
    r"\['([^']+)'\]\s*=\s*\{\s*base10\s*=\s*(\d+),\s*"
    r"base75\s*=\s*(\d+),\s*target75\s*=\s*(\d+),\s*"
    r"wsc\s*=\s*(\d+\.\d+)"
)


def load_ws():
    matches = list(ENTRY.finditer(CATALOG))
    result = []
    for i, m in enumerate(matches):
        block = CATALOG[m.start(): matches[i + 1].start() if i + 1 < len(matches) else len(CATALOG)]
        category = re.search(r"skillName\s*=\s*'([^']+)'", block)
        ws_type = re.search(r"wsType\s*=\s*'([^']+)'", block)
        hits = re.search(r"numHits\s*=\s*(\d+)", block)
        aoe = bool(re.search(r"aoe\s*=\s*true", block))
        result.append((int(m.group(1)), category.group(1), ws_type.group(1), int(hits.group(1)) if hits else 1, aoe))
    return result


class FoundationTests(unittest.TestCase):
    def test_all_219_entries_have_profile_or_explicit_utility_exclusion(self):
        entries = load_ws()
        profiles = {m.group(1) for m in PROFILE.finditer(FOUNDATION)}
        self.assertEqual(len(entries), 219)
        self.assertEqual(len({x[0] for x in entries}), 219)
        self.assertEqual(len(profiles), 15)
        self.assertTrue(all(cat in profiles for _, cat, _, _, _ in entries))
        self.assertEqual(sum(t == "utility" for _, _, t, _, _ in entries), 7)
        self.assertEqual(sum(t != "utility" for _, _, t, _, _ in entries), 212)

    def test_raw_physical_targets_at_levels_10_and_75(self):
        profiles = {
            m.group(1): {
                "base10": int(m.group(2)),
                "base75": int(m.group(3)),
                "target75": int(m.group(4)),
                "wsc": float(m.group(5)),
            }
            for m in PROFILE.finditer(FOUNDATION)
        }
        for id_, category, ws_type, hits, aoe in load_ws():
            if ws_type not in {"physical", "ranged"}:
                continue
            p = profiles[category]
            total_ftp = p["target75"] * (0.8 if aoe else 1.0) / (
                p["base75"] + 80 * 0.85 * p["wsc"]
            )
            per_hit = round(total_ftp / hits, 3)
            predicted75 = per_hit * hits * (p["base75"] + 80 * 0.85 * p["wsc"])
            target = p["target75"] * (0.8 if aoe else 1.0)
            with self.subTest(ws_id=id_, category=category):
                self.assertLess(abs(predicted75 - target) / target, 0.015)
                predicted10 = per_hit * hits * (p["base10"] + 20 * 0.85 * p["wsc"])
                self.assertGreater(predicted10, 0)

    def test_runtime_requires_investment_and_does_not_touch_zero_rank(self):
        self.assertIn("local ranks, wsSpent = talents.getWSRanks", OVERRIDES)
        self.assertIn("if wsSpent > 0 then", OVERRIDES)
        self.assertIn("local firstPoint = (wsSpent == 1)", OVERRIDES)
        self.assertIn("wsFoundations.get(ws)", OVERRIDES)
        self.assertIn("params.multiHitfTP = base.multiHitfTP or params.multiHitfTP", OVERRIDES)
        self.assertIn("ws.wsType == 'utility'", FOUNDATION)


if __name__ == "__main__":
    unittest.main()
