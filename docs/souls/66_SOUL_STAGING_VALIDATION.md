# SoulspireXI — 66-Soul Staging Deployment & Playability Validation Report

## Tested Revisions & Fix Branch

- **Server `main` Baseline:** `3518148929b034a2e0a0d25963e369969880d48a` (wiki refresh atop merge `61315036968d629988c54c51b7de3fab9635eb2b`)
- **Server Staging-Fix Branch:** `fix/staging-bst-untamed-load` @ `887cb1862cee4f9cc52e9e7ac95478267897df45`
  - `1d38610` — `fix(bst): remove nonexistent scripts/globals/utils require in bst_untamed_specs` (+ regression test)
  - `887cb18` — `fix(blu): resolve Warmage crystal id collision and blu_specs reload wipe` (+ regression test)
- **Launcher `main` Tested:** `2ad0865031640a56e525257e49c84f09cf7def21`
- **Production Safety:** **100% Untouched.** All 8 production containers (`soulspirexi-{mariadb,world,connect,search,profile,map,combat-analytics}`, `soulspire-parser`), production database (`xidb` on `127.0.0.1:3306`), and `/mnt/user/appdata/soulspirexi` remained untouched throughout.

---

## Native Build Status

- **Base Revision:** LandSandBoat `091e7409d1c9d702f366dc374115f939393c46ab`
- **Engine Patches:** All **77 patches** (including `0046-burrows-reborn-first-descent-instance.patch` and `0046-zealot-native-actions.patch`..`0070-diviner-native-actions.patch`) applied cleanly in 2.3s with zero conflicts.
- **Compiled Binaries (`soulspirexi/server:staging-66souls-3518148`):**
  - `xi_connect` — **PASS**
  - `xi_world` — **PASS**
  - `xi_search` — **PASS**
  - `xi_profile` — **PASS**
  - `xi_map` — **PASS**
  - `xi_test` — **PASS**
- **Custom C++ Modules:** `ah_announcement.cpp`, `ah_pagination.cpp`, `eos_companion.cpp`, `kazenoeye_sync.cpp`, `soulspire_soul_action_peers.cpp`, `soulspire_soulhud_sync.cpp` — compiled & linked cleanly with zero missing symbols.

---

## Isolated Unraid Staging Environment

- **Compose Stack:** `/mnt/user/appdata/soulspirexi-staging/docker-compose.staging.yml` (project `soulspirexi-staging`)
- **Network Isolation:** Dedicated bridge network `soulspire_staging_net` (NO `network_mode: host`, NO public ports, NO collision with production ports `3306/54001/54002/54003/54230/54231/51220/51240`).
- **Database Isolation:** Dedicated `soulspirexi-staging-mariadb` (`127.0.0.1:13306`, DB `xidb_staging`, staging-only credentials, 119 base LandSandBoat SQL files + 31 custom SQL modules imported).
- **Storage Isolation:** `/mnt/user/appdata/soulspirexi-staging/{mariadb,config/settings,config/certs,logs}` (only static navmeshes/ximeshes mounted read-only).
- **Container Health:** All **6 / 6** staging containers (`soulspirexi-staging-{mariadb,world,connect,search,profile,map}`) booted and reported **`healthy`**. `xi_map` initialized in 12.30s with zero startup crashes and zero Soul module load errors after the `bst_untamed_specs.lua` fix.

---

## Launcher & Ashita Delivery Verification

- **Manifest Source:** Confirmed `Infomatictek/soulspirexi-launcher` (`2ad0865031640a56e525257e49c84f09cf7def21`), and confirmed legacy `Infomatictek/overlordsxi-launcher` API redirect resolves to the exact same commit SHA.
- **Manifest Verification:** **PASS** — `1,109 / 1,109` entries verified (`verify-launcher-manifest.py`, `9 / 9` unit tests).
- **Soul Actions & Visibility TSVs:** **PASS** — `159 / 159` rows across 26 Souls validated (`validate-soul-actions-tsv.py`, 0 duplicates).
- **Soul HUD Layouts:** **PASS** — `66 / 66` canonical Souls present in `addons/ashita4/soulspire_soulhud/soulhud_layout.lua`.
- **Clean-Client HTTP Download Test:** **PASS** — Downloaded and SHA-256 verified 10 critical payload files (`soul_actions.tsv`, `visibility.tsv`, `soulspire_soul_actions.lua`, `soulhud_layout.lua`, `soulspire_soulhud.lua`, `soulspire_gear/og/state.lua`, `crystalsocket.lua`, `crystaljobs.dll`, `ROM/181/72.DAT`, `ROM/181/74.DAT`) directly from `raw.githubusercontent.com/Infomatictek/soulspirexi-launcher/<sha>/` into a clean Ashita layout.
- **Missing Optional Client Art (Non-Blocking):** 29 Souls lack dedicated 128x128 PNG icons in `addons/ashita4/crystalsocket/assets/` (the 25 newly integrated Souls + `defender`, `adventurer`, `musician`, `minstrel`); CrystalSocket falls back safely.
- **Manual Ashita Client Testing Required:** Live Windows Ashita v4 client inspection of native ability/magic menus, action descriptions, recast timers, macro execution, and nearby-player presentation.

