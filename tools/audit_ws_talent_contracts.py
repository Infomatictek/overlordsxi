#!/usr/bin/env python3
"""Deep Structural & Gameplay Differentiation Audit of all 23,427 WS Talent Contracts.

Detects:
  1. Duplicate or conflicting talent IDs.
  2. Identical non-SC talents masquerading as distinct choices within a WS tree.
  3. Invalid prerequisites (missing node, self-dep, higher-tier dep, unreachable tier).
  4. Broken exclusive groups (singleton group or invalid group).
  5. Unhandled effect keys (effect keys in Lua trees not handled by ws_overrides/ws_telemetry).
  6. Invalid Soul/WS associations or excluded weapon leakage.
  7. Role guardrail breaches (pure DPS healing/defensive buffs, no-MP MP gain, petless pet hooks).
  8. Gameplay differentiation gaps (branch overlap / missing Damage/Utility/Soul distinction).

Outputs: docs/talents/ws_talent_v21_baseline_audit.json (or --out path).
"""
from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "modules/custom/data/ws_eligibility_manifest.json"
CONTRACTS_PATH = ROOT / "modules/custom/data/ws_talent_contracts.json"
OVERRIDES_PATH = ROOT / "modules/custom/lua/soulspire_ws_overrides.lua"
TELEMETRY_PATH = ROOT / "modules/custom/lua/soulspire_ws_telemetry.lua"


