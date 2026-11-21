# SoulspireXI — Weapon Skill Talent Foundation Progress (Pass 2.0 + Pass 2.1 Live Combat Validation)

**Branch:** `feat/ws-talent-foundation-v2` (branched from `origin/main` @ `30d1fad`, NOT merged to `main`)  
**Schema Version:** `2.0.0`  
**Status:** **PASS 2.1 LIVE COMBAT VALIDATION & REPAIR COMPLETE**

---

## 1. Before / After Summary (Pass 2.1)

| Metric | Pass 2.0 Baseline (`89a138a`) | Pass 2.1 Final |
|---|---:|---:|
| Eligible Soul × WS combinations | 1,476 | **1,476** (66/66 Souls verified) |
| Compiled contracts | 23,427 | **23,427** |
| Structural PASS | 23,427 (14 cross-branch dup warnings) | **23,427** (0 defects) |
| Runtime handler PASS (unique taxonomy types) | 0 live-verified / 22 static | **22 / 22 live `xi_test` verified** |
| Live combat PASS (contracts) | 0 verified | **211 PASS** (66/66 Souls × D/U/S + 32/32 Lv10/30/50/75 + Evo + Adv Handlers) |
| Live combat FAIL | 0 (untested) | **0** |
| Live combat BLOCKED | 0 (untested) | **0** |
| Live combat NOT EXERCISED | 23,427 | **23,216** (explicitly tracked) |
| Redundant / invalid cross-branch talents | 14 | **0** |
| Confirmed defects repaired | 0 | **6** |

---

## 2. Confirmed Defects Repaired in Pass 2.1

1. **Server Double-Load Bug Breaking Combo (`#1`) Evolution (`soulspire_ws_talents.lua`):** Because `soulspire_ws_talents.lua` is loaded via `init.txt` (`dofile`) and also `require()`d by `soulspire_ws_overrides.lua`, it executed twice on real server boot, wiping `CUSTOM_TREES` while `package.loaded['modules/custom/lua/soulspire_ws_evolution']` skipped re-registering Combo `#1`. Fixed with an idempotent `talents._initialized` guard.
2. **Cross-Branch Single-Effect Duplication (`soulspire_ws_spec_profiles.lua`):** 14 cross-branch pairs collapsed to identical single-effect signatures after role/magic sanitization. Fixed via a shared Branch Differentiation Normalizer (`14 -> 0`).
3. **Incomplete Soul-Hook Contract Extraction (`soulspire_ws_talent_contracts.lua`):** Added contract extraction for `tp_refund`, `mp_siphon`, `party_pulse`, `next_ws_prime`, `enmity_surge`, `debuff_extend`, and `stance_empower`.
4. **Missing Cleanse Effect Extraction (`soulspire_ws_talent_contracts.lua`):** Added `cleanseSelf` / `cleanseParty` extraction into `status_apply`.
5. **Empty Post-WS Telemetry Payloads (`soulspire_ws_telemetry.lua`):** Populated real `applied_effects` payloads in `applySoulHookPostWS` for `party_pulse`, `pet_tp_heal`, `next_ws_prime`, `enmity_surge`, `debuff_extend`, and `stance_empower`.
6. **Spellblade Conduction Telemetry Gap (`soulspire_ws_telemetry.lua`):** Caught by live `xi_test` + Autoparser (`ws:48:spellblade:spb_t1c3`); wired `hook.conductionAdd` into `applied.soul_resource` (`OX_CONDUCTION`).

---

## 3. Verification Evidence & Snapshots

- **Baseline Structural Audit:** `docs/talents/ws_talent_v21_baseline_audit.json`
- **Post-Repair Structural Audit:** `docs/talents/ws_talent_v21_post_audit.json` (`23,427 PASS / 0 FAIL / 0 defects`)
- **Live `xi_test` Combat Evidence:** `docs/talents/ws_talent_v21_live_evidence.json` (real LandSandBoat C++ MapEngine against isolated staging DB `xidb_staging`; `66/66 Souls` × Damage/Utility/Soul, `32/32` Lv 10/30/50/75 checks, `22/22` unique effect handlers, `0` failures)
- **Permanent Coverage Matrix:** `docs/talents/WS_TALENT_COVERAGE_MATRIX.md` & `docs/talents/ws_talent_coverage_matrix.json`
- **Live `xi_test` Suite:** `tests/lua/ws_talent_live_xi_test.lua` (`[  PASSED  ] 1 test.` in ~29s)
- **LuaJIT Runtime Suite:** `tests/lua/ws_talent_foundation_v2.lua` (`8 / 8 PASS`)
- **Repo Python Suites:** `tests/test_ws_foundation.py` + `tests/test_ws_talent_foundation_v2.py` (`9 / 9 PASS`)
- **Autoparser Suite:** `parser-src/tests/test_ws_talent_autoparser.py` (`5 / 5 PASS`)

---

## 4. Remaining Untested Mechanics & Known Risks (Non-Blocking for Merge)

- **Exhaustive Per-WS Live Coverage:** `211` representative contracts (covering all `66/66` Souls, all 3 branches, all `22/22` unique effect handlers, Evolution `#1`/`#47`, and Lv 10/30/50/75) are live `xi_test`-verified; the remaining `23,216` contracts are structurally verified (`23,427/23,427`) and explicitly tracked as `NOT EXERCISED` in live combat.
- **Pre-Existing Unrelated Bug Observed in Logs:** `modules/custom/lua/war_specs.lua:420` logs `attempt to call method 'getBattleTarget' (a nil value)` during Spartan's Sense tick (outside WS talent scope; did not block Spartan WS execution).
- **Numerical Balance:** Deferred to owner balance pass (post-foundation).
