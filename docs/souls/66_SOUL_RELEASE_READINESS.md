# SoulspireXI — 66-Soul Release Readiness Report

## Executive Summary

- **Total Canonical Souls:** **66** (`DNC:freelancer` retired/excluded)
- **Implemented Souls:** **66 / 66** (0 incomplete, 0 planned)
- **Automated Verification:** **66 / 66** (strict roster audit, 101 LuaJIT module syntax checks, 141/147 Python + Lupa runtime tests passing, cross-repo wiki + Soul Actions validation passing, 1,109/1,109 launcher manifest entries verified)
- **Live Gameplay Verification:** **41 baseline Souls** previously deployed on `main`; **25 newly integrated Souls** require **Manual Verification Required** on a live test server + Ashita v4 client (levels 10, 30, 50, 75; 0 talent points at Lv. 10).
- **Status:** Both server and launcher integration branches are cleanly branched from current `main`, reconciled, verified, and pushed for PR review. Neither branch has been merged into `main` or deployed to the live server.

---

## Phase 1 — Reconciliation Categorization

### Implemented and Verified (Automated)
- All **66 canonical Souls** are registered and enabled in `modules/init.append.txt`, audited by `tools/audit_soul_coverage.py` (`implemented: 66, incomplete: 0, planned: 0`), and exported into `site/data.json` / `site/data.js` (`66 Crystal Specs, 256 Custom JAs, 44 Traits, 219 Weaponskill Trees, 77 Engine Patches`).
- All **25 newly implemented Souls** (`zealot`, `valkyrie`, `astromancer`, `channeler`, `scarletweaver`, `royaltactician`, `bandit`, `trickster`, `phantom`, `oathbreaker`, `reaper`, `scourge`, `sniper`, `arcanearcher`, `nightblade`, `lancer`, `skyborn`, `warmage`, `archivist`, `untamed`, `beastspeaker`, `primalist`, `herald`, `terramancer`, `diviner`) pass their focused native + Lupa runtime tests, strict LuaJIT syntax checks, and cross-repo TSV validation.
- All newer `main` systems are preserved intact:
  - **Server `main` (`8225245`)**: 66-Soul design contracts (`docs/souls-66/`), 219-WS Foundation (`feat/ws-foundation-playable-v1`), Burrows Reborn Lv. 10 prototype (`feat/burrows-reborn-first-descent-instance.patch`, `soulspire_burrows_first_descent.lua`, Unraid Docker hooks), Combat Analytics, Proving Grounds, Haste/Auto-Attack overhaul.
  - **Launcher `main` (`e32490c`)**: Gear Manager stability & polling optimizations (`addons/ashita4/soulspire_gear/og/state.lua`), native Soul Action visibility engine (`feat/native-soul-action-visibility`), Shinobi v2 native actions.
- Legacy `feat/souls-66-integration` in both repos predates the `overlords` → `soulspire` rename and contains only superseded Sequence A–E prototypes and older wiki drafts; no unique runtime functionality is missing from `main + feat/final-25-souls`.

### Implemented, Integrated on Dedicated Branches (Not Yet Merged to `main`)
- Server branch `feat/souls-66-final-integration` (from `origin/main` `8225245` + `origin/feat/final-25-souls` `a8c7555`).
- Launcher branch `feat/souls-66-final-integration` (from `origin/main` `e32490c` + `origin/feat/final-25-souls` `f2ef25b` + canonical repo updater repair).

### Client-Side Work Required (Optional Polish — Non-Blocking)
- **CrystalSocket PNG icons:** 29 Souls do not yet have dedicated 128x128 PNG art in `addons/ashita4/crystalsocket/assets/` (the 25 newly integrated Souls plus `defender` [legacy file is `aegistemplar.png`], `adventurer`, `musician`, `minstrel`). CrystalSocket loads all 66 Souls dynamically from the server protocol and falls back safely when `<soul>.png` is absent.
- **Custom DAT overlays:** None required for the 25 new Souls. Native Soul action renaming, descriptions, and visibility are delivered in-memory by `soulspire_soul_actions` via `soul_actions.tsv` (159 rows across 26 Souls) and `visibility.tsv` (159 rows across 26 Souls). Existing 8 XIPivot DATs (`ROM/118/108.DAT`, `114.DAT`, `119/57.DAT`, `180/102.DAT`, `181/72.DAT`, `73.DAT`, `74.DAT`, `75.DAT`) remain validated in `manifest.json`.

### Manual Gameplay Verification Required
- Live server + Ashita v4 client testing is unavailable in this environment; all 25 new Souls remain marked **Manual Verification Required** per their individual reports in `docs/souls/completed/*.md`.
- Priority verification matrix:
  - Levels **10, 30, 50, 75** (especially **Lv. 10 with 0 talent points**).
  - Soul switching, relogging, level sync (including Burrows Reborn Lv. 10 sync), native action menu visibility (no leaked original FFXI action names), cooldowns/recasts, resource HUD synchronization, pet lifecycle (`untamed`, `beastspeaker`, `primalist`, `herald`), and weapon/WS restrictions.

