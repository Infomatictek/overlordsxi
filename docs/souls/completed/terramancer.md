# Soul Implementation Report — Terramancer

**Queue 24 of 25 · GEO `terramancer` / TRM · Tier 1 damage · Lv. 10–75**

- Stone becomes **Stone Chip**, Stone II becomes **Shallow Fault**, Stone III becomes **Deep Fault**, and Full Circle becomes **Cancel Fault**. Stone Chip and Shallow Fault enable a Lv. 10 opener. Deep Fault unlocks at Lv. 30.
- Placement spends percentage MP once. Both faults share an eight-second recast. At detonation, the original enemy, claim, spawn, zone, battle and position are revalidated. Only the original quarry can take the delayed hit. Eruptions use native earth mitigation and the damage multiplier scales through Lv. 75.
- Club and Staff are the weapon-skill and talent families. The standard profile supplies Club and Handbell gear. The HUD shows fuse, tile occupancy, affected quarry and shared recast. The [player guide](../../guides/terramancer.md) and wiki cover the four native actions. Launcher commit `91cd730bc567cfb0074380a51d745cbc65fe1991`.

**Automated verification.** Four focused tests, 131 accessible regression tests, strict wiki and roster audits, eight native C++ syntax checks, Lua HUD fixture and all 1,109 launcher entries passed. Four Combat Analytics loopback tests require unavailable network access.

**Manual Verification Required.** Confirm Lv. 10 claim and damage without weapon-skill talents, both native spell names and animations, recast display after detonation, interrupt handling, and movement across both three-yalm limits. Check claim transfer, a second mob on the mark, death, zoning, and Soul changes. Compare stationary-boss damage at Lv. 10, 30, 50 and 75.
