# SoulspireXI — Weapon Skill Talent Foundation Pass 2.0 Progress

**Branch:** `feat/ws-talent-foundation-v2` (branched from `origin/main` @ `30d1fad`)  
**Schema Version:** `2.0.0`

---

## 1. Phase 1 — Architecture Audit Summary

### Existing WS Talent System
- **Tree Structure:** Three main columns (`Col 1`, `Col 2`, `Col 3`) × 4 Tiers (`T1..T4`), plus optional Skillchain Augment (`Col 4`).
- **Point Economy & Limits:**
  - `3` talent points per main job level (`225` pts at Lv 75).
  - `56` max points per WS -> `4` fully mastered WSs (`224` pts) at Lv 75.
  - `EVOLUTION_WS` (`#1 Combo`, `#47 Sanguine Blade`) use versioned storage (`OX_EVO1_`, `OX_EVO2_`, `OX_EVOSC_`) with 5 exclusive 1-rank stages.
- **WS Catalog:** `219` weapon skills across `15` weapon families (`modules/custom/lua/soulspire_ws_catalog.lua`), including custom Chakram Throwing WSs (`#241-#252` in `soulspire_throwing_ws.lua`).
- **First-Point Foundation:** `soulspire_ws_foundations.lua` grants a playable normalized baseline on 1st point spent across all 212 damaging WSs (7 utility WSs excluded).
- **Role Tiers:** 6-tier system in `soulspire_job_specs.lua` (`Damage` 1.00, `HybridSupport` 0.50, `Support` 0.35, `CombatHealer` 0.20, `Healer` 0.12, `Tank` 0.12).

### Critical Gaps Identified in Audit
1. **Incomplete 66-Soul Coverage in WS Trees:** `P.ALL_SPECS` in `soulspire_ws_spec_profiles.lua` only covered `34` of `66` canonical Souls. `SPEC_KEY_TO_CATEGORY` in `soulspire_ws_talents.lua` mapped several Souls to unrelated specs (`adventurer -> bladewheel`, `musician -> sage`, `minstrel -> spartan`, `alphawarden -> spartan`) and dropped 25+ Souls to `'generic'`.
2. **Overly Broad Weapon Eligibility:** `P.ALLOWED_SKILLS_BY_SPEC` used base-job open weapon tables (`WAR_OPEN_SKILLS` = 12 families for Berserker & Commander, `RUN_OPEN_SKILLS` = 5 families for Inquisitor & Lifebinder, `SCH_OPEN_SKILLS` = 3 families for Medic, 4 families for Sage, Sword leaking onto Bladewheel).
3. **No Runtime/UI Eligibility Enforcement:** `talents.sendCatalogSync()` sent all 219 WSs to every player; `talents.canInvest()` did not reject ineligible weapon families; no deterministic refund/migration existed for previously allocated ineligible WSs.
4. **No Machine-Readable Talent Contracts:** Talents lacked a structured effect taxonomy, trigger/condition metadata, expected combat events, and expected resource/modifier deltas for the Autoparser.
5. **No Talent-Level Combat Telemetry:** `soulspire_ws_overrides.lua` did not emit structured `ws_talent_eval` events distinguishing allocated/eligible/activated/applied/condition_not_met/blocked outcomes.
6. **Autoparser Blind to Talent Mechanics:** `functional_matrix.py` only verified `ws_uses > 0`; `profile_generator.py` did not read an authoritative eligibility manifest or generate WS talent contract tests.

---

## 2. Phase 2 — Authoritative 66-Soul Weapon Eligibility Manifest

- **Source of Truth (JSON):** `modules/custom/data/ws_eligibility_manifest.json`
- **Lua Runtime Mirror:** `modules/custom/lua/soulspire_ws_eligibility.lua`
- **Generator:** `tools/gen_ws_eligibility_manifest.py`

### Reduction Metrics
| Metric | Count |
|---|---|
| Canonical Souls | 66 |
| Total Catalog Weapon Skills | 219 (15 families) |
| Full Catalog Combinations (`66 × 219`) | 14,454 |
| Base-Job Theoretically Equipable Combinations | 5,577 |
| **Approved Eligible Soul × WS Combinations** | **1,474** |
| Excluded Base-Job Equipable Combinations | 4,103 (**73.57% reduction**) |
| Excluded vs Full Catalog | 12,980 (**89.80% reduction**) |
| Estimated Talent Definitions Avoided (`12 / WS`) | **49,236** (`66,924 -> 17,688`) |

Excluded weapon families generate **zero** talent definitions.

---

## 3. Checkpoint Tracker

| Checkpoint | Scope | Status |
|---|---|---|
| **CP1** | Phase 1 Audit + Phase 2 66-Soul Eligibility Manifest (JSON + Lua) | **COMPLETED** |
| **CP2** | Phases 3–6: Shared Effect Handlers, 3-Branch Taxonomy, Machine-Readable Talent Contracts, All 66 Souls Integrated, Eligibility Enforcement & Migration Refund | IN PROGRESS |
| **CP3** | Phase 7: Structured WS Talent Combat Telemetry & Soul Hook Runtime Execution | PENDING |
| **CP4** | Phases 8–10: Autoparser Profile/Matrix/Gauntlet Integration + LuaJIT & Python Verification Suites | PENDING |
| **CP5** | Phases 11–12: Permanent Coverage Matrix + Full Regression Run + Final Push | PENDING |
