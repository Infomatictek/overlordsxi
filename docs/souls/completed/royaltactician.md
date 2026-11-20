# Royal Tactician (RDM) — Soul Implementation Report

**RYT · Tier 3 Support · Crystal slot RDM 2 · Lv.10–75**  
Select with `!spec set royaltactician` or Crystal Socket. Verified against the canonical roster.

## Combat loop and progression

Land a single-target enfeeble and direct its order to one party member. Break Stride and Seize Initiative open **Advance**. Obscure Aim and Quiet Front open **Recompose**. **Issue Order** places the latest order on one party PC or yourself within 15y. You have six seconds to issue it. A delivered order lasts eight seconds, and orders of the same kind use the strongest active potency.

| Effective level | Advance | Recompose | Other milestones | M. Accuracy / Max MP |
|---|---|---|---|---|
| 10 | +10% Accuracy | 15% actual MP refund | Both orders usable on self or allies | +10 / +6% |
| 30 | +10% Accuracy, +5 Store TP | 20% refund | Unravel Defense repeats the last issued order | +18 / +10% |
| 50 | +10% Accuracy, +5 Store TP | 20% refund | Full resist can open a half-potency order on a 24s lockout | +28 / +14% |
| 70–75 | +15% Accuracy, +8 Store TP | 25% refund | Higher full-strength order potency | +38 / +18% |

Advance snapshots melee Accuracy when issued. Recompose is consumed only by a completed, cost-bearing, non-instant spell and refunds a portion of MP actually paid. Sword is the permitted WS family, with normal TP, baseline talents and attack speed. The kit has no pet and works at Lv.10 with zero talents. Trusts remain available.

## Native actions and HUD

| Action | Internal spell or server/client ability ID | Lv. | Base cast / recast |
|---|---|---|---|
| Break Stride | 56 | 10 | 2s / 20s |
| Seize Initiative | 58 | 10 | 3s / 10s |
| Obscure Aim | 254 | 10 | 2s / 10s |
| Quiet Front | 59 | 10 | 3s / 10s |
| Unravel Defense | 260 | 30 | 3s / 10s |
| Issue Order | 275 / 787 | 10 | Instant / 18s |

The HUD shows the pending order, half strength, window and recast. The [player guide](../../guides/royaltactician.md) and all six repurposed actions were verified in generated wiki data.

**Launcher commit:** `69916af58954ba4fc0e077eb4c4d7b25b8686c6a` on `feat/final-25-souls`.

## Verification

- Three focused tests and 67 non-loopback regression tests passed. Tests cover latest order, repeat, half-potency lockout, accurate replacement and cleanup, and per-Soul action scope.
- Strict coverage audit: 47 registered and 19 planned. Exact Lua wiki build validated all six actions. Launcher TSVs and 1,109 manifest entries passed.
- Native overlay applies after the previous Soul patches. Eleven touched or regression-sensitive C++ units passed MSVC syntax checks.
- **Manual Verification Required:** Play Lv.10/30/50/70/75 with ordinary gear and zero talents. Verify actual enfeeble landing/resist/no-effect messages, self and party use, Advance cleanup on zone/Soul change, actual Recompose refund after successful, interrupted and instant casts, two-Tactician priority, and client identity across RDM Souls.
