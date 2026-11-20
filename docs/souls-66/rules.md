# Combat and action contracts

The job cards specify the target design. Existing modules at the pinned revisions supply full formulas, spell gates, native overrides, traits and recasts for retained kits. When a handler differs from a guide or wiki sample, preserve the handler and record the difference. Proposed coefficients are **first-playtest values**.

## Effective level and permission rules

- Below effective main-job level 10 use existing no-Soul/ineligible-Soul behavior. Preserve the saved selection. Eligible levels are 10 through 75 inclusive. New schedules use 10–29, 30–49, 50–69 and 70–75. Each later row inherits previous actions and replaces only stated parameters. At 75 there is no extra rank or multiplier unless explicitly granted.
- A named starter must work on a fresh character in purchasable gear, with ordinary ammo/tools, without merits, rare drops, capped skill, late scrolls or a required subjob. Preserve existing early grants. For a demonstrated gap lend that action while eligible, through server usability/unlock state. Preserve equipped gear and permanent learned bits. For BLU supply enough temporary set points for its starter pair, then restore the saved set on exit. Do not call a destructive spell reset to switch profiles.
- Other native JAs, spells, pacts and WS require existing unlock levels and character entitlement unless an explicit Soul grant applies. A named family means its level-legal members in local resources, plus explicit Soul backports. Geomancy support families mean beneficial and enfeebling Indi/Geo lines. Player nukes require their own listing. “-na” means Poisona, Paralyna, Blindna, Silena, Stona, Viruna and Cursna. “Runes” means Ignis, Gelus, Flabra, Tellus, Sulpor, Unda, Lux and Tenebrae. Six probes mean first-rank single-target Stone, Water, Aero, Fire, Blizzard and Thunder. Where all six are starters, lend them at 10. Separate summon, command and pet-executed action permissions.
- Resolve a finite permitted action set for each Soul and effective level. For retained Souls take the union of the card list, the pinned registration's level-evaluated grants, and native actions already covered by that Soul's hooks or spell tables. A different Soul's code in the same module grants nothing. Expand named families to IDs from the installed resources before enabling enforcement. Native actions keep their ordinary requirements unless an explicit loan/override applies. A guide number, a matching substring or a job-wide grant cannot establish entitlement. New Souls permit only their listed native and proposed actions.
- Retain Attack/disengage, movement, targeting, equipment, items, examine, trade, ordinary recovery, level sync, Soul selection/clear and authorized GM controls. Sneak, Invisible, Deodorize, Warp, Escape, Retrace and the Teleport/Recall travel families remain subject to native learned/job/level requirements. Preserve accepting Raise and Return Home Point. Recheck restricted signatures at execution for macros, queue, items and subjobs. Do not change unrelated native item effects.
- Resolve visible actions by Soul, kind and verified source ID. Use only the current Soul name and behavior on player surfaces. Unmodified native actions keep their established names. Keep source-ID aliases in developer data. Test menus, macros, descriptions, combat messages, equipment labels, search, locale, animation and local resource fallback individually. The launcher demo is not a production mapping.
- Approved WS are existing, otherwise legal and unlocked WS for the listed combat skills. Sidearm WS trigger only bonuses explicitly tied to that skill. Existing custom throwing WS and other Soul exceptions keep their grants. No WS Evolution talent, haste change, purchased talent or global skillchain alteration is required for a starter loop. Use skill-appropriate starter equipment. Chi Weaver's bare hands are an intentional exception.

## Defaults for proposed actions

