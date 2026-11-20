# Automated Soul Combat Benchmarks — Implementation, Proof & Roadmap

Status:
- **Stage A (Formula, Matrix & Regression Suite)**: Implemented and verified (10/10 formula checks, 24/24 Python unit tests, 66-Soul matrix across 22 jobs excluding retired Freelancer).
- **Stage B / Milestone C (Real Server Combat Automation Proof of Concept)**: **Implemented and PROVEN** inside LandSandBoat's authoritative headless `MapEngine` (`xi_test.exe`) with bit-for-bit `--seed` determinism.
- **Stage C (Controlled Trio Party Testing & Full 66-Soul Sweep)**: Intentionally gated per the milestone rule (*stop expanding the automated combat system until one server-controlled character fighting one level-10 boss using real combat mechanics is proven*).

## Shared Encounter Contract

Both manual NPC trials and automated combat runs execute through `modules/custom/lua/overlords_proving_grounds_registry.lua` (`schemaVersion = 1.0.0`):
- Canonical encounter fields: `encounterId`, `version`, `bossType`, `bossLevel`, `playerLevel`, `levelGap`, `difficulty` (`even_match` / `boss_plus_3` / `boss_plus_8`), `bossPreset` (`normal` / `nm`), `behaviorProfile`, `durationSec`, `gearProfile` (`accessible_lv10`..`accessible_lv75`), `partyComposition`, `seed`, and live `combatRules` snapshot from `boss_like_combat_and_exp.lua`.
- **+8 Level Wall Separation**: `boss_plus_8` is explicitly flagged `standardBaseline = false, extremeChallenge = true` and excluded from standard Soul balancing baselines.
- **Accessible Gear Rule**: Level-10 benchmarks use `accessible_lv10` equipment via `xi.overlords.testGear` (every equipped item verified `lvl <= 10`, never Lv75 BiS).
- **Zero Balance Changes**: No Soul balance values were modified during benchmark implementation.

## Stage A — Formula & Regression Runner

Run:
```powershell
python tools/proving_grounds_benchmark.py --run-formula
python tools/proving_grounds_benchmark.py --matrix-out logs/proving_grounds_matrix.json
python -m unittest discover -s tests -v
```

Every Stage A output is explicitly labeled `test_mode = "formula"` and `combat_execution = "NO_REAL_COMBAT_EXECUTED"` so static math is never mistaken for measured combat. Covers:
1. Enemy level scaling (`getMobLevelScale`, Normal vs NM stats at Lv10/30/50/75)
2. Physical damage & level-gap penalties (EM, +3, +8 wall, hit-rate delta)
3. Magical damage, MACC resist scaling & breath anti-one-shot caps
4. Unified OverlordsXI attack-rate haste (`patches/0044`, melee/ranged, Snapshot, Slow)
5. TP generation (base delay + Store TP + active-combat-only Regain)
6. Mitigation & tank pressure (Normal 0.65 / NM 0.75 armor-piercing pDIF floor, Parry/Block caps, 35% min block bleedthrough)
7. Healing effective vs overheal accounting
8. MP sustainability model
9. Defensive stacking & six-tier Soul classification across all 66 canonical Souls (22 jobs, retired `DNC:freelancer` excluded)
10. Pet scaling (`petCombatPace`)

## Stage B — Real Server Combat Automation (Milestone C Proof)

### Engine Investigation & Solution
- Live `xi_map.exe` Lua modules cannot synthesize a genuine `CCharEntity` without a client session; Trusts and Ally Mobs do not execute `player:isPC()` Soul crystal hooks.
- LandSandBoat's native `xi_test.exe` embeds the real `MapEngine` + `WorldEngine` over `inproc://` IPC, loads all OverlordsXI custom modules from `modules/init.txt`, connects to MariaDB `xidb`, spawns real `CCharEntity` characters (`xi.test.world:spawnPlayer`), dispatches real client action packets (`0x01A` engage, Job Ability, Weapon Skill, Spell, Move), ticks real `PAI->Tick` / `CAttackState` / `CWeaponSkillState` / `CMobController` AI, and supports deterministic `--seed` PRNG + time acceleration (`skipTime`).
- **Minimal C++ Patch (`patches/0045-xi-test-lua-only-flag.patch`)**: Adds a 6-line `--lua-only` flag exclusively to `src/test/main.cpp` and `src/test/test_application.cpp` (zero changes to `xi_map.exe` or production code) so Lua integration benchmarks run directly without being blocked by an upstream Catch2 `database_tests.cpp` failure on MariaDB 10.11.10.