---

## Automated Verification & Staging Combat Results

| Suite | Result | Details |
|---|---|---|
| `tools/audit_soul_coverage.py .` | **PASS** | `implemented: 66, incomplete: 0, planned: 0` (`DNC:freelancer` excluded) |
| Server Python + Lupa full suite (`unittest discover`) | **PASS** | `147` tests (`0` failures; `5` skipped in slim container without `node`/`lua`) |
| Frontend JS syntax + Node UI tests | **PASS** | `8 / 8` tests passing (`node --check` + `node --test tests/test_combat_reports_ui.mjs`) |
| `xi_test` Real-Engine 66-Soul Smoke (`souls_66_smoke.lua`) | **65 / 66 PASS, 1 FAIL** | All **66** Souls load after fixes (`BST:untamed` & `BLU:warmage`); `263 / 264` Lv. 10/30/50/75 activations + HUD sync passed; **1 defect found** on `BST:alphawarden` at Lv. 10 |
| `xi_test` Proving Grounds Combat (`proving_grounds_combat.lua`) | **5 / 6 PASS** | Arbiter placement, Lv. 75→10 Level Sync, +0/+3/+5/+8 Normal/NM bosses, Shinobi clone/pet sync, 30s prep isolation + 1s snapshots + feedback all **PASS**; 1 path-unwritable negative test failed due to container permissions |
| `xi_test` Kurogane (`kurogane.lua`) | **1 / 2 PASS** | Canonical NIN crystal IDs **PASS**; `0x00E` test failed on `updateEntity` nil method in `xi_test` Lua helper |

---

## Verified Defects Found During Staging Validation

1. **FIXED (`1d38610`) — `BST:untamed` failed to load on `xi_map`:**
   - **Root Cause:** `modules/custom/lua/bst_untamed_specs.lua:5` called `require('scripts/globals/utils')`, which does not exist in LandSandBoat (`utils` is already a global).
   - **Fix:** Removed the nonexistent `require` and added a regression test in `tests/test_bst_untamed.py`. Verified `=== Module: soulspire_bst_untamed ===` loads cleanly on `soulspirexi-staging-map`.
   - **Rebuild Required:** Yes (staging server image rebuilt and verified).
2. **FIXED (`887cb18`) — `BLU:warmage` vanished from `xi.soulspire.spec.jobs[xi.job.BLU]` at runtime:**
   - **Root Cause:** (a) `blu_warmage_specs.lua:206` registered `id = 1`, colliding with `blu_specs.lua:600` (`azurebastion`, `id = 1`); (b) `blu_healer_specs.lua:7` unconditionally called `require('modules/custom/lua/blu_specs')` after `blu_warmage_specs.lua`, re-running `spec.registerJob(xi.job.BLU, ...)` and wiping out `warmage`.
   - **Fix:** Updated Warmage to `id = 3`, guarded `blu_specs` require in `blu_healer_specs.lua`, and added a regression test in `tests/test_blu_warmage.py`. Verified all 3 BLU Souls (`azurebastion`, `magus`, `warmage`) load and activate across Lv. 10/30/50/75 in `xi_test`.
   - **Rebuild Required:** Yes (staging image should be rebuilt from `887cb18` before live staging playtesting).
3. **OPEN (Baseline Defect) — `BST:alphawarden` Lv. 10 pet mod crash (`bst_specs.lua:377-379`):**
   - **Symptom:** Activating `BST:alphawarden` at Lv. 10 in `xi_test` throws `stack index 2, expected number, received nil: not a numeric type` in `pet:addMod(entry[1], entry[2])`.
   - **Root Cause:** `syncAlphaWardenPet` passes `xi.mod.PHYS_DMG_DEALT` / `RANGED_DMG_DEALT` / `MAG_DMG_DEALT` where at least one enum is `nil` in this LandSandBoat revision.
   - **Action:** Documented without silently altering Alpha Warden balance mechanics; requires confirming the intended LandSandBoat `xi.mod` enum before patching.
4. **OPEN (Non-Soul Warning) — Burrows Reborn instance script cache warning:**
   - `map-server.log` logs `No returned object to cache: ./scripts/zones/Ghoyus_Reverie/instances/the_first_descent.lua` (pre-existing `main` Burrows warning).

---

## 66-Soul Staging Status Table

*Legend: `PASS` = real `xi_test` engine activation/refresh/HUD smoke test passed; `FAIL` = reproducible defect; `MANUAL` = requires live Windows Ashita v4 client / interactive combat testing.*

