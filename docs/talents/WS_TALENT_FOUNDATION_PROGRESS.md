# SoulspireXI — Weapon Skill Talent Foundation Pass 2.0 Progress

**Branch:** `feat/ws-talent-foundation-v2` (branched from `origin/main` @ `30d1fad`)  
**Schema Version:** `2.0.0`  
**Status:** **FOUNDATION PASS COMPLETE** (all 5 checkpoints committed & pushed)

---

## 1. Phase 1 — Architecture Audit Summary

- **Tree Structure:** Three branches (`Col 1 = Damage`, `Col 2 = Utility`, `Col 3 = Soul`) × 4 Tiers (`T1..T4`), plus optional Skillchain Augment (`Col 4`). `EVOLUTION_WS` (`#1 Combo`, `#47 Sanguine Blade`) preserved with versioned storage.
- **Point Economy:** `3` pts/level (`225` at Lv 75), `56` max pts/WS (`4` mastered WSs).
- **WS Catalog:** `219` weapon skills across `15` weapon families (`modules/custom/lua/soulspire_ws_catalog.lua`), including custom Chakram Throwing WSs (`#241-#252`).
- **Role Tiers:** 6-tier system in `soulspire_job_specs.lua` (`Damage`, `HybridSupport`, `Support`, `CombatHealer`, `Healer`, `Tank`).

### Gaps Resolved in Pass 2.0
1. **Full 66-Soul Coverage:** Expanded `P.ALL_SPECS`, `SPEC_KEY_TO_CATEGORY`, and `soulspire_ws_soul_mechanics.lua` from 34 partial specs to all **66 canonical Souls** with real, grounded Soul-branch hooks (zero invented resources).
2. **Strict Soul Weapon Eligibility:** Replaced broad base-job proficiency tables (`WAR_OPEN_SKILLS`, `RUN_OPEN_SKILLS`, `SCH_OPEN_SKILLS`, Sword leaking onto Bladewheel) with the explicit 66-Soul manifest (`ws_eligibility_manifest.json` + `soulspire_ws_eligibility.lua`).
3. **Runtime, UI & Migration Enforcement:** `getTreeForWS`, `canInvest`, and `sendCatalogSync` now strictly enforce Soul weapon eligibility; `reconcileIneligibleAllocations` provides safe, deterministic refund/migration for legacy incompatible allocations while preserving eligible investments.
4. **Sanguine Blade (`#47`) Role Fix:** Restricted `e_sg_control` (`hpDrain`) to `{ vampire, lifebinder, defender, aegistemplar, templar }` so Tier-1 pure DPS RDM (`scarletweaver`) cannot bypass pure-DPS sustain guardrails.
5. **Machine-Readable Contracts & Taxonomy:** Added `soulspire_ws_talent_contracts.lua` (22 taxonomy effect types) and exported all **23,427** compiled contracts to `modules/custom/data/ws_talent_contracts.json`.
6. **Combat Instrumentation:** Added `soulspire_ws_telemetry.lua` wired into `soulspire_ws_overrides.lua` and `soulspire_proving_grounds_telemetry.lua` (zero production log spam; emits `ws_talent_eval` distinguishing `allocated`, `eligible`, `activated`, `applied`, `condition_not_met`, `blocked_by_restriction`, `proc_failed`, `unexpected_outcome`).
7. **Autoparser Integration:** Added `soulspire_suite/models/ws_talents.py` and `soulspire_suite/telemetry/ws_talent_validator.py`, extended `functional_matrix.py` (`STATUS_NOT_EXERCISED`) and `engine_bridge.py` (`talent_branch`, `talent_allocations`).

---

## 2. Eligibility & Reduction Metrics

| Metric | Count |
|---|---|
| Canonical Souls | 66 / 66 |
| Total Catalog Weapon Skills | 219 (15 families) |
| Full Catalog Combinations (`66 × 219`) | 14,454 |
| Base-Job Theoretically Equipable Combinations | 5,619 |
| **Approved Eligible Soul × WS Combinations** | **1,476** |
| Excluded Base-Job Equipable Combinations | 4,143 (**73.73% reduction**) |
| Estimated Talent Definitions Avoided (`12 / WS`) | **49,716** (`67,428 -> 17,712`) |
| Total Compiled Talent Contracts (incl. SC + Evo) | **23,427** (100% machine-readable) |
| Reusable Effect Taxonomy Types | 22 |

Full per-Soul breakdown: `docs/talents/WS_TALENT_COVERAGE_MATRIX.md` and `docs/talents/ws_talent_coverage_matrix.json`.

---

## 3. Verification Evidence

| Suite | Result | Details |
|---|---|---|
| `luajit tests/lua/ws_talent_foundation_v2.lua` | **8 / 8 PASS** | 66-Soul eligibility, UI catalog filtering, tier/level prereqs, evolution mutual exclusions, Sanguine Blade DPS block, deterministic migration refund, Soul switching isolation, live `wsTelemetry` + `applySoulHookPostWS` execution |
| `luajit tools/export_ws_talent_contracts.lua` | **PASS** | 66 Souls, 1,476 eligible trees, 23,427 contracts exported, 0 pure-DPS heal/defense violations, 0 no-MP violations, 0 petless pet-hook violations |
| `python3 -m unittest tests/test_ws_foundation.py tests/test_ws_talent_foundation_v2.py` | **9 / 9 PASS** | All 219 WS foundation proxies + 66-Soul manifest/contract parity + 0 excluded contracts |
| `python3 -m unittest tests/test_ws_talent_autoparser.py` (in `parser-src`) | **5 / 5 PASS** | 66-Soul automated test plans, non-damage Soul resource credit (`PASS`), all 5 matrix statuses (`PASS`, `FAIL`, `BLOCKED`, `NOT EXERCISED`, `NOT APPLICABLE`) |

---

## 4. Checkpoint Tracker

| Checkpoint | Scope | Commit | Status |
|---|---|---|---|
| **CP1** | Phase 1 Audit + Phase 2 66-Soul Eligibility Manifest (JSON + Lua) | `972b58a` | **DONE** |
| **CP2** | Phases 3–6: 66-Soul 3-Branch Mechanics, Role Guardrails, Contracts, Eligibility & Migration | `ca97a0a` | **DONE** |
| **CP3** | Phase 7: Structured WS Talent Combat Telemetry & Soul-Hook Runtime | `a1908bb` | **DONE** |
| **CP4** | Phases 8–10: Contract Catalog Export, Sanguine Blade Fix, Autoparser Integration, LuaJIT & Python Suites | `929e9fd` | **DONE** |
| **CP5** | Phases 11–12: Permanent Coverage Matrix, Final Regression Run & Push | *(HEAD)* | **DONE** |

---

## 5. Outstanding Balance & Live-Gauntlet Follow-Ups (Post-Foundation)

- **Numerical Balance Pass:** All talent curves and Soul-hook magnitudes are foundation-grade; final numerical balancing at Lv 10/30/50/75 is deferred to the project owner's balance pass.
- **Live `xi_test` Matrix Execution:** Every Soul's live `xi_test` combat gauntlet column is explicitly marked `NOT EXERCISED` in `WS_TALENT_COVERAGE_MATRIX.md` until the owner runs the automated gauntlet queue with `talent_branch` / `talent_allocations` enabled.
- **Flintlock Dual-Pistol Compatibility:** Flintlock is scoped to `Marksmanship` and ready for future dual-pistol client/engine additions without assuming unfinished client features.
