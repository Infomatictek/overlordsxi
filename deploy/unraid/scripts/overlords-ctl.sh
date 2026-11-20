#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# OverlordsXI — Unraid Deployment & Operations CLI
#
# Commands:
#   init                 Create persistent Unraid appdata layout & pull meshes
#   build <tag>          Build versioned OverlordsXI Docker image from Git HEAD
#   deploy <tag>         Pre-deploy DB backup + controlled rollout + health check
#   update <tag>         Build <tag> then deploy <tag>
#   backup [label]       Create consistent gzipped MariaDB backup + SHA256
#   restore <sql.gz>     Restore a backup into MariaDB + verify schema/counts
#   set-zone-ip <ipv4>   Update zone_settings.zoneip (preserves zone 0 port 0)
#   db-migrate           Run LandSandBoat dbtool.py update & re-apply OVERLORDS_ZONE_IP
#   rollback <tag>       Roll back to a previously built image tag
#   restart [service]    Gracefully restart one or all game services
#   status               Show container status, health, and active image tag
#   logs [service]       Follow container logs
#   verify               Run automated deployment & DB parity checks
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${DEPLOY_DIR}/../.." && pwd)"
COMPOSE_FILE="${DEPLOY_DIR}/docker-compose.yml"
ENV_FILE="${DEPLOY_DIR}/.env"

if [ -f "${ENV_FILE}" ]; then
    set -a
    # shellcheck disable=SC1090
    source "${ENV_FILE}"
    set +a
fi

APPDATA_DIR="${APPDATA_DIR:-/mnt/user/appdata/overlordsxi}"
OVERLORDS_IMAGE="${OVERLORDS_IMAGE:-overlordsxi/server}"
OVERLORDS_TAG="${OVERLORDS_TAG:-latest}"
MARIADB_DATABASE="${MARIADB_DATABASE:-xidb}"
PUID="${PUID:-99}"
PGID="${PGID:-100}"

dc() {
    docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"
}

require_env() {
    if [ ! -f "${ENV_FILE}" ]; then
        echo "[ERROR] Missing ${ENV_FILE}. Copy .env.example to .env and set credentials first." >&2
        exit 1
    fi
}

cmd_init() {
    echo "==> Initializing Unraid persistent storage under ${APPDATA_DIR}"
    mkdir -p \
        "${APPDATA_DIR}/mariadb" \
        "${APPDATA_DIR}/config/settings" \
        "${APPDATA_DIR}/config/certs" \
        "${APPDATA_DIR}/logs/proving_grounds/events" \
        "${APPDATA_DIR}/logs/proving_grounds/snapshots" \
        "${APPDATA_DIR}/logs/proving_grounds/feedback" \
        "${APPDATA_DIR}/meshes/navmeshes" \
        "${APPDATA_DIR}/meshes/ximeshes" \
        "${APPDATA_DIR}/backups/daily" \
        "${APPDATA_DIR}/backups/weekly" \
        "${APPDATA_DIR}/backups/pre-deploy"

    # Seed OverlordsXI customized gameplay settings if not yet present
    for cfg in main.lua map.lua; do
        if [ ! -f "${APPDATA_DIR}/config/settings/${cfg}" ] && [ -f "${DEPLOY_DIR}/config/settings/${cfg}" ]; then
            cp "${DEPLOY_DIR}/config/settings/${cfg}" "${APPDATA_DIR}/config/settings/${cfg}"
            echo "    Seeded ${APPDATA_DIR}/config/settings/${cfg}"
        fi
    done

    # Set Unraid permissions (nobody:users by default) on game-owned dirs (leave mariadb to its own uid)
    chown -R "${PUID}:${PGID}" \
        "${APPDATA_DIR}/config" \
        "${APPDATA_DIR}/logs" \
        "${APPDATA_DIR}/meshes" \
        "${APPDATA_DIR}/backups" || true

    # Populate navmeshes / ximeshes if empty
    if [ -z "$(ls -A "${APPDATA_DIR}/meshes/navmeshes" 2>/dev/null || true)" ]; then
        echo "==> Populating navmeshes & ximeshes from ghcr.io/landsandboat/ximeshes:latest..."
        docker run --rm \
            -v "${APPDATA_DIR}/meshes/navmeshes:/navmeshes" \
            -v "${APPDATA_DIR}/meshes/ximeshes:/ximeshes" \
            ghcr.io/landsandboat/ximeshes:latest
        chown -R "${PUID}:${PGID}" "${APPDATA_DIR}/meshes" || true
    else
        echo "    Meshes already populated ($(ls -1 "${APPDATA_DIR}/meshes/navmeshes" | wc -l) navmeshes)."
    fi

    echo "==> Initialization complete."
}

