# OverlordsXI Wiki Combat Analytics — Deployment & Operations Guide

This guide covers running the **Combat Reports** backend locally and deploying it behind your existing **SWAG / Nginx** reverse proxy without exposing private logs or secrets through GitHub Pages or `site/data.json`.

---

## Architecture Overview

- **Static Wiki UI (`site/`)**: Remains 100% static and GitHub-synced (`index.html`, `styles.css`, `combat-reports.css`, `combat-reports.js`, `app.js`, `data.json`, `data.js`). Contains **zero** private logs, credentials, or FFXI database references.
- **Lightweight Backend (`combat_analytics/`)**: Zero-dependency Python 3.11+ HTTP + SQLite service (`ThreadingHTTPServer` + SQLite WAL). Imports local Soul Proving Grounds JSONL files (`log/proving_grounds/` and `log/proving_grounds_runs.jsonl`), serves authenticated report APIs under `/api/combat/*`, enforces per-character retention, and manages revocable share links.
- **Privacy Guarantee**: Reports are **private by default** (`401 Unauthorized` when unauthenticated). Anonymous read-only access is granted **only** via explicitly created, optionally expiring, revocable `#share/<token>` links.

---

## Quick Local Prototype (Windows / Linux)

1. **Create a dedicated admin account** (never reuse an FFXI game password; minimum 10 characters):
   ```powershell
   python -m combat_analytics.cli --db .combat_analytics_data\analytics.db create-user --username admin --role admin
   ```
2. **Import local Proving Grounds JSONL logs** (supports both v2.0.0 `log/proving_grounds/` and v1.0.0 `log/proving_grounds_runs.jsonl`):
   ```powershell
   python -m combat_analytics.cli --db .combat_analytics_data\analytics.db import-logs --log-dir C:\dev\server\log\proving_grounds
   ```
3. **Start the local prototype server** (serving both the static `site/` wiki and `/api/combat/*` on one port):
   ```powershell
   python -m combat_analytics.cli --db .combat_analytics_data\analytics.db serve --serve-site --host 127.0.0.1 --port 8765 --log-dir C:\dev\server\log\proving_grounds --poll-interval 15
   ```
4. Open `http://127.0.0.1:8765/#reports` and sign in with your analytics admin account.

---

## Production Deployment Behind SWAG / Nginx

### 1. Configure Environment Variables

Copy `combat_analytics/.env.example` to a private location (e.g. `/etc/overlordsxi/combat-analytics.env` or `combat_analytics/.env`, which is gitignored) and configure:

- `OVERLORDS_ANALYTICS_DB`: Persistent SQLite path **outside `site/`** (e.g. `/var/lib/overlordsxi-analytics/analytics.db`).
- `OVERLORDS_PG_LOG_DIR`: Path to your game server's `log/proving_grounds` directory (mount read-only in Docker).
- `OVERLORDS_PG_LEGACY_LOG`: Optional path to `log/proving_grounds_runs.jsonl`.
- `OVERLORDS_PUBLIC_BASE_URL`: Public HTTPS origin of your wiki (e.g. `https://wiki.yourdomain.com`) used when generating share URLs.
- `OVERLORDS_COOKIE_SECURE=1` and `OVERLORDS_TRUST_PROXY_HEADERS=1`.
- `OVERLORDS_RETENTION_PER_CHARACTER=50` (default: keeps 50 newest unpinned reports per character, plus **all** pinned reports).

### 2. Choose Authentication Mode

- **Managed Local Accounts (default enabled)**:
  Create admin or player-scoped accounts using `python -m combat_analytics.cli create-user`. Passwords are hashed with `scrypt` (N=16384, r=8, p=1, random 16-byte salt). Player accounts only see encounters matching their linked `--characters` list; admins see all encounters.
- **Discord OAuth2 (optional)**:
  Create an application in the Discord Developer Portal, add redirect URI `https://<your-wiki-domain>/api/combat/auth/oauth/discord/callback`, and set `OVERLORDS_DISCORD_CLIENT_ID`, `OVERLORDS_DISCORD_CLIENT_SECRET`, `OVERLORDS_DISCORD_REDIRECT_URI`, and `OVERLORDS_DISCORD_ADMIN_IDS`.
- **GitHub OAuth2 (optional)**:
  Create a GitHub OAuth App with callback `https://<your-wiki-domain>/api/combat/auth/oauth/github/callback`, and set `OVERLORDS_GITHUB_CLIENT_ID`, `OVERLORDS_GITHUB_CLIENT_SECRET`, `OVERLORDS_GITHUB_REDIRECT_URI`, and `OVERLORDS_GITHUB_ADMIN_USERS`.

### 3. Run the Backend Service

- **Docker alongside SWAG**: Adapt `combat_analytics/deploy/docker-compose.example.yml` so the backend sits on your SWAG Docker network (`swag_net`) without publishing port `8765` directly to the internet.
- **Systemd on Linux**: Install `combat_analytics/deploy/overlordsxi-analytics.service`.

### 4. Add SWAG / Nginx Reverse Proxy Block

Insert the location block from `combat_analytics/deploy/nginx-combat-analytics.conf` into your existing SWAG site config (`server { ... }`) **before** your catch-all `location /`:

```nginx
location /api/combat/ {
    proxy_pass http://127.0.0.1:8765/api/combat/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_buffering off;
    proxy_no_cache 1;
    proxy_cache_bypass 1;
    add_header X-Robots-Tag "noindex, nofollow" always;
}
```

Reload SWAG/Nginx, then visit `https://<your-wiki-domain>/#reports`.

---

## Retention & Backup Notes

- Every import pass automatically prunes unpinned runs beyond `OVERLORDS_RETENTION_PER_CHARACTER` (default `50`) per character, ordered newest-first.
- Pinned runs are exempt from pruning and do not reduce the 50-report unpinned allowance.
- Original JSONL files (`summary`, `events`, `snapshots`, `feedback`) are archived gzip-compressed inside SQLite so downloads continue working even if game-server logs rotate.
- Back up only `OVERLORDS_ANALYTICS_DB` using SQLite's online backup (`sqlite3 analytics.db ".backup backup.db"`).
