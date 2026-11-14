#!/usr/bin/env python3
"""Regenerates the file hashes and sizes in launcher/manifest.json."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


def sha256_file(path: Path) -> tuple[str, int]:
    h = hashlib.sha256()
    size = 0
    with path.open("rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
            size += len(chunk)
    return h.hexdigest(), size


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    manifest_path = repo_root / "launcher" / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    entries: list[dict[str, object]] = []

    dat_root = repo_root / "dat-overlay" / "ROM"
    if dat_root.exists():
        for file_path in sorted(p for p in dat_root.rglob("*") if p.is_file()):
            rel_repo = file_path.relative_to(repo_root).as_posix()
            rel_dat = file_path.relative_to(repo_root / "dat-overlay").as_posix()
            digest, size = sha256_file(file_path)
            entries.append(
                {
                    "category": "dat",
                    "sourcePath": rel_repo,
                    "targetPath": rel_dat,
                    "sha256": digest,
                    "size": size,
                }
            )

    addons_root = repo_root / "addons" / "ashita4"
    if addons_root.exists():
        for file_path in sorted(p for p in addons_root.rglob("*") if p.is_file()):
            rel_repo = file_path.relative_to(repo_root).as_posix()
            rel_addon = file_path.relative_to(addons_root).as_posix()
            digest, size = sha256_file(file_path)
            entries.append(
                {
                    "category": "addon",
                    "sourcePath": rel_repo,
                    "targetPath": rel_addon,
                    "sha256": digest,
                    "size": size,
                }
            )

    manifest["files"] = entries
    with manifest_path.open("w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(manifest, indent=2) + "\n")
    print(f"Updated {manifest_path} with {len(entries)} file entries.")


if __name__ == "__main__":
    main()
