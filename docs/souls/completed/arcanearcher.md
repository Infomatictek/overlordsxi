# Arcane Archer implementation report

RNG Soul `arcanearcher` (ACA), Tier 3 support. Equip its Soul Crystal or use `!spec set arcanearcher` at Lv. 10. The gear profile provides a bow and arrows. Archery is the eligible WS family. The party loop works without WS talents or a specific subjob.

- Shadowbind (57, launcher 569) becomes **Attunement Arrow**, a single-projectile bow attack up to 20 yalms. A resolved shot spends one arrow and starts a 16-second recast. Only a hit that takes enemy HP places a mark.
- Sharpshot (59, launcher 571) and Camouflage (58, launcher 570) select the next or previous element among Fire, Ice, Wind, Earth, Lightning and Water. All three actions unlock at Lv. 10. RNG's kit has no native spells.
- One live mark per enemy and per archer. The first matching party direct elemental spell or skillchain that costs the enemy HP consumes the mark. Ordinary spell damage qualifies, including the ordinary portion of an Astromancer spell. Damage-over-time ticks, outsiders and wrong elements leave the mark intact. A solo archer can consume its own mark with a matching elemental bow weapon skill at half potency if its elemental component lands.
- Mark duration and party bonus scale to 10/12/12/14 seconds and 12/15/18/20% at Lv. 10/30/50/70+. The HUD shows selected element, current target's mark and recast. See the [player guide](../../guides/arcanearcher.md).

Four focused tests, 93 accessible regression tests, strict Lua wiki and roster checks, 15 native syntax checks, three shared Lua syntax checks and 1,109 launcher manifest checks passed. Launcher commit `53ed85a9a1517ff95cc1a3792b258c2e2963ba07`.

**Manual Verification Required** — Compare two simultaneous matching hits and two archers in a live party. Verify miss/ammo and ranged animation, party and pet follow-ups, actual skillchain element selection, Fire/Flaming Arrow solo payoff, target-mark HUD timing, level sync and Lv. 10/30/50/75 combat tuning. The shot uses the standard ranged result line. Four existing Combat Analytics tests require loopback.
