# Soul Proving Grounds Lite — NPC Testing Arena

Status: **Implemented and server-validated on `feat/soul-proving-grounds-lite` (awaiting manual in-game client playtest before merge to `main`)**.

No custom DATs, custom animations, new monster models, custom graphical interfaces, or player-facing chat commands are used.

## Architecture & Files

- `modules/custom/lua/overlords_proving_grounds_registry.lua` — Shared versioned encounter registry (`schemaVersion = 1.0.0`), strict behavior enforcement, boss scaling guard, and no-progression safeguards. Used identically by the NPC arena and the automated combat runner.
- `modules/custom/lua/overlords_proving_grounds_telemetry.lua` — Dedicated server-authoritative combat telemetry logger (separate from player parsers). Emits JSONL records to `log/proving_grounds_runs.jsonl` and explicitly reports `"unavailable"` for unsupported metrics.
- `modules/custom/lua/overlords_proving_grounds_lite.lua` — Native `customMenu` NPC controller (**The Arbiter**, existing look ID `2433`) in GM Home (zone 210) at `(5, 0, 5)`.
- `modules/init.append.txt` — Registers the registry, telemetry library, and arena module cleanly after `boss_like_combat_and_exp.lua`.

## Implemented NPC Capabilities

### Encounter Types (Verified Single-Role Behavior)
1. **Physical Bruiser** (`Orcish_Guard`, group `3723` / zone `86`, `HP=0`):
   - Pure physical autoattacks + strictly whitelisted single-target physical mobskills (`606` Shoulder Attack, `607` Slam Dunk via `onMobMobskillChoose`).
   - Magic casting disabled; AoE skills excluded.
2. **Magic-heavy Caster** (`Orcish_Hexspinner`, group `3724` / zone `86`, `HP=0`):
   - Verified `Beastmen_BLM` spell list (`21`, spells spanning Lv10 through Lv75) with rapid cast cadence (`MAGIC_COOL = 10`, scaled by `boss_like_combat_and_exp.lua`); mob TP abilities disabled.
3. **AoE Boss** (`Gigas_Flanker`, group `16` / zone `129`, `HP=0`):
   - Physical autoattacks + strictly whitelisted AoE damage mobskills (`665` Grand Slam, `664` Impact Roar via `onMobMobskillChoose`); magic disabled, no suicide/instant-death/sleep-lock moves.
4. **Training Dummy** (`Orcish_Guard`, group `3723` / zone `86`, `HP=0`):
   - Stationary (`NO_MOVE = 1`), unkillable with automatic HP refill below 50% so DPS runs never stall at 1 HP; autoattacks, magic, and mobskills disabled.
5. **Unavailable Matrix Archetypes** (`Mobile Boss`, `Endurance Boss`, `Burst Boss`):
   - Explicitly marked unavailable in the menu info option with clear reasons rather than substituting misleading encounters.

### Selectable Levels
- Level 10, Level 30, Level 50, Level 75, and **Match Player Level** (clamped 10–75).
- Exact `minLevel`/`maxLevel` are set before `mob:spawn()` so base stats and `xi.customBossServer.applyMobScaling(mob)` compute accurately for the chosen level without double-application (`[CustomBoss]Applied == 1` guard verified).

### Encounter Controls
- **Start Encounter** -> Encounter Type -> Level.
- **Reset Active Encounter** -> Finalizes telemetry, despawns trial mob, removes skill-up lock, releases session lock.
- **Repeat Previous Encounter** -> Remembers the tester's last `{ bossType, bossLevel, matchPlayerLevel }` selection for 1-click repeat.
- **Exit Proving Grounds** -> Cleans up any owned active session, clears skill-up lock, and warps safely to Ru'Lude Gardens `(0, 3, 2, 192)`.

## Testing Safety & Session Isolation

- **Zero Progression (Defense in Depth)**:
  - `mob:setCallForHelpFlag(true)` — skips EXP, Capacity Points, Gil, Item Drops, Records of Eminence kill credit, and Blue Mage spell learning in `CMobEntity::DistributeRewards()` without altering combat damage, enmity, TP, or scaling formulas.
  - `mob:setDropID(0)`, `xi.mobMod.NO_DROPS = 1`, `xi.mobMod.GIL_MAX = -1`, `xi.mobMod.EXP_BONUS = -100`.
  - `xi.experiencePoints.calculate` override returns `{ exp = 0, chainActive = false, chainWindow = 0 }` for any mob marked `[ProvingGrounds]TrialMob = 1`.
  - Temporary `-100` `COMBAT_SKILLUP_RATE` and `-100` `MAGIC_SKILLUP_RATE` lock applied to trial participants and cleanly removed on victory, defeat, reset, exit, disconnect, or zoning out.
- **Single-Session Lock & Cleanup**:
  - One locked session per arena; concurrent players cannot start a second trial or reset another player's active encounter.
  - Reliable cleanup on boss death (`onMobDeath`), player death (`xi.player.onPlayerDeath`), timeout (`onMobDespawn` / 600s lifetime), manual reset, repeat, player disconnect/zone-out (`DESPAWN` listener + `xi.player.onGameIn` safety net), server restart, and spawn failure rollback.

## Validation Performed

1. **LuaJIT Syntax & Load Check (`libluajit_64.dll`)**: All 3 Lua modules parse cleanly.
2. **Live `xi_map` Startup via RPC (`service.restart`)**: `overlords_proving_grounds_registry` and `overlords_proving_grounds_lite` load with zero errors or warnings in `log/map-server.log`.
3. **Headless MapEngine Integration Suite (`xi_test.exe --lua-only --file proving_grounds_combat --seed 12345`)**:
   - Verified `DE_Crucible_Arbiter` exists in GM Home.
   - Verified Lv10 Physical Bruiser exact level, single-application `xi.customBossServer` scaling (no double-scaling), zero EXP formula output, CallForHelp/NO_DROPS/GIL_MAX/EXP_BONUS/skill-up lock flags.
   - Verified concurrent-player session lock rejection, owner reset, 1-click repeat, spawning of `magic_caster`/`aoe_boss`/`training_dummy`, and rejection of unavailable `mobile_boss`.
   - Verified `test_npcs_in_gm_home` continues to pass (2/2).

## Remaining Limitations & Manual In-Game Testing Checklist

1. Arena currently resides in **GM Home (zone 210)** for controlled validation; no public-city entrance NPC has been placed until manual playtesting confirms coordinates and flow.
2. Manual client checks still recommended before merging to `main`:
   - Visually verify **The Arbiter** at `(5, 0, 5)` and spawned bosses at `(5, 0, 25)` in the FFXI client.
   - Walk through Start -> Physical Bruiser / Magic-heavy Caster / AoE Boss / Training Dummy -> Lv10/30/50/75/Match -> Reset -> Repeat -> Exit.
   - Confirm combat chat log shows expected behavior isolation (no spells from Physical Bruiser, spells from Magic Caster, AoE from AoE Boss, stationary dummy).
   - Confirm no EXP, gil, drops, skill-ups, or RoE progress occur on kill.
