# SMN · Soul specifications

[Primalist](#primalist) · [Celestial](#celestial) · [Herald](#herald) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Primalist | Commit an avatar's Rage | Elemental vulnerabilities rotate between boss phases |
| Celestial | Maintain an avatar sanctuary | Grouped allies need a Ward response and continuous sustain |
| Herald | Call an avatar accord | Several allies can follow an announced element together |

## Primalist

SMN 1 · PRM · Damage · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Choose an avatar for a coming elemental phase, commit its next Rage and hold the pact until resistance favors it. A swap changes the damage option but costs preparation time.

**Why choose it.** Pick adaptable elemental pet burst when vulnerability changes across phases. Astromancer commits its own long cast and Celestial uses Wards for recovery. A bad avatar choice wastes the Rage window. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set primalist` once the Soul is registered. Staff, summoning skill, pet magic accuracy, MP and pact damage.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Carbuncle, six prime elemental avatars, and Fenrir where already learned. Carbuncle and one starter elemental avatar are temporary Soul access at 10. |
| Job abilities and commands | Assault, Retreat, Release, Blood Pact: Rage, Astral Flow, Elemental Siphon, Challenge Aspect. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Challenge Aspect, 20s CD, 2s preparation, binds living avatar and its chosen target for 12s. Its next matching single-target damaging Rage gains 20% of base damage if the element is among the target's lowest resistances, otherwise ordinary damage. Give each starter avatar a single-target elemental starter Rage using native level-scaled pact base at normal MP/recast. Solo fallback Carbuncle light Rage. |
| 30–49 | Bonus 25%. Add two chosen prime avatars as Soul loans, selected out of combat. Native unlocked avatars remain available. |
| 50–69 | Six prime avatars available while active. Bonus 30%. Physical-only Rage works normally without an elemental bonus. |
| 70–75 | Bonus 35%, window 15s, one qualifying pact. Changing avatar clears the promise. No Ward resets or shared-target saturation. |

**HUD.** Avatar/element, promise, target and remaining window.. Show server-confirmed events and state only.

**Acceptance fight.** Swap avatar mid-commit and send pact to a different target. Test correct and resistant elements. Check master contributes no duplicate elemental hit. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from avatars, pacts and elemental allegiance and its signature decision (“Commit an avatar's Rage”). This is a setting-inspired hook for later writing.

## Celestial

SMN 2 · CEL · Healer · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/smn_specs.lua#L242) · [existing guide](../../guides/celestial.md)

**Player decision.** Keep an avatar deployed to maintain Sanctuary, choose the Ward for the incoming pressure and use Siphon or eligible WS for Starlight Mend.

**Why choose it.** Bring sustained avatar-centered recovery with a Ward response. Herald grants offensive teamwork windows. Losing or moving the avatar changes coverage. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set celestial` once the Soul is registered. Staff or club. MP, summoning skill, cure potency and avatar survival.

Pinned main WS specialization skills: staff, club. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Summons of accessible avatars, including starter Carbuncle; no player-cast nuke family. |
| Job abilities and commands | Blood Pact: Ward and the equipped avatar's level-eligible Wards, Release, Assault, Retreat, Avatar's Favor, Elemental Siphon, Astral Flow. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Astral Benediction, Celestial Convergence. |
| Existing traits | Astral Sanctuary (173). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Carbuncle, a legal Ward, Astral Benediction and Celestial Convergence. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +28% |
| Max MP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +28% |
| MND | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +32 |
| CHR | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +32 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Astral Avatar Resonance: Summoned Avatar projects Celestial Sanctuary (15y): 12/16/20/24 + 1.5% Max HP/t Regen, +4/6/8/10 MP/t Refresh, -10% DT.
- Ward-Loop & Starlight Mend: Blood Pact: Ward has a flat 12s recast (6s Apogee); Wards and Staff/Club WSs heal Avatar 50% HP and pulse 15% Max HP party heal.
- JA Enhancements: Elemental Siphon (20s CD, 45% MP without dismissing Avatar + 20% AoE heal) & Astral Flow (5s Ward CD, 25% Stoneskin).
- Astral Benediction (22s CD, 32% HP AoE heal + 3-debuff cleanse + Reraise III) & Celestial Convergence (25s CD, 12s -18% DT + +30 MEVA + 10% MP per Ward/WS).

**HUD.** Avatar, sanctuary coverage and Ward recast. Show server-confirmed events and state only.

**Acceptance fight.** Cast Ward with an ally inside then outside Sanctuary. Confirm avatar and player recovery fire once per intended trigger. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from avatars, pacts and elemental allegiance and its signature decision (“Maintain an avatar sanctuary”). This is a setting-inspired hook for later writing.

## Herald

SMN 3 · HLD · Support · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Select an avatar, announce its accord before your party acts, and coordinate several allies to follow that element during one short window.

**Why choose it.** Choose for a planned elemental party sequence. Arcane Archer pays one matching hit on one marked enemy. Primalist amplifies its own pact. Herald's payoff grows with participating allies. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set herald` once the Soul is registered. Staff or club. Summoning skill, MP and pet survival.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Carbuncle and six prime elemental avatars, with starter and Soul loan access as specified here. |
| Job abilities and commands | Astral Accord, Assault, Retreat, Release, Elemental Siphon, Blood Pact: Rage for ordinary single-target pacts. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Accord, 30s CD, 8s duration, 15y at cast, requires living avatar and costs 8% max MP. Window applies to in-range party PCs. Each distinct PC's first matching direct elemental action gains 8% ordinary damage. Matching pet pact counts for owner. Starter Carbuncle/light plus one prime, both loaned; use own Rage for solo follow-through. No healing wards. |
| 30–49 | 10% bonus, two additional prime avatar loans chosen outside combat. |
| 50–69 | Six prime avatars available. Up to one eligible action per member per window, across all targets. Dismissing/changing avatar ends the contract. |
| 70–75 | 12% bonus, 10s window. One accord per actor at a time, same-element refresh never restores a claim. Exclude extra Soul burst, recursive procs and periodic ticks. |

**HUD.** Announced element, time left and named allies who have followed.. Show server-confirmed events and state only.

**Acceptance fight.** Have two allies hit different mobs and one ally hit twice. Verify separate claims, one per ally, and ordinary damage from the repeat. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from avatars, pacts and elemental allegiance and its signature decision (“Call an avatar accord”). This is a setting-inspired hook for later writing.
