#!/usr/bin/env python3
"""Conservative static triage of OverlordsXI Soul modules.

Run from a repository checkout: python tools/audit_soul_coverage.py [repo-root]
Static evidence is not proof of in-game availability; see the output notes.
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

CATALOG = Path('modules/custom/lua/overlords_job_specs.lua')
JOB_OPEN = re.compile(r'^\s*([A-Z]{3})\s*=\s*$')
ID = re.compile(r"\bid\s*=\s*['\"]([a-z][a-z0-9_]*)['\"]")
KEY_ASSIGNMENT = re.compile(r"\\bkey\\s*=\\s*(?:['\\\"]([a-z][a-z0-9_]*)['\\\"]|([A-Z][A-Z_0-9]*))")
CONST = re.compile(r"\blocal\s+(\w+)\s*=\s*['\"]([a-z][a-z0-9_]*)['\"]")
REGISTRATION = re.compile(r'\bspec\s*\.\s*(?:registerCrystal|registerJob)\s*\(')


def catalog_entries(source: str) -> list[tuple[str, str]]:
    marker = 'spec.JOB_SPECS ='
    start = source.find(marker)
    if start < 0:
        raise ValueError('spec.JOB_SPECS assignment not found')
    end = source.find('local KEY_ALIASES', start)
    if end < 0:
        raise ValueError('KEY_ALIASES boundary not found (review parser)')
    current_job = None
    result = []
    for line in source[start:end].splitlines():
        job = JOB_OPEN.match(line)
        if job:
            current_job = job.group(1)
        match = ID.search(line)
        if match and current_job:
            result.append((current_job, match.group(1)))
    if len(result) < 60:
        raise ValueError(f'Only {len(result)} catalog entries parsed; review catalog format')
    return result


def extract_registration_args(source: str, start: int) -> str:
    """Read one balanced call, skipping quoted strings and line comments."""
    depth = 1
    i = start
    quote = None
    while i < len(source) and depth:
        char = source[i]
        if quote is not None:
            if char == '\\\\':
                i += 2
                continue
            if char == quote:
                quote = None
        elif source.startswith('--', i):
            newline = source.find('\\n', i)
            i = len(source) if newline < 0 else newline + 1
            continue
        elif char in ("'", '"'):
            quote = char
        elif char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
        i += 1
    return source[start:i - 1] if depth == 0 else ''


def analyze(root: Path) -> list[dict[str, str]]:
    path = root / CATALOG
    if not path.is_file():
        raise FileNotFoundError(f'Could not read {path}')
    souls = catalog_entries(path.read_text(encoding='utf-8-sig'))
    lua_root = root / 'modules/custom/lua'
    files = [p for p in lua_root.rglob('*.lua') if p != path]
    indexed = []
    for file in files:
        data = file.read_text(encoding='utf-8-sig', errors='replace')
        constants = dict(CONST.findall(data))
        registrations = set()
        for hit in REGISTRATION.finditer(data):
            args = extract_registration_args(data, hit.end())
            for match in KEY_ASSIGNMENT.finditer(args):
                literal, variable = match.groups()
                key = literal or constants.get(variable)
                if key:
                    registrations.add(key)
        indexed.append((file.relative_to(root).as_posix(), data, registrations))
    rows = []
    for job, key in souls:
        references, registrations = [], []
        pattern = re.compile(r'(?<![\w])'+re.escape(key)+r'(?![\w])', re.I)
        for file, data, regs in indexed:
            if pattern.search(data):
                references.append(file)
                if key in regs:
                    registrations.append(file)
        status = ('registration-evidence' if registrations else
                  'referenced-only' if references else 'catalog-only')
        rows.append({'job':job, 'soul':key, 'evidence':status,
                     'registration_files':';'.join(registrations),
                     'reference_files':';'.join(references)})
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('repo', nargs='?', default='.', help='OverlordsXI checkout root')
    parser.add_argument('--csv', dest='csv_path', help='Write evidence matrix to this CSV')
    args = parser.parse_args()
    try:
        rows = analyze(Path(args.repo).resolve())
    except (ValueError, OSError) as exc:
        print(f'audit error: {exc}', file=sys.stderr)
        return 2
    writer = csv.DictWriter(sys.stdout, fieldnames=list(rows[0]), delimiter='\t')
    writer.writeheader()
    writer.writerows(rows)
    if args.csv_path:
        with open(args.csv_path, 'w', newline='', encoding='utf-8') as out:
            csvwriter = csv.DictWriter(out, fieldnames=list(rows[0]))
            csvwriter.writeheader()
            csvwriter.writerows(rows)
    counts = {name:sum(r['evidence']==name for r in rows)
              for name in ('registration-evidence','referenced-only','catalog-only')}
    print(f"\n{len(rows)} catalog entries: {counts}", file=sys.stderr)
    print('Static evidence only; confirm SQL/client wiring and in-game activation.', file=sys.stderr)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
