# SoulspireXI — 66-Soul Staging Deployment & Playability Validation Report

## Tested Revisions & Fix Branch

- **Server `main` Baseline:** `3518148929b034a2e0a0d25963e369969880d48a` (wiki refresh atop merge `61315036968d629988c54c51b7de3fab9635eb2b`)
- **Server Staging-Fix Branch:** `fix/staging-bst-untamed-load` (0 behind `origin/main`)
  - `1d38610` — `fix(bst): remove nonexistent scripts/globals/utils require in bst_untamed_specs` (+ regression test)
  - `887cb18` — `fix(blu): resolve Warmage crystal id collision and blu_specs reload wipe` (+ regression test)
  - `7fee842` — `fix(bst): guard undefined DMG_DEALT mods in Alpha Warden and apply supported pet offense penalties` (+ `tests/test_bst_alphawarden.py`)
  - `63469ef` — `fix(tests): use cross-platform ENOTDIR blocker file in Proving Grounds write-failure test`
  - `742a18c` — `fix(tests): repair Kurogane xi_test helpers and add 66-Soul real-engine smoke suite` (`patches/0071-kurogane-xi-test-helpers.patch`, `tests/lua/souls_66_smoke.lua`)
- **Staging Docker Image Built & Running:** `soulspirexi/server:staging-66souls-742a18c`
- **Launcher `main` Tested:** `2ad0865031640a56e525257e49c84f09cf7def21`
- **Production Safety:** **100% Untouched.** All 8 production containers (`soulspirexi-{mariadb,world,connect,search,profile,map,combat-analytics}`, `soulspire-parser`), production database (`xidb` on `127.0.0.1:3306`), and `/mnt/user/appdata/soulspirexi` remained untouched throughout.

---

## Native Build Status

- **Base Revision:** LandSandBoat `091e7409d1c9d702f366dc374115f939393c46ab`
- **Engine Patches:** All **78 patches** (77 baseline + `0071-kurogane-xi-test-helpers.patch`) applied cleanly in 2.3s with zero conflicts.
- **Compiled Binaries (`soulspirexi/server:staging-66souls-742a18c`):**
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
| Cross-repo Lua wiki validation (`--require-lua --strict-actions`) | **PASS** | `66 Crystal Specs (256 Custom JAs, 44 Traits), 219 Weaponskill Trees, 78 Engine Patches` |
| Server Python + Lupa full suite (`unittest discover`) | **PASS** | `151` tests (`0` failures; `5` skipped in slim container without `node`/`lua`) |
| Frontend JS syntax + Node UI tests | **PASS** | `8 / 8` tests passing (`node --check` + `node --test tests/test_combat_reports_ui.mjs`) |
| `xi_test` Real-Engine 66-Soul Smoke (`tests/lua/souls_66_smoke.lua`) | **PASS (66 / 66)** | All **66 / 66** Souls loaded; **264 / 264** Lv. 10/30/50/75 activations + HUD sync passed with zero Lua exceptions |
| `xi_test` Proving Grounds Combat (`tests/lua/proving_grounds_combat.lua`) | **PASS (7 / 7)** | Arbiter placement, Lv. 75→10 Level Sync, +0/+3/+5/+8 Normal/NM bosses, Shinobi clone/pet sync, 30s prep isolation + 1s snapshots + feedback, cross-platform unwritable-path rejection, and multi-participant AoE correlation all **PASS** |
| `xi_test` Kurogane (`scripts/tests/custom/kurogane.lua`) | **PASS (5 / 5)** | Canonical NIN crystal IDs, 8-slot `0x00E` spawn + subsequent update preservation, lockstyle + hidden-head `0x00E` encoding, 5-clone cap + disengage cleanup, and failed-replacement preservation all **PASS** |

---

## Verified Defects Found & Resolved During Staging Validation

1. **FIXED (`1d38610`) — `BST:untamed` failed to load on `xi_map`:**
   - **Root Cause:** `modules/custom/lua/bst_untamed_specs.lua:5` called `require('scripts/globals/utils')`, which does not exist in LandSandBoat (`utils` is already a global).
   - **Fix:** Removed the nonexistent `require` and added a regression test in `tests/test_bst_untamed.py`. Verified `=== Module: soulspire_bst_untamed ===` loads cleanly on `soulspirexi-staging-map`.
