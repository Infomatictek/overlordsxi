# BLU · Soul specifications

[Warmage](#warmage) · [Magus](#magus) · [Azure Bastion](#azure-bastion) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Warmage | Set monster answers | A prepared Blue Mage can exploit changing damage resistances |
| Magus | Weave Blue heals and melee waves | Repeated group damage with opportunities to dual-wield |
| Azure Bastion | Layer Chitin and choose the next cast | Tanking demands flexible Blue Magic responses |

## Warmage

BLU 1 · WMG · Damage · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Select and set a compact Blue Magic loadout, then match blunt, slashing or magical attacks to the boss's changing resistance. Knowing when to change your answer matters more than alternating casts.

**Why choose it.** Choose flexible damage on a fight that changes its defenses. Azure Bastion uses physical Blue spells for Chitin. A Warmage who equips the wrong answers has lower peak damage than a specialist. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set warmage` once the Soul is registered. Sword or club. Blue skill, MP, accuracy and magic accuracy.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Sprout Smack, Power Attack, Foot Kick, Bludgeon, Smite of Rage, Bomb Toss (single-target Soul presentation), Jet Stream, Death Scissors, Mandibular Bite, Heat Breath, Mind Blast. Preserve learned/set limits; stage availability below. |
| Job abilities and commands | Chain Affinity, Burst Affinity, Azure Lore, Assess Prey. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Temporarily offer and allow setting Sprout Smack and Power Attack with one free starting set opportunity. Assess Prey, 12s CD, reveals target's least-resistant legal category for 8s from blunt/slash/pierce/element, ties explicit. Matching direct offensive Blue spells gain 12% after resistance. Starter pair supplies blunt/piercing answers. No WS/cast refund. The starter Soul profiles explicitly resolve Sprout Smack as blunt and Power Attack as piercing for this matching check. |
| 30–49 | Allow Bludgeon and Smite of Rage. Bonus 15%. Set changes use ordinary Blue Magic restrictions. |
| 50–69 | Allow Jet Stream, Mandibular Bite and single-target Bomb Toss at normal legal level or this tier, whichever comes first within profile; bonus 18%. |
| 70–75 | Remaining named spells become available by 70, bonus 20%. Single-target policy for every Soul-converted area technique. No instant/free Blue Magic from WS. |

**HUD.** Set answers, assessed category and duration.. Show server-confirmed events and state only.

**Acceptance fight.** Two equal-resistance categories both qualify. Verify only selected target takes Soul-converted Bomb Toss damage and no Azure Surge is granted. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from learning and setting monster techniques and its signature decision (“Set monster answers”). This is a setting-inspired hook for later writing.

## Magus

BLU 2 · MAG · CombatHealer · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/blu_healer_specs.lua#L603)

**Player decision.** Strike with two weapons to build Azure Catalyst. Decide between a healing Blue spell, a WS-triggered wave, or Osmotic Conduit during uninterrupted contact.

**Why choose it.** Choose for repeated close-range party healing plus Blue Magic utility. Vampire heals in proportion to damage. Magus can cast its learned healing spells while disengaged. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set magus` once the Soul is registered. Dual sword/club. MND, cure potency, HP, fast cast and accuracy.

Pinned main WS specialization skills: sword, club. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Exact MAGUS_BASELINE_SPELLS and BLU_HEAL_SPELLS in blu_healer_specs, preserving the native learned/set-spell exemptions currently granted. |
| Job abilities and commands | Diffusion, Azure Lore, Unbridled Learning where currently granted, Burst Affinity, Chain Affinity |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Diffusion, White Wind Surge, Osmotic Conduit. |
| Existing traits | Dual Wield (18), Azure Diffusion (171). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Pollen, a starter healing spell from the existing Magus list, White Wind Surge and Osmotic Conduit. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Dual Wield Delay | Lv.10 / 30 / 50 / 70+ | -15 / -20 / -25 / -30% |
| Max HP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| Max MP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| MND | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Azure Mending & AoE Diffusion: Healing Blue Magic splashes to all party members within 15y at 85% potency.
- Sanguine Catalyst: Dual-wield hits stack Azure Catalyst (max 5); at 5 stacks or on Sword/Club WS, unleashes Azure Mending Wave (12/16/20/24% Max HP AoE heal + 6% Max MP).
- JA Enhancements: Diffusion (20s CD) & Azure Lore (doubles Azure Mending Wave heals).
- White Wind Surge (20s CD, 28% HP AoE heal + 2-debuff cleanse + 15% Stoneskin) & Osmotic Conduit (25s CD, 12s -10% MDT + 3% HP / 2% MP party siphon per swing).

**HUD.** Azure Catalyst and Conduit time. Show server-confirmed events and state only.

**Acceptance fight.** Compare 4 vs 5 Catalyst and a qualifying WS. One healing spell should generate one intended splash per ally. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from learning and setting monster techniques and its signature decision (“Weave Blue heals and melee waves”). This is a setting-inspired hook for later writing.

## Azure Bastion

BLU 3 · AZB · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/blu_specs.lua#L602) · [existing guide](../../guides/azurebastion.md)

**Player decision.** Cast tagged physical Blue Magic to layer Chitin. Decide whether a sword/club WS's free instant Blue spell should restore, defend or take pressure off the group.

**Why choose it.** Pick a caster tank that adapts the next Blue spell to incoming damage. Warmage selects monster attacks for damage type. Losing MP or set access disrupts Azure Bastion's defense. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set azurebastion` once the Soul is registered. Sword or club, with Dual Wield. HP, Blue Magic, accuracy and mitigation.

Main has no explicit WS profile row for this key. Preserve currently legal WS; use the listed weapon conditions for signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | PHYSICAL_BLUE_SPELL_IDS in blu_specs, Cocoon, Metallic Body, Diamondhide, Zephyr Mantle, Pollen, Wild Carrot, Magic Fruit, Healing Breeze, Blank Gaze and Refueling. |
| Job abilities and commands | Chain Affinity, Burst Affinity, Diffusion, Azure Lore |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Behemoth Roar, Diamond Shell. |
| Existing traits | Dual Wield (18), Azure Carapace (162). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Head Butt or Bludgeon, Cocoon, Pollen, Behemoth Roar, Diamond Shell and one sword/club WS. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +26% |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| STR | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| MND | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Early Dual Wield & Mastery: Unlocks Dual Wield at Lv.10+ (-15/20/25/30% delay), +15/25/35/50 Sword/Club/Blue skill, +14/20/26/32% Parry, +20/30/40/50% Fast Cast, and 100% SIRD.
- Monster-Core Carapace: Physical Blue Magic (Head Butt, Sudden Lunge, Bludgeon, Smite of Rage, Heavy Strike, Goblin Rush) deals 3x VE, costs -30% MP, and grants Chitin Carapace (max 5: +4% DEF & -3% DT each for 15s); Defensive spells gain +35% potency & +6% Max MP at 3+ stacks.
- Azure Assimilation: Sword/Club WS grants Azure Surge (6s) making your next Blue Magic spell instant-cast, 0 MP, with an AoE 8y volatile enmity pulse.
- Tradeoff & JAs (-20% ATK/RATK, -15% WSD): Enhances Burst Affinity (heavy VE + -15% MATK Down), Chain Affinity (3s Stun + 20% Max HP barrier), and Azure Lore (-25% DT, +50 Enmity, -50% Blue Magic MP).

**HUD.** Chitin and Azure Surge. Show server-confirmed events and state only.

**Acceptance fight.** At two and three Chitin test the defensive cast. Spend a Surge on one spell and verify the next spell again costs MP. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from learning and setting monster techniques and its signature decision (“Layer Chitin and choose the next cast”). This is a setting-inspired hook for later writing.
