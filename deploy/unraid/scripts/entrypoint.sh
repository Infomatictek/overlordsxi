#!/usr/bin/env bash
set -euo pipefail

# Unraid-friendly entrypoint for SoulspireXI LandSandBoat containers.
# Preserves LandSandBoat's XI_* environment variable convention, ensures
# persistent directories exist, seeds default settings if a fresh bind mount
# is empty, and hands off PID 1 signal handling to tini.

unset MARIADB_ROOT_PASSWORD

: "${XI_NETWORK_SQL_PASSWORD:=${MARIADB_PASSWORD:-}}"
: "${XI_NETWORK_SQL_LOGIN:=${MARIADB_USER:-}}"
: "${XI_NETWORK_SQL_DATABASE:=${MARIADB_DATABASE:-xidb}}"
unset MARIADB_PASSWORD MARIADB_USER MARIADB_DATABASE

export XI_NETWORK_SQL_PASSWORD
export XI_NETWORK_SQL_LOGIN
export XI_NETWORK_SQL_DATABASE

# Seed /server/settings from /server/settings.image-defaults if bind-mounted empty
if [ -d /server/settings ] && [ -d /server/settings.image-defaults ]; then
    for f in logging.lua login.lua main.lua map.lua network.lua search.lua test.lua; do
        if [ ! -f "/server/settings/${f}" ] && [ -f "/server/settings.image-defaults/${f}" ]; then
            cp "/server/settings.image-defaults/${f}" "/server/settings/${f}"
        fi
    done
    if [ ! -d /server/settings/default ] && [ -d /server/settings.image-defaults/default ]; then
        cp -a /server/settings.image-defaults/default /server/settings/default
    fi
fi

# Ensure Proving Grounds telemetry directories exist on persistent log mount
if [ -d /server/log ] && [ -w /server/log ]; then
    mkdir -p /server/log/proving_grounds/events \
             /server/log/proving_grounds/snapshots \
             /server/log/proving_grounds/feedback || true
fi

exec tini -- "$@"
