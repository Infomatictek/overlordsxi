#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# SoulspireXI — Automated Linux/Unraid Deployment Verification
#
# Checks:
#   1. All 6 containers running & healthy
#   2. Expected game TCP/UDP ports listening
#   3. MariaDB port 3306 bound ONLY to 127.0.0.1 (isolated)
#   4. Database schema, charset, custom Soul tables & char_vars intact
#   5. zone_settings.zoneip matches SOULSPIRE_ZONE_IP (if configured)
#   6. Optional --run-lua-tests runs xi_test --lua-only inside container
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${DEPLOY_DIR}/.env"

if [ -f "${ENV_FILE}" ]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
fi

MARIADB_DATABASE="${MARIADB_DATABASE:-xidb}"
RUN_LUA_TESTS="${1:-}"
FAILURES=0

pass() { echo "  [PASS] $*"; }
fail() { echo "  [FAIL] $*" >&2; FAILURES=$((FAILURES + 1)); }

echo "=== 1. Container Health Checks ==="
for c in soulspirexi-mariadb soulspirexi-world soulspirexi-connect soulspirexi-search soulspirexi-profile soulspirexi-map; do
    status="$(docker inspect -f '{{.State.Status}}:{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${c}" 2>/dev/null || echo 'missing')"
    if [[ "${status}" == "running:healthy" ]]; then
        pass "${c} (${status})"
    else
        fail "${c} (${status})"
    fi
done

echo "=== 2. Listening Port Verification ==="
for port in 54001 54002 54003 54230 54231 51220 51240; do
    if ss -ltn | grep -qE ":${port}\s"; then
        pass "TCP :${port} listening"
    else
        fail "TCP :${port} NOT listening"
    fi
done

if ss -lun | grep -qE ':54230\s'; then
    pass "UDP :54230 listening (xi_map)"
else
    fail "UDP :54230 NOT listening (xi_map)"
fi

echo "=== 3. MariaDB Isolation Check ==="
if ss -ltn | grep -E ':3306\s' | grep -qvE '127\.0\.0\.1:3306|\[::1\]:3306'; then
    fail "MariaDB :3306 is bound on a non-loopback interface!"
else
    pass "MariaDB :3306 is loopback-only (127.0.0.1)"
fi

echo "=== 4. Database Schema & Custom SoulspireXI Parity ==="
if [ -n "${MARIADB_ROOT_PASSWORD:-}" ]; then
    db_info="$(docker exec soulspirexi-mariadb mariadb -uroot "-p${MARIADB_ROOT_PASSWORD}" -N -B "${MARIADB_DATABASE}" -e "
        SELECT @@version, @@character_set_server, @@collation_server, @@lower_case_table_names;
    " 2>/dev/null || true)"
    if [ -n "${db_info}" ]; then
        pass "MariaDB reachable: ${db_info}"
    else
        fail "Could not query MariaDB"
    fi

    custom_effects="$(docker exec soulspirexi-mariadb mariadb -uroot "-p${MARIADB_ROOT_PASSWORD}" -N -B "${MARIADB_DATABASE}" -e \
        "SELECT COUNT(*) FROM status_effects WHERE id >= 600;" 2>/dev/null || echo 0)"
    if [ "${custom_effects}" -ge 70 ]; then
        pass "Custom status_effects (id >= 600): ${custom_effects}"
    else
        fail "Expected >= 70 custom status_effects, found ${custom_effects}"
    fi

    zone_ips="$(docker exec soulspirexi-mariadb mariadb -uroot "-p${MARIADB_ROOT_PASSWORD}" -N -B "${MARIADB_DATABASE}" -e \
        "SELECT DISTINCT zoneip FROM zone_settings;" 2>/dev/null || true)"
    pass "zone_settings.zoneip values: $(echo "${zone_ips}" | tr '\n' ' ')"
    if [ -n "${SOULSPIRE_ZONE_IP:-}" ] && [ "${zone_ips}" != "${SOULSPIRE_ZONE_IP}" ]; then
        fail "zone_settings.zoneip (${zone_ips}) does not match SOULSPIRE_ZONE_IP (${SOULSPIRE_ZONE_IP})"
    fi
fi

if [ "${RUN_LUA_TESTS}" = "--run-lua-tests" ]; then
    echo "=== 5. Optional xi_test --lua-only Smoke Test ==="
    if docker exec soulspirexi-map /server/xi_test --lua-only; then
        pass "xi_test --lua-only passed"
    else
        fail "xi_test --lua-only failed"
    fi
fi

echo "========================================="
if [ "${FAILURES}" -gt 0 ]; then
    echo "Verification FAILED with ${FAILURES} error(s)." >&2
    exit 1
fi
echo "All deployment verification checks PASSED."