| Soul | Lv. 10 | Lv. 30 | Lv. 50 | Lv. 75 | Client | Notes |
|---|---|---|---|---|---|---|
| WAR:commander | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live combat/client manual |
| WAR:berserker | PASS | PASS | PASS | PASS | MANUAL | Engine smoke + PG Lv75→10 sync OK |
| WAR:spartan | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live tank enmity manual |
| MNK:sensei | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live tank enmity manual |
| MNK:chiweaver | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live healer sustain manual |
| MNK:blackbelt | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live combat manual |
| WHM:bishop | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live healer sustain manual |
| WHM:zealot | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| WHM:valkyrie | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| BLM:astromancer | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| BLM:channeler | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| BLM:necromancer | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live pet tank manual |
| RDM:crimsonduelist | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live combat manual |
| RDM:royaltactician | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| RDM:scarletweaver | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| THF:bandit | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| THF:trickster | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| THF:phantom | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; live tank enmity manual |
| PLD:templar | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live combat manual |
| PLD:defender | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK (legacy `aegistemplar` key); live tank manual |
| PLD:oathbreaker | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| DRK:reaper | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| DRK:dreadnought | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live tank manual |
| DRK:scourge | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| BST:alphawarden | FAIL | PASS | PASS | PASS | MANUAL | **Defect:** `bst_specs.lua:377-379` `nil` `xi.mod` on Lv10 pet spawn |
| BST:untamed | PASS | PASS | PASS | PASS | MANUAL | **Fixed (`1d38610`)**: removed bad `scripts/globals/utils` require |
| BST:beastspeaker | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| BRD:adventurer | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live combat manual |
| BRD:musician | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live healer/support manual |
| BRD:minstrel | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live support manual |
| RNG:sniper | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| RNG:huntsman | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live melee/ranged manual |
| RNG:arcanearcher | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| SAM:ronin | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live tank manual |
| SAM:imperialarcher | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live ranged manual |
| SAM:warlord | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live combat manual |
| NIN:kurogane | PASS | PASS | PASS | PASS | MANUAL | Engine smoke + PG clone Lv10 sync OK (Shinobi) |
| NIN:kagemusha | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live tank manual |
| NIN:nightblade | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| DRG:lancer | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| DRG:skyborn | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; live tank enmity manual |
| DRG:wyvernheart | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live pet healer manual |
| SMN:primalist | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| SMN:celestial | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live healer manual |
| SMN:herald | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| BLU:azurebastion | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live tank manual |
| BLU:magus | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK (`blu_healer_specs.lua` reload guard fixed) |
| BLU:warmage | PASS | PASS | PASS | PASS | MANUAL | **Fixed (`887cb18`)**: `id=3` + `blu_specs` reload guard |
| COR:flintlock | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live ranged manual |
| COR:gambler | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live support manual |
| COR:buccaneer | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live combat manual |
| PUP:vanguard | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live tank manual |
| PUP:animist | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live healer manual |
| PUP:pugilist | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live combat manual |
| DNC:vampire | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live healer manual |
| DNC:bladewheel | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live combat manual |
| DNC:miragesentinel | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live tank manual |
| SCH:medic | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; Eos DATs verified |
| SCH:sage | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; Titania DATs verified |
| SCH:archivist | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| GEO:diviner | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| GEO:verdant | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live healer manual |
| GEO:terramancer | PASS | PASS | PASS | PASS | MANUAL | New 25: Lupa + engine smoke OK; native actions TSV verified |
| RUN:spellblade | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live combat manual |
| RUN:lifebinder | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live healer manual |
| RUN:inquisitor | PASS | PASS | PASS | PASS | MANUAL | Engine smoke OK; live tank manual |

---

## Remaining Release Blockers

1. **Merge Staging Fix PR (`fix/staging-bst-untamed-load` → `main`):** Required so `BST:untamed` loads on `xi_map` and `BLU:warmage` is not wiped out by `blu_healer_specs.lua`.
2. **Fix `BST:alphawarden` Lv. 10 pet mod enum (`bst_specs.lua:377-379`):** Confirm intended LandSandBoat `xi.mod` constant for Alpha Warden guardian beast damage scaling.
3. **Live Ashita v4 Client & Interactive Gameplay Verification:** Connect a Windows Ashita v4 test client to staging and verify native Soul action menus, descriptions, recasts, macros, HUDs, and Proving Grounds encounters across Lv. 10 (0 talent points), 30, 50, and 75.
4. **Optional Launcher `.exe` Release:** Tag `v2.0.1` on `Infomatictek/soulspirexi-launcher` `main` (after bumping `<Version>` in `SoulspireLauncher.csproj`) to publish a native `soulspirexi-launcher` binary.