2. **FIXED (`887cb18`) — `BLU:warmage` vanished from `xi.soulspire.spec.jobs[xi.job.BLU]` at runtime:**
   - **Root Cause:** (a) `blu_warmage_specs.lua:206` registered `id = 1`, colliding with `blu_specs.lua:600` (`azurebastion`, `id = 1`); (b) `blu_healer_specs.lua:7` unconditionally called `require('modules/custom/lua/blu_specs')` after `blu_warmage_specs.lua`, re-running `spec.registerJob(xi.job.BLU, ...)` and wiping out `warmage`.
   - **Fix:** Updated Warmage to `id = 3`, guarded `blu_specs` require in `blu_healer_specs.lua`, and added a regression test in `tests/test_blu_warmage.py`.
3. **FIXED (`7fee842`) — `BST:alphawarden` Lv. 10 pet mod crash (`bst_specs.lua:377-379`):**
   - **Root Cause:** `xi.mod.PHYS_DMG_DEALT`, `RANGED_DMG_DEALT`, and `MAG_DMG_DEALT` do not exist in pinned LandSandBoat (`091e7409`, `/server/scripts/enum/mod.codegen.lua`). Passing `nil` to `pet:addMod` threw a type error on guardian beast spawn.
   - **Fix:** Guarded `*_DMG_DEALT` enums in `syncAlphaWardenPet` and `mods`, and applied supported LandSandBoat pet outgoing-offense penalty modifiers (`ATTP = -60`, `ALL_WSDMG_ALL_HITS = -60`, `RATTP = -60`, `MATT = -60`) when `*_DMG_DEALT` is absent — preserving Alpha Warden's `-60%` pet-tank offensive tradeoff and defensive mods without affecting other BST Souls. Added `tests/test_bst_alphawarden.py`.
4. **FIXED (`63469ef`) — Proving Grounds write-failure negative test failed on Linux/Docker:**
   - **Root Cause:** `tests/lua/proving_grounds_combat.lua:461-462` used Windows-invalid characters (`<invalid:path>`), which are valid POSIX filenames on Linux.
   - **Fix:** Replaced with a cross-platform `ENOTDIR` blocker file (creating a regular file and targeting a nested path beneath it), verifying `logging_status.ok == false`, `partial_recording == true`, and `#errors >= 1` on both Linux and Windows.
5. **FIXED (`742a18c`) — Kurogane `xi_test` helper failures (`patches/0071-kurogane-xi-test-helpers.patch`):**
   - **Root Cause:** `kurogane.lua` called nonexistent `cloneA:updateEntity()` and sent raw `0x053` `Mode=3, Count=0` on a player with no equipped items.
   - **Fix:** Used supported `xi_test` interfaces (`setMaxHP(2); setHP(1); xi.test.world:skipTime(1)` for subsequent `0x00E` packet generation, and equipped `BRONZE_HARNESS` + `player.actions:setLockstyle(3, ...)` for lockstyle + hidden-head `0x00E` verification) with zero production Kurogane changes.
6. **OPEN (Non-Soul Warning) — Burrows Reborn instance script cache warning:**
   - `map-server.log` logs `No returned object to cache: ./scripts/zones/Ghoyus_Reverie/instances/the_first_descent.lua` (pre-existing `main` Burrows warning, non-blocking for 66 Souls).

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
| BST:alphawarden | PASS | PASS | PASS | PASS | MANUAL | **Fixed (`7fee842`)**: guarded `*_DMG_DEALT` + applied supported `-60` pet offense penalties |
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

1. **Review & Merge Staging Fix PR (`fix/staging-bst-untamed-load` → `main`):** Required so `BST:untamed`, `BLU:warmage`, `BST:alphawarden`, `Proving Grounds`, and `Kurogane` fixes are merged into `main` and GitHub Actions CI passes.
2. **Live Ashita v4 Client & Interactive Gameplay Verification (Manual):** Automated engine validation confirms all 66 Souls load and activate cleanly across Lv. 10/30/50/75, but **does not substitute for real gameplay**. Connect a Windows Ashita v4 test client to staging and verify native Soul action menus, descriptions, recasts, macros, HUDs, and interactive Proving Grounds encounters across Lv. 10 (0 talent points), 30, 50, and 75.
3. **Optional Launcher `.exe` Release:** Tag `v2.0.1` on `Infomatictek/soulspirexi-launcher` `main` (after bumping `<Version>` in `SoulspireLauncher.csproj`) to publish a native `soulspirexi-launcher` binary.
