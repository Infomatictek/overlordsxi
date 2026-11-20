# Sniper implementation report

RNG Soul `sniper` (SNP), Tier 1 damage. Equip its Soul Crystal or use `!spec set sniper` at Lv. 10. An ordinary crossbow and bolts work from unlock. Marksmanship is the permitted WS family, and both normal ranged attacks and the core loop work with zero WS talents.

- Shadowbind (57, launcher 569) becomes **Sightline Shot**. A three-second aim fires one projectile up to 20 yalms away. It uses the native ranged hit, damage, and ammo pipeline with a scoped profile. A resolved hit or miss spends one projectile and starts a 12-second recast. Barrage, Sange, Double/Triple Shot and Recycle cannot change the shot count or cost.
- Moving beyond one yalm, losing line of sight or the engaged target, losing compatible equipment or being incapacitated cancels without ammunition cost and starts a three-second retry. The server validates the target again at release.
- Sharpshot (59, launcher 571) becomes **Deep Sight** at Lv. 50. Toggle a four-second aim to increase Sightline from the 2.3× standard shot to 2.8× at Lv. 50 and 3.2× at Lv. 70. The Lv. 10 shot starts at 2.0×. Added Ranged Accuracy scales +10/20/20/30 at Lv. 10/30/50/70+.
- The damage modifier is confined to the aimed shot. Ordinary ranged attacks, existing other-Soul abilities and non-Sniper Eagle Eye Shot keep their own resolution. RNG's Soul kit has no native spells. The HUD shows aim, recast and current mode. See the [player guide](../../guides/sniper.md).

Three focused tests, 89 accessible regression tests, strict Lua wiki and roster checks, 15 native syntax checks and 1,109 launcher manifest checks passed. Launcher commit `38862b165b8d4964bc31f43086410c12f1f5aaf9`.

**Manual Verification Required** — In-game menu identity, target and movement interruption, one-ammo hit and miss, zero-ammo cancellation, engine animation and combat log presentation, crossbow and gun performance, level sync, and Lv. 10/30/50/75 stationary and moving-enemy trials. The native attack uses the standard ranged animation and result line. Four existing Combat Analytics API tests require loopback access.
