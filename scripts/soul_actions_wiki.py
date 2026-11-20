#!/usr/bin/env python3
"""Automatic Soul Action catalog integration and validation for SoulspireXI Wiki.

Combines:
  1. Authoritative 66-Soul roster and alias map (modules/custom/lua/soulspire_job_specs.lua
     + tools/audit_soul_coverage.py)
  2. Server-authoritative spell grants, kit spell tables, ability registrations,
     unlock levels, cast times, and recasts
  3. Launcher native Soul action definitions and visibility policies:
     - addons/ashita4/soulspire_soul_actions/data/soul_actions.tsv (or legacy overlords_soul_actions)
     - addons/ashita4/soulspire_soul_actions/data/visibility.tsv

Produces per-Soul `soulActions` arrays across all 66 Souls while enforcing strict
consistency, anti-stale-description, and no-vanilla-name-leakage checks.
"""
from __future__ import annotations

import copy
import importlib.util
import os
import re
import sys
from pathlib import Path
from typing import Any

VALID_KINDS = ("spell", "ability", "weaponskill")
KIND_LIMITS = {
    "spell": (0, 1023),
    "weaponskill": (0, 511),
    "ability": (512, 2047),
}
KIND_TO_CATEGORY = {
    "spell": "Spell",
    "ability": "Job Ability",
    "weaponskill": "Weapon Skill",
}
CATEGORY_SORT_ORDER = {
    "Spell": 0,
    "Job Ability": 1,
    "Weapon Skill": 2,
}
ABILITY_CLIENT_OFFSET = 512

# Preferred player-facing/launcher Soul key when server catalog uses a legacy internal key.
PREFERRED_ACTION_KEYS = {
    "kurogane": "shinobi",
}

# Known vanilla spell names keyed by FFXI spell ID, used ONLY internally for
# validation so repurposed Soul actions never display original vanilla names.
KNOWN_VANILLA_SPELL_NAMES = {
    320: "Katon: Ichi",
    321: "Katon: Ni",
    322: "Katon: San",
    323: "Hyoton: Ichi",
    324: "Hyoton: Ni",
    325: "Hyoton: San",
    326: "Huton: Ichi",
    327: "Huton: Ni",
    328: "Huton: San",
    329: "Doton: Ichi",
    330: "Doton: Ni",
    331: "Doton: San",
    332: "Raiton: Ichi",
    333: "Raiton: Ni",
    334: "Raiton: San",
    335: "Suiton: Ichi",
    336: "Suiton: Ni",
    337: "Suiton: San",
    338: "Utsusemi: Ichi",
    339: "Utsusemi: Ni",
    340: "Utsusemi: San",
}

STALE_PROTOTYPE_PHRASES = (
    "still awaiting implementation",
    "not yet implemented",
    "awaiting implementation",
)

LAUNCHER_SUBPATHS = (
    Path("addons/ashita4/soulspire_soul_actions/data"),
    Path("addons/ashita4/overlords_soul_actions/data"),
)


