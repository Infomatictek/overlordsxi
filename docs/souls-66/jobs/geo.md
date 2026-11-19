# GEO · Soul specifications

[Diviner](#diviner) · [Verdant](#verdant) · [Terramancer](#terramancer) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Diviner | Maintain a useful corridor | The party can hold a line whose endpoints you control |
| Verdant | Position and renew a luopan | A group can stand within a healing sanctuary |
| Terramancer | Predict a fault impact | The boss will stay still for a delayed single-target detonation |

## Diviner

GEO 1 · DIV · Support · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Place one convergence anchor and stand at the other end of a corridor. Move to preserve the line between yourself and the anchor as the fight shifts.

**Why choose it.** Choose a positional support for a team that can hold a lane. Verdant heals inside a circular sanctuary. Diviner earns value by guiding allies through space, and loses it when the group spreads. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set diviner` once the Soul is registered. Club or staff and handbell. HP, geomancy skill and positioning.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Lay Meridian, Recall Meridian, Indi-Precision, Indi-Focus. |
| Job abilities and commands | Full Circle, Meridian Shift. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Lay Meridian: 1.5s cast, 6% max MP, 18s recast, one ground point at caster's current position for 30s. Caster is mobile second endpoint. Segment is active at length 3–15y, same floor (vertical difference ≤3y). Allies within 2y of segment gain +12 accuracy and magic accuracy from the next 1s sample. Leave line and lose benefit within 1s. Recall is free. No extra luopan needed. |
| 30–49 | Line bonus +20. Shift moves fixed anchor to caster position at 20s CD without refreshing lifetime. |
| 50–69 | Line width 2.5y, bonus +28. Optional Indi-Precision/Focus apply native nonstacking rules with like effects; strongest bonus to same stat only. |
| 70–75 | Bonus +35, anchor lasts 40s. End on zone, death or Soul change. Multiple Diviners grant only strongest segment. |

**HUD.** Endpoints, active length, remaining life and inside/outside state.. Show server-confirmed events and state only.

**Acceptance fight.** Move past both ends, across the edge and onto another floor. No bonus beyond the segment ends plus the allowed width or across floors. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from handbells, luopans and geomantic positioning and its signature decision (“Maintain a useful corridor”). This is a setting-inspired hook for later writing.

## Verdant

GEO 2 · VRD · Healer · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/geo_specs.lua#L228) · [existing guide](../../guides/verdant.md)

**Player decision.** Position a luopan for a group that can stay in its sanctuary. Renew the luopan with Cure, Indi/Geo magic or a qualifying WS to trigger a group surge. Move when the encounter forces the party out.

**Why choose it.** Pick for sustained attrition around a stable point. Medic can move its cures with the group and Diviner rewards holding a narrow line. Frequent relocation costs coverage. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set verdant` once the Soul is registered. Club/shield or staff, handbell. MND, geomancy, MP and pet durability.

Pinned main WS specialization skills: club, staff. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Cure I–IV, learned Indi and Geo support spell families available to the main job through 75, including Regen and Refresh lines. |
| Job abilities and commands | Full Circle, Life Cycle, Dematerialize, Lasting Emanation, Ecliptic Attrition, Bolster, Entrust and the two registered Soul JAs. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Verdant Renewal, Canopy of the Ancients. |
| Existing traits | Sylvan Bloom (175). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: A starter Geo spell that places a luopan, an Indi spell, Cure, Verdant Renewal and Canopy of the Ancients. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +28% |
| Max MP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +28% |
| MND | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +32 |
| VIT | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +32 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Living Luopan Sanctuary: Luopan pulses Verdant Bloom every 3s (15y): 6/8/10/12% Max HP heal, +15 MP, and overheal Barkskin Stoneskin (cap 25% Max HP).
- Sylvan Resonance: Indi/Geo/Cure or Club/Staff WS heals Luopan to 100% HP and triggers Nature's Surge (16% Max HP party heal + 1-debuff cleanse).
- JA Enhancements: Life Cycle (15s CD, 0 self-HP loss + 25% party heal) & Bolster (doubles Verdant Bloom).
- Verdant Renewal (20s CD, 30% HP AoE heal + 3-debuff cleanse + 25 + 3.5% Max HP/t Regen + 8/t Refresh 15s) & Canopy of the Ancients (25s CD, 12s -18% DT + Knockback Immune + 10% AoE heal per spell/WS).

**HUD.** Luopan HP, bloom radius and Canopy. Show server-confirmed events and state only.

**Acceptance fight.** Move an ally out of range, heal with a nearly full luopan, then dismiss it. Check the surge and overheal shield independently. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from handbells, luopans and geomantic positioning and its signature decision (“Position and renew a luopan”). This is a setting-inspired hook for later writing.

## Terramancer

GEO 3 · TRM · Damage · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Mark the predicted position of one boss, then keep it inside the fault until the eruption. Decide between a quick shallow fault and a delayed deeper strike.

**Why choose it.** Pick positional burst on a boss whose movement you understand. Sage's Helix travels with its victim, while Diviner maintains a corridor for allies. A bad prediction can waste an entire cast. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set terramancer` once the Soul is registered. Staff or club and handbell. INT, MAB, magic accuracy.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Shallow Fault, Deep Fault, Stone I–IV, Gravity (native resist rules). |
| Job abilities and commands | Survey Ground (reads current fault radius and remaining time, free). |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Shallow Fault 1s cast, 7% max MP, 8s shared recast, range 18y. Snapshot target and position on cast completion. At +2s if same claimed enemy alive within 3y and same floor, hit that target only for 1.8× a level-appropriate Stone nuke after resists. No field pulse or replacement target. |
| 30–49 | Deep Fault: 1.5s cast, 12% MP, +4s fuse, 3y, 2.8× same Stone reference. Both faults share the timer; one outstanding per caster. |
| 50–69 | Deep Fault 3.2× and Shallow 2.0×. Existing fault disappears on Soul change/zone, enemy death or loss of claim. |
| 70–75 | Deep Fault 3.6×, shallow 2.2×. Do not move the marker with the enemy. A miss spends the cast and MP. Spectators are never damage targets. |

**HUD.** Fixed position, locked enemy, radius, fuse and hit/miss.. Show server-confirmed events and state only.

**Acceptance fight.** Put a second mob on the marker and move the claimed target away. Neither mob should take damage. Repeat with the original target stationary. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from handbells, luopans and geomantic positioning and its signature decision (“Predict a fault impact”). This is a setting-inspired hook for later writing.
