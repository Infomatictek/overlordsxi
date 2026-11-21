# Soul Implementation Report — Beastspeaker

**Queue 21 of 25 · BST `beastspeaker` / BSP · Tier 3 support · Lv. 10–75**

- Gauge becomes **Read Quarry**. Tame becomes **Expose Quarry**. Call Beast becomes **Call Tracker**, a jug-free mandragora summon. Fight, Heel and Leave become tracker commands. Stay becomes **Choose Weakness** at Lv. 50.
- From Lv. 10, a landed hit by the assigned tracker exposes the recorded weakness for the party. Each party member can claim at most two matching regular hits, one per attack round. Single-hit ranged attacks can claim. Weapon skills, skillchains and landed multi-hit volleys are excluded.
- Known-family exposure scales from 8% to 12%. The unknown-family fallback scales from 4% to 6%. At Lv. 30 the read tracks subsequent completed hostile actions. At Lv. 50 exposure lasts ten seconds and the player can cycle the weakness. Axe is the enabled weapon-skill and talent family.
- The HUD shows family, weakness, observed attack, pending tracker order and active exposure. The [player guide](../../guides/beastspeaker.md) and wiki match all seven actions. Launcher commit `12238365431a324427f67920329e05b9303de7f9`. The [tracker](../FINAL_25_PROGRESS.md) records the server checkpoint.

**Automated verification.** Four focused tests, 119 accessible regression tests, strict wiki and roster audits, nine native C++ syntax checks, a Lua HUD fixture and all 1,109 manifest entries passed. Four Combat Analytics tests require loopback access unavailable in this environment.

**Manual Verification Required.** Test the no-talent starter loop with a party. Verify a known family and an unknown-family boss, companion hits in an instanced fight, solo and party contribution, physical attack types, two Beastspeakers against one quarry, and damage at Lv. 10 and Lv. 75. Compare multiattack rounds, ranged shots, weaponskills and skillchains in the combat log. Confirm the native names and descriptions and verify kit reset when switching among the three BST Souls.
