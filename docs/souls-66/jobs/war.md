# WAR · Soul specifications

[Commander](#commander) · [Berserker](#berserker) · [Spartan](#spartan) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Commander | Call formation | A planned group chain or knockback |
| Berserker | Overstrain | Short physical burn with healing available |
| Spartan | Brace | A telegraphed heavy hit with a buckler |

## Commander

WAR 1 · CDR · Support · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/war_specs.lua#L557) · [existing guide](../../guides/commander.md)

**Player decision.** Read the party's next action. Share one WAR stance through Warcry, mark the enemy before a chain, or spend the same animation window on a defensive formation.

**Why choose it.** Bring it for a planned group skillchain or knockback. Warlord earns its aura through Tachi closures. Commander can call a formation before anyone has TP, at the cost of its own swings. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set commander` once the Soul is registered. WAR open skills. Start with an axe and prioritize accuracy, HP and JA availability.

Pinned main WS specialization skills: hand to hand, dagger, sword, great sword, axe, great axe, scythe, polearm, club, staff, archery, marksmanship. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Berserk, Defender, Aggressor, Retaliation, Restraint, Warcry, Blood Rage |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Warcry (Commander), Tactical Breach, Formation: Bulwark, Battle Cadence, Rallying Horn. |
| Existing traits | Commander's Tactics (140). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Warcry, Berserk, Defender, Tactical Breach and Formation: Bulwark. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50+ | +5 / +8 / +12% |
| Attack | Lv.10 / 30 / 50+ | +8 / +16 / +28 |
| Accuracy | Lv.10 / 30 / 50+ | +6 / +12 / +20 |
| Store TP | Lv.10 / 30 / 50+ | +4 / +8 / +12 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Early & Rapid Warcry (Lv10, 60s CD): Shares your single active WAR stance (Berserk, Defender, Aggressor, Retaliation, or Restraint) with the party.
- Tactical Breach (Lv10, 20s CD, 10s, Enemy 15y): +12/18/24/30% Skillchain DMG, +8/12/16/20% Magic Burst & Crit DMG, +100/150/200/250 TP on SC close.
- Formation: Bulwark (Lv10, 25s CD, 15s, Party 10y): Stacking Phalanx (8 + 0.45*Lv), +5/10/15/20 MDEF, +12/18/25/35 Status Resist, +30/50/75/100% Knockback Resist.
- Battle Cadence (Lv10, 20s CD, 12s, Party 10y): +12/18/24/30 Subtle Blow (+0/0/5/10 SB II), +10/15/22/30 Conserve TP, +8/12/16/20% Cure Rcvd.
- Rallying Horn (Lv10, 45s CD, 12s, Party 12y): Cleanses Slow/Bind (Lv30+ Weight/Para; Lv50+ DEF/MDEF Down; Lv70+ Atk/Acc Down), +5/7/9/12% HP, +75/125/175/250 TP, +8/10/12/15% Move Speed.

**HUD.** Shared stance, mark and ward expiry. Show server-confirmed events and state only.

**Acceptance fight.** Open at zero TP. Test a chain inside and outside Breach and have an ally stand outside the formation. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Warcry and the Warrior's combat stances and its signature decision (“Call formation”). This is a setting-inspired hook for later writing.

## Berserker

WAR 2 · BRZ · Damage · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/war_specs.lua#L596) · [existing guide](../../guides/berserker.md)

**Player decision.** Fit a string of physical WS into enhanced WAR buffs. Choose when the defense loss and Savage Cleave recoil are affordable.

**Why choose it.** Pick it for a short melee burn with healer cover. Black Belt rewards uninterrupted fist contact, while Oathbreaker commits to one vow over an encounter. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set berserker` once the Soul is registered. WAR open skills. Prefer great axe, attack, multiattack and accuracy.

Pinned main WS specialization skills: hand to hand, dagger, sword, great sword, axe, great axe, scythe, polearm, club, staff, archery, marksmanship. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Berserk, Aggressor, Warcry, Blood Rage, Restraint, Retaliation, Mighty Strikes |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Bloodlust Surge, Savage Cleave. |
| Existing traits | Berserker's Fury (141). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Berserk, Bloodlust Surge, Savage Cleave and a legal starter WS. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Attack | Lv.10 / 30 / 50+ | +8 / +12 / +16% |
| Double Attack | Lv.10 / 30 / 50+ | +6 / +10 / +14% |
| Weaponskill Damage | Lv.10 / 30 / 50+ | +5 / +8 / +12% |
| Store TP | Lv.10 / 30 / 50+ | +5 / +10 / +15 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Bloodlust Surge (Lv10, 25s CD, 10s, Self): +10/14/18/24% Attack% and +15/22/30/40% Double Attack Damage at -10% DEF%.
- Savage Cleave (Lv10, 20s CD, Enemy 4y): Overstraining physical strike (0 TP gained) that inflicts 6/8/10/12% Max HP recoil.
- Berserk: +10% extra Attack%, +60s duration, and instantly grants +300 TP on activation.
- Aggressor: Removes -25 Evasion penalty and grants +5% Critical Hit Rate.
- Blood Rage: +10% extra Critical Hit Rate and +15s duration.

**HUD.** Surge remaining, recoil and current HP. Show server-confirmed events and state only.

**Acceptance fight.** Record damage, HP recoil and lost swings through a boss retaliation. Check Savage Cleave on a single claimed target. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Warcry and the Warrior's combat stances and its signature decision (“Overstrain”). This is a setting-inspired hook for later writing.

## Spartan

WAR 3 · SPT · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/war_specs.lua#L630) · [existing guide](../../guides/spartan.md)

**Player decision.** Brace into a telegraphed impact with polearm and buckler. Build Grit from pressure and Impaling Thrust, then time a WS to renew Iron Resolve.

**Why choose it.** Choose a tank that can prepare a shield wall while using a two-handed weapon. Ronin carries damage forward in time. Spartan needs a ward before the next hit. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set spartan` once the Soul is registered. Polearm plus the supported buckler path. HP, block, accuracy and enmity.

Pinned main WS specialization skills: polearm. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Defender, Provoke, Retaliation, Warcry; Mighty Strikes |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Impaling Thrust, Phalanx Ward. |
| Existing traits | Spartan's Phalanx (142). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Defender (Light Brace), Impaling Thrust, Phalanx Ward (Heavy Brace) and a legal polearm WS. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| Defense | Lv.10 / 30 / 50 / 70+ | +14 / +20 / +26 / +32% |
| Shield Defense Bonus | Lv.10 / 30 / 50 / 70+ | +12 / +24 / +36 / +48 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Phalanx Spear & Buckler Mastery: +15/25/35/50 Polearm & Shield skill, +10/16/22/28% Block Rate, +15/25/35/45 Shield TP. Real Size-1 Buckler: +10% Block and Iron Resolve cap 40% Max HP; empty SUB: 10% virtual Aspis Buckler block.
- Spartan's Grit: taking damage or blocking grants +1 Grit (max 5). Any Polearm WS consumes all Grit for an Iron Resolve barrier (4/5/6/7% Max HP per stack, cap 35%/40%), heavy enmity, and Maim.
- Impaling Thrust (Lv10, 20s CD, Enemy 8y, Polearm): Stun 2s (+5s Silence mid-cast), Maim, +2 Grit (+4 during Defender / Mighty Strikes).
- Phalanx Ward (Lv10, 35s CD, 2 Grit, Self 12s, Polearm): +15/22/30/38% Block, -10/12/15/18% DT, +25/35/45/55 Enmity, Knockback Immunity, arms a Heavy Brace.
- Spear-Wall Brace: Defender (15s CD) arms a Light Brace (-25% next hit, +1 Grit, Off-Balance). Heavy Brace: -50% next hit, Grit to 5, 2s Stun, Exposed Guard (+4s Silence vs spells).

**Source or integration decision.** Actual Brace is armed by Defender or Phalanx Ward. It is not an extra button. A real size-1 buckler and the empty-sub virtual fallback differ.

**HUD.** Grit, Brace and Iron Resolve. Show server-confirmed events and state only.

**Acceptance fight.** Pull without /WAR as a dependency, brace before an attack, then repeat with buckler removed. Check ward depletion. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Warcry and the Warrior's combat stances and its signature decision (“Brace”). This is a setting-inspired hook for later writing.