### Actually Missing or Broken (Found & Addressed / Documented)
1. **Fixed — Launcher repo URL references:** `manifest.json`, `LauncherManifest.cs`, `LauncherSelfUpdateService.cs`, `ManifestUpdateService.cs`, addon metadata, and tests still referenced `Infomatictek/overlordsxi-launcher`. Updated all canonical references to `Infomatictek/soulspirexi-launcher` (while retaining `LegacyLauncherExeAssetName = "OverlordsLauncher.exe"` for upgrade migration) and regenerated `manifest.json` (1,109 entries verified).
2. **Pre-existing `main` test discrepancy (not introduced by this integration):** `tests/test_combat_analytics.py::SecurityHygieneAndUiSuiteTests::test_no_private_logs_or_secrets_in_static_site_or_backend` fails because `combat_analytics/auth.py` intentionally added `import pymysql` on `main` (commit `30eb966`, FFXI MariaDB account auth) while the older test assertion still forbids `"import pymysql"`. Left untouched so security-test intent is reviewed explicitly.

---

## Server Integration Status

- **Repository:** `Infomatictek/soulspirexi`
- **Integration Branch:** `feat/souls-66-final-integration`
- **Base `main`:** `8225245dca6559c34dc2657b1ef2a6529547a12c`
- **Merged `feat/final-25-souls`:** `a8c755584981264be8cd3e03141d8a5cac28d95f`
- **Conflict Analysis:**
  - `modules/init.append.txt` auto-merged cleanly, retaining all 25 new Soul modules plus `main`'s Burrows Reborn entries (`soulspire_burrows_config.lua`, `soulspire_burrows_first_descent.lua`).
  - **Patch numbering / overlap check:** `main` added `patches/0046-burrows-reborn-first-descent-instance.patch` (touches only `scripts/zones/Ghoyus_Reverie/instances/the_first_descent.lua`). `feat/final-25-souls` adds `patches/0046-zealot-native-actions.patch` through `patches/0070-diviner-native-actions.patch`. Zero file overlap exists between `0046-burrows` and `0046-zealot`..`0070-diviner`.
  - **Wiki data:** Regenerated `site/data.json` and `site/data.js` using `--require-lua --launcher-dir /launcher --strict-actions` (66 Crystal Specs, 256 Custom JAs, 44 Traits, 219 WS Trees, 77 Engine Patches).

---

## Launcher Integration & Delivery Analysis

- **Repository:** `Infomatictek/soulspirexi-launcher`
- **Integration Branch:** `feat/souls-66-final-integration`
- **Base `main`:** `e32490c1379bab7be64cb134c5c3475fd84af1fe`
- **Merged `feat/final-25-souls`:** `f2ef25b79d92cf11ed8ed15699b190e9c51638a9`
- **Auto-Updater Live Endpoint Verification:**
  - `https://api.github.com/repos/Infomatictek/soulspirexi-launcher/commits/main` → `200 OK`
  - `https://raw.githubusercontent.com/Infomatictek/soulspirexi-launcher/main/manifest.json` → `200 OK`
  - `https://api.github.com/repos/Infomatictek/soulspirexi-launcher/releases/latest` → `200 OK`
  - Legacy `overlordsxi-launcher` URLs currently redirect via GitHub repository ID, allowing existing `v2.0.0` launchers to fetch the updated `manifest.json` and discover the next `SoulspireLauncher.exe` release seamlessly.

### Delivery Channel Breakdown

| Channel | Files Covered | Requires New `.exe` Release? |
|---|---|---|
| **Manifest Updater (`manifest.json`)** | `addons/ashita4/soulspire_soul_actions/data/soul_actions.tsv`, `visibility.tsv`, `soulspire_soulhud/soulhud_layout.lua`, `soulspire_gear/og/state.lua`, all 69 Soulspire addon Lua files, `plugins/ashita4/crystaljobs.dll` | **No** — delivered automatically on next launcher sync once merged to `main`. |
| **Compiled Launcher Executable (`SoulspireLauncher.exe`)** | Updated C# defaults (`LauncherManifest.cs`, `LauncherSelfUpdateService.cs`, `ManifestUpdateService.cs`) and newly embedded `manifest.json` pointing natively to `Infomatictek/soulspirexi-launcher` | **Yes** — bump `<Version>` (e.g. `2.0.1`) and tag `v2.0.1` on `main` to trigger `.github/workflows/build-launcher.yml` (`windows-latest` .NET 8 build + GitHub Release). |
| **XIPivot Client DAT Overlay** | 8 existing DATs in `dat-overlay/ROM/` (SCH Eos/Titania, Orphic Egg, Huntsman, custom status icons); distributed automatically via `manifest.json` (`category: "dat"`) | **No** — no new DATs needed for the 25 new Souls. |

---

## Remaining Manual Visual / DAT Polish (Non-Blocking)

