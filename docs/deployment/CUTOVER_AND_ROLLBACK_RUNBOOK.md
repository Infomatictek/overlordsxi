# SoulspireXI — Phase 11 Final Cutover & Rollback Runbook

> **RULE:** Perform final cutover **only** after explicit owner authorization and after Phases 2–10 have all passed staging validation. Never allow both the Windows server and Unraid server to accept player progress simultaneously.

---

## 1. Pre-Cutover Readiness Gate

All items must be verified before starting the cutover window:

- [ ] All 6 Unraid containers pass `./scripts/overlords-ctl.sh verify`.
- [ ] Phase 5 local LAN gameplay validation passed (including 66 Souls, Shinobi clones, Proving Grounds, container recreation).
- [ ] Phase 6–8 VPS + WireGuard + `play.<domain>` external client tests passed (login, zoning, logout, reconnect).
- [ ] Phase 10 security & privacy verification passed (`verify-privacy.sh`).
- [ ] Maintenance window announced to players.

---

## 2. Synchronized Cutover Steps

1. **Freeze Windows Production (Stop Writes):**
   - Stop `xi_map.exe`, `xi_connect.exe`, `xi_search.exe`, `xi_profile.exe`, and `xi_world.exe` on Windows so no new player writes occur.
   - Leave Windows `mariadbd.exe` running momentarily for a clean final export.
2. **Create & Verify Final Windows DB Export:**
   ```powershell
   .\deploy\unraid\scripts\windows-export-db.ps1 -OutputDir C:\overlordsxi-migration-cutover -Label final-cutover
   ```
   Record the SHA256 and `counts` from `xidb-final-cutover-*.manifest.json`.
3. **Stop Windows MariaDB (Prevent Accidental Re-Start/Split-Brain):**
   - Stop `mariadbd.exe` on Windows and keep `C:\dev\server`, `C:\dev\mariadb`, and `C:\overlordsxi-migration-cutover` intact (do **not** delete!).
4. **Transfer & Restore Final DB to Unraid:**
   - Copy `xidb-final-cutover-*.sql.gz` and `.sha256` to `/mnt/user/appdata/overlordsxi/backups/`.
   - On Unraid:
     ```bash
     ./scripts/overlords-ctl.sh restore /mnt/user/appdata/overlordsxi/backups/xidb-final-cutover-*.sql.gz
     ./scripts/overlords-ctl.sh set-zone-ip <VPS_PUBLIC_IPV4>
     ```
5. **Verify Parity Against Windows Manifest:**
   - Compare restored table/row counts (`tables_total`, `accounts`, `chars`, `char_vars`, `char_inventory`, `status_effects`, `zone_settings`) against `xidb-final-cutover-*.manifest.json`.
6. **Start Unraid Production & Verify Health:**
   ```bash
   ./scripts/overlords-ctl.sh restart
   ./scripts/overlords-ctl.sh verify
   ```
7. **Switch Public Endpoint & Launcher:**
   - Confirm Cloudflare `A` record `play.<domain>` → `<VPS_PUBLIC_IPV4>` (DNS only).
   - Update `overlordsxi-launcher/manifest.json` `defaultHost` to `play.<domain>` (only when authorized).
8. **Post-Cutover Smoke Test:**
   - Connect externally via `play.<domain>`, verify character state/Soul unlocks/inventory, make a small state change (move/zone), logout, reconnect, and confirm persistence.
   - Confirm old Windows server is offline and no longer accepting connections.

---

## 3. Split-Brain-Safe Rollback Procedure

### Scenario A — Rollback Application Image Only (Unraid DB Healthy)
If a new SoulspireXI Docker image has a regression:
```bash
./scripts/overlords-ctl.sh rollback <previous-known-good-tag>
```
Persistent MariaDB data and player progress are preserved.

### Scenario B — Full Rollback to Windows Server (Emergency)
To prevent divergent player progression:
1. **Immediately stop all Unraid game containers:**
   ```bash
   docker compose -f deploy/unraid/docker-compose.yml stop xi-map xi-connect xi-search xi-profile xi-world
   ```
2. **Export any post-cutover progress from Unraid (if players logged in):**
   ```bash
   ./scripts/overlords-ctl.sh backup rollback-export
   ```
3. **Decide DB state:**
   - If no players played on Unraid (or progress is discarded): restart Windows `mariadbd.exe` and `start_server.ps1` directly from the untouched Windows DB.
   - If players played on Unraid and progress must be preserved: import `xidb-rollback-export-*.sql.gz` into Windows MariaDB and restore Windows `zone_settings.zoneip` (`100.108.203.69` or desired host) before starting Windows `xi_*`.
4. **Ensure Unraid stays stopped** while Windows is live so only one authoritative database accepts writes at any time.
