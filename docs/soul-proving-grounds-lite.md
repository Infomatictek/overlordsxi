# Soul Proving Grounds Lite — Phase 1 prototype

Status: **prototype on feature branch, not deployed or playtested**.
No custom DAT, NPC model, animation, or command required **inside the arena**.

## Implemented
- Existing dynamic NPC model (look ID 2433), named **The Arbiter**, at (5,0,5) in GM Home (zone 210).
- NPC opens a server-side native `customMenu` with a level submenu.
- Select Lv10, Lv30, Lv50, Lv75 or current player level (clamped to 10–75).
- Spawns one dynamic mob with the documented LSB Fafnir mob group (5, group zone 154) at (5,0,25), forced to requested level.
- Calls the actual OverlordsXI `xi.customBossServer.applyMobScaling` hook after spawn, so global normal/NM, level gap and tank-pressure logic applies in combat.
- Reset makes the trial entity disappear. Spawn has a 600-second lifetime; drops disabled via drop table 0 and NO_DROPS mob mod.
- Only one active trial per zone (intentionally prevents overlapping encounters until session isolation exists).

## Important limitations / release blockers
1. This is an **internal GM Home test**, not a public-city entrance or private battlefield. Testers require their existing authorized way into GM Home. No player-facing chat command is implemented.
2. The prototype uses the real Fafnir ability and spell behavior; it is **not** guaranteed physical-only. Do not use it to draw physical tank balance conclusions until the final behavior is verified.
3. **EXP/skill-up and other progression suppression is not proven**. Keep this restricted to trusted test characters until in-game verification adds the correct no-reward safeguards.
4. The dynamic entity, lifetime/ID release and alive-state behavior need real server validation. A dead or timed-out mob can remain in entity storage temporarily; test repeated summon/reset carefully.
5. No telemetry, fight results, party isolation, XP-proofing, cross-zone entry/exit, or custom animations in Phase 1.
6. Current prototype deliberately spawns nothing if another active trial is detected. Do not expose the single shared GM Home arena to multiple groups.
7. GM Home coordinates and model placement must be checked in the actual client. Do not deploy to main until confirmed.
8. Check the local pinned LandSandBoat version, ordered init module loading, and possible menu-handler compatibility before merging.

## Suggested test procedure
1. Pull `feat/soul-proving-grounds-lite` into a local development checkout of `C:\overlordsxi`, then mirror the module plus updated init list into `C:\dev\server`.
2. Run Lua syntax checks using the **local** Lua/LuaJIT toolchain and start/restart `xi_map` through the configured RPC service, not a manual process kill. Confirm no Lua traceback.
3. In GM Home, target The Arbiter and verify level selection.
4. Try Lv10. Confirm exact mob level, status, boss profile, combat scaling, actual damage, no drops, and no unintended progression. Kill, reset, retry.
5. Repeat Lv30, Lv50, Lv75; test timeouts, repeated interactions, two players, zoning, and server restart.
6. If all pass, choose a public hub entrance and suitable dedicated arena with verified coordinates, then add session isolation and no-reward enforcement.

## Phase 2 after successful smoke test
- Proper native-event city NPC and zone entry, no developer teleport dependency.
- Separate controlled physical/caster/AoE/dummy profiles with verified ability lists.
- Per-player/party session ownership and cleanup.
- Minimal server-side combat results suitable for parser comparison.

This prototype intentionally does not modify the retiring `!spec` system.
