# DRG · Soul specifications

[Lancer](#lancer) · [Skyborn](#skyborn) · [Wyvernheart](#wyvernheart) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Lancer | Choose a launch lane | Melee burst after a safe approach from distance |
| Skyborn | Time aerial guard | One predictable incoming technique while the tank retains hate |
| Wyvernheart | Jump for triage | Emergency spot healing with a living wyvern |

## Lancer

DRG 1 · LNC · Damage · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Choose a safe launch lane, then leap toward one locked target for a heavy polearm impact from the correct approach distance. In cramped fights stay close and use ordinary polearm WS.

**Why choose it.** Choose offensive repositioning when a fight allows run-up space. Skyborn times defense against a hit; Wyvernheart's jumps heal. Lancer commits its own position for damage. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set lancer` once the Soul is registered. Polearm, STR, accuracy and jump gear.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Jump, High Jump, Spineshatter Vault, Angon. No pet needed for signature. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Vault locks one enemy 4–12y away; 1s startup, 18s CD. If path valid, land at nearest safe melee point on same terrain. Deal 1.6× one normalized polearm hit at 4–7y or 2.2× at >7–12y. Never cross impassable terrain; invalid finish cancels displacement and damage, 3s retry. No threat shed or immunity. |
| 30–49 | Long-lane hit 2.5×. HUD shows legal landing point/range. |
| 50–69 | High Jump remains a distinct native reposition/threat option. On landed long Vault, native Jump used within 5s gains +15% damage once. |
| 70–75 | Long-lane 2.8×, follow-up +20%. No chain property on Vault. Natural auto/WS play fills movement restrictions. |

**HUD.** Run-up band, landing validity and follow-up.. Show server-confirmed events and state only.

**Acceptance fight.** Test wall, elevation, moving target and ordinary close melee. Count exactly one Vault hit on one enemy and no traversal of blocked geometry. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from jump timing, polearms and the wyvern bond and its signature decision (“Choose a launch lane”). This is a setting-inspired hook for later writing.

## Skyborn

DRG 2 · SKY · Tank · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Hold hate on the ground, then time a short aerial guard to soften one telegraphed hit and bring the boss back onto you at landing.

**Why choose it.** Choose reliable timed protection from one readable technique. Phantom's value depends on repeated misses. Repeated fast hits punish a poorly timed landing. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set skyborn` once the Soul is registered. Polearm, HP, enmity and mitigation.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Skyward Guard, Grounding Cry, Jump, High Jump. Soul guard never calls native hate-clearing Super Jump. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Grounding Cry 15y, 16s CD, 200 CE/700 VE on one enemy at zero TP. Guard 20s CD, 1.5s stance; remain targetable and stationary. First eligible direct spell/TP hit during stance deals 35% less to self. On landing add 100 CE/300 VE to original living enemy. Impact and landing never damage nearby mobs. |
| 30–49 | Guard 40%; landing grants 5% max HP ward for 5s on a successful intercept. |
| 50–69 | Guard 45%; successful landing ward 8%. Native Jump may be used after landing, no reset of Guard timer. |
| 70–75 | Guard 50%, ward 10%. Scripted fatal/HP-set effects excluded. Multi-hit move shares one action sequence; mitigate that sequence once, no invulnerability frames. |

**HUD.** Guard expiry, intercepted action and landing threat.. Show server-confirmed events and state only.

**Acceptance fight.** With healer second on hate verify boss never turns away simply because Guard was pressed. Compare early, on-time and late activation. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from jump timing, polearms and the wyvern bond and its signature decision (“Time aerial guard”). This is a setting-inspired hook for later writing.

## Wyvernheart

DRG 3 · WYV · CombatHealer · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/drg_specs.lua#L481) · [existing guide](../../guides/wyvernheart.md)

**Player decision.** Jump and use Spirit Link to manage Wyrmscale. A polearm WS triages the lowest ally. Time Restoring Breath while the wyvern is alive for group recovery.

**Why choose it.** Pick a healer who can react through a jump or breath while fighting. Templar's beacon follows club swings. Pet loss removes the breath option. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set wyvernheart` once the Soul is registered. Polearm. HP, cure potency, accuracy and wyvern survival.

Pinned main WS specialization skills: polearm. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Call Wyvern, Jump, High Jump, Super Jump, Spirit Link, Restoring Breath, Spirit Surge |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Call Wyvern, Jump, High Jump, Super Jump, Spirit Link, Restoring Breath, Wyrmblood Pulse, Dragonscale Sanctuary. |
| Existing traits | Wyrmblood Breath (176). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Call Wyvern, Jump, Spirit Link, Restoring Breath, Wyrmblood Pulse and a polearm WS. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +28% |
| VIT | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| MND | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| STR | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Lv.10+ Kit & Polearm Triage: Unlocks Call Wyvern (15s CD, in-combat, 100% HP), Jump, High Jump, Spirit Link, and Restoring Breath @ Lv.10+ (Super Jump @ Lv.50+); Polearm WSs command Wyvern Crimson Triage (18/21/24/28% DRG Max HP on lowest-HP ally + overheal -> 12% Stoneskin) + 1 Wyrmscale (max 3).
- Distinct Jump Directives & Spirit Link: Jump (20s CD, +150 TP, +1 Wyrmscale, 2 lowest-HP allies Hybrid Regen 15 + 2.2% Max HP/t + 1 Erase); High Jump (35s CD, +1 Wyrmscale, 15y 2-debuff party cleanse + 10% Stoneskin); Spirit Link (15s CD, 0 HP cost, 22/25/28/32% single-target heal + 2 Erase + 40% Wyvern HP + 1 Wyrmscale).
- Restoring Breath & Super Jump: Restoring Breath (20s CD) spends 0..3 Wyrmscale for 14/20/26/32% DRG Max HP party heal (3 stacks -> 15% Dragonscale Stoneskin); Super Jump (75s CD) wipes enmity, hides Wyvern 8s, and grants 3 Wyrmscale (Spirit Surge halves Jump CDs & +2 Wyrmscale).
- Wyrmblood Pulse (45s CD, 24% DRG Max HP party heal + 2-debuff cleanse + resets Jump/High Jump) & Dragonscale Sanctuary (75s CD, 15s: 15% Max HP Stoneskin, Knockback Immune & shared Ward -12% DMG / +30 MEVA).

**HUD.** Wyrmscale, wyvern HP and breath readiness. Show server-confirmed events and state only.

**Acceptance fight.** Create different HP deficits, use a WS and then a breath. Dismiss the wyvern and verify pet-dependent healing stops. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from jump timing, polearms and the wyvern bond and its signature decision (“Jump for triage”). This is a setting-inspired hook for later writing.