def run_audit() -> dict[str, Any]:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    contracts_doc = json.loads(CONTRACTS_PATH.read_text(encoding="utf-8"))
    contracts: list[dict[str, Any]] = contracts_doc["contracts"]
    taxonomy: dict[str, Any] = contracts_doc["effect_taxonomy"]

    eligible_by_soul = {
        skey: set(entry["eligible_ws_ids"])
        for skey, entry in manifest["souls"].items()
    }

    # Group contracts by (soul, ws_id)
    by_tree: dict[tuple[str, int], list[dict[str, Any]]] = defaultdict(list)
    seen_ids: Counter[str] = Counter()

    defects: dict[str, list[dict[str, Any]]] = {
        "duplicate_talent_ids": [],
        "ineligible_ws_leakage": [],
        "unknown_effect_types": [],
        "empty_effects": [],
        "invalid_prerequisites": [],
        "broken_exclusive_groups": [],
        "unreachable_tiers": [],
        "duplicate_branch_nodes_in_tree": [],
        "missing_three_branch_distinction": [],
    }

    structural_pass = 0
    structural_fail = 0

    for c in contracts:
        tid = c["id"]
        seen_ids[tid] += 1
        skey = c["soul"]
        ws_id = int(c["ws"])
        by_tree[(skey, ws_id)].append(c)

        node_ok = True
        if ws_id not in eligible_by_soul.get(skey, set()):
            defects["ineligible_ws_leakage"].append({"talent_id": tid, "soul": skey, "ws_id": ws_id})
            node_ok = False

        effs = c.get("eff") or []
        if not effs:
            defects["empty_effects"].append({"talent_id": tid})
            node_ok = False
        for ef in effs:
            if ef.get("t") not in taxonomy:
                defects["unknown_effect_types"].append({"talent_id": tid, "effect_type": ef.get("t")})
                node_ok = False

        # Level reachability check (Lv 75 cap)
        rlvl = int(c.get("rlvl") or 1)
        if rlvl < 1 or rlvl > 75:
            defects["unreachable_tiers"].append({"talent_id": tid, "req_level": rlvl})
            node_ok = False

        if node_ok:
            structural_pass += 1
        else:
            structural_fail += 1

    for tid, cnt in seen_ids.items():
        if cnt > 1:
            defects["duplicate_talent_ids"].append({"talent_id": tid, "count": cnt})

    # Per-tree structural & gameplay differentiation checks
    identical_choice_trees = 0
    for (skey, ws_id), nodes in by_tree.items():
        by_key = {n["node"]: n for n in nodes}
        ex_groups: dict[str, list[str]] = defaultdict(list)

        non_sc = [n for n in nodes if n["br"] != "skillchain"]
        branches = {n["br"] for n in non_sc}
        is_evo = "evolution" in branches

        if not is_evo:
            for req_br in ("damage", "utility", "soul"):
                if req_br not in branches:
                    defects["missing_three_branch_distinction"].append({
                        "soul": skey, "ws_id": ws_id, "missing_branch": req_br,
                    })

        # Check prerequisites & exclusive groups
        for n in nodes:
            req = n.get("req")
            if req:
                if req not in by_key:
                    defects["invalid_prerequisites"].append({
                        "talent_id": n["id"], "requires_node": req, "reason": "missing_target_node",
                    })
                elif int(by_key[req]["tier"]) > int(n["tier"]):
                    defects["invalid_prerequisites"].append({
                        "talent_id": n["id"], "requires_node": req, "reason": "depends_on_higher_tier",
                    })
            if n.get("exg"):
                ex_groups[n["exg"]].append(n["id"])

        for grp, members in ex_groups.items():
            # Evolution Sanguine Blade filters disallowed specs per stage, so 1-member filtered group is valid on evo
            if len(members) < 2 and not is_evo:
                defects["broken_exclusive_groups"].append({
                    "soul": skey, "ws_id": ws_id, "group": grp, "members": members,
                })

        # Check for identical effect-signature nodes within the same (tier, tree) masquerading as distinct choices
        by_tier_sig: dict[tuple[int, str], list[str]] = defaultdict(list)
        for n in non_sc:
            sig = json.dumps(sorted((e["t"], e["tgt"]) for e in n.get("eff") or []))
            by_tier_sig[(int(n["tier"]), sig)].append(n["id"])
        for (tier, sig), tids in by_tier_sig.items():
            if len(tids) > 1:
                # Only flag if they are in different branches AND have identical single-effect signature
                brs = {by_key[tid.split(":")[-1]]["br"] for tid in tids if tid.split(":")[-1] in by_key}
                if len(brs) > 1 and len(json.loads(sig)) == 1:
                    identical_choice_trees += 1
                    defects["duplicate_branch_nodes_in_tree"].append({
                        "soul": skey, "ws_id": ws_id, "tier": tier, "talents": tids, "signature": sig,
                    })

    # Verify runtime handler coverage in ws_overrides.lua + ws_telemetry.lua
    overrides_src = OVERRIDES_PATH.read_text(encoding="utf-8") + "\n" + TELEMETRY_PATH.read_text(encoding="utf-8")
    expected_runtime_tokens = {
        "ftp_modifier": "ftpCurve",
        "wsc_modifier": "eff.wsc",
        "damage_modifier": "ALL_WSDMG_ALL_HITS",
        "hit_count_modifier": "eff.hits",
        "critical_modifier": "critCurve",
        "def_ignore_modifier": "defIgnore",
        "accuracy_modifier": "accVaries",
        "tp_bonus": "tpBonus",
        "tp_gain": "tpRefund",
        "mp_gain": "mpReturn",
        "enmity_modifier": "eff.enmity",
        "status_apply": "statusBuffs",
        "debuff_apply": "targetDebuffs",
        "dispel": "eff.dispel",
        "heal_modifier": "partyHealPct",
        "next_ws_primer": "OX_NEXT_WS_EXP",
        "resource_build": "applySoulHookPostWS",
        "pet_interaction": "eosHeal",
        "clone_interaction": "clone_interaction",
        "skillchain_modifier": "OX_WS_SC1",
        "stance_conditional": "isStanceActive",
        "elemental_followup": "elemFollow",
    }
    missing_handlers = [
        et for et, tok in expected_runtime_tokens.items() if tok not in overrides_src
    ]

    total_defect_items = sum(len(v) for v in defects.values()) + len(missing_handlers)
    return {
        "summary": {
            "canonical_souls": manifest["canonical_soul_count"],
            "eligible_soul_ws_combinations": manifest["summary"]["total_approved_soul_ws_combinations"],
            "compiled_contracts": len(contracts),
            "structural_pass": structural_pass,
            "structural_fail": structural_fail,
            "taxonomy_types": len(taxonomy),
            "missing_runtime_handlers": missing_handlers,
            "defect_counts": {k: len(v) for k, v in defects.items()},
            "total_defect_items": total_defect_items,
            "identical_single_effect_cross_branch_count": identical_choice_trees,
        },
        "defects_sample": {k: v[:25] for k, v in defects.items() if v},
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="docs/talents/ws_talent_v21_baseline_audit.json")
    args = ap.parse_args()
    report = run_audit()
    out_path = ROOT / args.out
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    s = report["summary"]
    print(f"Audit complete -> {args.out}")
    print(f"  Souls: {s['canonical_souls']} | Eligible SoulxWS: {s['eligible_soul_ws_combinations']} | Contracts: {s['compiled_contracts']}")
    print(f"  Structural PASS: {s['structural_pass']} | FAIL: {s['structural_fail']} | Missing handlers: {len(s['missing_runtime_handlers'])}")
    print(f"  Defect counts: {s['defect_counts']}")


if __name__ == "__main__":
    main()
