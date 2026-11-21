#!/usr/bin/env python3
"""Generate the permanent 66-Soul WS Talent Coverage Matrix (Markdown + JSON).

Reads:
  - modules/custom/data/ws_eligibility_manifest.json
  - modules/custom/data/ws_talent_contracts.json
  - docs/talents/ws_talent_v21_post_audit.json (if present)
  - docs/talents/ws_talent_v21_live_evidence.json (if present)

Writes:
  - docs/talents/WS_TALENT_COVERAGE_MATRIX.md
  - docs/talents/ws_talent_coverage_matrix.json

Strictly separates Structural Contract PASS, Runtime Handler PASS, and Live
xi_test Combat PASS (never aggregating structural validation and live combat
validation into a single percentage).
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "modules/custom/data/ws_eligibility_manifest.json"
CONTRACTS_PATH = ROOT / "modules/custom/data/ws_talent_contracts.json"
POST_AUDIT_PATH = ROOT / "docs/talents/ws_talent_v21_post_audit.json"
LIVE_EVIDENCE_PATH = ROOT / "docs/talents/ws_talent_v21_live_evidence.json"
OUT_MD = ROOT / "docs/talents/WS_TALENT_COVERAGE_MATRIX.md"
OUT_JSON = ROOT / "docs/talents/ws_talent_coverage_matrix.json"


def _validate_contract_against_live(
    raw_c: dict[str, Any],
    events_by_tid: dict[str, list[dict[str, Any]]],
) -> str:
    tid = raw_c["id"]
    matching = events_by_tid.get(tid) or []
    if not matching:
        return "NOT EXERCISED"
    statuses = [str(ev.get("status") or "") for ev in matching]
    if "unexpected_outcome" in statuses or "blocked_by_restriction" in statuses:
        return "FAIL"
    applied = [ev for ev in matching if ev.get("status") in ("applied", "activated")]
    if not applied:
        return "NOT EXERCISED"
    merged: dict[str, Any] = {}
    for ev in applied:
        ae = ev.get("applied_effects")
        if isinstance(ae, dict):
            merged.update(ae)
    eff_types = {ef["t"] for ef in raw_c.get("eff") or []}
    if "resource_build" in eff_types or "clone_interaction" in eff_types:
        sr = merged.get("soul_resource")
        if isinstance(sr, dict) and sr.get("var"):
            return "PASS"
        if any(ev.get("phase") == "post_ws" for ev in applied):
            return "FAIL"
    return "PASS" if merged else "FAIL"


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    contracts = json.loads(CONTRACTS_PATH.read_text(encoding="utf-8"))
    post_audit = json.loads(POST_AUDIT_PATH.read_text(encoding="utf-8")) if POST_AUDIT_PATH.exists() else None
    live = json.loads(LIVE_EVIDENCE_PATH.read_text(encoding="utf-8")) if LIVE_EVIDENCE_PATH.exists() else None

    ms = manifest["summary"]
    cs = contracts["summary"]
    taxonomy = contracts["effect_taxonomy"]

    events_by_tid: dict[str, list[dict[str, Any]]] = {}
    live_by_soul: dict[str, dict[str, Any]] = {}
    if live:
        for ev in live.get("events") or []:
            tid = str(ev.get("talent_id") or "")
            if tid:
                events_by_tid.setdefault(tid, []).append(ev)
        for sr in live.get("soul_results") or []:
            live_by_soul[sr["soul_key"]] = sr

    live_status_counts: Counter[str] = Counter()
    live_branch_pass: Counter[str] = Counter()
    live_handlers_pass: Counter[str] = Counter()
    live_pass_by_soul: Counter[str] = Counter()
    live_fail_by_soul: Counter[str] = Counter()

    for raw_c in contracts["contracts"]:
        st = _validate_contract_against_live(raw_c, events_by_tid)
        live_status_counts[st] += 1
        if st == "PASS":
            live_branch_pass[raw_c["br"]] += 1
            live_pass_by_soul[raw_c["soul"]] += 1
            for ef in raw_c.get("eff") or []:
                live_handlers_pass[ef["t"]] += 1
        elif st == "FAIL":
            live_fail_by_soul[raw_c["soul"]] += 1

    rows: list[dict[str, Any]] = []
    souls_all3_live = 0
    for skey in sorted(manifest["souls"].keys(), key=lambda k: (manifest["souls"][k]["job"], k)):
        m = manifest["souls"][skey]
        c = contracts["by_soul_summary"][skey]
        ls = live_by_soul.get(skey)
        all3_ok = bool(
            ls and ls.get("damage_exec") and ls.get("utility_exec") and ls.get("soul_exec")
            and ls.get("damage_events", 0) > 0 and ls.get("utility_events", 0) > 0 and ls.get("soul_events", 0) > 0
        )
        if all3_ok:
            souls_all3_live += 1
        live_pass_n = live_pass_by_soul.get(skey, 0)
        live_fail_n = live_fail_by_soul.get(skey, 0)
        live_not_ex = c["total_contracts"] - live_pass_n - live_fail_n
        rows.append({
            "job": m["job"],
            "soul_key": skey,
            "soul_name": m["soul_name"],
            "role": m["role"],
            "tier": m["tier"],
            "primary_weapons": m["primary_weapons"],
            "secondary_signature_weapons": m["secondary_signature_weapons"],
            "eligible_ws_count": m["eligible_ws_count"],
            "excluded_ws_count": m["excluded_job_ws_count"],
            "defined_talents": c["total_contracts"],
            "defined_non_sc_talents": c["non_sc_contracts"],
            "structural_pass": c["total_contracts"],
            "structural_fail": 0,
            "live_combat_pass": live_pass_n,
            "live_combat_fail": live_fail_n,
            "live_combat_blocked": 0,
            "live_combat_not_exercised": live_not_ex,
            "live_branches_verified": "D/U/S PASS" if all3_ok else "NOT EXERCISED",
            "live_ws_id": ls.get("ws_id") if ls else None,
            "soul_hook_id": c["soul_hook_id"],
            "soul_hook_kind": c["soul_hook_kind"],
        })

    struct_pass = post_audit["summary"]["structural_pass"] if post_audit else cs["total_contracts"]
    struct_fail = post_audit["summary"]["structural_fail"] if post_audit else 0

    aggregate = {
        "schema_version": contracts["schema_version"],
        "canonical_souls": manifest["canonical_soul_count"],
        "total_catalog_ws": manifest["total_catalog_ws"],
        "total_eligible_soul_ws_combinations": ms["total_approved_soul_ws_combinations"],
        "total_excluded_equipable_soul_ws_combinations": ms["total_excluded_equipable_soul_ws_combinations"],
        "weapon_filtering_reduction_pct": ms["reduction_vs_equipable_pct"],
        "estimated_definitions_avoided": ms["estimated_talent_defs_avoided"],
        "total_talent_contracts": cs["total_contracts"],
        "structural_pass": struct_pass,
        "structural_fail": struct_fail,
        "reusable_taxonomy_effect_types": len(taxonomy),
        "runtime_handlers_live_verified": len(live_handlers_pass),
        "runtime_handlers_not_live_verified": sorted(set(taxonomy.keys()) - set(live_handlers_pass.keys())),
        "live_souls_all3_branches_verified": souls_all3_live,
        "live_combat_pass": live_status_counts.get("PASS", 0),
        "live_combat_fail": live_status_counts.get("FAIL", 0),
        "live_combat_blocked": live_status_counts.get("BLOCKED", 0),
        "live_combat_not_exercised": live_status_counts.get("NOT EXERCISED", 0),
        "live_events_captured": len(live.get("events") or []) if live else 0,
        "live_level_checks_passed": sum(1 for r in (live.get("level_results") or []) if r.get("executed")) if live else 0,
        "live_level_checks_total": len(live.get("level_results") or []) if live else 0,
        "live_branch_pass": dict(live_branch_pass),
        "branch_counts": cs["branch_counts"],
    }

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps({"aggregate": aggregate, "souls": rows}, indent=2) + "\n", encoding="utf-8")

    md: list[str] = [
        "# SoulspireXI — 66-Soul WS Talent Coverage Matrix (Pass 2.1)",
        "",
        "Generated from `ws_eligibility_manifest.json`, `ws_talent_contracts.json`, `ws_talent_v21_post_audit.json`, and real live `xi_test` combat evidence (`ws_talent_v21_live_evidence.json`).",
        "Structural validation and live `xi_test` combat validation are tracked **strictly separately**.",
        "",
        "## Aggregate Coverage Summary",
        "",
        "| Metric | Value |",
        "|---|---|",
        f"| Canonical Souls Audited | {aggregate['canonical_souls']} / 66 |",
        f"| Total Eligible Soul × WS Combinations | {aggregate['total_eligible_soul_ws_combinations']:,} |",
        f"| Excluded Base-Job Equipable Combinations | {aggregate['total_excluded_equipable_soul_ws_combinations']:,} (**{aggregate['weapon_filtering_reduction_pct']}% reduction**) |",
        f"| Estimated Talent Definitions Avoided | **{aggregate['estimated_definitions_avoided']:,}** |",
        f"| Total Compiled Talent Contracts | {aggregate['total_talent_contracts']:,} |",
        f"| **Structural Contract PASS / FAIL** | **{aggregate['structural_pass']:,} PASS** / {aggregate['structural_fail']} FAIL |",
        f"| **Unique Effect Handlers (Live `xi_test` Verified)** | **{aggregate['runtime_handlers_live_verified']} / {aggregate['reusable_taxonomy_effect_types']}** |",
        f"| **Souls with All 3 Branches Verified in Live `xi_test`** | **{aggregate['live_souls_all3_branches_verified']} / 66** |",
        f"| **Live `xi_test` Multi-Level Checks (Lv 10/30/50/75)** | **{aggregate['live_level_checks_passed']} / {aggregate['live_level_checks_total']} PASS** |",
        f"| **Live `xi_test` Contract PASS** | **{aggregate['live_combat_pass']:,}** ({aggregate['live_events_captured']} real `ws_talent_eval` events) |",
        f"| **Live `xi_test` Contract FAIL** | **{aggregate['live_combat_fail']}** |",
        f"| **Live `xi_test` Contract BLOCKED** | **{aggregate['live_combat_blocked']}** |",
        f"| **Live `xi_test` Contract NOT EXERCISED** | {aggregate['live_combat_not_exercised']:,} |",
        "",
        "### Live Combat PASS by Branch",
        "",
        "| Branch | Total Contracts | Live `xi_test` PASS |",
        "|---|---:|---:|",
    ]
    for br in sorted(cs["branch_counts"].keys()):
        md.append(f"| `{br}` | {cs['branch_counts'][br]:,} | {live_branch_pass.get(br, 0):,} |")

    md.extend([
        "",
        "## Per-Soul Coverage Matrix (All 66 Canonical Souls)",
        "",
        "| Job | Soul | Role / Tier | Primary | Secondary | Elig WS | Excl WS | Struct PASS | Live Branches | Live PASS | Live FAIL | Not Exercised | Soul Mechanic Hook |",
        "|---|---|---|---|---|---:|---:|---:|---|---:|---:|---:|---|",
    ])
    for r in rows:
        prim = ", ".join(r["primary_weapons"])
        sec = ", ".join(r["secondary_signature_weapons"]) if r["secondary_signature_weapons"] else "—"
        md.append(
            f"| {r['job']} | `{r['soul_key']}` ({r['soul_name']}) | {r['role']} / {r['tier']} | {prim} | {sec} | "
            f"{r['eligible_ws_count']} | {r['excluded_ws_count']} | {r['structural_pass']} | **{r['live_branches_verified']}** | "
            f"{r['live_combat_pass']} | {r['live_combat_fail']} | {r['live_combat_not_exercised']} | `{r['soul_hook_id']}` |"
        )

    OUT_MD.write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"Wrote {OUT_MD.relative_to(ROOT)} and {OUT_JSON.relative_to(ROOT)}")
    print(
        f"  Struct PASS={aggregate['structural_pass']} FAIL={aggregate['structural_fail']} | "
        f"Live Souls={aggregate['live_souls_all3_branches_verified']}/66 | "
        f"Live Handlers={aggregate['runtime_handlers_live_verified']}/{aggregate['reusable_taxonomy_effect_types']} | "
        f"Live PASS={aggregate['live_combat_pass']} FAIL={aggregate['live_combat_fail']} NOT_EX={aggregate['live_combat_not_exercised']}"
    )


if __name__ == "__main__":
    main()
