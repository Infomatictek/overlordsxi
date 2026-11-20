# MNK · Soul specifications

[Sensei](#sensei) · [Chi Weaver](#chi-weaver) · [Black Belt](#black-belt) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Sensei | Riposte | Repeated parryable or evasible melee |
| Chi Weaver | Place chi pulses | Allies clustered around an engaged enemy |
| Black Belt | Chain fist WS | Sustained uninterrupted melee with fast TP recovery |

## Sensei

MNK 1 · SEN · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/mnk_specs.lua#L851) · [existing guide](../../guides/sensei.md)

**Player decision.** Let a staff parry or evade an attack to riposte, recover HP and gain threat. Choose Counterstance or Dodge for the incoming string.

**Why choose it.** Handles repeated physical swings while self-recovering. Phantom retains hate on a miss without a counter or heal. Unavoidable magic denies Sensei these reactions. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set sensei` once the Soul is registered. Staff, evasion, parry, HP and enmity.

Pinned main WS specialization skills: staff. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Counterstance, Dodge, Focus, Boost, Chi Blast, Chakra, Perfect Counter, Mantra, Inner Strength, Hundred Fists |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Iron Counterstance. |
| Existing traits | Sensei's Flow (143). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Counterstance, Boost and Dodge. Open with the existing Chi Blast threat variation when available. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Staff Skill | Lv.10 / 30 / 50+ | +12 / +22 / +35 |
| Accuracy | Lv.10 / 30 / 50+ | +8 / +15 / +25 |
| Evasion Skill | Lv.10 / 30 / 50+ | +12 / +24 / +40 |
| Evasion | Lv.10 / 30 / 50+ | +10 / +22 / +38 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Counter & Deflection: +15/30/50 Parry Skill, +5/10/15% Parry Rate, +12/22/30% Counter, +8/16/28 Counter DMG, +15/25/40 Enmity, -25/40/60% Enmity Loss, +6/10/15% HP, -5/8/12% DT.
- Staff Riposte (w/ Staff): +12% Parry Rate; Parrying heals 2% Max HP, grants +75 TP, +Enmity, and strikes back. Evading grants 1.5% Max HP, +50 TP, +Enmity, and deals an Evasive Counter.
- Iron Counterstance (Lv10, 120s CD): +30% Counter, +20 Counter DMG, -10% DT, +20 Enmity, with no DEF halving penalty.
- Tank JAs: Dodge (60s, +25 EVA, +15% EVA, +12% Parry, +15 Enmity, +25% Evasive Counter DMG), Focus (+15% Counter, +15 Parry, +10 Counter DMG), Boost (+15 Enmity, +50 TP), Chi Blast (heavy Enmity + Acc Down), Chakra (+50% heal, Regen, cleanses Slow/Silence), Perfect Counter (45s CD, +25 Counter DMG, +25 Enmity, 5% heal), Mantra (party -5% DT), Inner Strength (60s, -25% DT, +20% EVA%, +30 Counter DMG, +50 Enmity).

**HUD.** Stance, recent parry/evade and riposte. Show server-confirmed events and state only.

**Acceptance fight.** Check distinct miss, parry and hit outcomes. On a spell-only target verify that incoming magic cannot manufacture ripostes. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Boost, disciplined weapon choice and martial stances and its signature decision (“Riposte”). This is a setting-inspired hook for later writing.

## Chi Weaver

MNK 2 · CWV · Healer · Completed / Playable · [server registration and hooks](../../../modules/custom/lua/mnk_specs.lua#L938) · [existing guide](../../guides/chiweaver.md)

**Player decision.** Leave both hands empty. Land Light Chi bolts on the engaged enemy to pulse healing around it. Decide whether to spend Boost early on Chi Blast or keep building while smaller pulses suffice.

**Why choose it.** Choose for sustained MP-free healing around a dangerous melee target while standing at range. Vampire relies on connecting for damage. Chi Weaver can choose a large heal or cleanse before reaching its 100-stack cap. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set chiweaver` once the Soul is registered. Both main and sub empty. H2H is the WS skill. MND, cure potency and accuracy take priority.

Pinned main WS specialization skills: hand to hand. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Boost, Chi Blast, Focus, Dodge, Chakra, Mantra, Formless Strikes, Hundred Fists |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Resonant Chi, Tranquil Lotus, Inner Harmony. |
| Existing traits | Chi Weaver's Pulse (154). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Empty-hand Light Chi, Boost, Chi Blast, Resonant Chi, Tranquil Lotus and Inner Harmony. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +8 / +12 / +16 / +20% |
| Regen | Lv.10 / 30 / 50 / 70+ | +8 / +16 / +26 / +38/tick |
| MND | Lv.10 / 30 / 50 / 70+ | +8 / +16 / +26 / +36 |
| VIT | Lv.10 / 30 / 50 / 70+ | +5 / +10 / +16 / +24 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Empty-Handed Vow: Cannot equip ANY weapon or item in Main or Sub slots (bare fists only).
- Dual-Fist Chi & Boost Stacking (0-20y): Auto-attacks unleash main & off-hand Light Chi bolts (+Kick procs) and ranged H2H Weaponskills work up to 20y. Every landed bolt grants +1 Boost stack (WS +3/+4/+5, max 100, +1 Cure Pot/MACC/MAB per 5 stacks) plus light sustain pulses.
- Custom JAs (Lv10+): Resonant Chi (20s CD, 20y Light burst + 1.75x target AoE heal & Cleanse), Tranquil Lotus (30s CD, 12y Party/Pet heal + 15s Regen, +Cure Rcvd, & Enmity-), Inner Harmony (45s CD, 18s +Cure Potency, +MAB/MACC, +Ability Haste, +Regen, & +40% Chi Bolt/Pulse power).
- Healer MNK JAs: Chi Blast (5s CD, 0 damage, consumes all 0-100 Boost stacks for a massive 20y party AoE heal + up to 3 debuff cleanses), Boost (+5 Boost stacks, +50 TP & light engaged pulse), Focus (+25 MACC, +20 MAB, +15% Cure Pot), Dodge (+30 EVA, -10% DT, -25 Enmity), Chakra (projects 45% AoE heal + self cleanse), Mantra (party Regen + Cure Rcvd%), Formless Strikes (+15% Chi DMG/+20% Pulse), Hundred Fists (2x Chi Bolt speed & +25% Pulse).

**Source or integration decision.** The no-weapon vow is intentional. The prose Attack% penalty needs comparison against actual applied modifiers and the non-DPS floor. Changing the player's heal loop to make the guide agree is outside the contract.

**HUD.** Boost 0–100, pulse reach, Chi Blast. Show server-confirmed events and state only.

**Acceptance fight.** At 0, partial and 100 Boost compare heal and cleanse. Stand within bolt range with one ally near the target and another outside pulse range. Verify zero MP cost. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Boost, disciplined weapon choice and martial stances and its signature decision (“Place chi pulses”). This is a setting-inspired hook for later writing.

## Black Belt

MNK 3 · BLK · Damage · Completed / Playable · [server registration and hooks](../../../modules/custom/lua/mnk_specs.lua#L895) · [existing guide](../../guides/blackbelt.md)

**Player decision.** Stay in H2H range, line Boost up with a WS and use kicks, crits and double attacks to get back to the next WS. Use Chakra to regain tempo after a disabling effect.

**Why choose it.** Choose fast personal WS recovery without managing a pet, tank counter or HP sacrifice. Berserker has a stronger reason to wait for an offensive buff window. Forced disengagement breaks Black Belt's cadence. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set blackbelt` once the Soul is registered. H2H weapon or bare fists. STR, DEX, kick attacks, attack, accuracy and haste.

Pinned main WS specialization skills: hand to hand. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Boost, Focus, Dodge, Footwork, Impetus, Chi Blast, Chakra, Hundred Fists |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. The registration supplies no separate custom JA list in the site export. |
| Existing traits | Black Belt's Mastery (153). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Boost, H2H starter WS and the existing Combo Momentum refund. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Hand-to-Hand Skill | Lv.10 / 30 / 50 / 70+ | +10 / +20 / +32 / +45 |
| Accuracy | Lv.10 / 30 / 50 / 70+ | +8 / +16 / +26 / +38 |
| Attack | Lv.10 / 30 / 50 / 70+ | +12 / +24 / +40 / +60 |
| Attack | Lv.10 / 30 / 50 / 70+ | +6 / +10 / +15 / +20% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- H2H Oath: Restricted strictly to Hand-to-Hand weapons or bare fists (cannot equip Staves, Clubs, or non-H2H weapons in Main/Sub).
- Martial Relentlessness: +6/10/15/20% Kick Rate, +8/15/24/35 Kick DMG, +3/5/8/12% Crit Rate, +5/9/14/20 Store TP, +5/10/15/20 Subtle Blow, +6/10/16/22% WSD.
- Combo Momentum: Every Hand-to-Hand Weaponskill refunds +75 TP to sustain rapid skillchain pressure.
- Aggressive JAs: Boost (+100 TP, +8% Crit & +15% next WSD), Focus (+10% Crit, +15% Crit DMG, +25 Acc), Dodge (+10% Abil Haste, +15 Subtle Blow), Chakra (+30% heal, +150 TP, cleanses Para/Blind/Weight), Chi Blast (+35% DMG, -15% DEF Down, +100 TP), Footwork (+15 Kick DMG, +10% Kick Rate, +10% Atk%), Hundred Fists (+25% Atk%, +15% Crit, +20% DA, +20 Store TP).

**HUD.** Boost readiness, TP and stance timers. Show server-confirmed events and state only.

**Acceptance fight.** Log TP before and after a qualifying WS. Verify exactly one +75 refund, including bare fists. Re-equip a staff and check the existing weapon gate. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Boost, disciplined weapon choice and martial stances and its signature decision (“Chain fist WS”). This is a setting-inspired hook for later writing.
