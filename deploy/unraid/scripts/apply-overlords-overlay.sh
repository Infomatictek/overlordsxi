#!/usr/bin/env bash
set -euo pipefail

# Applies OverlordsXI engine patches, custom modules, and modules/init.txt
# cleanly onto a pinned LandSandBoat checkout inside Docker (or Linux).
#
# Usage: apply-overlords-overlay.sh <overlords_repo_dir> <lsb_server_dir>

OVERLORDS_DIR="${1:?overlords_repo_dir required}"
SERVER_DIR="${2:?lsb_server_dir required}"

echo "==> Applying OverlordsXI patches from ${OVERLORDS_DIR}/patches to ${SERVER_DIR}"
cd "${SERVER_DIR}"

applied=0
skipped=0

# Sort patches in deterministic ASCII order (LC_ALL=C)
while IFS= read -r patch; do
    name="$(basename "${patch}")"

    # Skip if already present (e.g. folded into an earlier patch)
    if git apply --reverse --check "${patch}" >/dev/null 2>&1 || \
       git apply --reverse --check --ignore-space-change "${patch}" >/dev/null 2>&1; then
        echo "    [SKIP] ${name} (already applied)"
        skipped=$((skipped + 1))
        continue
    fi

    if git apply --check "${patch}" >/dev/null 2>&1; then
        git apply "${patch}"
        echo "    [OK]   ${name}"
        applied=$((applied + 1))
    elif git apply --check --ignore-space-change "${patch}" >/dev/null 2>&1; then
        git apply --ignore-space-change "${patch}"
        echo "    [OK*]  ${name} (--ignore-space-change)"
        applied=$((applied + 1))
    else
        echo "    [FAIL] ${name} failed to apply cleanly!" >&2
        git apply --check "${patch}" || true
        exit 1
    fi
done < <(LC_ALL=C find "${OVERLORDS_DIR}/patches" -maxdepth 1 -type f -name '*.patch' | sort)

echo "==> Patches complete: ${applied} applied, ${skipped} skipped."

echo "==> Syncing OverlordsXI custom modules (lua, cpp, sql, commands)..."
for sub in lua cpp sql commands; do
    src="${OVERLORDS_DIR}/modules/custom/${sub}"
    dst="${SERVER_DIR}/modules/custom/${sub}"
    if [ -d "${src}" ]; then
        mkdir -p "${dst}"
        cp -a "${src}/." "${dst}/"
    fi
done

# Remove known stale SQL files matching setup-local-server.ps1
for stale in ws_strip_skillchains.sql war_specs.sql mnk_specs.sql; do
    rm -f "${SERVER_DIR}/modules/custom/sql/${stale}"
done

echo "==> Updating modules/init.txt..."
INIT_FILE="${SERVER_DIR}/modules/init.txt"
if [ ! -f "${INIT_FILE}" ]; then
    if [ -f "${SERVER_DIR}/modules/init.txt.example" ]; then
        cp "${SERVER_DIR}/modules/init.txt.example" "${INIT_FILE}"
    else
        touch "${INIT_FILE}"
    fi
fi

# Strip UTF-8 BOM and CRLF, filter stale entries, append OverlordsXI entries idempotently
python3 - "${INIT_FILE}" "${OVERLORDS_DIR}/modules/init.append.txt" <<'PYEOF'
import sys
from pathlib import Path

init_path = Path(sys.argv[1])
append_path = Path(sys.argv[2])

stale = {
    "custom/sql/ws_strip_skillchains.sql",
    "custom/sql/war_specs.sql",
    "custom/sql/mnk_specs.sql",
    "custom/lua/overlords_regen_potency.lua",
}

existing = []
seen = set()
if init_path.exists():
    for raw in init_path.read_text(encoding="utf-8-sig").splitlines():
        line = raw.strip()
        if line in stale:
            continue
        existing.append(raw.rstrip("\r"))
        if line:
            seen.add(line)

added = 0
for raw in append_path.read_text(encoding="utf-8-sig").splitlines():
    line = raw.strip()
    if not line or line in seen:
        continue
    existing.append(line)
    seen.add(line)
    added += 1

init_path.write_text("\n".join(existing) + "\n", encoding="utf-8")
print(f"    modules/init.txt updated ({added} OverlordsXI entries added).")
PYEOF

echo "==> Seeding OverlordsXI default gameplay settings (main.lua, map.lua)..."
if [ -d "${OVERLORDS_DIR}/deploy/unraid/config/settings" ]; then
    for cfg in main.lua map.lua; do
        if [ -f "${OVERLORDS_DIR}/deploy/unraid/config/settings/${cfg}" ]; then
            cp "${OVERLORDS_DIR}/deploy/unraid/config/settings/${cfg}" "${SERVER_DIR}/settings/${cfg}"
            echo "    Installed settings/${cfg}"
        fi
    done
fi

echo "==> OverlordsXI overlay complete."
