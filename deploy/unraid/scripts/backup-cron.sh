#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# SoulspireXI — Automated Scheduled MariaDB Backup (Unraid User Scripts / cron)
#
# Runs daily (e.g. 04:00):
#   - Creates consistent gzipped dump + SHA256 checksum
#   - Copies Sunday backups to weekly/
#   - Prunes old daily/weekly backups per BACKUP_KEEP_DAILY / BACKUP_KEEP_WEEKLY
#   - Optionally syncs to an off-host location via OFFHOST_BACKUP_CMD
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

APPDATA_DIR="${APPDATA_DIR:-/mnt/user/appdata/overlordsxi}"
KEEP_DAILY="${BACKUP_KEEP_DAILY:-14}"
KEEP_WEEKLY="${BACKUP_KEEP_WEEKLY:-4}"

"${SCRIPT_DIR}/overlords-ctl.sh" backup "scheduled" "daily"

# Promote Sunday backups (day 7) to weekly retention
if [ "$(date +%u)" = "7" ]; then
    latest_daily="$(ls -1t "${APPDATA_DIR}/backups/daily/"xidb-scheduled-*.sql.gz | head -n1 || true)"
    if [ -n "${latest_daily}" ]; then
        cp -a "${latest_daily}" "${APPDATA_DIR}/backups/weekly/"
        cp -a "${latest_daily}.sha256" "${APPDATA_DIR}/backups/weekly/"
        echo "==> Promoted weekly backup: $(basename "${latest_daily}")"
    fi
fi

# Prune old daily & weekly backups
find "${APPDATA_DIR}/backups/daily" -type f -name 'xidb-*.sql.gz*' -mtime "+${KEEP_DAILY}" -delete
find "${APPDATA_DIR}/backups/weekly" -type f -name 'xidb-*.sql.gz*' -mtime "+$((KEEP_WEEKLY * 7))" -delete

# Optional off-host backup sync (e.g. rclone copy to Backblaze B2 / S3 / remote NAS)
if [ -n "${OFFHOST_BACKUP_CMD:-}" ]; then
    echo "==> Running off-host backup sync..."
    eval "${OFFHOST_BACKUP_CMD}"
fi

echo "==> Scheduled backup finished cleanly."
