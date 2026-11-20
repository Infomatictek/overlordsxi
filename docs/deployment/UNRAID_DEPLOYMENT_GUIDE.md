# SoulspireXI — Unraid Docker Deployment, Migration & Operations Guide

Covers **Phases 2, 3, 4, 5, and 9** of the SoulspireXI Unraid migration.

---

## 1. Prerequisites on Unraid

- **Architecture:** Linux `x86_64` (verify with `uname -m`)
- **Docker & Docker Compose:** Built-in Docker + Unraid **Docker Compose Manager** plugin (or `docker compose` CLI)
- **User Scripts Plugin (Recommended):** For automated daily MariaDB backups (`backup-cron.sh`)
- **Disk Space:** ~8 GB free for Docker build cache + ~1.5 GB for `/mnt/user/appdata/overlordsxi` (includes 733 MB of `navmeshes`/`ximeshes`)

---

## 2. Persistent Storage Layout (`/mnt/user/appdata/overlordsxi`)

Source code and compiled C++ binaries live inside versioned Docker images (`overlordsxi/server:<tag>`). Only genuinely persistent state is bind-mounted on Unraid:

```text
/mnt/user/appdata/overlordsxi/
├── mariadb/                  # MariaDB 10.11 data directory (/var/lib/mysql)
├── config/
│   ├── settings/             # Seeded with SoulspireXI main.lua, map.lua, etc.
│   └── certs/                # Persistent TLS login.key & login.cert
├── logs/                     # Server logs + proving_grounds/ JSONL telemetry
├── meshes/
│   ├── navmeshes/            # 307 .nav files (read-only mount)
│   └── ximeshes/             # 299 .ximesh files (read-only mount)
└── backups/
    ├── daily/                # 14-day rolling gzipped dumps + .sha256
    ├── weekly/               # 4-week rolling Sunday dumps + .sha256
    └── pre-deploy/           # Automatic pre-deploy / pre-migrate snapshots
```

Recreating containers or upgrading image tags **never** touches `mariadb/`, `config/`, `logs/`, or `backups/`.

### Off-Host Backup Recommendation

Because Unraid array parity is not a backup against ransomware, fire, or accidental deletion, configure `OFFHOST_BACKUP_CMD` in `deploy/unraid/.env` to mirror `/mnt/user/appdata/overlordsxi/backups/` off-host (e.g., encrypted **Backblaze B2** or **Cloudflare R2** via `rclone copy`, or a remote NAS via `rsync` over SSH).

---

## 3. Initial Staging Deployment on Unraid (Phases 2–4)

```bash
# 1. Clone SoulspireXI on Unraid (e.g. /mnt/user/appdata/overlordsxi-src)
git clone https://github.com/Infomatictek/overlordsxi.git /mnt/user/appdata/overlordsxi-src
cd /mnt/user/appdata/overlordsxi-src
git checkout feat/unraid-docker-migration   # until approved & merged to main

# 2. Configure environment & strong database passwords
cd deploy/unraid
cp .env.example .env
chmod 600 .env
# Edit .env: set MARIADB_ROOT_PASSWORD, MARIADB_PASSWORD,
# and OVERLORDS_ZONE_IP=<UNRAID_LAN_IPV4> for Phase 5 local LAN validation.

# 3. Initialize persistent directories & pull navmeshes/ximeshes
chmod +x scripts/*.sh
./scripts/overlords-ctl.sh init

# 4. Build the custom SoulspireXI Docker image (compiles pinned LSB + all 50 patches + 4 C++ modules)
./scripts/overlords-ctl.sh build v2026.11.19

# 5. Copy staging DB export from Windows (created by windows-export-db.ps1)
#    Transfer xidb-staging-*.sql.gz and .sha256 to /mnt/user/appdata/overlordsxi/backups/
./scripts/overlords-ctl.sh restore /mnt/user/appdata/overlordsxi/backups/xidb-staging-*.sql.gz

# 6. Deploy stack & verify health + DB parity
./scripts/overlords-ctl.sh deploy v2026.11.19
./scripts/overlords-ctl.sh verify --run-lua-tests
```

> **Optional TLS Cert Carryover:** You may copy `C:\dev\server\login.cert` and `login.key` into `/mnt/user/appdata/overlordsxi/config/certs/` (chmod `600` on `login.key`), or let `xi_connect` generate a fresh pair on first start.

---

## 4. Phase 5 — Local LAN Gameplay Validation Checklist

Before configuring VPS / public access, point a LAN Ashita v4 client at `--server <UNRAID_LAN_IPV4>` and verify:

- [ ] Login & authentication (`xi_connect` TCP 54231/54230/54001)
- [ ] Character selection & zone load (`xi_map` UDP 54230)
- [ ] Zone transitions (e.g. city → field → Mog House → city)
- [ ] Inventory, equipment, Mog Satchel/Wardrobe, and gil match Windows
- [ ] Combat, haste/attack-speed, and custom weapon skill talent trees
- [ ] Custom Soul abilities, spells, and Soul HUD (`/soulhud`)
- [ ] Shinobi / Kurogane shadow clone spawning & behavior
- [ ] Custom NPCs, trials, and Soul Proving Grounds (verify JSONL written to `/mnt/user/appdata/overlordsxi/logs/proving_grounds/`)
- [ ] Search / Auction House (`xi_search` TCP 54002)
- [ ] Logout & reconnect — verify character position & EXP persist
- [ ] Container restart (`./scripts/overlords-ctl.sh restart`) & reconnect — verify persistence
- [ ] Full container recreation (`docker compose down && ./scripts/overlords-ctl.sh deploy <tag>`) — verify zero data loss

---

## 5. Phase 9 — Ongoing Deployment & Operations Workflow

Never auto-deploy unvalidated GitHub commits. Follow this manual, versioned workflow:

| Action | Command |
|---|---|
| Check status & active tag | `./scripts/overlords-ctl.sh status` |
| Tail logs (all or one service) | `./scripts/overlords-ctl.sh logs xi-map` |
| Manual DB backup | `./scripts/overlords-ctl.sh backup pre-patch` |
| Build new versioned release | `git pull && ./scripts/overlords-ctl.sh build v2026.12.01` |
| Deploy with automatic pre-deploy backup | `./scripts/overlords-ctl.sh deploy v2026.12.01` |
| Run schema migrations safely | `./scripts/overlords-ctl.sh db-migrate` |
| Roll back to previous image | `./scripts/overlords-ctl.sh rollback v2026.11.19` |
| Update advertised zone IP | `./scripts/overlords-ctl.sh set-zone-ip <IPV4>` |
| Verify stack health & DB parity | `./scripts/overlords-ctl.sh verify` |

### Automated Daily Backups (Unraid User Scripts)

Create an Unraid User Script scheduled daily at `04:00`:

```bash
#!/bin/bash
/mnt/user/appdata/overlordsxi-src/deploy/unraid/scripts/backup-cron.sh
```
