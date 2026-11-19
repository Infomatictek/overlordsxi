# PLD · Soul specifications

[Templar](#templar) · [Defender](#defender) · [Oathbreaker](#oathbreaker) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Templar | Beacon the lowest ally | Frontline triage and clustered Majesty cures |
| Defender | Intercept for allies | Exposed party members within interception range |
| Oathbreaker | Choose an encounter vow | A predictable fight with a stable offensive or reactive assignment |

## Templar

PLD 1 · TMP · CombatHealer · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/pld_healer_specs.lua#L329)

**Player decision.** Keep Majesty active. Land club strikes to beacon the lowest ally, then decide whether splash cures or a shield-assisted emergency JA suit the next incoming hit.

**Why choose it.** Pick a frontline healer for the most injured ally plus immediate group cures. Defender absorbs allies' incoming damage. Wyvernheart routes triage through jumps and a living wyvern. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set templar` once the Soul is registered. Club and shield. HP, MND, cure potency and shield block.

Pinned main WS specialization skills: club. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Cure I–IV, Protect, Shell, Flash, Reprisal and Raise. |
| Job abilities and commands | Majesty, Divine Seal, Chivalry, Rampart, Sentinel, Invincible, Shield Bash |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Majesty, Chivalry, Holy Radiance, Crusader's Aegis. |
| Existing traits | Perpetual Majesty (170). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Majesty, Cure, Holy Radiance, Crusader's Aegis, club WS. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +26% |
| Max MP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +26% |
| MND | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| VIT | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Perpetual Majesty: Always active @ Lv10+ (0s lockout); single-target Cures splash to party (15y) at 100% potency; overhealing grants Light's Grace (15 + 2.2% Max HP/tick HoT, 10s).
- Beacon of Light: Melee hits and Club WSs heal the lowest-HP ally (12y) for 8/11/14/18% PLD Max HP and restore +5% Max MP.
- JA Enhancements: Divine Seal (20s CD, 2-debuff party cleanse), Chivalry (15s CD, 40% MP + 15% AoE heal), Rampart (-15% DT aura), Sanctuary Benediction (replaces Invincible: 100% party heal/cleanse + -20% DT).
- Holy Radiance (20s CD, Club+Shield: 25% HP AoE heal + 2-debuff cleanse + 10% MP) & Crusader's Aegis (25s CD, 10s -15% DT + Knockback Immune + 2x Beacon).

**HUD.** Beacon recipient, Majesty and Aegis. Show server-confirmed events and state only.

**Acceptance fight.** Injure two allies by different amounts. Verify Beacon chooses the intended ally and splash cures do not recursively splash. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from oaths, shields and divine intervention and its signature decision (“Beacon the lowest ally”). This is a setting-inspired hook for later writing.

## Defender

PLD 2 · DFN · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/pld_specs.lua#L774) · [existing guide](../../guides/aegistemplar.md)

**Player decision.** Stand in reach of allies with club and shield. Interception and blocks build Zeal. Spend Zeal on the next Flash, Shield Bash, qualifying club WS or Judgment Gavel.

**Why choose it.** Choose to protect someone else taking a hit. Spartan shores up its own shield wall. Scattered allies and simultaneous heavy hits make interception expensive. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set aegistemplar` once the Soul is registered. Club and shield. Block, HP, enmity and mitigation.

Pinned main WS specialization skills: club. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Flash, Cure I–IV, Protect, Shell, Reprisal, Phalanx. |
| Job abilities and commands | Shield Bash, Sentinel, Rampart, Cover, Palisade, Majesty, Invincible |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Aegis Consecration, Judgment Gavel. |
| Existing traits | Aegis Devotion (165). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Flash, Shield Bash, Aegis Consecration, Judgment Gavel. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +26% |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| MND | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| Defense | Lv.10 / 30 / 50 / 70+ | +14 / +20 / +26 / +32% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Club & Shield Mastery: +15/25/35/50 Club & Shield skill, +3/5/7/9 Shield DEF Bonus, +12/18/24/30% Block (+10% w/ Club+Shield), +20/30/40/50 Shield Mastery TP, 100% SIRD w/ Shield.
- Divine Intercept: While Shield+Club equipped & >35% HP, redirects 25% of party damage within 10y (40% in Consecration) onto PLD (-20% dmg, capped at 12%/18% Max HP per hit and 30%/40% per 1.5s AoE window).
- Zeal & Holy Retribution (Max 5): Blocking or intercepting grants +1 Zeal; at 5 Zeal, Flash / Shield Bash / Club WS detonates Holy Nova (+8% Max MP, party -10% DT for 8s, heavy enmity).
- Club WS Engine & JAs: Club WSs scale off VIT+MND, inflict -15% ATK/MATK Down (Skullbreaker/Brainshaker), and restore party HP/MP; enhances Sentinel, Rampart, Chivalry, and Invincible.

**HUD.** Zeal, intercept coverage and party ward. Show server-confirmed events and state only.

**Acceptance fight.** Compare the same attack on an ally inside and outside intercept range. Check both HP deltas and total redirected damage. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from oaths, shields and divine intervention and its signature decision (“Intercept for allies”). This is a setting-inspired hook for later writing.

## Oathbreaker

PLD 3 · OTB · Damage · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Before the pull choose Condemn for sustained great-sword punishment or Absolve for a riposte after you personally take a meaningful hit. Commit to the choice through that encounter.

**Why choose it.** Choose predictable damage under a chosen vow. Reaper times its hit after the enemy's action regardless of whom it targeted. A bad pre-pull vow costs Oathbreaker a phase. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set oathbreaker` once the Soul is registered. Great sword, STR, accuracy, HP.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Banish I–II, Flash, Protect I–III, Shell I–III. Flash unavailable under Condemn. |
| Job abilities and commands | Swear Condemn, Swear Absolve, Reckoning. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Choose either oath out of combat, 5s shared recast, persist until disengaged with no hate. Reckoning single target 4y, 18s CD, damage = 1.5 × one normalized noncritical main-hand attack after defense. Condemn increases regular GS damage 10% and disables Flash. Absolve grants 8% personal DT and doubles Reckoning after a single enemy hit ≥8% max HP within 5s. Invalid target never spends it. |
| 30–49 | Condemn 13%, Absolve 10% DT. Reckoning 1.7×. |
| 50–69 | Condemn 16%, Absolve 12%. Absolve's reactive window extends to 7s; one qualifying hit cannot be reused. |
| 70–75 | Condemn 18%, Absolve 12%, Reckoning 2.0× through 75. No party interception. Vow resets on Soul removal. |

**HUD.** Oath, eligible retaliation and time left.. Show server-confirmed events and state only.

**Acceptance fight.** Try swapping on hate list and test a qualifying hit on an ally versus the player. Only the latter arms Absolve. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from oaths, shields and divine intervention and its signature decision (“Choose an encounter vow”). This is a setting-inspired hook for later writing.
