# RUN · Soul specifications

[Spellblade](#spellblade) · [Lifebinder](#lifebinder) · [Inquisitor](#inquisitor) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Spellblade | Conduct a runic spell | Great-sword uptime can prepare a personal magic burst |
| Lifebinder | Prepare the right runic Pulse | A frontline party needs different healing or cleanse outcomes |
| Inquisitor | Switch parry and rune ward stances | Physical and elemental boss phases alternate |

## Spellblade

RUN 1 · SPB · Damage · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/run_specs.lua#L1290) · [existing guide](../../guides/spellblade.md)

**Player decision.** Choose a rune element, attack with a great sword and use Effusion Slash to charge Conduction. Spend that preparation on Runic Bolt or Sever during a burst window.

**Why choose it.** Choose a melee caster who turns rune selection and contact into a prepared offensive cast. Scarlet Weaver switches damage mode as defenses change. Lost contact delays Conduction. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set spellblade` once the Soul is registered. Great sword. Accuracy, STR, MAB and magic accuracy.

Pinned main WS specialization skills: great sword. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Exact RUN_NATIVE_SPELLS plus the two current Runic Bolt/Sever mappings in run_specs. |
| Job abilities and commands | Eight rune enchantments, Swipe, Lunge, Swordplay, Vallation, Valiance, Pflug, Battuta, Liement, Gambit, Rayke, Elemental Sforzo. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Effusion Slash, Overcharge Runes, Swordplay, Pflug, Valiance, Battuta, Liement. |
| Existing traits | Runic Brand (151). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Runes, Effusion Slash, Overcharge Runes, Runic Bolt and Runic Sever. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Great Sword Skill | Lv.10 / 30 / 50 / 70+ | 0 / 0 / 0 / +7 |
| Elemental Magic Skill | Lv.10 / 30 / 50 / 70+ | +33 / +93 / +153 / +269 |
| Magic Atk. Bonus | Lv.10 / 30 / 50 / 70+ | +12 / +20 / +28 / +36 |
| Magic Accuracy | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +28 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Skills & Passives: Greatsword A+, Elemental Magic A, Enhancing Magic B, +12/20/28/36 MAB, +8/14/20/28 MACC; one Rune Enchantment fills all unlocked slots (1/2/3 at Lv5/35/65).
- Rune Edge: First landed normal Greatsword hit per round deals floor((0.08*GS + 0.04*Enh + 4*Runes) * Delay/480) elemental damage (2x during Overcharge Runes) and builds Conduction (max 3) + MP.
- Effusion Slash (Lv10, 20s CD, Enemy 4y): Non-consuming Great Sword arcane strike (1.5x-2.8x +20%/Rune) aligned to newest Rune; can Magic Burst (+35% DMG) and grants +100/150/200/250 TP.
- Overcharge Runes (Lv10, 30s CD, Self): 12s overdrive granting +15/22/30/40 MAB, +10/14/18/24% Attack%, +15/20/25/30 MB Bonus, 2x Runic Brand damage, and refreshes active Rune durations.
- Magic Spell: Runic Bolt (Lv10, 2.0s cast, 8s CD, 8-24 MP, 10y): High-potency arcane bolt scaling with Elemental Skill, Weapon DMG, INT, STR, Runes (+5%/Rune), & Conduction (+10% DMG, -0.5s cast, -15% MP/stack).

**HUD.** Runes, Conduction and Edgeflare. Show server-confirmed events and state only.

**Acceptance fight.** Compare Bolt/Sever at zero and full Conduction. Change element and check only the intended cast consumes the preparation. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from rune enchantments, swordplay and elemental wards and its signature decision (“Conduct a runic spell”). This is a setting-inspired hook for later writing.

## Lifebinder

RUN 2 · LFB · Healer · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/run_specs.lua#L1373) · [existing guide](../../guides/lifebinder.md)

**Player decision.** Choose three runes for the next Vivacious Pulse. Swing for Runic Lifetap, cover ongoing harm with party Regen, and hold a rune combination that answers the next status or damage event.

**Why choose it.** Choose a healer whose next response can be prepared by rune selection. Templar's beacon selects by HP and Verdant commits to a location. Wrong runes make the pulse less useful. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set lifebinder` once the Soul is registered. RUN open WS skills. Great sword preferred for melee uptime. MND, HP, cure potency and Regen.

Pinned main WS specialization skills: sword, great sword, axe, great axe, club. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Exact RUN_NATIVE_SPELLS, including Regen I–IV at existing grants. |
| Job abilities and commands | Eight rune enchantments, Swordplay, Valiance, Vallation, One for All, Vivacious Pulse, Elemental Sforzo. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Valiance, One for All, Sacred Pulse (Vivacious Pulse), Font of Life, Sanctified Ward. |
| Existing traits | Sacred Pulse (152). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Three runes, Vivacious Pulse, Regen, Font of Life and Sanctified Ward. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max MP | Lv.10 / 30 / 50 / 70+ | +10 / +18 / +28 / +35% |
| Refresh | Lv.10 / 30 / 50 / 70+ | +2 / +4 / +7 / +10/tick |
| MND | Lv.10 / 30 / 50 / 70+ | +8 / +16 / +25 / +32 |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +16 / +25 / +32 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Sacred Pulse (Vivacious Pulse at Lv10, 15s CD, Party 12y AoE): Party heal + per-Rune boons (Lux: +25% heal & Regen; Unda: Party debuff cleanse; Tenebrae: Caster MP & Party Refresh; Elemental: 25% Stoneskin).
- Font of Life (Lv10, 20s CD, Ally 15y): Restores 22/30/38/48% Max HP, cleanses 2 status ailments, and grants -10/14/18/22% DT & +10/15/20/25% Cure Rcvd for 12s.
- Sanctified Ward (Lv10, 35s CD, 15s, Party 12y): Instant 10/14/18/22% Party HP heal + 15s Sanctuary (25 + 3.5% Max HP/tick Regen, -8/12/16/20% DT, +15/25/35/50 MEVA).
- Runic Lifetap: Melee hits & WSs while holding Runes mend the most injured party member (2.5-5% HP + 0.5*MND) and restore 1-3% Max MP.
- AoE Regen & Wards: Regen I-IV project as 10y Party AoE with +50% potency & +60s duration; One for All (60s CD) also heals the party for 18% of your Max HP; Valiance (60s CD) grants +15% Cure Rcvd & Fast Cast.

**HUD.** Rune order, next Pulse result, Regen and ward. Show server-confirmed events and state only.

**Acceptance fight.** Repeat Pulse with two distinct combinations against the same injury/status. Measure lifetap separately from Regen. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from rune enchantments, swordplay and elemental wards and its signature decision (“Prepare the right runic Pulse”). This is a setting-inspired hook for later writing.

## Inquisitor

RUN 3 · INQ · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/run_specs.lua#L1231) · [existing guide](../../guides/inquisitor.md)

**Player decision.** Read whether the incoming string is physical or magical, hold the matching runes and switch between Iron Battuta and Runic Aegis. Use Convergence at the right transition.

**Why choose it.** Choose for alternating elemental and physical threats. Crimson Duelist depends on sticking enfeebles. Misreading a phase gives up the more useful stance. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set inquisitor` once the Soul is registered. RUN open WS skills; great sword maximizes the parry benefit. HP, parry, magic evasion and enmity.

Pinned main WS specialization skills: sword, great sword, axe, great axe, club. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Exact RUN_NATIVE_SPELLS in run_specs. |
| Job abilities and commands | Eight rune enchantments, Swordplay, Pflug, Liement, Battuta, Vallation, Valiance, Swipe, Lunge, Gambit, Rayke, One for All, Elemental Sforzo. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Swordplay, Pflug, Liement, Battuta, Stance: Iron Battuta, Stance: Runic Aegis, Runic Convergence. |
| Existing traits | Inquisitor's Ward (150). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Three runes, Iron Battuta, Runic Aegis, Runic Convergence and Flash. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +24% |
| VIT | Lv.10 / 30 / 50 / 70+ | +6 / +12 / +20 / +25 |
| AGI | Lv.10 / 30 / 50 / 70+ | +6 / +12 / +20 / +25 |
| Damage Taken | Lv.10 / 30 / 50 / 70+ | -5 / -8 / -12 / -15% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Parry & Runic Persistence: +12/24/40/50 Parry & Great Sword Skill, +6/10/15/18% Parry Rate (+10% w/ GS); 3 Runes at Lv10+; Swipe/Lunge/Gambit/Rayke preserve Runes & add Enmity.
- Runic Riposte: Parrying heals 1.5% Max HP, restores 1% Max MP, grants +50 TP & +Enmity, and deals an elemental counter-slash.
- Stance: Iron Battuta (Lv10, 15s CD): +15/22/30/40% Parry Rate, -8/12/16/20% PDT, +15/25/35/50% DEF; swap triggers Steel Flash (+Enmity & 4/6/8/10% HP Stoneskin).
- Stance: Runic Aegis (Lv10, 15s CD): -10/15/20/25% MDT/BDT, +20/35/50/70 MEVA, +15/25/35/50 MDEF, +10/15/20/25% Magic Absorb; swap triggers Odyllic Pulse (+Enmity, HP/MP & cleanse).
- Runic Convergence (Lv10, 30s CD, 10s): Fuses both stances (-12/16/20/25% DT, +20/30/40/50% Parry, +30/45/60/80 MEVA, +Enmity) and heals 3% HP per Rune.

**HUD.** Stance, held runes and transition cooldown. Show server-confirmed events and state only.

**Acceptance fight.** Alternate physical and elemental hits in each stance. Check rune retention on Lunge and hate recovery at zero TP. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from rune enchantments, swordplay and elemental wards and its signature decision (“Switch parry and rune ward stances”). This is a setting-inspired hook for later writing.