def _load_audit_module(repo_root: Path):
    audit_path = repo_root / "tools" / "audit_soul_coverage.py"
    spec = importlib.util.spec_from_file_location("soulspire_audit_soul_coverage", str(audit_path))
    if not spec or not spec.loader:
        raise RuntimeError(f"Unable to load {audit_path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules["soulspire_audit_soul_coverage"] = mod
    spec.loader.exec_module(mod)
    return mod


def build_soul_roster(repo_root: Path) -> dict[str, Any]:
    """Build the authoritative 66-Soul roster and bidirectional alias resolver."""
    audit_mod = _load_audit_module(repo_root)
    catalog_src = (repo_root / "modules/custom/lua/soulspire_job_specs.lua").read_text(
        encoding="utf-8", errors="replace"
    )
    entries, raw_aliases = audit_mod.parse_catalog_and_aliases(catalog_src)
    report = audit_mod.analyze(repo_root, baseline_path=None)
    status_by_pair = {
        (row["job"], row["soul"]): row["status"]
        for row in report.get("rows", [])
    }

    souls: list[dict[str, Any]] = []
    by_canonical: dict[str, dict[str, Any]] = {}
    branch_counters: dict[str, int] = {}

    for entry in entries:
        job = entry["job"]
        canonical = entry["soul"].lower()
        if (job, canonical) in audit_mod.RETIRED_LEGACY_SOULS:
            continue
        branch_counters[job] = branch_counters.get(job, 0) + 1
        action_key = PREFERRED_ACTION_KEYS.get(canonical, canonical)
        rec = {
            "jobKey": job,
            "branchId": branch_counters[job],
            "canonicalKey": canonical,
            "actionKey": action_key,
            "name": entry["name"],
            "role": entry["role"],
            "implementationStatus": status_by_pair.get((job, canonical), "planned"),
            "aliases": sorted({canonical, action_key}),
        }
        souls.append(rec)
        by_canonical[canonical] = rec

    alias_to_canonical: dict[str, str] = {}
    for canonical, rec in by_canonical.items():
        alias_to_canonical[canonical] = canonical
        alias_to_canonical[rec["actionKey"]] = canonical

    for alias_key, target_key in raw_aliases.items():
        a = alias_key.lower()
        t = target_key.lower()
        if t in by_canonical:
            alias_to_canonical[a] = t
            if a not in by_canonical[t]["aliases"]:
                by_canonical[t]["aliases"].append(a)
                by_canonical[t]["aliases"].sort()

    return {
        "souls": souls,
        "byCanonical": by_canonical,
        "aliasToCanonical": alias_to_canonical,
        "expectedCount": audit_mod.EXPECTED_CANONICAL_COUNT,
    }


def resolve_soul_key(raw_key: str, roster: dict[str, Any]) -> tuple[str | None, dict[str, Any] | None]:
    """Resolve any canonical key or legacy alias to `(canonicalKey, rosterEntry)`."""
    if not raw_key:
        return None, None
    key = raw_key.strip().lower()
    canonical = roster["aliasToCanonical"].get(key)
    if not canonical:
        return None, None
    return canonical, roster["byCanonical"].get(canonical)


def locate_launcher_files(launcher_dir: Path | None, repo_root: Path | None = None) -> tuple[Path | None, Path | None]:
    """Locate `soul_actions.tsv` and `visibility.tsv` in a launcher checkout."""
    candidates: list[Path] = []
    if launcher_dir is not None:
        candidates.append(launcher_dir)
    else:
        for env_var in ("SOULSPIRE_LAUNCHER_DIR", "OVERLORDS_LAUNCHER_DIR"):
            env_val = os.environ.get(env_var, "").strip()
            if env_val:
                candidates.append(Path(env_val))
        if repo_root is not None:
            for sibling in (
                repo_root.parent / "overlordsxi-launcher",
                repo_root.parent / "soulspirexi-launcher",
                repo_root / ".launcher-repo",
            ):
                candidates.append(sibling)

    for base in candidates:
        if not base.exists():
            continue
        for sub in LAUNCHER_SUBPATHS:
            data_dir = base / sub
            actions_path = data_dir / "soul_actions.tsv"
            vis_path = data_dir / "visibility.tsv"
            if actions_path.is_file() or vis_path.is_file():
                return (
                    actions_path if actions_path.is_file() else None,
                    vis_path if vis_path.is_file() else None,
                )
    return None, None


def _valid_soul_token(token: str) -> bool:
    return bool(re.match(r"^[a-z0-9_-]{2,64}$", token))


def parse_soul_actions_tsv(
    content: str,
    roster: dict[str, Any],
    source_label: str = "soul_actions.tsv",
) -> tuple[list[dict[str, Any]], list[str]]:
    """Parse and validate `soul_actions.tsv`."""
    rows: list[dict[str, Any]] = []
    errors: list[str] = []
    seen: dict[tuple[str, str, int], int] = {}

    for line_no, raw_line in enumerate(content.splitlines(), start=1):
        line = raw_line.strip("\r\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 5 or len(parts) > 7:
            errors.append(f"{source_label}:{line_no}: expected 5..7 TSV columns, got {len(parts)}")
            continue

        raw_soul, kind, id_str, name, desc = (p.strip() for p in parts[:5])
        if not _valid_soul_token(raw_soul):
            errors.append(f"{source_label}:{line_no}: invalid soul key '{raw_soul}'")
            continue
        canonical, _ = resolve_soul_key(raw_soul, roster)
        if not canonical:
            errors.append(f"{source_label}:{line_no}: unknown soul key '{raw_soul}' (missing Soul mapping)")
            continue
        if kind not in VALID_KINDS:
            errors.append(f"{source_label}:{line_no}: invalid kind '{kind}' (expected spell|ability|weaponskill)")
            continue
        if not re.match(r"^\d+$", id_str):
            errors.append(f"{source_label}:{line_no}: invalid integer ID '{id_str}'")
            continue
        action_id = int(id_str)
        lo, hi = KIND_LIMITS[kind]
        if action_id < lo or action_id > hi:
            errors.append(f"{source_label}:{line_no}: {kind} ID {action_id} out of valid range {lo}..{hi}")
            continue
        if not name or len(name) > 79:
            errors.append(f"{source_label}:{line_no}: action name must be 1..79 chars")
            continue
        if not desc or len(desc) > 180:
            errors.append(f"{source_label}:{line_no}: action description must be 1..180 chars")
            continue

        dedupe_key = (canonical, kind, action_id)
        if dedupe_key in seen:
            errors.append(
                f"{source_label}:{line_no}: duplicate action ID ({raw_soul}, {kind}, {action_id}); "
                f"previously defined at line {seen[dedupe_key]}"
            )
            continue
        seen[dedupe_key] = line_no

        rows.append(
            {
                "line": line_no,
                "rawSoul": raw_soul,
                "canonicalSoul": canonical,
                "kind": kind,
                "id": action_id,
                "name": name,
                "description": desc,
            }
        )
    return rows, errors


def parse_visibility_tsv(
    content: str,
    roster: dict[str, Any],
    source_label: str = "visibility.tsv",
) -> tuple[list[dict[str, Any]], list[str]]:
    """Parse and validate `visibility.tsv`."""
    rows: list[dict[str, Any]] = []
    errors: list[str] = []
    seen: dict[tuple[str, str, int], int] = {}

    for line_no, raw_line in enumerate(content.splitlines(), start=1):
        line = raw_line.strip("\r\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 5:
            errors.append(f"{source_label}:{line_no}: expected 5 TSV columns, got {len(parts)}")
            continue

        raw_soul, kind, id_str, level_str, rule = (p.strip() for p in parts)
        if not _valid_soul_token(raw_soul):
            errors.append(f"{source_label}:{line_no}: invalid soul key '{raw_soul}'")
            continue
        canonical, _ = resolve_soul_key(raw_soul, roster)
        if not canonical:
            errors.append(f"{source_label}:{line_no}: unknown soul key '{raw_soul}' (missing Soul mapping)")
            continue
        if kind not in VALID_KINDS:
            errors.append(f"{source_label}:{line_no}: invalid kind '{kind}'")
            continue
        if not re.match(r"^\d+$", id_str):
            errors.append(f"{source_label}:{line_no}: invalid integer ID '{id_str}'")
            continue
        action_id = int(id_str)
        lo, hi = KIND_LIMITS[kind]
        if action_id < lo or action_id > hi:
            errors.append(f"{source_label}:{line_no}: {kind} ID {action_id} out of valid range {lo}..{hi}")
            continue
        if not re.match(r"^\d+$", level_str):
            errors.append(f"{source_label}:{line_no}: invalid unlock level '{level_str}'")
            continue
        min_level = int(level_str)
        if min_level < 1 or min_level > 75:
            errors.append(f"{source_label}:{line_no}: unlock level {min_level} out of valid range 1..75")
            continue
        if rule not in ("unlock", "hidden"):
            errors.append(f"{source_label}:{line_no}: invalid visibility rule '{rule}' (expected unlock|hidden)")
            continue

        dedupe_key = (canonical, kind, action_id)
        if dedupe_key in seen:
            errors.append(
                f"{source_label}:{line_no}: duplicate visibility ID ({raw_soul}, {kind}, {action_id}); "
                f"previously defined at line {seen[dedupe_key]}"
            )
            continue
        seen[dedupe_key] = line_no

        rows.append(
            {
                "line": line_no,
                "rawSoul": raw_soul,
                "canonicalSoul": canonical,
                "kind": kind,
                "id": action_id,
                "minLevel": min_level,
                "rule": rule,
            }
        )
    return rows, errors


def _vanilla_names_for_spell(spell_id: int, script_name: str | None = None) -> list[str]:
    names: list[str] = []
    if spell_id in KNOWN_VANILLA_SPELL_NAMES:
        vname = KNOWN_VANILLA_SPELL_NAMES[spell_id]
        names.append(vname)
        base = vname.split(":", 1)[0].strip()
        if base and base not in names:
            names.append(base)
    if script_name:
        parts = script_name.split("_")
        if len(parts) >= 2 and parts[-1] in ("ichi", "ni", "san"):
            pretty = f"{' '.join(p.capitalize() for p in parts[:-1])}: {parts[-1].capitalize()}"
            base = " ".join(p.capitalize() for p in parts[:-1])
            for candidate in (pretty, base):
                if candidate and candidate not in names:
                    names.append(candidate)
    return names


def _contains_vanilla_name(text: str, vanilla_names: list[str]) -> str | None:
    if not text:
        return None
    for vname in vanilla_names:
        if re.search(rf"\b{re.escape(vname)}\b", text, flags=re.IGNORECASE):
            return vname
    return None


def _format_cast_time(cast_ms: int | float | None) -> str | None:
    if cast_ms is None:
        return None
    secs = float(cast_ms) / 1000.0
    if secs <= 0:
        return "Instant"
    if abs(secs - round(secs)) < 1e-6:
        return f"{int(round(secs))}.0s"
    return f"{secs:.1f}s"


def _parse_seconds(text: str | None) -> int | None:
    if not text:
        return None
    m = re.search(r"(\d+)\s*s\b", str(text), flags=re.IGNORECASE)
    return int(m.group(1)) if m else None


def _extract_desc_recast_sec(desc: str) -> int | None:
    m = re.search(r"\b(\d+)\s*s\s*(?:recast|cd)\b", desc, flags=re.IGNORECASE)
    return int(m.group(1)) if m else None


def _extract_desc_summon_count(desc: str) -> int | None:
    m = re.search(r"\bsummons?\s+(\d+)\b", desc, flags=re.IGNORECASE)
    return int(m.group(1)) if m else None


def integrate_soul_actions(
    *,
    jobs: list[dict[str, Any]],
    job_meta: dict[str, dict[str, Any]],
    roster: dict[str, Any],
    kit_spells_by_soul: dict[str, dict[str, dict[str, Any]]] | None = None,
    server_ability_unlocks: dict[str, dict[int, int]] | None = None,
    kit_ability_recasts: dict[str, dict[str, int]] | None = None,
    server_spell_grants: dict[str, dict[int, int]] | None = None,
    launcher_actions: list[dict[str, Any]] | None = None,
    launcher_visibility: list[dict[str, Any]] | None = None,
    guides_map: dict[str, dict[str, Any]] | None = None,
    build_fallback_guide_fn=None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Merge server roster + Lua progression + launcher action/visibility catalogs for all 66 Souls."""
    errors: list[str] = []
    warnings: list[str] = []

    kit_spells_by_canonical: dict[str, dict[int, dict[str, Any]]] = {}
    for raw_soul, spells_map in (kit_spells_by_soul or {}).items():
        canonical, _ = resolve_soul_key(raw_soul, roster)
        if not canonical:
            errors.append(f"Server kitSpells references unknown soul '{raw_soul}'")
            continue
        dst = kit_spells_by_canonical.setdefault(canonical, {})
        for sid_str, info in (spells_map or {}).items():
            sid = int(info.get("id", sid_str))
            dst[sid] = info

    actions_by_soul: dict[str, list[dict[str, Any]]] = {}
    for row in launcher_actions or []:
        actions_by_soul.setdefault(row["canonicalSoul"], []).append(row)

    vis_by_soul: dict[str, dict[tuple[str, int], dict[str, Any]]] = {}
    for row in launcher_visibility or []:
        vis_by_soul.setdefault(row["canonicalSoul"], {})[(row["kind"], row["id"])] = row

    # Index existing implemented jobs & crystals by canonical soul key
    jobs_by_key: dict[str, dict[str, Any]] = {j["jobKey"]: j for j in jobs}
    crystals_by_canonical: dict[str, dict[str, Any]] = {}
    for j in jobs:
        for c in j.get("crystals", []):
            canonical, _ = resolve_soul_key(c.get("key", ""), roster)
            if canonical:
                crystals_by_canonical[canonical] = c

    # Ensure all 22 jobs and all 66 canonical Souls exist in jobSpecs
    for roster_soul in roster["souls"]:
        jkey = roster_soul["jobKey"]
        canonical = roster_soul["canonicalKey"]
        if jkey not in jobs_by_key:
            jmeta = job_meta.get(jkey, {"id": 99, "name": jkey, "color": "#60a5fa"})
            jobs_by_key[jkey] = {
                "jobKey": jkey,
                "jobId": jmeta["id"],
                "jobName": jmeta["name"],
                "color": jmeta["color"],
                "crystals": [],
            }

        crystal = crystals_by_canonical.get(canonical)
        if crystal is None:
            crystal = {
                "id": roster_soul["branchId"],
                "key": canonical,
                "name": roster_soul["name"],
                "role": roster_soul["role"],
                "icon": canonical,
                "reqLevel": 10,
                "description": f"Planned {jobs_by_key[jkey]['jobName']} Soul specialization — not yet implemented on the server.",
                "highlights": [],
                "passiveMods": [],
                "customAbilities": [],
                "customTraits": [],
            }
            jobs_by_key[jkey]["crystals"].append(crystal)
            crystals_by_canonical[canonical] = crystal

        crystal["canonicalKey"] = canonical
        crystal["actionKey"] = roster_soul["actionKey"]
        crystal["aliases"] = list(roster_soul["aliases"])
        crystal["branchId"] = roster_soul["branchId"]
        crystal["implementationStatus"] = roster_soul["implementationStatus"]

        # Resolve guide using preferred actionKey first, then canonicalKey, then aliases
        if guides_map is not None:
            resolved_guide = None
            for candidate_key in [roster_soul["actionKey"], canonical] + roster_soul["aliases"]:
                if candidate_key in guides_map:
                    resolved_guide = copy.deepcopy(guides_map[candidate_key])
                    break
            if roster_soul["implementationStatus"] != "implemented":
                crystal["guide"] = {
                    "atAGlance": f"{roster_soul['name']} is part of the 66-Soul roadmap and is not yet implemented on the live server.",
                    "setup": [],
                    "loop": [],
                    "mechanics": [],
                    "tips": [],
                    "hasHandwrittenGuide": False,
                }
            elif resolved_guide is not None:
                crystal["guide"] = resolved_guide
            elif build_fallback_guide_fn is not None:
                crystal["guide"] = build_fallback_guide_fn(jobs_by_key[jkey], crystal)

        # Check guide for stale prototype claims on implemented Souls
        if roster_soul["implementationStatus"] == "implemented" and isinstance(crystal.get("guide"), dict):
            guide_obj = crystal["guide"]
            guide_blob = " ".join(
                [guide_obj.get("atAGlance", "")]
                + list(guide_obj.get("setup", []))
                + list(guide_obj.get("loop", []))
                + list(guide_obj.get("mechanics", []))
                + list(guide_obj.get("tips", []))
            ).lower()
            for phrase in STALE_PROTOTYPE_PHRASES:
                if phrase in guide_blob:
                    errors.append(
                        f"Stale guide text for implemented Soul '{roster_soul['actionKey']}' "
                        f"({guide_obj.get('sourceFile', 'guide')}): contains '{phrase}'"
                    )

    # Now build soulActions and validate server <-> launcher consistency for all 66 Souls
    total_launcher_actions = 0
    total_generated_actions = 0
    souls_with_launcher_catalog = 0

    for roster_soul in roster["souls"]:
        canonical = roster_soul["canonicalKey"]
        action_key = roster_soul["actionKey"]
        status = roster_soul["implementationStatus"]
        crystal = crystals_by_canonical[canonical]

        l_actions = actions_by_soul.get(canonical, [])
        l_vis = vis_by_soul.get(canonical, {})
        kit_spells = kit_spells_by_canonical.get(canonical, {})
        spell_grants = (server_spell_grants or {}).get(canonical, {})
        abil_unlocks = (server_ability_unlocks or {}).get(canonical, {})
        custom_abils_by_id = {
            int(a["id"]): a for a in crystal.get("customAbilities", []) if isinstance(a.get("id"), int)
        }

        if l_actions:
            souls_with_launcher_catalog += 1

        # Guard: planned/unimplemented Souls must never carry launcher action/visibility definitions
        if status != "implemented":
            for row in l_actions:
                errors.append(
                    f"Unsupported action record for {status} Soul '{row['rawSoul']}' "
                    f"({row['kind']} {row['id']} '{row['name']}'): prototype mechanics cannot be published as implemented"
                )
            for (vkind, vid), vrow in l_vis.items():
                errors.append(
                    f"Unsupported visibility record for {status} Soul '{vrow['rawSoul']}' ({vkind} {vid})"
                )
            crystal["soulActions"] = []
            continue

        # Validate visibility.tsv entries against server truth
        for (vkind, vid), vrow in l_vis.items():
            if vrow["rule"] == "hidden":
                continue
            if vkind == "spell":
                srv_lvl = None
                if vid in kit_spells and "unlockLvl" in kit_spells[vid]:
                    srv_lvl = int(kit_spells[vid]["unlockLvl"])
                elif vid in spell_grants:
                    srv_lvl = int(spell_grants[vid])
                if srv_lvl is None:
                    errors.append(
                        f"Unsupported visibility spell for '{vrow['rawSoul']}': spell {vid} is not granted by server"
                    )
                elif srv_lvl != vrow["minLevel"]:
                    errors.append(
                        f"Unlock level mismatch for '{vrow['rawSoul']}' spell {vid}: "
                        f"visibility.tsv has Lv.{vrow['minLevel']} but server unlocks at Lv.{srv_lvl}"
                    )
            elif vkind == "ability":
                srv_id = vid - ABILITY_CLIENT_OFFSET
                if srv_id not in abil_unlocks and srv_id not in custom_abils_by_id:
                    errors.append(
                        f"Unsupported visibility ability for '{vrow['rawSoul']}': "
                        f"client ID {vid} (server ID {srv_id}) is not registered for this Soul"
                    )
                else:
                    srv_lvl = abil_unlocks.get(srv_id, int(crystal.get("reqLevel", 10)))
                    if srv_lvl != vrow["minLevel"]:
                        errors.append(
                            f"Unlock level mismatch for '{vrow['rawSoul']}' ability {vid} (server {srv_id}): "
                            f"visibility.tsv has Lv.{vrow['minLevel']} but server unlocks at Lv.{srv_lvl}"
                        )

        generated: list[dict[str, Any]] = []
        handled_spell_ids: set[int] = set()
        handled_server_abil_ids: set[int] = set()

        # 1. Process launcher-defined Soul actions (highest priority for player-facing names & descriptions)
        for row in l_actions:
            total_launcher_actions += 1
            kind = row["kind"]
            aid = row["id"]
            vis_entry = l_vis.get((kind, aid))
            if vis_entry and vis_entry["rule"] == "hidden":
                errors.append(
                    f"Contradictory catalog entry for '{row['rawSoul']}' {kind} {aid} ('{row['name']}'): "
                    f"defined in soul_actions.tsv but marked hidden in visibility.tsv"
                )
                continue
            if l_vis and vis_entry is None:
                warnings.append(
                    f"Missing visibility.tsv entry for '{row['rawSoul']}' {kind} {aid} ('{row['name']}')"
                )

            if kind == "spell":
                kit_info = kit_spells.get(aid)
                grant_lvl = spell_grants.get(aid)
                if kit_info is None and grant_lvl is None:
                    errors.append(
                        f"Unsupported spell action for '{row['rawSoul']}': spell {aid} ('{row['name']}') "
                        f"is not granted or defined by the server"
                    )
                    continue

                # Never display original vanilla spell names alongside repurposed Soul identities
                vnames = _vanilla_names_for_spell(aid, kit_info.get("script") if kit_info else None)
                leaked_name = _contains_vanilla_name(row["name"], vnames)
                if leaked_name:
                    errors.append(
                        f"Vanilla spell name leakage in soul_actions.tsv name for '{row['rawSoul']}' "
                        f"spell {aid}: '{row['name']}' contains '{leaked_name}'"
                    )
                leaked_desc = _contains_vanilla_name(row["description"], vnames)
                if leaked_desc:
                    errors.append(
                        f"Vanilla spell name leakage in soul_actions.tsv description for '{row['rawSoul']}' "
                        f"spell {aid}: description contains '{leaked_desc}'"
                    )

                srv_unlock = int(kit_info["unlockLvl"]) if (kit_info and "unlockLvl" in kit_info) else int(grant_lvl)
                if vis_entry and vis_entry["minLevel"] != srv_unlock:
                    # Already reported above, keep server authoritative
                    pass

                # Cross-check name, recast, and summonCount against server kit definition
                if kit_info:
                    if kit_info.get("name") and kit_info["name"] != row["name"]:
                        errors.append(
                            f"Action name conflict for '{row['rawSoul']}' spell {aid}: "
                            f"soul_actions.tsv has '{row['name']}' but server has '{kit_info['name']}'"
                        )
                    if "recastSec" in kit_info:
                        desc_recast = _extract_desc_recast_sec(row["description"])
                        if desc_recast is not None and desc_recast != int(kit_info["recastSec"]):
                            errors.append(
                                f"Stale description recast for '{row['rawSoul']}' spell {aid} ('{row['name']}'): "
                                f"description says {desc_recast}s but server has {kit_info['recastSec']}s"
                            )
                    if "summonCount" in kit_info:
                        desc_summon = _extract_desc_summon_count(row["description"])
                        if desc_summon is not None and desc_summon != int(kit_info["summonCount"]):
                            errors.append(
                                f"Stale description summon count for '{row['rawSoul']}' spell {aid} ('{row['name']}'): "
                                f"description says {desc_summon} but server summons {kit_info['summonCount']}"
                            )

                cost_str = None
                if kit_info and "mpCost" in kit_info:
                    cost_str = f"{int(kit_info['mpCost'])} MP"
                elif canonical == "kurogane":
                    cost_str = "0 MP (No Tools)"

                action_rec = {
                    "name": row["name"],
                    "category": KIND_TO_CATEGORY[kind],
                    "kind": kind,
                    "unlockLevel": srv_unlock,
                    "description": row["description"],
                    "cost": cost_str,
                    "castTime": _format_cast_time(kit_info.get("castMs")) if kit_info else None,
                    "recast": f"{int(kit_info['recastSec'])}s" if (kit_info and "recastSec" in kit_info) else None,
                    "target": None,
                    "implementationStatus": "implemented",
                    "source": "launcher+server",
                    "internalId": aid,
                }
                generated.append(action_rec)
                handled_spell_ids.add(aid)

            elif kind == "ability":
                srv_id = aid - ABILITY_CLIENT_OFFSET
                srv_abil = custom_abils_by_id.get(srv_id)
                if srv_abil is None and srv_id not in abil_unlocks:
                    errors.append(
                        f"Unsupported ability action for '{row['rawSoul']}': client ID {aid} (server ID {srv_id}, "
                        f"'{row['name']}') is not registered for this Soul"
                    )
                    continue

                srv_unlock = abil_unlocks.get(srv_id, int(crystal.get("reqLevel", 10)))
                kit_recast = (kit_ability_recasts or {}).get(canonical, {}).get(str(srv_id))
                srv_recast_sec = kit_recast if kit_recast is not None else _parse_seconds(srv_abil.get("cd") if srv_abil else None)
                desc_recast = _extract_desc_recast_sec(row["description"])
                if srv_recast_sec is not None and desc_recast is not None and desc_recast != srv_recast_sec:
                    errors.append(
                        f"Stale description recast for '{row['rawSoul']}' ability {aid} ('{row['name']}'): "
                        f"description says {desc_recast}s but the server has {srv_recast_sec}s"
                    )

                action_rec = {
                    "name": row["name"],
                    "category": KIND_TO_CATEGORY[kind],
                    "kind": kind,
                    "unlockLevel": srv_unlock,
                    "description": row["description"],
                    "cost": None,
                    "castTime": "Instant",
                    "recast": f"{srv_recast_sec}s" if srv_recast_sec is not None else (f"{desc_recast}s" if desc_recast else None),
                    "target": srv_abil.get("target") if srv_abil else None,
                    "implementationStatus": "implemented",
                    "source": "launcher+server",
                    "internalId": aid,
                    "serverId": srv_id,
                }
                generated.append(action_rec)
                handled_server_abil_ids.add(srv_id)

                # Keep legacy customAbilities entry synchronized with Soul-specific catalog text
                if srv_abil is not None:
                    srv_abil["name"] = row["name"]
                    srv_abil["desc"] = row["description"]
                    srv_abil["unlockLevel"] = srv_unlock
                    if kit_recast is not None:
                        srv_abil["cd"] = f"{kit_recast}s"

            elif kind == "weaponskill":
                # Weapon skills are validated against positive unlock level if present in visibility.tsv
                ws_unlock = vis_entry["minLevel"] if vis_entry else int(crystal.get("reqLevel", 10))
                action_rec = {
                    "name": row["name"],
                    "category": KIND_TO_CATEGORY[kind],
                    "kind": kind,
                    "unlockLevel": ws_unlock,
                    "description": row["description"],
                    "cost": "1000+ TP",
                    "castTime": "Instant",
                    "recast": None,
                    "target": "Enemy",
                    "implementationStatus": "implemented",
                    "source": "launcher+server",
                    "internalId": aid,
                }
                generated.append(action_rec)

        # 2. Include any server-authoritative kitSpells not yet present in launcher TSV
        for sid, kit_info in sorted(kit_spells.items()):
            if sid in handled_spell_ids:
                continue
            warnings.append(
                f"Server kit spell {sid} ('{kit_info.get('name', sid)}') for '{action_key}' "
                f"is missing from launcher soul_actions.tsv"
            )
            generated.append(
                {
                    "name": kit_info.get("name") or f"Spell #{sid}",
                    "category": "Spell",
                    "kind": "spell",
                    "unlockLevel": int(kit_info.get("unlockLvl", crystal.get("reqLevel", 10))),
                    "description": f"{crystal['name']} Soul spell.",
                    "cost": f"{int(kit_info['mpCost'])} MP" if "mpCost" in kit_info else None,
                    "castTime": _format_cast_time(kit_info.get("castMs")),
                    "recast": f"{int(kit_info['recastSec'])}s" if "recastSec" in kit_info else None,
                    "target": None,
                    "implementationStatus": "implemented",
                    "source": "server",
                    "internalId": sid,
                }
            )
            handled_spell_ids.add(sid)

        # 3. Include remaining server-registered customAbilities (for all Souls not yet in soul_actions.tsv)
        for ab in crystal.get("customAbilities", []):
            srv_id = ab.get("id")
            if isinstance(srv_id, int) and srv_id in handled_server_abil_ids:
                continue
            srv_unlock = (
                abil_unlocks.get(srv_id, int(crystal.get("reqLevel", 10)))
                if isinstance(srv_id, int)
                else int(crystal.get("reqLevel", 10))
            )
            ab["unlockLevel"] = srv_unlock
            generated.append(
                {
                    "name": ab.get("name", "Custom Ability"),
                    "category": "Job Ability",
                    "kind": "ability",
                    "unlockLevel": srv_unlock,
                    "description": ab.get("desc", ""),
                    "cost": None,
                    "castTime": "Instant",
                    "recast": ab.get("cd"),
                    "target": ab.get("target"),
                    "implementationStatus": "implemented",
                    "source": "server",
                    "internalId": (srv_id + ABILITY_CLIENT_OFFSET) if isinstance(srv_id, int) else None,
                    "serverId": srv_id if isinstance(srv_id, int) else None,
                }
            )

        # Sort actions by unlockLevel -> category (Spell, Job Ability, Weapon Skill) -> name
        generated.sort(
            key=lambda a: (
                int(a.get("unlockLevel") or 10),
                CATEGORY_SORT_ORDER.get(a.get("category", "Job Ability"), 9),
                a.get("name", "").lower(),
            )
        )
        # Sanitize any parenthetical vanilla spell names from highlights when this Soul has repurposed launcher spells
        if handled_spell_ids and isinstance(crystal.get("highlights"), list):
            repurposed_vnames: list[str] = []
            for sid in handled_spell_ids:
                kinfo = kit_spells.get(sid)
                for vn in _vanilla_names_for_spell(sid, kinfo.get("script") if kinfo else None):
                    if vn not in repurposed_vnames:
                        repurposed_vnames.append(vn)
            cleaned_highlights = []
            for h in crystal["highlights"]:
                cleaned = h
                for vn in sorted(repurposed_vnames, key=len, reverse=True):
                    cleaned = re.sub(rf"\b{re.escape(vn)}\s+", "", cleaned, flags=re.IGNORECASE)
                    cleaned = re.sub(rf"\b{re.escape(vn)}\b", "", cleaned, flags=re.IGNORECASE)
                cleaned = re.sub(r"\(\s+", "(", cleaned)
                cleaned = re.sub(r"\s+\)", ")", cleaned)
                cleaned = re.sub(r"\s{2,}", " ", cleaned).strip()
                cleaned_highlights.append(cleaned)
            crystal["highlights"] = cleaned_highlights

        crystal["soulActions"] = generated
        total_generated_actions += len(generated)

    # Sort jobs by jobId and crystals within each job by branchId
    ordered_jobs = sorted(jobs_by_key.values(), key=lambda j: j["jobId"])
    for j in ordered_jobs:
        j["crystals"].sort(key=lambda c: (int(c.get("branchId") or c.get("id") or 99), c.get("name", "")))

    implemented_count = sum(1 for s in roster["souls"] if s["implementationStatus"] == "implemented")
    planned_count = sum(1 for s in roster["souls"] if s["implementationStatus"] != "implemented")

    audit_summary = {
        "totalCanonicalSouls": len(roster["souls"]),
        "implementedSouls": implemented_count,
        "plannedSouls": planned_count,
        "soulsWithLauncherCatalog": souls_with_launcher_catalog,
        "totalLauncherActions": total_launcher_actions,
        "totalGeneratedActions": total_generated_actions,
        "errorCount": len(errors),
        "warningCount": len(warnings),
        "errors": errors,
        "warnings": warnings,
    }
    return ordered_jobs, audit_summary