cmd_build() {
    local tag="${1:?Usage: $0 build <tag>}"
    local commit_sha
    commit_sha="$(git -C "${REPO_ROOT}" rev-parse HEAD 2>/dev/null || echo 'unknown')"

    echo "==> Building ${OVERLORDS_IMAGE}:${tag} (commit ${commit_sha})"
    DOCKER_BUILDKIT=1 docker build \
        --platform linux/amd64 \
        -f "${DEPLOY_DIR}/Dockerfile" \
        --build-arg "UID=${PUID}" \
        --build-arg "GID=${PGID}" \
        --build-arg "OVERLORDS_VERSION=${tag}" \
        --build-arg "OVERLORDS_COMMIT=${commit_sha}" \
        -t "${OVERLORDS_IMAGE}:${tag}" \
        "${REPO_ROOT}"

    echo "==> Built ${OVERLORDS_IMAGE}:${tag} successfully."
}

cmd_backup() {
    require_env
    local label="${1:-manual}"
    local subdir="${2:-daily}"
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local out_dir="${APPDATA_DIR}/backups/${subdir}"
    mkdir -p "${out_dir}"
    local out_file="${out_dir}/xidb-${label}-${ts}.sql.gz"

    echo "==> Backing up ${MARIADB_DATABASE} -> ${out_file}"
    docker exec overlordsxi-mariadb \
        mariadb-dump -uroot "-p${MARIADB_ROOT_PASSWORD}" \
        --single-transaction --routines --triggers --events --hex-blob \
        --default-character-set=utf8mb4 \
        "${MARIADB_DATABASE}" | gzip -9 > "${out_file}"

    if [ ! -s "${out_file}" ]; then
        echo "[ERROR] Backup file is empty!" >&2
        rm -f "${out_file}"
        exit 1
    fi

    sha256sum "${out_file}" > "${out_file}.sha256"
    # Verify gzip stream integrity
    gzip -t "${out_file}"
    echo "==> Backup verified: $(du -h "${out_file}" | cut -f1) (${out_file})"
}

cmd_restore() {
    require_env
    local src="${1:?Usage: $0 restore <path/to/backup.sql.gz|backup.sql>}"
    if [ ! -f "${src}" ]; then
        echo "[ERROR] Backup file not found: ${src}" >&2
        exit 1
    fi

    if [ -f "${src}.sha256" ]; then
        echo "==> Verifying SHA256 checksum..."
        (cd "$(dirname "${src}")" && sha256sum -c "$(basename "${src}.sha256")")
    fi

    echo "==> Ensuring MariaDB is running and game services are stopped..."
    dc stop xi-map xi-connect xi-search xi-profile xi-world || true
    dc up -d mariadb
    echo "==> Waiting for MariaDB health..."
    for _ in $(seq 1 30); do
        if [ "$(docker inspect -f '{{.State.Health.Status}}' overlordsxi-mariadb 2>/dev/null || true)" = "healthy" ]; then
            break
        fi
        sleep 2
    done

    echo "==> Restoring ${src} into ${MARIADB_DATABASE}..."
    docker exec -i overlordsxi-mariadb mariadb -uroot "-p${MARIADB_ROOT_PASSWORD}" -e \
        "CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

    if [[ "${src}" == *.gz ]]; then
        gunzip -c "${src}" | docker exec -i overlordsxi-mariadb mariadb -uroot "-p${MARIADB_ROOT_PASSWORD}" "${MARIADB_DATABASE}"
    else
        docker exec -i overlordsxi-mariadb mariadb -uroot "-p${MARIADB_ROOT_PASSWORD}" "${MARIADB_DATABASE}" < "${src}"
    fi

    echo "==> Verifying restored table & row counts:"
    docker exec overlordsxi-mariadb mariadb -uroot "-p${MARIADB_ROOT_PASSWORD}" -N -B "${MARIADB_DATABASE}" -e "
        SELECT 'tables_total', COUNT(*) FROM information_schema.TABLES WHERE table_schema='${MARIADB_DATABASE}'
        UNION ALL SELECT 'accounts', COUNT(*) FROM accounts
        UNION ALL SELECT 'chars', COUNT(*) FROM chars
        UNION ALL SELECT 'char_vars', COUNT(*) FROM char_vars
        UNION ALL SELECT 'char_inventory', COUNT(*) FROM char_inventory
        UNION ALL SELECT 'status_effects', COUNT(*) FROM status_effects
        UNION ALL SELECT 'zone_settings', COUNT(*) FROM zone_settings;
    "

    if [ -n "${OVERLORDS_ZONE_IP:-}" ] && [ "${OVERLORDS_ZONE_IP}" != "127.0.0.1" ]; then
        echo "==> Applying OVERLORDS_ZONE_IP=${OVERLORDS_ZONE_IP} to zone_settings..."
        cmd_set_zone_ip "${OVERLORDS_ZONE_IP}"
    fi
    echo "==> Restore complete. Start services with: $0 restart"
}

