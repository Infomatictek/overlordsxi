# Automated Soul Combat Benchmarks — Architecture and Safe Delivery

Status: design contract; **not implemented**. Companion to `feat/soul-proving-grounds-lite` NPC prototype. No engine simulation or real-combat automation is claimed.

## Goals
- Same encounter definitions power automated tests and manual NPC arena tests.
- Capture reproducible damage/healing/mitigation/TP/MP/threat/pet outcomes with controlled levels, gear, party setup and deterministic seeds where supported.
- No client DAT/model/animation work, no dependency on retiring `!spec`, and no change to live balance values.
- Safe for one playable server: do not deploy automated combatant spawning without isolation, cleanup and progression suppression.

## Three layers
1. **Static/regression layer (immediately feasible):** Python tests validate configuration, level-gap math, stat caps, roster coverage, test case schema, encounter definitions and metric output. Clearly label these `formula` results; no simulated DPS output masquerading as combat.
2. **Real combat adapter (requires local engine proof):** run real battle loops with server-controlled actors using the same underlying combat calculations as player combat. Investigate available entity spawn APIs, Mob/Trust AI, commands via the existing RPC infrastructure, and authoritative effect/skill APIs on the pinned LandSandBoat checkout. Avoid fake players that skip action delay, TP, enmity, global cooldown, cast interrupt or damage hooks. If accurate player-AI actors are infeasible without C++/runtime work, report and gate this stage.
3. **Full encounter suite:** controlled tank/healer/DPS group, action scripts, deterministic encounter schedule, fixed gear accessibility, death/revive policy, player and pet telemetry. Compare an identical pair of scenarios across Souls and record confidence/variance.

## Shared scenario contract (versioned JSON or Lua registry)
`scenario_id`, `scenario_version`, `encounter_profile` (bruiser/caster/aoe/mobile/endurance/burst/dummy), `boss_level`, `player_level`, `level_gap`, `boss_preset` (normal/NM), `duration_seconds`, `party_composition`, `gear_profile` (accessible/practical/best), `seed`, `soul_key`, `combat_mode` (formula/real/manual), `server_git_sha`, `runner_version`.
- Core comparisons at 10/30/50/75, EM and +3 boss; +8 wall separate.
- Boss level may exceed player cap (75); level 75 actors stay capped.
- In-game menu must resolve the same encounter profile registry; never create second sets of hidden multipliers.
- All synthetic/fallback actors must be explicitly labeled and must not contaminate real telemetry baselines.

## Server-authoritative results
Each run: unique ID, scenario ID/version, commit SHA, time, duration, outcome, deaths, actual DPS by source (player/pet/clone), effective HPS, overheal, raw and post-mitigation damage, spikes, block/parry/evasion rates, enmity lead/uptime, TP gained/spent and TP moves, MP gained/spent, casts/interrupts/resists, cooldown use, pet uptime/deaths, benchmark warnings. Export JSONL/CSV with schema validation.

## Isolation and safety requirements
- Dedicated arena or instance; single-owner session lock initially.
- No EXP, drops, gil, skill-ups, quests, titles or permanent rewards; avoid use of normal progression hooks for automated targets.
- Cleanup on death, timeout, abort, disconnect, zoning, server restart and exceptions.
- Never auto-run tests on `main` or a public/populated zone without explicit deployment approval.
- RPC restart only via user's established server automation, not guessed endpoints.
- Run unit tests first, then local engine verification, then manual NPC acceptance.

## Incremental acceptance
**Milestone A:** versioned shared profile schema + matrix generator + static regression tests. Test output must say `NO_REAL_COMBAT_EXECUTED`.
**Milestone B:** NPC reads shared profile definitions; physical template fully validated at Lv10. Explicitly fix prototype's current Fafnir-based opponent, which is not physical-only.
**Milestone C:** one engine-authoritative automated Lv10 physical boss vs one controlled actor, proving real damage, TP and threat hooks. Only then expand to roles, all levels and archetypes.
**Milestone D:** three-party-role full tests and cross-Soul comparisons, reproducible JSONL and variance over repeats.

## Notes
Current NPC prototype lives in `modules/custom/lua/overlords_proving_grounds_lite.lua`. It is untested in game, lives in GM Home, uses a documented Fafnir mob group and does not yet suppress EXP or skill-ups. Never represent it as safe for public deployment until progression and cleanup are verified.
