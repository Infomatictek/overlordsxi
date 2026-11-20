# Soul Proving Grounds Lite — NPC Testing Arena, Level Sync & Combat Recorder

Status: **Implemented and server-validated on `feat/soul-proving-grounds-lite` (not merged to `main`)**.

No custom DATs, custom animations, new monster models, custom graphical interfaces, or player-facing chat commands are used.

## Architecture & Files

- `modules/custom/lua/overlords_proving_grounds_registry.lua` — Shared versioned encounter registry (`schemaVersion = 2.0.0`), native level synchronization (`xi.effect.LEVEL_RESTRICTION`), OverlordsXI Soul/HP/pet/clone rescaling, Normal & NM pools, and no-progression safeguards.
- `modules/custom/lua/overlords_proving_grounds_telemetry.lua` — Full server-authoritative combat recorder (`telemetry_schema_version = 2.0.0`) producing summary index, millisecond chronological event logs, 1-second combat snapshots, and gameplay feedback files with explicit write-failure detection.
- `modules/custom/lua/overlords_proving_grounds_lite.lua` — Native `customMenu` NPC controller (**The Arbiter**, existing look ID `2433`) in GM Home (zone 210) at `(-5, 0, 5)` (10 yalms clear of GM Home's sample `Menu Example` NPC at `(5, 0, 5)`).

## Native NPC Menu Flow (The Arbiter)

1. **Encounter Type**:
   - **Physical Bruiser** (Normal: `Orcish_Guard` 3723/86; NM: `Ashu_Talif_Marine` 2017/60) — pure physical autoattacks + single-target physical TP skills only; magic disabled.
   - **Magic-heavy Caster** (Normal: `Orcish_Hexspinner` 3724/86; NM: `Living_Staves` 30/56) — `Beastmen_BLM` spell list (`21`, Lv10–75+) with rapid cast cadence; mob TP abilities disabled.
   - **AoE Boss** (Normal: `Gigas_Flanker` 16/129; NM: `Kraken_assault` 32/55) — physical autoattacks + strictly whitelisted AoE damage mobskills; magic disabled.
   - **Training Dummy** (Normal: `Orcish_Guard` 3723/86; NM: `Ashu_Talif_Marine` 2017/60) — stationary (`NO_MOVE = 1`), unkillable with automatic HP refill below 50%; offensive actions disabled.
   - **Unavailable Archetypes Info** — explicitly explains why `Mobile Boss`, `Endurance Boss`, and `Burst Boss` are unavailable rather than substituting misleading encounters.
2. **Effective Player Level**: `10`, `30`, `50`, `75`, or `Match Current Level (10-75)`.
3. **Difficulty** (offset applied to effective synced player level):
   - `Even Match (+0)` (standard baseline)
   - `Very Tough (+3)` (standard baseline)
   - `Incredibly Tough (+5)` (standard baseline)
   - `Extreme (+8) [Non-Baseline]` (explicitly excluded from standard Soul balance averages)
4. **Enemy Classification**: `Normal` or `NM (Notorious Monster)` — supports boss levels above 75 (`Lv78`, `Lv80`, `Lv83`).
5. **Controls**: `Start Encounter`, `Reset Active Encounter`, `Repeat Previous Encounter` (preserves boss type, effective level, difficulty, and Normal/NM preset), `Record Feedback (Last Run)` (`Felt Great`, `Damage Felt Weak`, `Survival Felt Bad`, `Resource Problems`, `Mechanics Felt Unfair`, `Skip Feedback`), and `Exit Proving Grounds`.

## Native Level Synchronization

- Uses LandSandBoat's native `xi.effect.LEVEL_RESTRICTION` (`CLuaBaseEntity::levelRestriction`), **never** `setLevelCap` (which permanently writes DB genkai) and **never** mutating permanent job levels or learned abilities.
- Enforces native stats, subjob cap (`floor(effectiveLevel / 2)`), equipment restrictions, skills, traits, spells, BLU spell validation, and pet stat recalculation.
- Immediately refreshes OverlordsXI systems to the effective combat level:
  - `xi.overlords.spec.refreshPlayer(player)` (Soul mods/abilities/traits)
  - `xi.customBossServer.applyPlayerCombatPace(player, true)` (rescales `BASE_HP` from effective level's Base HP)
  - Dismisses high-level Kurogane Shinobi clones before/after sync so clones summoned in combat inherit `owner:getMainLvl() == effectiveLevel`
  - Resets `[CustomBoss]PetPaceApplied` and re-syncs Soul pet role mods
- Rejects upward sync (`originalLevel < effectivePlayerLevel`) cleanly across solo and party sessions (`cannot_sync_upward`) so invalid level-sync benchmarks never silently run.
- Guaranteed restoration on victory, defeat, reset, timeout, repeat, exit, disconnect (`DESPAWN`), zoning out, and post-crash/relog recovery via `[ProvingGrounds]SyncActive` charVar in `xi.player.onGameIn`.

## Persistent Combat Records & Timing

Files stored under `C:\dev\server\log\proving_grounds\`:
- `runs.jsonl` — compact summary index (also mirrored to `C:\dev\server\log\proving_grounds_runs.jsonl` for compatibility)
- `events/<run_id>.jsonl` — millisecond-precision monotonic chronological combat events
- `snapshots/<run_id>.jsonl` — 1-second combat state snapshots (HP/MP/TP, boss HP%, threat owner, pets/clones, interval & cumulative damage/healing)
- `feedback/<run_id>.json` — optional NPC or CLI gameplay feedback correlated by `run_id`

Timing isolates `arena_entry_ms`, `prep_start_ms`, `combat_start_ms` (first hostile action), and `combat_end_ms`. Preparation time is recorded in `prep_duration_sec` and never inflates combat duration or DPS. Write errors are detected explicitly and surfaced in `logging_status` and in-game chat warnings.

## Remaining Limitations & Manual In-Game Checklist

1. Arena remains in GM Home (zone 210) for controlled validation before public hub placement.
2. Manual client verification checklist:
   - Confirm **The Arbiter** at `(-5, 0, 5)` is cleanly separated from `Menu Example` at `(5, 0, 5)`.
   - Enter as Lv75, select `Physical Bruiser` -> `Effective Level 10` -> `Very Tough (+3)` -> `Normal` (Boss Lv13), verify Lv10 stats/subjob/gear/Soul scaling, fight, tag feedback, and verify full Lv75 restoration on victory/reset/exit.
   - Verify `Repeat Previous Encounter` preserves effective level, difficulty, and Normal/NM preset.
