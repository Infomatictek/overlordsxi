# Haste / Attack Speed / Autoattack Overhaul — Phase 1

Scope: `Infomatictek/overlordsxi` engine patches and combat/Soul modules only. No WS tree, WS Evolution, or Ashita talent-addon changes. `main` is the playable test environment and must remain unchanged until deployment is approved.

## Confirmed code paths

- Standard melee: upstream `src/map/entities/battle_entity.cpp::CBattleEntity::GetWeaponDelay(bool tp)`. Reduces delay with Martial Arts, Dual Wield, haste categories and `main.DELAY_REDUCTION_CAP`; `tp=true` bypasses haste. Attack-state schedule: `src/map/ai/states/attack_state.cpp`.
- Standard TP return: upstream `src/map/utils/battleutils.cpp::CalculateBaseTP` invokes Lua `xi.combat.tp.calculateTPReturn` with delay. Do not assume TP per second is stable when changing attack timing.
- OverlordsXI player baseline: `modules/custom/lua/boss_like_combat_and_exp.lua` grants +15% gear haste, +10% ability haste, +25 Store TP and combat-only +20 TP per 3 seconds.
- Custom ranged autoattack: `patches/0014-auto-ranged-attack.patch` uses ranged delay after Snapshot and Velocity Shot, applies magic/ability/gear haste and a 600 ms minimum. It previously hardcoded a 20% haste multiplier floor rather than reading the melee configuration. Patch 0042 aligns that haste floor with the setting. Patch 0043 preserves the elapsed attack-timer remainder across auto-ranged rounds, matching the melee scheduler.
- Chi Weaver: `modules/custom/lua/mnk_specs.lua::executeChiRangedAttack` computes unarmed / Martial Arts / haste delay independently, applies Hundred Fists speedup, clamps to 600–5000 ms, and grants flat TP values plus Store TP on landed bolts. `patches/0021-mnk-chiweaver-ranged-chi.patch` consumes the computed interval.
- Further mechanics needing dedicated balance reviews: Dual Wield on Mirage Sentinel / Adventurer; ranged Snapshot and Rapid Shot on Flintlock / Huntsman; Hasso and special haste effects on Samurai Souls.

## Phase-1 patches and boundaries

`patches/0042-auto-ranged-configured-haste-cap.patch` only aligns auto-ranged attack haste with the melee server setting; it does not remove the 600 ms safety floor or alter Snapshot, TP gain, WS mechanics, or unique Soul bonuses. A cap such as 0.80 corresponds to a minimum haste multiplier of 0.20; changing the setting to 0.70 changes that floor to 0.30.\n\n`patches/0043-auto-ranged-preserve-swing-time.patch` changes the auto-ranged timer update from overwriting the countdown to adding a new interval to the elapsed countdown (the standard melee pattern), avoiding loss of sub-tick scheduling remainder. This should reduce scheduler-rate-dependent attack-speed drift without changing TP awarded per hit.

## Validation before live deployment

1. Confirm both patch 0042 and patch 0043 can apply sequentially after patches 0014 and 0021. A structural hunk-count and patch-context inspection was performed in GitHub, but no full `git apply --check` or compilation has been run.\n2. In a disposable LandSandBoat worktree at the server's pinned upstream revision, run the existing `scripts/setup-local-server.ps1` patch validation or `git apply --check` on the entire ordered patch series, then compile `xi_map`. Do not run patch setup on the playable server before validation.
3. Record `main.DELAY_REDUCTION_CAP` and run 60-second combat samples at two settings (for example 0.80 then 0.70) against a durable harmless target. Compare melee swing intervals and auto-ranged intervals (same weapon, Soul, equipment, and buffs).
4. Repeat with no haste buffs, high haste buffs, Snapshot gear, and Velocity Shot. The ranged cap should affect haste only; Snapshot and the 600 ms floor should remain in force.
5. Record actual attack rounds, landed hits, TP gained from hits, combat Regain, damage dealt, and enemy TP feed. Separate active-combat Regain from hit-generated TP.
6. Repeat with Chi Weaver, Flintlock, Huntsman, dual-wield and H2H Souls; check Soul swaps, loss of ammo, disengage/re-engage, target death, and weapon removal.
7. Compare with an unmodified `main` server first. Do not merge the feature branch until the engine builds and in-game test data are reviewed.

## Known unknowns

The connected server repo stores custom patches, not the exact checkout state of the local LandSandBoat engine. The upstream `LandSandBoat/server` `base` source was inspected for the standard calculation, but the user's local pinned engine revision and settings have not been verified. Neither a complete patch-series application, C++ compilation, nor in-game timing tests have been executed during the GitHub-only audit.
