# Scourge implementation report

DRK Soul `scourge` (SCR), Tier 3 support. Equip its Soul Crystal or use `!spec set scourge` at Lv. 10. The gear profile supplies a Scythe, its permitted WS family. The support loop works with zero WS talent points and any subjob.

- Absorb-STR (266) becomes **Withering**, a Lv. 10 curse on physical TP move and weaponskill damage. Bio (230) becomes **Ash**, a Lv. 10 curse on damage from an enemy's spells. The damage curses scale to 8/8/12/15% at Lv. 10/30/50/70+.
- Absorb-MND (271) becomes **Famine** at Lv. 30. It reduces the enemy's standard self-cures and healing TP moves by 20/25/30% at Lv. 30/50/70+. All curses cost 10 MP, cast in one second and share a 12-second recast.
- The target holds one curse at a time. Full and partial landings last 24 and 12 seconds respectively. Full resist preserves the current curse. Explicit Dark immunity can grant an eight-second, half-potency ward to the caster's party for one matching hit or self-heal. A personal 24-second recast and the enemy's same-category curse gate the ward.
- Arcane Circle (50, launcher 562) becomes **Rite of Malice**, a Lv. 10 self-only MP recovery JA, with 14/18/22/28 MP at Lv. 10/30/50/70+ on a 24-second recast. It requires your curse or ward on the engaged enemy.
- HUD shows the curse, immunity ward, and recasts. All four actions and their unlocks are published through wiki generation. See the [player guide](../../guides/scourge.md).

Four focused tests, 86 accessible regression tests, strict Lua wiki and roster checks, 12 native syntax checks, and 1,109 launcher manifest entries passed. Launcher commit `2229742f63489e0dac751cfae774fed09d2dc002`.

**Manual Verification Required** — In-game names and cast/recast timing, two Scourges on immune and partially resistant bosses, real TP/spell damage and NPC self-heal coverage, pet/trust party ward behavior, level sync and the Lv. 10/30/50/75 combat loop. Four existing Combat Analytics API tests require loopback.