| Property | Contract |
|---|---|
| Range and target | Melee 4y, hostile spells 18y, friendly actions 15y. Card-specific range prevails. Require a living legal target in the same zone and line of sight. Self is eligible for friendly actions unless another actor is required. Use server yalms and validate terrain on movement. |
| Time and cost | New JAs are instant with normal animation lock and no MP/TP cost unless stated. An unpriced proposed spell costs 4% max MP, takes 1s and has 12s recast. Native spells keep native pricing. Percentage costs round up, minimum 1. Explicit personal/shared recovery is a floor. |
| Damage | One normalized swing is one ordinarily resolved, noncritical main-hand hit at current stats, level correction and enemy defense. Suppress multiattack, TP, additional hits and skillchains on synthetic strikes. Ranged multipliers use one resolved shot and normal TP only where specified. Round down at final resolution, clamp to normal pools unless an existing Soul explicitly overcaps. |
| Spell references | For a level-appropriate native nuke use the highest normal single-target rank for that element at effective level; use BLM's table if the new Soul has no native rank. Ancient Invocation at 10 always uses a tier-I probe. Check resistance once. Added Soul damage never multiplies prior bonus damage. |
| Allied modifiers | A mark or accord applies to ordinary resolved damage before Soul-exclusive bonuses. For overlapping new teamwork bonuses on the same portion, apply only the strongest percentage and spend only the corresponding limited claim. Tie: earliest application. Preserve native magic burst and skillchain resolution. |
| Trigger validity | One proc per original resolved action sequence. No synthetic follow-up, reflected damage, periodic tick, self damage, cancellation, duplicate packet or miss may manufacture another opening unless an existing mechanic explicitly requires it. Full resists that yield zero damage cannot earn on-hit rewards. |
| Incoming effects | Honor normal resist, boss immunity and existing phase floors. New controls and reductions never alter scripted deaths or HP sets. New encounter-specific reductions of the same kind use the strongest eligible value per hit. Retain existing mitigation order. |
| State and cleanup | Scope target records to zone + spawn generation, owner records to character + Soul activation. Use server monotonic time. End effects on removal, loss of eligibility, death, logout or zone. Re-evaluate on sync. A switch or resummon cannot refresh a personal timer. Clear invalid targets and stale listeners. |
| Role math | Use existing role tier once. Never apply negative ATTP, RATTP, MATT or MACC to tanks, healers or supports. Primary utility must operate with ordinary accuracy and gear. New tanks need a zero-TP opener and access to it without /WAR. |
| HUD | Publish confirmed changes and bounded resync to the existing subscription. Show the actual resource, condition or recast for this Soul. No optimistic pet or proc success and no placeholder live meter. |

## Cold-start tank threat

| Tank | Zero-TP opening route to validate | Sustained threat belongs to |
|---|---|---|
| Spartan | Impaling Thrust or native WAR Provoke | Shield-wall player |
| Sensei | Existing Chi Blast threat variation; lend at 10 if needed | Staff user |
| Necromancer | Fight plus Grave Provoke on warrior thrall | Warrior thrall |
| Crimson Duelist | Hex Volley | Fencer |
| Defender | Flash or Judgment Gavel | Intercepting PLD |
| Dreadnought | Abyssal Cleave on the single engaged boss | Scythe user |
| Minstrel | Dissonant Chord | Singer |
| Huntsman | Main Tusker order; redesign Gore/Rend | Commanded beast; main Saurian uses another role |
| Ronin | Blade Bash | Samurai |
| Kagemusha | Smoke Lotus | Ninja |
| Skyborn | Grounding Cry | Dragoon even during aerial guard |
| Phantom | Phantom's Dare | Thief |
| Azure Bastion | Behemoth Roar | Blue Mage |
| Buccaneer | Grapeshot Broadside | Corsair |
| Mirage Sentinel | Animated Flourish; first successful Step supplies any required move | Dancer |
| Alpha Warden | Feral Roar with guardian active | Master; guardian shares damage |
| Vanguard | Deploy plus Hydraulic Slam | Valoredge |
| Inquisitor | Flash or Foil | Rune Fencer |

Test with a healer casting immediately. For an inaccessible opener borrow the existing button locally. If it still cannot beat the first cure or requires unavailable moves, trial a **floor** of 180 CE/650 VE on that Soul's first valid targeted opener per 18s. For Mirage allow the first cold-start Animated Flourish at zero finishing moves if its Step cannot land. Credit the intended tank. Never add this floor to a stronger existing effect. Record measured cure threat before accepting it.

## Solo onboarding for cooperative kits

Arcane Archer can consume its own mark for half effect with an elemental bow WS. If no matching starter exists, teach a loaned level-10 fire bow WS, one ordinary shot at 1000 TP with native starter WS base, no new skillchain property. Trickster suppresses via WS solo and uses threat geometry in a party. Herald follows with its own avatar Rage, Channeler can give itself one discounted cast, and Beastspeaker exposes with its own beast. Solo never awards multiple party claims. Valkyrie can Wingmate itself at 10 and practice a retry after a real interruption. Against enemies that never interrupt, its protection, cleanse and ordinary polearm remain available.