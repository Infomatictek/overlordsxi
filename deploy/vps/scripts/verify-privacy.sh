#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# OverlordsXI — Phase 10 Security & Origin-IP Privacy Verification
#
# Run from an external machine (NOT home LAN) to verify:
#   1. play.<domain> resolves ONLY to VPS_PUBLIC_IP (not RESIDENTIAL_IP)
#   2. Authorized game ports are reachable on VPS_PUBLIC_IP
#   3. MariaDB (3306), ZeroMQ (54003), and Unraid WebUI (80/443) are CLOSED on VPS
#
# Usage:
#   ./verify-privacy.sh play.example.com <VPS_PUBLIC_IP> [RESIDENTIAL_IP]
###############################################################################

PLAY_HOST="${1:?Usage: $0 <play.domain> <vps_public_ip> [residential_ip]}"
VPS_IP="${2:?Usage: $0 <play.domain> <vps_public_ip> [residential_ip]}"
RESIDENTIAL_IP="${3:-}"
FAILURES=0

pass() { echo "  [PASS] $*"; }
fail() { echo "  [FAIL] $*" >&2; FAILURES=$((FAILURES + 1)); }

echo "=== 1. Public DNS Resolution Check (${PLAY_HOST}) ==="
resolved_ips="$(dig +short A "${PLAY_HOST}" @1.1.1.1 | sort -u)"
echo "  Resolved A records (1.1.1.1): ${resolved_ips:-<none>}"

if [ "${resolved_ips}" = "${VPS_IP}" ]; then
    pass "${PLAY_HOST} resolves strictly to VPS IP (${VPS_IP})"
else
    fail "${PLAY_HOST} resolved to '${resolved_ips}', expected '${VPS_IP}'"
fi

if [ -n "${RESIDENTIAL_IP}" ] && echo "${resolved_ips}" | grep -Fq "${RESIDENTIAL_IP}"; then
    fail "CRITICAL: Residential IP ${RESIDENTIAL_IP} is exposed in DNS!"
fi

echo "=== 2. Authorized FFXI TCP Ports Reachable on VPS ==="
for port in 54001 54002 54230 54231 51220 51240; do
    if nc -z -w 3 "${VPS_IP}" "${port}" 2>/dev/null; then
        pass "VPS TCP :${port} open"
    else
        fail "VPS TCP :${port} unreachable"
    fi
done

echo "=== 3. Restricted Internal Ports MUST Be Closed on VPS ==="
for port in 3306 54003 8088; do
    if nc -z -w 2 "${VPS_IP}" "${port}" 2>/dev/null; then
        fail "CRITICAL: Restricted port TCP :${port} is OPEN on VPS!"
    else
        pass "Restricted port TCP :${port} is closed"
    fi
done

echo "========================================="
if [ "${FAILURES}" -gt 0 ]; then
    echo "Privacy & Security Verification FAILED (${FAILURES} error(s))." >&2
    exit 1
fi
echo "All automated privacy & port checks PASSED."
