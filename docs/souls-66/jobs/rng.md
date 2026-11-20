# RNG · Soul specifications

[Sniper](#sniper) · [Huntsman](#huntsman) · [Arcane Archer](#arcane-archer) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Sniper | Hold a sightline | A clear firing lane and few mandatory movements |
| Huntsman | Command the beast tank | A pet must hold hate while its fragile master directs it |
| Arcane Archer | Call an elemental arrow mark | One ally can land a specific elemental follow-up |

## Sniper

RNG 1 · SNP · Damage · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Plant at a safe firing lane and aim at one claimed target. Move to escape a telegraph or hold still for a single accurate shot. Normal ranged shots cover downtime.

**Why choose it.** Pick predictable one-shot precision with low ammo consumption. Flintlock floods a target with independent pistol fire. Frequent knockbacks punish Sniper's aim. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set sniper` once the Soul is registered. Gun or crossbow, matching bullets/bolts; dagger or axe as ordinary melee sidearm. Ranged accuracy then ranged attack.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Sightline Shot, Sharpshot, Camouflage, Eagle Eye Shot. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Sightline Shot 20y, 3s aimed windup, 12s recast. At completion spend one ammo and roll one ordinary ranged attack with +10 RACC and ×2.0 damage. Moving >1y from start, losing LOS, changing target or incapacitation cancels aim, no ammo, 3s retry. Resolved miss spends ammo/recast. |
| 30–49 | +20 RACC, ×2.3. Successful hits keep ordinary TP return for exactly one shot. |
| 50–69 | A 4s full aim increases to ×2.8. A player may release at 3s for the 30-tier shot. No extra projectile or forced WS. |
| 70–75 | Full aim ×3.2, +30 RACC. Boss position and cover continue to matter. Eagle Eye Shot cannot inherit this multiplier. |

**HUD.** Aim progress, lane validity and ammo.. Show server-confirmed events and state only.

**Acceptance fight.** Count projectiles, ammo, TP and claims on successful, interrupted and missed shots. Compare a stationary boss and forced movement. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from tracking, sightlines and ranged weapons and its signature decision (“Hold a sightline”). This is a setting-inspired hook for later writing.

## Huntsman

RNG 2 · HNT · Tank / HybridSupport on main; Tank with either redesign beast · Partially Implemented · [server registration and hooks](../../../modules/custom/lua/rng_specs.lua#L952) · [staged implementation](https://github.com/Infomatictek/overlordsxi/blob/18bb7e3168d825e715f21fd557a8464fb038275d/modules/custom/lua/rng_specs.lua) · [existing guide](../../guides/huntsman.md)

**Player decision.** On main a ranged WS feeds the pet. The redesign moves the master into axe range. Direct a Tusker to hold a punishing string or a Saurian to snap threat, then stay close enough for Beastguard.

**Why choose it.** Choose mobile command of a beast that actually holds the boss. Alpha Warden needs the master to take hits. Losing the beast leaves the Ranger personally vulnerable. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set huntsman` once the Soul is registered. Redesign uses one-handed axe, optional offhand dagger. Commands work without a custom horn. Accuracy, pet HP and threat. Preserve ranged gear and learned ranged WS in storage.

Pinned main WS specialization skills: archery, marksmanship. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Fight, Heel, Leave, Stay, four existing summons and family orders, Primeval Takedown, Predator's Feint 489 and Guardian's Call 490. Last Whistle is the branch's emergency pet-loss mechanic. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Fight, Heel, Stay, Call Wild Raaz, Call Stalker Raptor, Rimetusk Gore, Saurian Rend, Primeval Takedown, Call Cehuetzi, Call Gabbrath. |
| Existing traits | Warden's Ration (181), Primeval Pack (182), Apex Bond (183). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Wild Raaz or Stalker Raptor, Fight, Heel, Rimetusk Gore or Saurian Rend, Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Ranged baseline (redesign values follow below) | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| Archery Skill | Lv.10 / 30 / 50 / 70+ | +15 / +25 / +35 / +50 |
| Marksmanship Skill | Lv.10 / 30 / 50 / 70+ | +15 / +25 / +35 / +50 |
| Ranged Accuracy | Lv.10 / 30 / 50 / 70+ | +12 / +20 / +28 / +38 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Source or integration decision.** Use the [melee redesign](https://github.com/Infomatictek/overlordsxi/blob/18bb7e3168d825e715f21fd557a8464fb038275d/docs/guides/huntsman.md) as target and the pinned main module as rollback reference. Axe WS ration heals 10/12/14/16% pet max HP, +200 pet TP, and shaves 3s off eligible recasts at most every 6s. Beastguard within 8y gives 25/28/32/35% eligible area mitigation. At 75 unlock Cehuetzi/Gabbrath. Redesign Last Whistle is a pet-loss recovery path; a custom horn item is optional.

**HUD.** Pet form, pet threat, Beastguard range and Last Whistle. Show server-confirmed events and state only.

**Acceptance fight.** At 8y and beyond, log master damage from conal and single-target hits. Kill the pet and test recovery. Both redesign families must hold hate. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from tracking, sightlines and ranged weapons and its signature decision (“Command the beast tank”). This is a setting-inspired hook for later writing.

## Arcane Archer

RNG 3 · ACA · Support · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Choose an element, land one arrow and tell a party member to follow with that element. A mismatched hit leaves the mark available for the intended ally.

**Why choose it.** Choose a single precise ally payoff from range. Herald rewards several participants over a window. Imperial Archer weaves its own bow and blade WS. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set arcanearcher` once the Soul is registered. Bow and arrows, dagger or axe sidearm. Ranged accuracy and magic accuracy.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Attunement Arrow (six mutually exclusive elemental variants), Sharpshot, Camouflage. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Six arrow aspects share 16s recast. One arrow, ordinary ranged accuracy, 20y. On hit mark one enemy for 10s. First matching direct elemental spell or elemental skillchain from another same-party PC consumes for +12% damage on that event, after resists. Solo own qualifying elemental WS at half bonus. Miss spends ammo but sets no mark. |
| 30–49 | Bonus 15%, 12s mark. |
| 50–69 | Bonus 18%. Compatible allied pet action may count once for its participating owner; a multi-hit or chain is one event. |
| 70–75 | Bonus 20%, mark lasts 14s. One mark per target, one per archer, nonstacking, newest replaces prior. Party bonus excludes Astro's added Ancient component. |

**HUD.** Element, enemy and unclaimed mark time.. Show server-confirmed events and state only.

**Acceptance fight.** Resolve two matching ally hits simultaneously; apply bonus once. A wrong element, DoT or unrelated party cannot claim it. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from tracking, sightlines and ranged weapons and its signature decision (“Call an elemental arrow mark”). This is a setting-inspired hook for later writing.