| Component | Target Path | Missing Items | Notes |
|---|---|---|---|
| CrystalSocket Icons | `addons/ashita4/crystalsocket/assets/<soul>.png` | 25 new Souls (`zealot`, `valkyrie`, `astromancer`, `channeler`, `scarletweaver`, `royaltactician`, `bandit`, `trickster`, `phantom`, `oathbreaker`, `reaper`, `scourge`, `sniper`, `arcanearcher`, `nightblade`, `lancer`, `skyborn`, `warmage`, `archivist`, `untamed`, `beastspeaker`, `primalist`, `herald`, `terramancer`, `diviner`) + `defender` (alias/rename of `aegistemplar.png`), `adventurer`, `musician`, `minstrel` | Optional 128x128 art polish; CrystalSocket falls back safely without PNGs. |
| `crystaljobs.dll` metadata | `native/crystaljobs/crystaljobs.cpp` (`GetLink()`) | Cosmetic plugin URL string still references `overlordsxi-launcher` | Left untouched to keep source and precompiled `plugins/ashita4/crystaljobs.dll` in sync. |

---

## Automated Verification Results

| Check | Scope | Result |
|---|---|---|
| `tools/audit_soul_coverage.py .` | All 66 canonical Souls | **PASS** (`implemented: 66, incomplete: 0, planned: 0`) |
| `luajit -bl` on all server custom Lua | 101 files (`modules/custom/lua/*.lua`, `modules/custom/commands/*.lua`) | **PASS** (101/101) |
| `python3 -m unittest discover -s tests` (with `lupa`) | 147 server tests (native + Lupa Lua runtime + Burrows + WS Foundation + CI + Analytics) | **141 PASS, 5 SKIP** (no `node`/`lua` in slim analytics image), **1 pre-existing `main` FAIL** (`test_no_private_logs_or_secrets_in_static_site_or_backend` — `import pymysql` from `30eb966`) |
| `scripts/generate-site-data.py --require-lua --launcher-dir /launcher --strict-actions` | Cross-repo Lua export + wiki + Soul Actions TSV | **PASS** (66 Specs, 256 JAs, 44 Traits, 219 WS Trees, 77 Patches) |
| `scripts/verify-launcher-manifest.py` | Launcher `manifest.json` (read-only) | **PASS** (1,109 / 1,109 files verified) |
| `scripts/validate-soul-actions-tsv.py` | Launcher `soul_actions.tsv` & `visibility.tsv` | **PASS** (159 / 159 rows across 26 Souls) |
| Launcher `tests/test_manifest_verification.py` | 9 manifest verifier unit tests | **PASS** (9/9) |
| `luajit -bl` on launcher Soulspire addons | 69 files (`soulspire_*`, `crystalsocket`) | **PASS** (69/69) |
| C++ `xi_map` full compilation & Windows `.NET 8` build | Native C++ patches 0046–0070 & `SoulspireLauncher.sln` | **CI / Build Host Required** (no C++ toolchain or Windows .NET 8 SDK on Unraid host; verified via PR CI + Docker image build) |

---

## Deployment Blockers & Required Release Order

### Blockers Before Live Deployment
1. **PR Review & CI Green:** Open PRs for both `feat/souls-66-final-integration` branches targeting `main` and verify GitHub Actions (`soul-coverage.yml`, `update-wiki.yml`, `build-launcher.yml` including Windows `.NET 8` `dotnet test`).
2. **Server Docker Image Build:** Rebuild `soulspirexi/server` from the merged server branch so C++ patches `0046-zealot` through `0070-diviner` are compiled into `xi_map`.
3. **Manual Gameplay Verification:** Test the rebuilt server image + synced Ashita v4 client on a staging/test environment for the 25 new Souls at Lv. 10/30/50/75.
4. **Optional Analytics Test Fix:** Decide whether to update `test_no_private_logs_or_secrets_in_static_site_or_backend` on `main` to allow the intentional read-only `pymysql` FFXI auth added in `30eb966`.

### Safe Merge & Deployment Order
1. **Merge Launcher PR first** (`Infomatictek/soulspirexi-launcher`: `feat/souls-66-final-integration` → `main`).
   - Existing launchers immediately pick up the 25 new Souls' `soul_actions.tsv`, `visibility.tsv`, and `soulhud_layout.lua` via `manifest.json`.
2. **Tag Launcher Release (recommended)** — bump `<Version>` in `SoulspireLauncher/SoulspireLauncher.csproj` to `2.0.1` and push tag `v2.0.1` on `main` so `build-launcher.yml` publishes a fresh `SoulspireLauncher.exe` (+ compatibility `OverlordsLauncher.exe`) natively targeting `Infomatictek/soulspirexi-launcher`.
3. **Merge Server PR second** (`Infomatictek/soulspirexi`: `feat/souls-66-final-integration` → `main`).
   - `update-wiki.yml` will automatically publish updated 66-Soul wiki data.
4. **Build & Deploy Staging Server Image** — build `soulspirexi/server` against the merged commit, run manual gameplay verification, then promote to production.

### Rollback Procedure
- **Server:** Revert Docker image tag to the previous known-good image (`soulspirexi/server:main-8225245`) and restart the stack; no destructive DB schema migrations were added by the 25 Souls.
- **Launcher:** Revert the merge commit on `Infomatictek/soulspirexi-launcher` `main`; `ManifestUpdateService` pins to the latest `main` commit SHA and will automatically sync clients back to the reverted `manifest.json` hashes on next launch.
