# Lancer implementation report

DRG Soul `lancer` (LNC), Tier 1 damage. Equip its Soul Crystal or use `!spec set lancer` from Lv. 10. An ordinary polearm supports both actions without weapon skill talents or a support subjob. Polearm is the allowed WS family.

- High Jump (67, launcher 579) becomes **Spineshatter Vault**. It launches between 4 and 12 yalms, lands on validated ground and strikes the enemy once. An ordinary hit or miss spends 18 seconds of recast. Obstructed or invalid landing terrain costs three seconds with no motion or damage.
- Short lanes deal 1.6× normalized spear damage. Long lanes over seven yalms deal 2.2/2.5/2.5/2.8× at Lv. 10/30/50/70+.
- Jump (66, launcher 578) becomes **Piercing Jump**. From Lv. 50, a long Vault that takes HP opens a five-second window against the same enemy. The next damaging Jump gains 15%, rising to 20% at Lv. 70, and spends the opportunity.
- Lancer has no wyvern or native magic kit. The HUD shows launch distance, Vault recast and the follow-up window. See the [player guide](../../guides/lancer.md).

Three focused tests, 100 accessible regression tests, strict Lua wiki and roster checks, 16 native syntax checks, two shared Lua syntax checks and 1,109 launcher manifest checks passed. Launcher commit `5307c576b30e7bdf3854ab69d04f436320d48544`.

**Manual Verification Required** — Live validation of landing and client position under movement, geometry with walls/elevation/doors, no navigation data, large target hitboxes, animation, hit/miss/absorb and target-matched Jump, level sync and Lv. 10/30/50/75 DPS tuning. Four existing Combat Analytics tests require loopback.
