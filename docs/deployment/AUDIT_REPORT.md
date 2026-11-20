# SoulspireXI — Phase 1 Environment Audit Report

**Audit Date:** 2026-11-19  
**Source Environment:** Windows (`C:\overlordsxi` + `C:\dev\server` + `C:\dev\mariadb` + `C:\overlordsxi-launcher`)  
**Target Environment:** Unraid Linux `x86_64` Docker + MariaDB `10.11` + Ubuntu LTS VPS WireGuard Gateway + Cloudflare DNS

---

## 1. Authoritative Repositories & Current State

| Path / Repo | Remote | Branch / Commit | Role |
|---|---|---|---|
| `C:\overlordsxi` | `https://github.com/Infomatictek/overlordsxi.git` | `main` (`ad8bb88`) — *current live playable server*<br>(`C:\overlordsxi` working tree is currently on `feat/shinobi-2-combat` with uncommitted WIP; migration work is isolated in worktree `feat/unraid-docker-migration` off `main`) | **Authoritative source of truth** for all SoulspireXI patches, custom modules, SQL, commands, telemetry, combat analytics, and docs |
| `C:\dev\server` | `https://github.com/landsandboat/server.git` | `base` @ `091e7409d1c9d702f366dc374115f939393c46ab` (2026-11-12, PR #11980) | Windows build/runtime checkout of upstream LandSandBoat with SoulspireXI patches & modules overlaid |
| `C:\overlordsxi-launcher` | `https://github.com/Infomatictek/overlordsxi-launcher.git` | `main` (working tree currently on `feat/shinobi-2-client-hud`) | Ashita v4 client launcher, manifest, addons, and DAT overlay |

---

## 2. LandSandBoat Version, Build Process & Dependencies

- **Pinned Upstream Commit:** `091e7409d1c9d702f366dc374115f939393c46ab`
- **Windows Build Process:** `scripts/setup-local-server.ps1` applies all `patches/*.patch`, syncs `modules/custom/{lua,cpp,sql,commands}`, updates `modules/init.txt` from `modules/init.append.txt`, and builds via Visual Studio 2022 + CMake/Ninja (`xi_connect`, `xi_world`, `xi_search`, `xi_map`).
- **Linux Docker Build Process (Upstream Native Support):** LandSandBoat ships `docker/ubuntu.Dockerfile` targeting `ubuntu:26.04` with GCC 15, CMake, Ninja, `ccache`, `libluajit-5.1-dev`, `libmariadb-dev-compat`, `libzmq3-dev`, `libssl-dev`, `libdwarf-dev`, `zlib1g-dev`, `libzstd-dev`, `python3-venv`, and `tini`.
- **Server Executables Built:**
  - `xi_world` — Central ZeroMQ IPC broker (and optional HTTP API)
  - `xi_connect` — Login / Lobby / Auth server (TLS via `login.key` / `login.cert`)
  - `xi_search` — Auction House / Player Search server
  - `xi_profile` — PlayOnline Profile / Friends / IRC server (TLS via `login.key` / `login.cert`)
  - `xi_map` — Zone / Combat / Gameplay server (loads all custom Lua & C++ modules)
  - `xi_test` — Automated C++ / Lua test runner (supports `--lua-only` via patch `0045`)

---

## 3. Inventory of Custom SoulspireXI Systems (`main`)

| Category | Count | Highlights |
|---|---:|---|
| Native Engine Patches (`patches/*.patch`) | **50** | Custom pet/effect IDs, Eos/Titania, all WS unlock & dynamic skillchains, crystal socket packets (`0x11f`/`0x1ff`), spec ability/trait unlocks, DoT damage log, throwing WS, auto-ranged attack, DNC ranged dances, BLM necromancer pets, search job labels, talent WS gating, AoE healing on pets, shared OX status slots, polearm+buckler, `MAX_EFFECTID=1024`, Kurogane authoritative look/appearance/regression tests, unified attack-rate haste, `xi_test --lua-only` |
| Custom C++ Modules (`modules/custom/cpp/`) | **4** | `eos_companion.cpp`, `kazenoeye_sync.cpp`, `soulspire_soulhud_sync.cpp`, `soulspire_soul_action_peers.cpp` |
| Custom Lua Modules (`modules/custom/lua/`) | **64** | All 66 Soul specializations across all 22 jobs, Soul Action System, Soul HUD, Kurogane shadow clones (`kurogane_clones.lua`), WS talent trees & overrides, Boss-like combat & EXP, Proving Grounds Lite (`registry`, `telemetry`, `lite`), Eos companion, Regen scaling, Polearm/Buckler, Shared slots, Status registry & mob status sync |
| Custom Commands (`modules/custom/commands/`) | **9** | `buckler.lua`, `camp.lua`, `eos.lua`, `gear.lua`, `kurogane.lua`, `shield.lua`, `soulhud.lua`, `spec.lua`, `talent.lua` |
| Custom SQL Modules (`modules/custom/sql/`) | **30** | Spec abilities/spells/traits for all jobs, `custom_status_effects_sync.sql` (71 custom status effects, IDs ≥ 600), `eos_companion.sql` |
| Combat Analytics (`combat_analytics/`) | **1 service** | Python analytics dashboard & importer reading `log/proving_grounds/` JSONL files; already Docker/SWAG-ready |

---

## 4. Database Audit (Windows MariaDB)

- **Engine & Binary:** `C:\dev\mariadb\bin\mariadbd.exe` — **MariaDB `10.11.10`** (`mariadb.org binary distribution`)
- **Recommended Docker Image:** `mariadb:10.11` (preserves major/minor version parity)
- **Server Settings:**
  - `character_set_server`: `utf8mb4`
  - `collation_server`: `utf8mb4_general_ci`
  - `time_zone`: `SYSTEM` (`America/Chicago`)
  - `sql_mode`: `STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION`
  - `lower_case_table_names`: `1` (Windows default — explicitly configured in `deploy/unraid/config/mariadb/soulspirexi.cnf` for Linux parity)
- **Databases:** `xidb` (`utf8mb4` / `utf8mb4_general_ci`) — **119 tables**, **14.31 MB** total
- **Baseline Row Counts (`xidb`):**
  - `accounts`: 3 | `chars`: 3 | `char_jobs`: 3 | `char_skills`: 135 | `char_spells`: 2,434
  - `char_inventory`: 634 | `char_equip`: 40 | `char_storage`: 3 | `char_unlocks`: 3 | `char_points`: 3
  - `char_vars`: 153 (stores `OX_SPEC_*`, `OX_WST*`, `OX_BLU_*`, `[CustomBoss]*`, quests/missions)
  - `server_variables`: 42 | `status_effects`: 71 (all custom IDs ≥ 600) | `abilities`: 713 | `zone_settings`: 300
- **Non-Standard Tables (not in `sql/*.sql`):** `bcnm_records`, `status_effects` — **MUST** be preserved via full `mariadb-dump` (never rely solely on `dbtool.py` fresh import!).

---

## 5. Untracked Files & Runtime Data Found on Windows

These exist in `C:\dev\server` but were **not tracked in `C:\overlordsxi`**:

1. **Custom Gameplay Settings (`settings/main.lua` & `settings/map.lua`):**
   - `main.lua` has **24 customized settings** (Lv75 cap, 5x EXP/RoE/Book, 3x Tabs/Sparks, 10k start gil, 80 inventory, subjob/advanced jobs at Lv0, all maps, outpost warps, Sneak/Invis 3x, Trust events, Explorer Moogle Lv1, multi-EXP rings, equip from other containers).
   - `map.lua` has **15 customized settings** (0% EXP loss, `BASE_SPEED = 60`, 3x skillup/craft, custom mob/NM HP/MP/stat/TP multipliers, 2x drop rate, +25 gil bonus).
   - **Resolution:** Tracked in `deploy/unraid/config/settings/` and seeded into `/mnt/user/appdata/soulspirexi/config/settings/` on first init.
2. **Local `tools/dbtool.py` Customization:**
   - Windows `C:\dev\server\tools\dbtool.py` had untracked edits (`snapshot_custom_zoneips` / `restore_custom_zoneips`, `autocommit=True`, `ensure_connected()`) to prevent `dbtool.py update` from resetting `zone_settings.zoneip` back to `127.0.0.1`.
   - **Resolution:** Packaged cleanly in our deployment scripts (`soulspire-ctl.sh set-zone-ip` + `SOULSPIRE_ZONE_IP` verification after any DB update) so `zone_settings.zoneip` is never accidentally reverted.
3. **TLS Certificates (`login.cert`, `login.key`):**
   - Generated at `C:\dev\server\login.cert` / `login.key` and shared by `xi_connect` and `xi_profile`.
   - **Resolution:** Persist in `/mnt/user/appdata/soulspirexi/config/certs/` (can be migrated from Windows or freshly generated on first boot).
4. **Navigation & LOS Meshes (`navmeshes/`, `ximeshes/`):**
   - `navmeshes`: 307 files (581.99 MB), `ximeshes`: 299 files (150.75 MB). Excluded from LandSandBoat's main image; required for mob pathfinding and LOS.
   - **Resolution:** Stored persistently in `/mnt/user/appdata/soulspirexi/meshes/{navmeshes,ximeshes}` (populated via `ghcr.io/landsandboat/ximeshes:latest` or copied from Windows).
5. **Logs & Proving Grounds Telemetry (`log/`):**
   - Server logs + `log/proving_grounds/{runs.jsonl, events/, snapshots/, feedback/}` + `log/proving_grounds_runs.jsonl`.
   - **Resolution:** Stored persistently in `/mnt/user/appdata/soulspirexi/logs/` (and mountable read-only into `overlordsxi-combat-analytics`).

---

## 6. Network Ports, Bindings & FFXI Handoff Audit

### Active Listening Ports Audited on Windows

| Process | Protocol | Port | Current Binding | Public via VPS? | Purpose |
|---|---|---|---|---|---|
| `xi_connect` | TCP | `54231` | `0.0.0.0` | **YES** | Auth server (TLS) |
| `xi_connect` | TCP | `54230` | `0.0.0.0` | **YES** | Lobby Data server |
| `xi_connect` | TCP | `54001` | `0.0.0.0` | **YES** | Lobby View server |
| `xi_search` | TCP | `54002` | `0.0.0.0` | **YES** | Search / Auction House server |
| `xi_profile` | TCP | `51220` | `0.0.0.0` | **YES** | PlayOnline Profile server (TLS) |
| `xi_profile` | TCP | `51240` | `0.0.0.0` | **YES** | PlayOnline IRC / Presence server |
| `xi_map` | **UDP** | `54230` | `0.0.0.0` | **YES** | Zone / Gameplay map server |
| `xi_world` | TCP | `54003` | `127.0.0.1` | **NO (internal)** | ZeroMQ IPC message broker |
| `xi_world` | TCP | `8088` | disabled (`ENABLE_HTTP = false`) | **NO** | Optional HTTP API |
| `mariadbd` | TCP | `3306` | `0.0.0.0` / `::` (Windows) → **`127.0.0.1` only on Unraid** | **NO (isolated)** | MariaDB database |

> **Critical Protocol Detail:** Port `54230` is used by **both** `xi_connect` (**TCP**) and `xi_map` (**UDP**). Both protocols must be forwarded on the VPS.

### FFXI Login & Zone Handoff IP Audit (`src/login/` & `src/map/`)

- **Search Server IP (`cache_ip`):** Verified in `src/login/data_session.cpp:105,381`. `xi_connect` echoes back `session.serverIP` sent by `xiloader` (which resolves `--server play.<domain>` to the VPS public IPv4). It does **not** leak Unraid's LAN or residential IP.
- **Map / Zone Handoff IP (`server_ip` / `zone_ipp`):** Verified in `src/login/data_session.cpp:375` and `src/map/utils/zoneutils.cpp:1534`. Both read `zone_settings.zoneip` and `zone_settings.zoneport` from MariaDB.
  - Currently on Windows: `100.108.203.69` (Tailscale CGNAT IP) for 299 zones (`zoneport=54230`) and zone 0 (`zoneport=0`).
  - **Staging (Phase 5 LAN):** Set `zone_settings.zoneip` to Unraid's LAN IPv4.
  - **Production (Phase 6–11 VPS):** Set `zone_settings.zoneip` to the **VPS public IPv4**.
- **`xi_map` Socket Binding:** Verified in `src/map/map_networking.cpp:117` and `src/map/map_socket.cpp:187`. `MapSocket` binds to `0.0.0.0:54230/udp` regardless of `zone_settings.zoneip`, so advertising the VPS public IPv4 works natively without binding errors.

---

## 7. Launcher Audit (`C:\overlordsxi-launcher`)

- `manifest.json` currently has `"defaultHost": "127.0.0.1"`, `"useHairpin": false`, and ports `lobby: 54231`, `auth: 54001`, `search: 54002`.
- No residential public IP or Tailscale IP is hardcoded in `overlordsxi-launcher`.
- Manifest updates and bootstrap downloads (`Ashita`, `xiloader`, `XIPivot`, `metrics`, `mobdb`, `kazenoeye`, DAT overlays, addons) are served exclusively from GitHub (`raw.githubusercontent.com/Infomatictek/overlordsxi-launcher` and `api.github.com`) — **zero residential IP exposure** from launcher updates.
- Supports `overlords-server.json` override and `--server <host>` / `--hairpin` flags. Once `play.<domain>` is live and verified, only `manifest.json`'s `defaultHost` (or a shareable `overlords-server.json`) needs to point to `play.<domain>`.

---

## 8. Linux Docker Compatibility & Migration Risks

| Area | Status | Notes / Mitigation |
|---|---|---|
| Custom C++ Modules (4 files) | **Compatible** | Zero Windows-only headers (`windows.h`, `_WIN32`, etc.) found. Uses standard C++ / LandSandBoat headers. |
| Native Engine Patches (50 files) | **Compatible** | Standard C++/Lua/CMake diffs; verified against pinned LSB commit `091e7409d1`. |
| Custom Lua Modules (64 files) | **Compatible** | `soulspire_proving_grounds_telemetry.lua` uses LuaJIT FFI `CreateDirectoryA` on Windows and falls back cleanly to `mkdir -p` on Linux. |
| MariaDB Case Sensitivity | **Low Risk (Mitigated)** | Windows MariaDB uses `lower_case_table_names=1`. Linux defaults to `0`. Mitigated by setting `lower_case_table_names=1` in `soulspirexi.cnf` on fresh container initialization. |
| Dual-Protocol Port `54230` | **Medium Risk (Mitigated)** | `xi_connect` = TCP 54230, `xi_map` = UDP 54230. Handled explicitly in Docker Compose and VPS `nftables` rules. |
| Asymmetric Routing / IP Leak | **High Risk (Mitigated)** | If Unraid replies directly via residential WAN instead of WireGuard, players receive packets from the residential IP and FFXI drops/leaks. Mitigated via VPS SNAT (`masquerade` on `wg0`) or dedicated policy routing table on Unraid; documented in Phase 6 guide. |
| `dbtool.py update` Resetting `zoneip` | **Medium Risk (Mitigated)** | Upstream `zone_settings.sql` resets `zoneip` to `127.0.0.1`. Mitigated by `soulspire-ctl.sh` preserving/re-applying `SOULSPIRE_ZONE_IP` after every migration. |
| Residential IP via Wiki / Analytics | **Check in Phase 10** | `combat_analytics` uses SWAG reverse proxy; confirm wiki/API domain is Cloudflare-proxied (orange cloud) or hosted via VPS so it never exposes residential IP alongside `play.<domain>`. |
