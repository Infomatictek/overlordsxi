# SoulspireXI unified haste attack-rate foundation (experimental)

**Branch:** `feature/combat-haste-aps-foundation-20261119`  
**Scope:** melee attack scheduling, custom ranged autoattack, Chi Weaver, server player haste baseline.  
**Not included:** WS Evolution, talent trees, Ashita talent addon, rebalancing all Souls.

## Design

Player baseline remains +25% total haste, migrated from +15% gear / +10% ability to +15% innate (currently transported by HASTE_MAGIC) / +10% ability. This transport is temporary and deliberately explicit: it does not give the engine a new `HASTE_INNATE` modifier, and other code reading HASTE_MAGIC will see the 15% allowance. Existing characters migrate on the next combat-pace refresh. Login and periodic effects ticks already invoke refresh.

Melee rate is calculated by multiplying gear and other-haste attack-rate factors:

- `G = HASTE_GEAR / 10000`; `O = (HASTE_MAGIC + HASTE_ABILITY [+ two-hand ability haste]) / 10000`
- For nonnegative haste: `gearRate = 1 + 1.5*G`; `otherRate = 1 + (5/3)*O/(1+O)`
- For negative haste (Slow): `gearRate = 1/(1-1.5*G)`; `otherRate = 1/(1-O)`
- `newDelay = pre-haste weaponDelay / (gearRate*otherRate)`, subject to existing engine minimum and maximum delay and remaining delay modifiers.
- Baseline: `G=0, O=.25` => `otherRate=4/3`, exactly the old 25% delay-reduction result.

Ranged autoattack keeps `GetRangedDelayReduction` for Snapshot/Velocity Shot and then multiplies by separate full gear haste and reduced other-haste coefficients: `rangedRate=(10/9)*gearRate*(1+O/(1+O))` for nonnegative O. The coefficient keeps the old +25% baseline's 0.75 haste time multiplier. **The 600 ms minimum ranged interval remains.**

Both rates have no traditional haste-category caps. Existing melee minimum-delay clamping (20% of weapon base delay) still provides an effective maximum attack rate; this is a timing safety floor, not a category cap. Existing negative haste remains a slowdown.

## TP and damage boundaries

Normal per-hit TP is unchanged, including standard delay-based TP calculations, Store TP, combat Regain and enemy TP feed. This preserves traditional benefits of haste gear while preventing an untested universal TP penalty. **Extreme high-speed Souls have not yet received their separate TP-efficiency or damage-budget profile.** Do not grant uncontrolled 4–5× speed multipliers to Souls until those are implemented and measured. This is a foundation, not the completed Soul balance phase.

## Validation

Deterministic formula checks: `python scripts/test-attack-rate-haste.py`.

Patch order: existing patch 0014 (auto ranged), 0042 (configured cap), 0043 (preserve swing time), followed by new patch 0044 (unified attack rate). Sequential patch context matching against upstream `LandSandBoat/server` `base` was verified for these target hunks; this is **not** equivalent to `git apply --check` across the complete server patch series, a C++ build, or live timing measurement.

**Before moving to main:**
1. Apply the full ordered patch series to the server's actual pinned LandSandBoat checkout in a disposable worktree, run `git apply --check`, compile `xi_map`, check Lua syntax.
2. Compare baseline attack cadence and TP earned against an unmodified `main` client/server. Check migration for logged-in characters and no double-counting after relog, Soul swap, zoning.
3. Test +3%, +5%, +10%, +20%, +25% actual gear haste; test magic/ability/Soul haste totals beyond old caps and verify monotonic rates, enemy TP feed and attack animations.
4. Repeat with H2H, dual wield, two-handed weapons, slow, Hundred Fists, Chi Weaver, Snapshot, Velocity Shot, ranged ammo depletion, and boss fight combat.
5. Confirm actual attacks, TP/min, WS/min and DPS in 60–120 second samples for representative level-75 Souls.
6. Only then push to `main` and test on the playable server with a rollback plan.

No WS Evolution / talent files were modified.
