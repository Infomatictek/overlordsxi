# Automated Soul Combat Benchmarks, Full Timeline Recorder & Historical Analysis

Status:
- **Stage A (Formula, Matrix & Regression Suite)**: Implemented and verified (10/10 formula checks, 25/25 Python unit tests, 66-Soul matrix across 22 jobs excluding retired `DNC:freelancer`, all 4 difficulties including bosses up to Lv83).
- **Stage B / Milestone C (Real Server Combat Automation Proof + Level Sync + Full Combat Recorder)**: **Implemented and PROVEN** inside LandSandBoat's authoritative headless `MapEngine` (`xi_test.exe`) with bit-for-bit `--seed` determinism.
- **Stage C (Controlled Trio Party Testing & Full 66-Soul Sweep)**: Gated pending review of Milestone C and manual NPC arena playtesting.

## Storage Layout (`C:\dev\server\log\proving_grounds\`)

- `runs.jsonl` — summary records with `original_character_level`, `effective_combat_level`, `actual_boss_level`, `level_gap`, `difficulty`, `standard_baseline`, `extreme_challenge`, `boss_preset`, `level_sync` verification object, `valid_for_balance`, `warnings`, `timing`, `logging_status`, `files`, and full metrics.
- `events/<run_id>.jsonl` — chronological millisecond-precision events (`seq`, `phase`, `session_ms`, `combat_ms`, `category`, `event_type`, `source_id`/`name`, `target_id`/`name`, `value`, `meta`), flushed in bounded batches (`FLUSH_BATCH_SIZE = 64`, cap `25,000` events/run with explicit `events_dropped` counter).
- `snapshots/<run_id>.jsonl` — 1-second active-combat snapshots (`combat_sec`, `players` HP/MP/TP/buffs, `boss` HP%/target/threat/debuffs, `pets_and_clones`, 1-second interval & cumulative damage/healing).
- `feedback/<run_id>.json` — gameplay feedback from The Arbiter menu or local CLI notes.

## Measured vs Explicitly Unavailable Data

Authoritative server listeners capture autoattacks, misses, crits, Weapon Skills (without double-counting in `TAKE_DAMAGE`), TP spent, spells started/completed/interrupted, Job Abilities, boss AoE correlation (`meta.boss_action_seq`), HP thresholds (75%/50%/25%/0%), buff/debuff changes, pet & Shinobi clone lifecycle/damage attribution, incoming damage spikes, enmity, and 0-EXP safety verification.

The following remain explicitly recorded as `"unavailable"` (never fabricated as `0`) until engine hooks expose them:
- `raw_incoming_damage` / `mitigated_damage` (`TAKE_DAMAGE` provides post-mitigation final damage only)
- Individual `block_rate` / `parry_rate` / `evasion_rate` split (`MELEE_SWING_MISS` aggregates avoidance)
- `overhealing` (`MAGIC_USE` action param provides applied HP recovery without pre-cap amount)
- `spell_resist_tier` (`MAGIC_USE` does not expose resist fraction directly)
- `soul_specific_metrics` (per-Soul custom gauges not yet instrumented)

## CLI Workflows (`tools/proving_grounds_benchmark.py`)

```powershell
# Stage A formulas & 66-Soul matrix
python tools/proving_grounds_benchmark.py --run-formula
python tools/proving_grounds_benchmark.py --matrix-out logs/proving_grounds_matrix.json

# Stage B real server combat suite (xi_test.exe --lua-only)
python tools/proving_grounds_benchmark.py --run-stage-b --seed 12345

# Historical analysis & summaries (excludes invalid level-sync & +8 Extreme from standard averages)
python tools/proving_grounds_benchmark.py --summarize C:\dev\server\log\proving_grounds\runs.jsonl
python tools/proving_grounds_benchmark.py --list-runs --soul berserker --level 10 --boss physical_bruiser
python tools/proving_grounds_benchmark.py --show-run <run_id>
python tools/proving_grounds_benchmark.py --timeline <run_id> --rolling 5 --export-csv logs/timeline.csv
python tools/proving_grounds_benchmark.py --compare <run_id_1> <run_id_2>
python tools/proving_grounds_benchmark.py --add-feedback <run_id> --tag damage_felt_weak --note "DPS dropped at 35s"
```

## Validation Summary

1. **Python Unit & Analyzer Suite (`python -m unittest discover -s tests -v`)**: 25/25 passed (66 Souls, no Freelancer, LuaJIT registry check, 4 difficulties including Lv78/80/83, invalid sync & `+8` exclusion, timeline spike/DPS-drop analysis, mismatched condition comparison warning, feedback & CSV export).
2. **Real Engine Suite (`xi_test.exe --lua-only --file proving_grounds_combat --seed 12345`)**: 7/7 passed:
   - Arbiter placement at `(-5, 0, 5)`.
   - Lv75 -> Lv10 native `LEVEL_RESTRICTION` sync (subjob `<=5`, OverlordsXI HP & Soul rescaling, `+3` boss Lv13, Repeat preserving settings, clean Lv75 restoration on reset).
   - Upward sync rejection (`cannot_sync_upward`) and Normal/NM combos across Lv10/30/50/75 including Lv78, Lv80, and Lv83 bosses.
   - Lv75 -> Lv10 Shinobi clone level scaling and dismissal on reset.
   - 30-second preparation phase isolation, monotonic `seq`/`session_ms`, non-double-counted WS, 1-second snapshots, and feedback persistence.
   - Explicit file-write failure detection (`logging_status.ok == false` on invalid path).
   - Multi-participant boss AoE correlation (`boss_action_seq`) and zero listener leak across repeated runs.
3. **Live `xi_map` Restart via RPC**: Clean boot with zero Proving Grounds errors or warnings.
