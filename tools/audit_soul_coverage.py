#!/usr/bin/env python3
"""Static Soul coverage, registration integrity, and regression audit for SoulspireXI.

Run from a repository checkout:
  python tools/audit_soul_coverage.py . --strict --csv soul-coverage.csv --json soul-coverage.json

Classifies the 66 canonical Souls into:
  - implemented: registered in an enabled Lua module with substantive Soul definitions
  - incomplete:  registered in Lua, but disabled in init.append.txt or missing core definitions
  - planned:     present in the canonical catalog but not yet registered (does NOT fail CI)

Retired legacy placeholders (e.g. DNC:freelancer) are tracked separately and must never
be registered as active Souls.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

CATALOG = Path("modules/custom/lua/soulspire_job_specs.lua")
INIT_APPEND = Path("modules/init.append.txt")
DEFAULT_BASELINE = Path("tools/soul_coverage_baseline.json")

RETIRED_LEGACY_SOULS = {("DNC", "freelancer")}
EXPECTED_CANONICAL_COUNT = 66

JOB_OPEN = re.compile(r"^\s*([A-Z]{3})\s*=\s*$")
ID_RE = re.compile(r"\bid\s*=\s*['\"]([a-z][a-z0-9_]*)['\"]")
NAME_RE = re.compile(r"\bname\s*=\s*['\"]([^'\"]+)['\"]")
ROLE_RE = re.compile(r"\brole\s*=\s*['\"]([^'\"]+)['\"]")
CONST_STR_RE = re.compile(r"\blocal\s+(\w+)\s*=\s*['\"]([a-zA-Z0-9_]+)['\"]")
LOCAL_TABLE_RE = re.compile(r"\blocal\s+(\w+)\s*=\s*\{")
REQUIRE_CUSTOM_RE = re.compile(r"\brequire\s*\(\s*['\"](modules/custom/[^'\"]+)['\"]\s*\)")
REGISTRATION_CALL_RE = re.compile(r"\bspec\s*\.\s*(registerJob|registerCrystal)\s*\(")
REGISTRATION = REGISTRATION_CALL_RE
KEY_ASSIGNMENT = re.compile(r"\bkey\s*=\s*(?:['\"]([a-zA-Z0-9_]+)['\"]|(\w+))")


def extract_registration_args(source: str, start_idx: int) -> str:
    """Return the argument slice inside a spec.registerJob/registerCrystal(...) call."""
    paren_open = start_idx - 1
    if paren_open < 0 or source[paren_open] != "(":
        paren_open = source.find("(", max(0, start_idx - 1))
    if paren_open < 0:
        return ""
    end_idx = find_balanced(source, paren_open, "(", ")")
    if end_idx < 0:
        return source[start_idx:]
    return source[start_idx:end_idx]


def strip_lua_comments(src: str) -> str:
    src = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.DOTALL)
    out_lines: list[str] = []
    for line in src.splitlines():
        in_str: str | None = None
        escaped = False
        cut_idx: int | None = None
        for i, ch in enumerate(line):
            if escaped:
                escaped = False
                continue
            if ch == "\\":
                escaped = True
                continue
            if in_str:
                if ch == in_str:
                    in_str = None
            else:
                if ch in ("'", '"'):
                    in_str = ch
                elif ch == "-" and i + 1 < len(line) and line[i + 1] == "-":
                    cut_idx = i
                    break
        out_lines.append(line[:cut_idx] if cut_idx is not None else line)
    return "\n".join(out_lines)


def find_balanced(text: str, start_idx: int, open_ch: str, close_ch: str) -> int:
    depth = 0
    in_str: str | None = None
    escaped = False
    for i in range(start_idx, len(text)):
        ch = text[i]
        if escaped:
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            continue
        if in_str:
            if ch == in_str:
                in_str = None
            continue
        if ch in ("'", '"'):
            in_str = ch
            continue
        if ch == open_ch:
            depth += 1
        elif ch == close_ch:
            depth -= 1
            if depth == 0:
                return i
    return -1


def split_top_level(text: str) -> list[str]:
    parts: list[str] = []
    cur: list[str] = []
    depth_brace = 0
    depth_paren = 0
    depth_bracket = 0
    in_str: str | None = None
    escaped = False
    for ch in text:
        if escaped:
            cur.append(ch)
            escaped = False
            continue
        if ch == "\\":
            cur.append(ch)
            escaped = True
            continue
        if in_str:
            cur.append(ch)
            if ch == in_str:
                in_str = None
            continue
        if ch in ("'", '"'):
            in_str = ch
            cur.append(ch)
            continue
        if ch == "{":
            depth_brace += 1
        elif ch == "}":
            depth_brace -= 1
        elif ch == "(":
            depth_paren += 1
        elif ch == ")":
            depth_paren -= 1
        elif ch == "[":
            depth_bracket += 1
        elif ch == "]":
            depth_bracket -= 1
        elif ch == "," and depth_brace == 0 and depth_paren == 0 and depth_bracket == 0:
            parts.append("".join(cur).strip())
            cur = []
            continue
        cur.append(ch)
    tail = "".join(cur).strip()
    if tail:
        parts.append(tail)
    return parts


def parse_catalog_and_aliases(source: str) -> tuple[list[dict[str, str]], dict[str, str]]:
    clean = strip_lua_comments(source)
    marker = "spec.JOB_SPECS ="
    start = clean.find(marker)
    if start < 0:
        raise ValueError("spec.JOB_SPECS assignment not found")
    end = clean.find("local KEY_ALIASES", start)
    if end < 0:
        raise ValueError("KEY_ALIASES boundary not found (review catalog parser)")

    current_job: str | None = None
    entries: list[dict[str, str]] = []
    for line in clean[start:end].splitlines():
        job_m = JOB_OPEN.match(line)
        if job_m:
            current_job = job_m.group(1)
            continue
        id_m = ID_RE.search(line)
        if id_m and current_job:
            name_m = NAME_RE.search(line)
            role_m = ROLE_RE.search(line)
            entries.append(
                {
                    "job": current_job,
                    "soul": id_m.group(1).lower(),
                    "name": name_m.group(1) if name_m else id_m.group(1),
                    "role": role_m.group(1) if role_m else "",
                }
            )

    alias_brace = clean.find("{", end)
    alias_end = find_balanced(clean, alias_brace, "{", "}") if alias_brace >= 0 else -1
    aliases: dict[str, str] = {}
    if alias_brace >= 0 and alias_end > alias_brace:
        for k, v in re.findall(r"(\w+)\s*=\s*['\"]([a-z0-9_]+)['\"]", clean[alias_brace + 1 : alias_end]):
            aliases[k.lower()] = v.lower()

    if len(entries) < 60:
        raise ValueError(f"Only {len(entries)} catalog entries parsed; review catalog format")
    return entries, aliases


def parse_init_append(root: Path) -> tuple[set[str], list[str]]:
    init_path = root / INIT_APPEND
    enabled: set[str] = set()
    missing: list[str] = []
    if not init_path.is_file():
        return enabled, [f"Missing module init list: {INIT_APPEND.as_posix()}"]
    for raw_line in init_path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("--") or line.startswith("#"):
            continue
        rel = f"modules/{line}" if not line.startswith("modules/") else line
        enabled.add(rel)
        if not (root / rel).is_file():
            missing.append(f"modules/init.append.txt references missing file: {rel}")
    return enabled, missing


def extract_local_tables(clean_src: str) -> dict[str, str]:
    tables: dict[str, str] = {}
    for m in LOCAL_TABLE_RE.finditer(clean_src):
        name = m.group(1)
        brace_idx = m.end() - 1
        end_idx = find_balanced(clean_src, brace_idx, "{", "}")
        if end_idx > brace_idx:
            tables[name] = clean_src[brace_idx : end_idx + 1]
    return tables


def _extract_entry_info(table_src: str, consts: dict[str, str], aliases: dict[str, str]) -> dict[str, object] | None:
    km = re.search(r"\bkey\s*=\s*(?:['\"]([a-zA-Z0-9_]+)['\"]|(\w+))", table_src)
    if not km:
        return None
    raw_key = (km.group(1) or consts.get(km.group(2), "")).lower()
    if not raw_key:
        return None
    canonical_key = aliases.get(raw_key, raw_key)
    has_mods = bool(re.search(r"\bmods\s*=", table_src))
    has_abilities = bool(re.search(r"\bextraAbilities\s*=", table_src))
    has_traits = bool(re.search(r"\bextraTraits\s*=", table_src))
    has_substantive_def = has_mods or has_abilities or has_traits
    return {
        "raw_key": raw_key,
        "soul": canonical_key,
        "has_mods": has_mods,
        "has_abilities": has_abilities,
        "has_traits": has_traits,
        "substantive": has_substantive_def,
    }


def extract_registrations_from_file(
    rel_path: str,
    clean_src: str,
    aliases: dict[str, str],
) -> list[dict[str, object]]:
    consts = dict(CONST_STR_RE.findall(clean_src))
    local_tables = extract_local_tables(clean_src)
    registrations: list[dict[str, object]] = []

    for m in REGISTRATION_CALL_RE.finditer(clean_src):
        kind = m.group(1)
        paren_start = m.end() - 1
        paren_end = find_balanced(clean_src, paren_start, "(", ")")
        if paren_end < 0:
            continue
        args = split_top_level(clean_src[m.end() : paren_end])
        if not args:
            continue

        job: str | None = None
        job_m = re.search(r"\bxi\.job\.([A-Z]{3})\b", args[0])
        if job_m:
            job = job_m.group(1)
        elif len(args) > 1:
            str_m = re.search(r"['\"]([A-Z]{3})['\"]", args[1])
            if str_m:
                job = str_m.group(1)
        if not job:
            continue

        candidate_tables: list[str] = []
        if kind == "registerCrystal" and len(args) >= 2:
            arg = args[1].strip()
            if arg.startswith("{"):
                candidate_tables.append(arg)
            elif arg in local_tables:
                candidate_tables.append(local_tables[arg])
            else:
                # Handle dynamic loop registration: `for _, entry in ipairs(TBL) do spec.registerCrystal(xi.job.X, entry)`
                loop_prefix = clean_src[max(0, m.start() - 300) : m.start()]
                loop_m = re.search(
                    rf"\bfor\s+\w+\s*,\s*{re.escape(arg)}\s+in\s+i?pairs\s*\(\s*(\w+)\s*\)",
                    loop_prefix,
                )
                if loop_m and loop_m.group(1) in local_tables:
                    tbl = local_tables[loop_m.group(1)]
                    candidate_tables.extend(split_top_level(tbl[1:-1]))
        elif kind == "registerJob" and len(args) >= 3:
            arg = args[2].strip()
            tbl = arg if arg.startswith("{") and arg.endswith("}") else local_tables.get(arg, "")
            if tbl.startswith("{") and tbl.endswith("}"):
                candidate_tables.extend(split_top_level(tbl[1:-1]))

        for tbl_src in candidate_tables:
            info = _extract_entry_info(tbl_src, consts, aliases)
            if info:
                info["job"] = job
                info["file"] = rel_path
                info["kind"] = kind
                registrations.append(info)

    return registrations


def analyze(root: Path, baseline_path: Path | None = None) -> dict[str, object]:
    catalog_path = root / CATALOG
    if not catalog_path.is_file():
        raise FileNotFoundError(f"Could not read {catalog_path}")

    raw_catalog_entries, aliases = parse_catalog_and_aliases(catalog_path.read_text(encoding="utf-8-sig"))
    enabled_modules, init_errors = parse_init_append(root)

    canonical_entries: list[dict[str, str]] = []
    retired_entries: list[dict[str, str]] = []
    for entry in raw_catalog_entries:
        pair = (entry["job"], entry["soul"])
        if pair in RETIRED_LEGACY_SOULS:
            retired_entries.append(entry)
        else:
            canonical_entries.append(entry)

    canonical_set = {(e["job"], e["soul"]) for e in canonical_entries}

    lua_root = root / "modules/custom/lua"
    all_lua_files = sorted(lua_root.rglob("*.lua"))

    errors: list[str] = list(init_errors)
    warnings: list[str] = []

    if len(canonical_entries) != EXPECTED_CANONICAL_COUNT:
        errors.append(
            f"Canonical Soul roster count mismatch: expected {EXPECTED_CANONICAL_COUNT}, "
            f"found {len(canonical_entries)} (excluding {len(retired_entries)} retired legacy entries)."
        )

    all_registrations: list[dict[str, object]] = []
    file_texts: list[tuple[str, str]] = []

    for lua_file in all_lua_files:
        rel = lua_file.relative_to(root).as_posix()
        raw_text = lua_file.read_text(encoding="utf-8-sig", errors="replace")
        clean_text = strip_lua_comments(raw_text)
        file_texts.append((rel, clean_text))

        # Check require('modules/custom/...') dependencies
        for req_mod in REQUIRE_CUSTOM_RE.findall(clean_text):
            req_path = root / f"{req_mod}.lua"
            if not req_path.is_file():
                errors.append(f"{rel} requires missing module: {req_mod}.lua")

        regs = extract_registrations_from_file(rel, clean_text, aliases)
        all_registrations.extend(regs)

    # Index registrations by (job, soul) and check duplicates / retired / unknown
    regs_by_pair: dict[tuple[str, str], list[dict[str, object]]] = {}
    for reg in all_registrations:
        pair = (str(reg["job"]), str(reg["soul"]))
        regs_by_pair.setdefault(pair, []).append(reg)

    for pair, regs in sorted(regs_by_pair.items()):
        job, soul = pair
        if pair in RETIRED_LEGACY_SOULS:
            files_str = ", ".join(str(r["file"]) for r in regs)
            errors.append(f"Retired legacy Soul {job}:{soul} must NOT be registered (found in {files_str})")
            continue
        if pair not in canonical_set:
            files_str = ", ".join(str(r["file"]) for r in regs)
            errors.append(f"Unrecognized Soul registration {job}:{soul} not in canonical catalog (found in {files_str})")
        if len(regs) > 1:
            files_str = ", ".join(str(r["file"]) for r in regs)
            errors.append(f"Duplicate Soul registration for {job}:{soul} ({len(regs)} registrations: {files_str})")
        for r in regs:
            f = str(r["file"])
            if enabled_modules and f not in enabled_modules:
                errors.append(f"Soul {job}:{soul} is registered in {f}, which is not listed in {INIT_APPEND.as_posix()}")

    # Build coverage rows for the 66 canonical Souls
    rows: list[dict[str, str]] = []
    implemented_ids: set[str] = set()

    for entry in canonical_entries:
        job = entry["job"]
        soul = entry["soul"]
        pair = (job, soul)
        regs = regs_by_pair.get(pair, [])

        # Name references (informational only; NEVER proof of implementation)
        ref_pattern = re.compile(r"(?<![\w])" + re.escape(soul) + r"(?![\w])", re.I)
        ref_files = [
            rel
            for rel, clean_text in file_texts
            if rel != CATALOG.as_posix() and ref_pattern.search(clean_text)
        ]

        reg_files = sorted({str(r["file"]) for r in regs})
        enabled_regs = [r for r in regs if (not enabled_modules or str(r["file"]) in enabled_modules)]
        substantive_regs = [r for r in enabled_regs if bool(r["substantive"])]

        if substantive_regs:
            status = "implemented"
            implemented_ids.add(f"{job}:{soul}")
            notes = "registered+enabled"
        elif regs:
            status = "incomplete"
            reasons = []
            if not enabled_regs:
                reasons.append("module-not-in-init")
            else:
                reasons.append("missing-mods-or-abilities")
            notes = ",".join(reasons)
        else:
            status = "planned"
            notes = "referenced-in-lua" if ref_files else "catalog-only"

        rows.append(
            {
                "job": job,
                "soul": soul,
                "name": entry["name"],
                "role": entry["role"],
                "status": status,
                "notes": notes,
                "registration_files": ";".join(reg_files),
                "reference_files": ";".join(ref_files),
            }
        )

    # Regression check against baseline of already-implemented Souls
    baseline_regressions: list[str] = []
    newly_implemented: list[str] = []
    if baseline_path and baseline_path.is_file():
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
        expected_impl = set(baseline.get("implemented", []))
        baseline_regressions = sorted(expected_impl - implemented_ids)
        newly_implemented = sorted(implemented_ids - expected_impl)
        for reg_id in baseline_regressions:
            errors.append(f"Regression: previously implemented Soul {reg_id} is no longer implemented")
        if newly_implemented:
            warnings.append(
                f"Newly implemented Souls since baseline ({len(newly_implemented)}): {', '.join(newly_implemented)}"
            )

    counts = {
        status: sum(1 for r in rows if r["status"] == status)
        for status in ("implemented", "incomplete", "planned")
    }

    return {
        "canonical_count": len(rows),
        "retired_legacy": [f"{e['job']}:{e['soul']}" for e in retired_entries],
        "counts": counts,
        "rows": rows,
        "errors": errors,
        "warnings": warnings,
        "baseline_regressions": baseline_regressions,
        "newly_implemented": newly_implemented,
    }


def render_markdown_summary(report: dict[str, object]) -> str:
    counts = report["counts"]
    rows = report["rows"]
    errors = report["errors"]
    warnings = report["warnings"]
    retired = report["retired_legacy"]

    lines = [
        "## SoulspireXI Soul Coverage Audit",
        "",
        f"- **Canonical Roster**: {report['canonical_count']} Souls (22 jobs x 3)",
        f"- **Implemented**: {counts['implemented']}",
        f"- **Incomplete**: {counts['incomplete']}",
        f"- **Planned**: {counts['planned']} (does not fail CI)",
        f"- **Retired Legacy (excluded)**: {', '.join(retired) if retired else 'none'}",
        "",
    ]
    if errors:
        lines.append("### Errors")
        for err in errors:
            lines.append(f"- {err}")
        lines.append("")
    if warnings:
        lines.append("### Notices")
        for w in warnings:
            lines.append(f"- {w}")
        lines.append("")

    incomplete = [r for r in rows if r["status"] == "incomplete"]
    if incomplete:
        lines.append("### Incomplete Souls")
        lines.append("| Job | Soul | Notes | Registration Files |")
        lines.append("|---|---|---|---|")
        for r in incomplete:
            lines.append(f"| {r['job']} | `{r['soul']}` | {r['notes']} | `{r['registration_files']}` |")
        lines.append("")

    planned = [r for r in rows if r["status"] == "planned"]
    if planned:
        lines.append("### Planned Souls (Not Yet Implemented)")
        lines.append("| Job | Soul | Name | Role | Notes |")
        lines.append("|---|---|---|---|---|")
        for r in planned:
            lines.append(f"| {r['job']} | `{r['soul']}` | {r['name']} | {r['role']} | {r['notes']} |")
        lines.append("")

    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repo", nargs="?", default=".", help="SoulspireXI checkout root")
    parser.add_argument("--csv", dest="csv_path", help="Write coverage matrix to this CSV")
    parser.add_argument("--json", dest="json_path", help="Write full audit report to this JSON")
    parser.add_argument("--summary-md", dest="summary_md_path", help="Write readable Markdown summary")
    parser.add_argument(
        "--baseline",
        dest="baseline_path",
        default=None,
        help="Path to soul_coverage_baseline.json (defaults to <repo>/tools/soul_coverage_baseline.json if present)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero on duplicate registrations, missing dependencies, retired Soul registration, or regressions.",
    )
    args = parser.parse_args(argv)

    repo_root = Path(args.repo).resolve()
    baseline = Path(args.baseline_path) if args.baseline_path else (repo_root / DEFAULT_BASELINE)
    if not baseline.is_file():
        baseline = None

    try:
        report = analyze(repo_root, baseline_path=baseline)
    except (ValueError, OSError) as exc:
        print(f"audit error: {exc}", file=sys.stderr)
        return 2

    rows = report["rows"]
    fieldnames = list(rows[0].keys()) if rows else []
    writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames, delimiter="\t")
    writer.writeheader()
    writer.writerows(rows)

    if args.csv_path:
        with open(args.csv_path, "w", newline="", encoding="utf-8") as out:
            csvwriter = csv.DictWriter(out, fieldnames=fieldnames)
            csvwriter.writeheader()
            csvwriter.writerows(rows)

    if args.json_path:
        Path(args.json_path).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    if args.summary_md_path:
        Path(args.summary_md_path).write_text(render_markdown_summary(report), encoding="utf-8")

    counts = report["counts"]
    print(
        f"\n{report['canonical_count']} canonical Souls: {counts} "
        f"(retired legacy excluded: {report['retired_legacy']})",
        file=sys.stderr,
    )
    for w in report["warnings"]:
        print(f"[notice] {w}", file=sys.stderr)
    for err in report["errors"]:
        print(f"[error] {err}", file=sys.stderr)

    if args.strict and report["errors"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
