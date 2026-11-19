# WS Evolution: first in-game playtest

Branch: `feature/ws-evolution-playtest`

This is a deliberately limited first prototype for **Combo (WS #1)** and **Sanguine Blade (WS #47)**. It does not migrate the other WS trees.

## What changed

- Two evolution choices per stage; one of the two can be active. Stages are 1/5/10/15/25 (level gates). The first choice immediately changes the WS identity.
- Combo offers a follow-up WS opener or TP-flow identity. Later stages provide alternate forms of follow-up pressure and precision instead of mandatory rotation steps.
- Sanguine Blade offers magical offense for compatible Souls/specs and controlled sustain for supported specs. Offense and additional sustain have separate controls.
- Old packed character variables (`OX_WST_*` and `OX_WST2_*`) are **not overwritten**. Evolution ranks use `OX_EVO1_*` and `OX_EVO2_*`; spec identifiers remain part of the variable name.
- Optional skillchain tuning uses separate spec-specific `OX_EVOSC_*` storage (leaving old `OX_WSSC_*` selections untouched): the default for evolution WSs is **NONE**, and each unlocked stage 1-4 offers a configurable property. Tiers 1-2 allow level-1 properties, tier 3 level-2, and tier 4 Light/Darkness. The setting can remain OFF at every tier. Up to three unique properties can be active, and choosing them costs no WS evolution points.
- Existing non-evolution WS trees remain in place.

## Installation

Deploy the server files from this branch **together** with the Ashita addon branch of the same name in `Infomatictek/overlordsxi-launcher`. Restart the game server, then reload `overlords_talents` in Ashita, use `/talents sync`, and select Combo or Sanguine Blade.

## Suggested tests

1. Select one Stage 1 identity for Combo. Check that the subsequent WS gets its intended follow-up benefit and that the bonus does not remain indefinitely.
2. Ensure selecting the other Stage 1 identity is rejected until the first is refunded.
3. Use Sanguine Blade on a magic-specialized Soul/spec and then on a PLD defensive spec. Check damage, HP recovery, MP recovery, and whether inaccessible offensive nodes are rejected.
4. Set all SC controls to **OFF** and verify no skillchain property is emitted from these evolved WSs.
5. Set the first SC property and verify the desired chain; test the other three selectors and confirm no more than three unique properties are applied.
6. Change specs, return, and verify the previous evolution ranks and skillchain selections were restored.
7. Reset an evolution WS and then reset the active spec; verify versioned evolution ranks are cleared without altering archived legacy ranks.
8. Confirm unrelated WS trees still open and operate normally.

This prototype is **not live-tested**; please report combat logs, UI errors, and unexpected effects before merging it into production. Review any existing native HP drain on Sanguine Blade separately from the capped *additional* talent heal.