### Verified Milestone C Run (`--seed 12345`)

Command:
```powershell
python tools/proving_grounds_benchmark.py --run-stage-b --seed 12345
# or directly in C:\dev\server:
.\xi_test.exe --lua-only --file proving_grounds_combat --seed 12345
```

- **Combat Policy (`lv10_war_berserker_v1`)**:
  - Actor: Real `CCharEntity` Lv10 WAR, **Berserker** Soul (`Damage` tier), accessible Lv10 TP equipment (`lvl <= 10` verified), Tier-1 Weapon Skill unlocked via real `xi.overlords.wsTalents.invest`.
  - Opponent: Shared-registry Lv10 **Physical Bruiser** (`Orcish_Guard`, scaled once via `xi.customBossServer.applyMobScaling`).
  - Actions: Real `0x01A` engage packet, `Provoke` on 30s cooldown, matching Lv10 Weapon Skill whenever `TP >= 1000`, 1-second simulation steps.
- **Measured Real Combat Results (identical bit-for-bit across repeated `--seed 12345` runs)**:
  - `test_mode`: `automated_real` | `outcome`: `defeat` (Tier-1 Damage Soul solo with no healer succumbed to boss pressure at `30s`, consistent with OverlordsXI's fragile-DPS balance philosophy)
  - `offense`: `total_damage = 130` (`sustained_dps = 4.3333`, `burst_dps_10s = 9.1`), `autoattack_damage = 112` (`5` hits, `1` miss, `hit_rate = 0.8333`), `weaponskill_uses = 1`, `weaponskill_damage = 18`, `ability_uses = 1`
  - `defense`: `actual_incoming_damage = 478` (`10` boss hits, `1` miss, `max_damage_spike = 114`, `deaths = 1`)
  - `threat`: `enmity_generation = 4414` (`max_ce = 293`, `max_ve = 4212`, `tank_aggro_uptime_pct = 100%`, `threat_samples = 58`)
  - `resources`: `tp_generated = 1437`, `tp_spent = 1093`
  - `safety`: `exp_events_observed = 0`, `exp_points_observed = 0`, `progression_clean = true`

### Telemetry Honesty (`unavailable` Fields)
Metrics not exposed by authoritative Lua listeners are explicitly recorded as `"unavailable"` (with reasons in `metric_availability`):
- `raw_incoming_damage` / `mitigated_damage`: `TAKE_DAMAGE` reports post-mitigation final damage only.
- `block_rate` / `parry_rate` / `evasion_rate`: `MELEE_SWING_MISS` aggregates avoidance without a per-reaction split.
- `overhealing`: `MAGIC_USE` action param reports applied HP recovery without pre-cap amount.
- `soul_specific_metrics`: Per-Soul custom gauge hooks are not yet instrumented in Stage B POC.

## Next Steps (Stage C — Gated Until Review)
1. Add controlled 3-player party composition (`trio_standard`: Tank + Healer + DPS) using `xi.test.world:spawnPlayer` + real party formation packets and explicit per-role combat policies.
2. Add repeatable multi-seed sweeps (`>=3` seeds per Soul) for statistical confidence and role-dominance comparison across all 66 Souls.
3. Instrument optional pre-mitigation damage / overheal / block-parry-evade telemetry hooks only if needed for deeper Tank and Healer balancing.
4. Client-verify GM Home navmesh coordinates before enabling `Mobile Boss` in the NPC menu.
