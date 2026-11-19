#!/usr/bin/env python3
"""Audit player-facing Soul playstyle guide coverage (not gameplay completeness).

Run: python tools/audit_soul_wiki_guides.py . --csv soul-guides.csv
Use --strict to fail when ANY active Soul lacks a complete handwritten guide.
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

REGISTRY = Path("modules/custom/lua/overlords_job_specs.lua")
GUIDES = Path("docs/guides")
JOB = re.compile(r"^\s*([A-Z]{3})\s*=\s*$")
ENTRY = re.compile(r"\bid\s*=\s*['\"]([a-z][a-z0-9_]*)['\"]")
RETIRED = {("DNC", "freelancer")}
HEADINGS = {
    "at a glance": "Overview",
    "setup & gear": "Setup & Gear",
    "how to play (step-by-step)": "How to Play",
    "key mechanics & stacks": "Key Mechanics",
    "common mistakes (don't do this)": "Common Mistakes",
}


def active_souls(root: Path) -> list[tuple[str, str]]:
    source = (root / REGISTRY).read_text(encoding="utf-8-sig")
    start = source.find("spec.JOB_SPECS =")
    end = source.find("local KEY_ALIASES", start)
    if start < 0 or end < 0:
        raise ValueError("Canonical Soul registry boundary is unknown")
    results = []
    job = None
    for line in source[start:end].splitlines():
        found = JOB.match(line)
        if found:
            job = found.group(1)
        found = ENTRY.search(line)
        if found and job and (job, found.group(1)) not in RETIRED:
            results.append((job, found.group(1)))
    if len(results) != 66:
        raise ValueError(f"Expected 66 active Souls, found {len(results)}")
    return results


def audit(root: Path) -> list[dict[str, str]]:
    results = []
    for job, key in active_souls(root):
        path = root / GUIDES / (key + ".md")
        missing = []
        if not path.is_file():
            state = "missing"
            missing = list(HEADINGS.values())
        else:
            text = path.read_text(encoding="utf-8-sig", errors="replace")
            sections = {}
            heading = None
            for line in text.splitlines():
                found = re.match(r"^##\s+(.+?)\s*$", line)
                if found:
                    heading = found.group(1).strip().lower()
                    sections[heading] = []
                elif heading is not None:
                    sections[heading].append(line.strip())

            for key_heading, friendly in HEADINGS.items():
                lines = sections.get(key_heading, [])
                meaningful = [line for line in lines if line and not line.startswith("<!--")]
                if not meaningful:
                    missing.append(friendly)
            steps = sections.get("how to play (step-by-step)", [])
            if sum(bool(re.match(r"\d+\.\s+", line)) for line in steps) < 2:
                missing.append("At least two numbered play steps")
            state = "complete" if not missing else "thin"

        results.append({
            "job": job,
            "soul": key,
            "guide": str((GUIDES / (key + ".md")).as_posix()),
            "status": state,
            "issues": "; ".join(missing),
        })
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--csv")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    try:
        rows = audit(Path(args.root).resolve())
    except (OSError, ValueError) as exc:
        print(f"Soul wiki guide audit failed: {exc}", file=sys.stderr)
        return 2
    summary = {s: sum(r["status"] == s for r in rows) for s in ("complete", "thin", "missing")}
    print(f"Soul guides: {summary['complete']}/66 complete; {summary['thin']} thin; {summary['missing']} missing.")
    for row in rows:
        if row["status"] != "complete":
            print(f"  {row['job']}/{row['soul']}: {row['status']} ({row['issues']})")
    if args.csv:
        with open(args.csv, "w", encoding="utf-8", newline="") as target:
            writer = csv.DictWriter(target, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
    return 1 if args.strict and summary["complete"] != 66 else 0


if __name__ == "__main__":
    raise SystemExit(main())
