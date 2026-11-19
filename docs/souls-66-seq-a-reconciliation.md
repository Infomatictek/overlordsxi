# Issue #20 · Sequence A Head Reconciliation & Compatibility Record

## 1. Source & Staging Head Reconciliation

| Repository / Branch | Recorded in `docs/souls-66` | Current Head at Sequence A Start | Reconciliation Notes |
|---|---|---|---|
| `Infomatictek/overlordsxi` (`main`) | `c34cd4f` | `c34cd4f` | Identical. Already contains `999dc6d` (`overlords_soul_actions.lua`) and `4a57be5` (`docs/soul-action-system.md`). |
| `Infomatictek/overlordsxi` (staged THF/BST/RNG) | `feature/thf-souls-first-pass`, `feature/bst-untamed-feral-sync`, `feature/huntsman-melee-overhaul` | Unchanged on remote | Preserved intact for Sequences B and F. |
| `Infomatictek/overlordsxi-launcher` (`main`) | `d386532` (initial) / `4f6b4dc` (recheck) | `a12a4a6` (+9 commits) | Preserved all 9 post-audit commits (`4aace66..a12a4a6`: Crystal Socket HUD-to-native label fallback, diagnostics, v1.1.3 release/manifest sync). |

## 2. Sequence A Implementation Summary

- **Feature branches**: `feat/souls-66-seq-a-compat` branched from `origin/main` in both `Infomatictek/overlordsxi` and `Infomatictek/overlordsxi-launcher`. `main` was not modified, merged, deployed, or restarted.
- **Launcher (`overlordsxi-launcher`)**:
  - Added single explicit 22 × 3 active Soul + retired DNC slot 1 mapping in `addons/ashita4/overlords_soul_actions/soul_identity_map.lua`.
  - Updated `soul_packet.lua` and `soul_bridge.lua` to share `soul_identity_map.lua`, fixing BST 2 (`alphawarden`), PUP 2/3 (`animist`/`pugilist`), DNC 2/3/4 (`vampire`/`bladewheel`/`miragesentinel`), and ensuring retired DNC 1 (`freelancer`) never remaps to `miragesentinel`.
  - Updated `overlords_soul_actions.lua` so verified `0x1FC` HUD packets take precedence when fresh for the active job, with Crystal Jobs DLL fallback when absent/stale and clean reset on zone/logout/job/character change.
  - Updated `addons/ashita4/crystalsocket/soul_identity.lua` to accept server storage-key aliases (`alphawarden`, `aegistemplar`, `gladiator`, `marionettist`, `caller`) and reject retired `freelancer`.
  - Updated `manifest.json` via `scripts/update-launcher-manifest.py` and verified read-only via `scripts/verify-launcher-manifest.py`.
- **Server (`overlordsxi`)**:
  - Extended `modules/custom/lua/overlords_soul_actions.lua` with the canonical 22 × 3 active Soul identity table, retired DNC slot 1 persistence handling, alias normalization, structured compatibility snapshots (`buildSnapshot`), and opt-in WARN-mode action observation (`setObservationMode('warn')`, `observe(ctx)`).
  - No global strict switch, no numeric renumbering, no live combat or SQL changes.
  - Added `tests/test_soul_compatibility_fixtures.py` covering all 66 active Souls, retired DNC 1 persistence, level-255 SQL ability uniqueness, cross-repo server/launcher map parity, and normal/RNG/PUP/DNC/NIN WARN-mode observation without outcome changes.

## 3. Remaining Live / Field Validation (Deferred to Host Window)

- Live Ashita v4 client session test with installed `crystaljobs.dll` binary verifying native job/search labels for BST 2, PUP 2/3, and DNC 4 (note: `native/crystaljobs/labels.h` still carries legacy native labels until a coordinated DLL rebuild).
- Live DB snapshot against production `char_vars` (`OX_SPEC_<JOB>`) for any legacy characters still holding `OX_SPEC_DNC = 1`.
- In-game Lv10 and Lv75 combat/sync/relog acceptance tests per cohort (Sequences B–G).
