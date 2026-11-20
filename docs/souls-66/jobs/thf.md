# THF · Soul specifications

[Trickster](#trickster) · [Bandit](#bandit) · [Phantom](#phantom) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Trickster | Route threat through an ally | Planned physical mitigation and tight hate ordering |
| Bandit | Exploit Defense Down | Another party member or gear reliably exposes defense |
| Phantom | Retain hate on misses | Fast enemy attack rounds and little unavoidable magic |

## Trickster

THF 1 · TRK · Support · Partially Implemented · [staged implementation](https://github.com/Infomatictek/overlordsxi/blob/de974135babab04aa47d017a8a97c128cb5f9de2/modules/custom/lua/thf_specs.lua) · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Set up behind the right ally for a native Trick Attack transfer, then time a dagger/sword WS for the enemy's heavy attack window.

**Why choose it.** Choose for directed threat and short physical disruption before a tankbuster. Nightblade reacts while a cast is underway. Bad geometry leaves Trickster with only its suppression window. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set trickster` once the Soul is registered. Dagger or sword, accuracy, DEX and reduced enmity.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Sneak Attack, Trick Attack, Flee, Collaborator, Accomplice. Preserve native exclusive timers. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Staged WS listener: 5% Attack Down for 16s, 20s personal cooldown, no overwrite of existing Attack Down. Grant Trick Attack and a starter WS as temporary Soul access at 10 so geometry works without /THF. Normal Trick Attack threat transfer rules. |
| 30–49 | WS debuff 7%; retain 16s duration. |
| 50–69 | WS debuff 9%; Collaborator allows active threat correction at its legal unlock. |
| 70–75 | 12% debuff through 75. No transfer or weaken on missed WS. Respect boss resistance and immunity. |

**Source or integration decision.** The staged implementation supplies suppression; the native positional threat-transfer is a dependency. The prototype debuff path uses WS use rather than an explicit landed-action check. Confirm the underlying listener semantics or route to the resolved hit.

**HUD.** Transfer ally/position and Attack Down ICD.. Show server-confirmed events and state only.

**Acceptance fight.** Test same WS hit and miss, with/without ally aligned, and with stronger Attack Down. Prototype currently tests WS use and existing status, so require hit confirmation. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from positional attacks, evasion and manipulation of enmity and its signature decision (“Route threat through an ally”). This is a setting-inspired hook for later writing.

## Bandit

THF 2 · BND · Damage · Partially Implemented · [staged implementation](https://github.com/Infomatictek/overlordsxi/blob/de974135babab04aa47d017a8a97c128cb5f9de2/modules/custom/lua/thf_specs.lua) · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Exploit an existing Defense Down with a dagger or sword WS. Decide whether to take the current opportunity or delay for a party chain without wasting TP.

**Why choose it.** Choose to capitalize on allies or equipment exposing an enemy. Reaper follows the boss's recovery and Black Belt gets an unconditional H2H refund. Bandit relies on an external opening. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set bandit` once the Soul is registered. Dagger or sword. DEX, crit, accuracy and attack. Optional crossbow with acid bolts for solo Defense Down; marksmanship WS never triggers the refund.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Sneak Attack, Trick Attack, Flee, Steal, Hide. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Staged refund +75 TP for a landed qualifying WS during existing Defense Down, at most once per 12s. Starter Sneak Attack and a qualifying WS. For a solo tutorial supply one attainable Defense Down weapon proc or acid bolt accessible at 10; no Soul ability applies the opening. |
| 30–49 | Refund +100 TP. Normal WS remains useful without a debuff. |
| 50–69 | Refund +125 TP. Retain the native sneak-attack positional option and allow timing with party debuffs. |
| 70–75 | Refund +150 TP through 75. No side proc or extra WS hit; hit confirmation required. |

**Source or integration decision.** On the prototype WEAPONSKILL_USE checks Defense Down and the personal timer. Require a resolved landed WS before awarding TP. A cheap crossbow and acid bolts or a qualifying starter proc make the solo route testable.

**HUD.** Target Defense Down, ICD and TP.. Show server-confirmed events and state only.

**Acceptance fight.** Test solo equipment proc and party-applied debuff, then a missed WS while debuffed. Miss gives zero refund and leaves ICD ready. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from positional attacks, evasion and manipulation of enmity and its signature decision (“Exploit Defense Down”). This is a setting-inspired hook for later writing.

## Phantom

THF 3 · PHN · Tank · Partially Implemented · [staged implementation](https://github.com/Infomatictek/overlordsxi/blob/de974135babab04aa47d017a8a97c128cb5f9de2/modules/custom/lua/thf_specs.lua) · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Open with a targeted challenge and frustrate physical swings. Each actual evasion reinforces the mob's focus. Choose when to use Perfect Dodge versus trusting natural evasion.

**Why choose it.** Choose threat retention against a fast physical attacker. Sensei counter-heals, Kagemusha consumes images. Phantom needs help during unavoidable magic. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set phantom` once the Soul is registered. Dagger or katana; EVA, AGI, HP and mitigation.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Perfect Dodge, Flee, Hide (outside combat only), Feint, Phantom's Dare. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Keep staged 2s evasion ICD and +30 CE/+85 VE on eligible enemy miss. Add Dare (15y, 18s CD, 180 CE/650 VE); works with no TP and no subjob. A successful Dare also grants 8% mitigation of next unavoidable hit within 6s, once. Neither clones nor ripostes. |
| 30–49 | Evade 40/115 CE/VE, Dare absorbs 10% of that one hit. |
| 50–69 | 55/150 CE/VE. Dare 12% mitigation. |
| 70–75 | 70/190 CE/VE, mitigation 15%. Ignore absorbs, shadows, scripted zero damage and other mobs' misses. |

**Source or integration decision.** Staged source contains miss-triggered CE/VE and defensive passives. Dare and its one-hit guard are proposed to solve cold-start hate without requiring /WAR.

**HUD.** Dare timer, actual evades and incoming unavoidable hit guard.. Show server-confirmed events and state only.

**Acceptance fight.** Start with a healer pulling aggro. Confirm Dare recovers it, ordinary misses yield threat at most every 2s, and a magic-only boss produces no evade triggers. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from positional attacks, evasion and manipulation of enmity and its signature decision (“Retain hate on misses”). This is a setting-inspired hook for later writing.
