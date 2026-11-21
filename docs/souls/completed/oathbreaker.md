# Oathbreaker implementation report

PLD Soul `oathbreaker` (OTB), Tier 1 damage. Select it with `!spec set oathbreaker` from level 10. Great Sword is the sole WS-eligible weapon skill family and the ordinary starting gear uses a Great Sword.

- Condemn boosts ordinary Great Sword swings by 10/13/16/18% at levels 10/30/50/75 and adds 10% to enemy damage taken. Absolution turns a single hit costing at least 8% maximum HP into a 5/5/7/7-second retaliation window. Both vows are available at level 10 and can change outside combat.
- Sentinel and Divine Emblem become Vow of Condemnation and Vow of Absolution. Shield Bash becomes the single-target, Great Sword based Reckoning, which gains double damage during a matching retaliation window. Banish becomes Ashen Judgment, a 15 MP single-target ranged spell. Absolution is an offensive vow in keeping with the Tier 1 role. The kit functions without WS talents or a support subjob.
- HUD tracks the active vow and target-matched retaliation. The wiki has four Soul-specific actions and uses the actual server recast overrides. See the [player guide](../../guides/oathbreaker.md).

Automated checks passed: 3 focused tests, 79 tests outside the restricted loopback group, strict roster and Lua wiki checks, 12 native syntax checks, and 1,109 manifest entries. Launcher commit `7c372adf1535e52cc1699f8b0958f9cbce755a47`.

**Manual Verification Required** — In-game name and menu refresh, native recast timers, shield/Great Sword equip swaps, miss and absorption behavior, live HUD timing, level sync, and level 10/30/50/75 combat tuning. Four pre-existing Combat Analytics HTTP tests require loopback access.