cmd_set_zone_ip() {
    require_env
    local ip="${1:?Usage: $0 set-zone-ip <ipv4>}"
    if ! [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "[ERROR] Invalid IPv4 address: ${ip}" >&2
        exit 1
    fi
    echo "==> Updating zone_settings.zoneip -> ${ip}"
    docker exec overlordsxi-mariadb mariadb -uroot "-p${MARIADB_ROOT_PASSWORD}" "${MARIADB_DATABASE}" -e \
        "UPDATE zone_settings SET zoneip = '${ip}';"
    docker exec overlordsxi-mariadb mariadb -uroot "-p${MARIADB_ROOT_PASSWORD}" "${MARIADB_DATABASE}" -e \
        "SELECT zoneip, zoneport, COUNT(*) AS zones FROM zone_settings GROUP BY zoneip, zoneport;"
}

cmd_db_migrate() {
    require_env
    cmd_backup "pre-migrate" "pre-deploy"
    echo "==> Running LandSandBoat dbtool.py update..."
    dc --profile tools run --rm db-migrate
    if [ -n "${OVERLORDS_ZONE_IP:-}" ]; then
        cmd_set_zone_ip "${OVERLORDS_ZONE_IP}"
    fi
}

update_env_tag() {
    local tag="$1"
    if grep -q '^OVERLORDS_TAG=' "${ENV_FILE}"; then
        sed -i "s|^OVERLORDS_TAG=.*|OVERLORDS_TAG=${tag}|" "${ENV_FILE}"
    else
        echo "OVERLORDS_TAG=${tag}" >> "${ENV_FILE}"
    fi
}

cmd_deploy() {
    require_env
    local tag="${1:?Usage: $0 deploy <tag>}"
    if ! docker image inspect "${OVERLORDS_IMAGE}:${tag}" >/dev/null 2>&1; then
        echo "[ERROR] Image ${OVERLORDS_IMAGE}:${tag} not found locally. Run '$0 build ${tag}' first." >&2
        exit 1
    fi

    # Take pre-deploy DB backup if MariaDB is already running
    if [ "$(docker inspect -f '{{.State.Running}}' overlordsxi-mariadb 2>/dev/null || true)" = "true" ]; then
        cmd_backup "pre-deploy-${tag}" "pre-deploy"
    fi

    echo "==> Recording active tag ${tag} in ${ENV_FILE}"
    update_env_tag "${tag}"

    echo "==> Rolling out OverlordsXI ${tag}..."
    dc up -d --remove-orphans

    echo "==> Waiting for health checks..."
    sleep 5
    "${SCRIPT_DIR}/verify-deployment.sh"
}

cmd_rollback() {
    require_env
    local tag="${1:?Usage: $0 rollback <previous-tag>}"
    echo "==> Rolling back OverlordsXI application image to ${tag} (persistent data untouched)..."
    cmd_deploy "${tag}"
}

cmd_restart() {
    require_env
    if [ $# -gt 0 ]; then
        dc restart "$@"
    else
        dc restart xi-world xi-connect xi-search xi-profile xi-map
    fi
}

cmd_status() {
    require_env
    echo "==> Active OVERLORDS_TAG=${OVERLORDS_TAG}"
    dc ps
}

cmd_logs() {
    require_env
    dc logs -f --tail=100 "$@"
}

usage() {
    sed -n '3,20p' "$0" | sed 's/^#//'
}

case "${1:-}" in
    init)        shift; cmd_init "$@" ;;
    build)       shift; cmd_build "$@" ;;
    deploy)      shift; cmd_deploy "$@" ;;
    update)      shift; cmd_build "$1" && cmd_deploy "$1" ;;
    backup)      shift; cmd_backup "$@" ;;
    restore)     shift; cmd_restore "$@" ;;
    set-zone-ip) shift; cmd_set_zone_ip "$@" ;;
    db-migrate)  shift; cmd_db_migrate "$@" ;;
    rollback)    shift; cmd_rollback "$@" ;;
    restart)     shift; cmd_restart "$@" ;;
    status)      shift; cmd_status "$@" ;;
    logs)        shift; cmd_logs "$@" ;;
    verify)      shift; "${SCRIPT_DIR}/verify-deployment.sh" "$@" ;;
    *)           usage; exit 1 ;;
esac
