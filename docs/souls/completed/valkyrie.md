# Valkyrie (WHM) — Soul Implementation Report

**VLK · Tier 3 Support · Crystal slot WHM 3 · Lv.10–75**  
Select at Lv.10 via `!spec set valkyrie` or Crystal Socket. Identity and role match the canonical roster.

## Combat loop and progression

Designate one Wingmate. When hostile mob damage interrupts their cast, claim the interruption with **Valkyrie's Escort** and let the Wingmate begin a protected retry of that exact spell. Each window lasts up to six seconds. One Valkyrie can claim an interruption. Movement, manual cancellation, incapacity and Silence do not open an Escort window. Ally spells provide the strongest payoff. Self-targeting and **Vigil Lance** make the loop usable solo at Lv.10.

| Effective level | Escort range | Ally / self refund of actual retry MP | Bonus Polearm Skill / Max HP / Magic Evasion |
|---|---|---|---|
| 10 | 15y | 0% / 0% | +10 / +6% / +8 |
| 30 | 15y | 15% / 0% | +19 / +10% / +15 |
| 50 | 20y | 15% / 7% | +28 / +14% / +22 |
| 70–75 | 20y | 25% / 12% | +37 / +18% / +29 |

The server scopes a Polearm skill baseline and five ordinary spears to Valkyrie. Bronze Spear is available at Lv.10. Polearm is the only permitted WS family and still uses the existing talent rules. Escort depends on timing and the ally's next action. There is no pet, shared TP or altered attack speed. Trust summons retain native access.

## Actions and HUD

| Action | Server / client ID | Base timing and targets |
|---|---|---|
| Wingmate | 273 / 785 | 5s recast; self or one party PC within 15y |
| Valkyrie's Escort | 275 / 787 | 25s recast; Wingmate within 15y, 20y starting at Lv.50 |
| Vigil Lance | 28 | 2.5s cast / 15s recast / 15 MP; single enemy |

The HUD shows Polearm and Wingmate readiness, claim/retry windows and Escort recast. The [player guide](../../guides/valkyrie.md) and three custom actions generate in the wiki. WHM test gear picks a compatible Polearm for Valkyrie and a Staff for Zealot.

**Launcher commit:** `463d7b43b040f48a47e34aaf0cc672e089577b9c` on `feat/final-25-souls`.

## Verification

- Seven focused WHM tests and 54 tests outside the loopback-only Combat Analytics suite passed. Tests cover single-claim behavior, invalid targets, progression, cleanup and Zealot fallback.
- Strict roster audit: 43 registered and 23 planned. Strict wiki generation and nine action wiki tests passed. Validated all three Valkyrie entries at Lv.10.
- Patch application and nine C++ syntax checks passed. Launcher TSVs and all 1,109 manifest entries verified.
- **Manual Verification Required:** In a built server and two clients, verify Bronze Spear and polearm WS availability, a hostile damage interrupt versus a manual cancel, successful and canceled retries, same-spell gating, actual MP refund and range at effective Lv.10/30/50/70/75, race between two Valkyries, and native target/menu/HUD behavior after switching Souls or zoning.
