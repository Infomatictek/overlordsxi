#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# SoulspireXI — WireGuard Tunnel Health Check
# Run on VPS (or Unraid with TARGET_IP=10.77.0.1) via cron / systemd timer.
###############################################################################

TARGET_IP="${1:-10.77.0.2}"
WG_IF="${WG_IF:-wg0}"
MAX_HANDSHAKE_AGE_SEC="${MAX_HANDSHAKE_AGE_SEC:-180}"

if ! ip link show "${WG_IF}" >/dev/null 2>&1; then
    echo "[FAIL] WireGuard interface ${WG_IF} is down!" >&2
    exit 1
fi

latest_hs="$(wg show "${WG_IF}" latest-handshakes | awk '{print $2}' | head -n1 || echo 0)"
now="$(date +%s)"
if [ -n "${latest_hs}" ] && [ "${latest_hs}" -gt 0 ]; then
    age=$((now - latest_hs))
    if [ "${age}" -gt "${MAX_HANDSHAKE_AGE_SEC}" ]; then
        echo "[WARN] WireGuard handshake is stale (${age}s > ${MAX_HANDSHAKE_AGE_SEC}s)" >&2
    else
        echo "[OK] WireGuard handshake age: ${age}s"
    fi
else
    echo "[FAIL] No WireGuard handshake recorded on ${WG_IF}" >&2
    exit 1
fi

if ping -c 3 -W 2 "${TARGET_IP}" >/dev/null 2>&1; then
    echo "[OK] Tunnel peer ${TARGET_IP} reachable."
else
    echo "[FAIL] Cannot ping tunnel peer ${TARGET_IP}!" >&2
    exit 1
fi
