# RDM · Soul specifications

[Crimson Duelist](#crimson-duelist) · [Royal Tactician](#royal-tactician) · [Scarlet Weaver](#scarlet-weaver) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Crimson Duelist | Fence through hexes | A boss susceptible to several different enfeebles |
| Royal Tactician | Convert enfeebles into orders | A mixed party needing different individual buffs mid-fight |
| Scarlet Weaver | Hold Yin or Yang | A boss alternating melee and magic vulnerabilities |

## Crimson Duelist

RDM 1 · DLS · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/rdm_specs.lua#L699) · [existing guide](../../guides/crimsonduelist.md)

**Player decision.** Fence with an empty offhand. Maintain different enfeebles for Hex-Mitigation and parry. Spend a sword WS's Crimson Flow on the most urgent ward or enfeeble.

**Why choose it.** Best when a boss accepts several enfeebles and pressure alternates between hits and casting. Scourge suppresses one selected behavior. Resists reduce this tank's protection. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set crimsonduelist` once the Soul is registered. Sword, empty sub. Enhancing skill, magic accuracy, parry, HP and MP.

Main has no explicit WS profile row for this key. Preserve currently legal WS; use the listed weapon conditions for signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Stoneskin, Phalanx, Slow, Paralyze, Blind, Silence, Poison, Bio, Dia, Gravity, Bind, Refresh, Aquaveil, Blink, Protect, Shell, Cure I–IV. Include native level-eligible ranks of named enfeebles. |
| Job abilities and commands | Composure, Convert, Chainspell, Saboteur, Spontaneity |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Hex Volley, Crimson Fleche. |
| Existing traits | Crimson Riposte (163). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Stoneskin, Phalanx, Slow, Paralyze, Blind, Hex Volley and a legal sword WS. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| INT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| MND | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Crimson Fencer Mastery (1H Sword + Empty Sub): +15/25/35/50 Sword & Enfeebling/Enhancing skill, +14/20/26/32% Parry Rate, +15/25/35/45% Fast Cast, and 100% Spell Interruption Rate Down.
- Hex-Mitigation: reduces target physical & magical damage dealt by 5% per active enfeeble (up to -25%) and grants +3% Parry Rate per enfeeble (+15% max).
- Crimson Riposte: parrying triggers light/ice counter-damage, heavy volatile enmity, and restores +4% Max MP.
- Barrier & WS Weaving: enhances Stoneskin (25% Max HP, 15s recast) & Phalanx (30s recast); Sword WSs grant Crimson Flow (next Enfeeble/Stoneskin/Phalanx instant, 0 MP, +50% VE).
- Enhances Convert (30s CD, 50% HP floor + full Stoneskin), Composure (+30 ACC/MACC, +50% Enfeebling duration), and Chainspell (30s, -25% DT, enmity pulse).

**Source or integration decision.** Tuning target from the owner's RDM review: +60/80/100/125% max MP, +40 flat at 10 (retain +40 through cap for the first test), 0.5/0.6/0.7/0.8% max MP per 3s; Stoneskin 20/24/27/30% max HP. Main currently calculates a 25% ward. For the separate tuning trial retain existing enhancing-skill Phalanx, add floor(0.5% max HP) to base flat absorb, and refund 3% max MP only on a successfully consumed Crimson Flow. Preserve 5% Hex-Mitigation per distinct enfeeble, cap 25%. These are candidate values, not shipped effects.

**HUD.** Enfeeble count, ward remaining and Flow. Show server-confirmed events and state only.

**Acceptance fight.** Measure at 0, 1 and 5 distinct enfeebles. A resisted cast contributes zero. Spend one Flow and check its cost on recast. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from enfeebling, enhancing and swordsmanship and its signature decision (“Fence through hexes”). This is a setting-inspired hook for later writing.

## Royal Tactician

RDM 2 · RYT · Support · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Read the next enemy melee or spell action and choose who receives your response. A landed Slow or Paralyze opens a short order to one frontliner; a landed Silence or Blind opens a different order for a caster.

**Why choose it.** Pick flexible one-ally tactical enhancement in a mixed party. Scourge suppresses a single boss behavior continuously and Commander shares one stance broadly. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set royaltactician` once the Soul is registered. Sword or dagger; magic accuracy, enhancing skill and MP.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Slow, Paralyze, Blind, Silence, Haste, Refresh, Dispel, Protect I–IV, Shell I–IV. |
| Job abilities and commands | Issue Order, Convert. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Slow/Paralyze open Advance; Blind/Silence open Recompose for 6s after landing or refreshing the debuff on the engaged mob. Issue Order at 15y, 18s CD, chooses ally or self. Advance adds 10% accuracy for 8s; Recompose reduces next non-instant spell's MP cost 15% within 8s. Only latest order available. |
| 30–49 | Advance also adds 5 Store TP; Recompose MP discount 20%. Dispel success opens either via the last successfully issued type. |
| 50–69 | At full resist grant the corresponding order at half potency, lockout 24s so an immune boss still permits tactical support. |
| 70–75 | Advance accuracy 15%, Store TP 8; Recompose discounts 25%. Per recipient only strongest order, one cast per Recompose through 75. |

**HUD.** Order type, intended ally, expiry.. Show server-confirmed events and state only.

**Acceptance fight.** Overwrite an Advance with Recompose before issuing. Verify a resisted or dispelled effect cannot create two full orders. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from enfeebling, enhancing and swordsmanship and its signature decision (“Convert enfeebles into orders”). This is a setting-inspired hook for later writing.

## Scarlet Weaver

RDM 3 · SCW · Damage · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Choose a Yin or Yang aspect as the boss changes defenses. Yin exploits magical access from range. Yang commits your sword to normal physical contact. Stay in one aspect while the encounter favors it.

**Why choose it.** Choose a RDM who can switch between resistant phases. Spellblade builds Conduction to pay for a cast. Scarlet Weaver can stay in one aspect indefinitely and pays a real opportunity cost to switch. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set scarletweaver` once the Soul is registered. Sword, empty sub or shield; DEX, accuracy, INT and MAB.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Enfire, Enblizzard, Enaero, Enstone, Enthunder, Enwater; six single-target tier I–III elemental lines; Blink and Aquaveil. |
| Job abilities and commands | Yin Aspect, Yang Aspect, Convert. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Enter either aspect out of combat free. In combat they share a 12s recast; entry has 2s recovery. Yin grants +15% final eligible elemental spell damage; Yang grants +15% landed regular main-hand sword damage. Only one applies. Enspell damage receives neither multiplier. No requirement to alternate. |
| 30–49 | Aspect bonus 18%. Learn the six tier-II element lines at their existing legal levels up to this tier, borrowing one tier-II starter at 30 if necessary. |
| 50–69 | Aspect bonus 22%. Changing aspect clears only this Soul's previous effect; completed casts and hits evaluate the aspect at resolution. |
| 70–75 | 25% aspect bonus. Tier-III spell family legal through 75, no extra action on switch. No procs on WS, skillchains or additional attacks. |

**HUD.** Yin/Yang, switch recovery, target damage response.. Show server-confirmed events and state only.

**Acceptance fight.** Compare equal time in one favorable aspect vs rapid switching on an unchanged boss. Switch during an elemental cast and verify a single resolution. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from enfeebling, enhancing and swordsmanship and its signature decision (“Hold Yin or Yang”). This is a setting-inspired hook for later writing.
