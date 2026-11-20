# COR · Soul specifications

[Flintlock](#flintlock) · [Gambler](#gambler) · [Buccaneer](#buccaneer) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Flintlock | Sustain successive pistol volleys | A single target allows long firing uptime |
| Gambler | Stand or double up | Reliable party rolls plus a voluntary cooldown gamble |
| Buccaneer | Convert Grapeshot into a shield | Close-range gun control and timed personal shielding |

## Flintlock

COR 1 · FLT · Damage · Partially Implemented · [server registration and hooks](../../../modules/custom/lua/cor_specs.lua#L1410) · [existing guide](../../guides/flintlock.md)

**Player decision.** Main uses Quick Draw to mark a target, a gun WS to detonate it, and a self-only Deadeye Chamber. The separate twin-pistol target is sustained waves of lighter shots on one enemy.

**Why choose it.** Choose repeated single-target fire with two independently acting pistols. Sniper trades volume for one deliberate shot. Movement and interrupted firing cost Flintlock sustained output. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set flintlock` once the Soul is registered. Main gun with bullets. Owner's target uses two pistols and shared ammo. Preserve the existing owner's equipment and recovery conventions.

Pinned main WS specialization skills: marksmanship. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Current Flintlock grants, Quick Draw shots, Phantom Roll (Deadeye), Hair Trigger, Broadside Salvo. Twin-pistol actions belong to their owner. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Phantom Roll, Fire Shot, Ice Shot, Wind Shot, Earth Shot, Thunder Shot, Water Shot, Light Shot, Dark Shot, Hair Trigger, Broadside Salvo. |
| Existing traits | Flintlock Deadeye (178). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Current gun, bullets, self Roll, Quick Draw and one gun WS. The independent owner defines the dual-pistol starter. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Enmity | Lv.10 / 30 / 50 / 70+ | -15 / -20 / -25 / -35 |
| Ranged Attack | Lv.10 / 30 / 50 / 70+ | +15 / +22 / +30 / +40% |
| Magic Atk. Bonus | Lv.10 / 30 / 50 / 70+ | +15 / +22 / +30 / +40 |
| Snapshot | Lv.10 / 30 / 50 / 70+ | +20 / +30 / +40 / +50% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Deadeye Chamber (Phantom Roll, 15s CD, self-only): +15/20/25/30% Ranged/Magic WS DMG & +15% Ranged Crit DMG for 30s.
- Powder Mark (Quick Draw, 10s charge, 2 charges): marks target for 10s; Marksmanship WS detonates +20% elemental dmg & refunds +150 TP.
- Crystal JAs: Hair Trigger (30s CD, +30% Snapshot & +25% WS DMG / -15% DEF), Broadside Salvo (22s CD, 20y single-target 2.0-3.2x shot, +250 TP, +1 QD charge).

**Source or integration decision.** Owner boundary applies at 10, 30, 50, 70 and 75. Preserve independent pistol actions, shared ammunition, separate TP accounting and the owner-defined hybrid ordinary-fire path. The external implementation owns pacing, animation, hand state and reset semantics. No new pistol spell, JA, WS, ID, ammo debit or firing timer is specified by this branch.

**HUD.** Current Powder Mark/Deadeye; display twin-pistol state only when its owner supplies it. Show server-confirmed events and state only.

**Acceptance fight.** Test the main single-gun fallback, then run the owner's acceptance for independent fire/TP, shared ammo, strip/re-equip and single-target credit. No implementation work on twin pistols in this handoff. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from dice, cards and firearms and its signature decision (“Sustain successive pistol volleys”). This is a setting-inspired hook for later writing.

## Gambler

COR 2 · GMB · Support · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/cor_specs.lua#L1463) · [existing guide](../../guides/gambler.md)

**Player decision.** Keep three reliable rolls active. Stand on the safe floor or ante 10% current HP and 150 TP on Double-Up for a Lucky/XI reward, with personal debt on bust.

**Why choose it.** Choose stable group buffs with a voluntary personal risk for a cooldown payout. Commander delivers deterministic calls. A low-HP or TP-starved Gambler cannot chase a jackpot freely. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set gambler` once the Soul is registered. Gun with bullets or dagger; cards where applicable. HP, roll potency and TP reserve.

Pinned main WS specialization skills: marksmanship, dagger. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Phantom Roll and learned roll family, Double-Up, Quick Draw, Snake Eye, Fold, Random Deal, Wild Card, Crooked Cards |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Fire Shot, Ice Shot, Wind Shot, Earth Shot, Thunder Shot, Water Shot, Light Shot, Dark Shot, Random Deal, Snake Eye, Fold, House Advantage, Dead Man's Hand. |
| Existing traits | High Roller Stakes (177). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Phantom Roll, Double-Up, one starter roll, House Advantage and Quick Draw. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| Max MP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| AGI | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +32 |
| CHR | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +32 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- High-Roller Stakes: Rolls 1-10 have Roll 8-9 Safe Standing; Lucky & XI clear Bust and pulse +150 TP & +8% MP (15y).
- Random Deal (35s CD, 15y) shaves -12s off standard party JAs (excludes 1hrs/Wild Card/Random Deal/Dead Man's Hand); Quick Draw shaves -3s & applies Expose.
- Crystal JAs: House Advantage (30s CD, forced XI + 15y Offense), Dead Man's Hand (35s CD, single-target 2x Dispel + Breach, -10s party JAs, +200 TP on Lucky/XI).

**Source or integration decision.** Runtime Double-Up charges 10% current HP and 150 TP even on a forced XI. Jackpot shaves 8s initially, +2s per further applicable ante up to 14s. Bust inflicts nonlethal personal HP backlash, House Debt and roll lock. The guide's simple forced-XI description omits this pricing. Retain exclusions for powerful and reset abilities.

**HUD.** Roll totals, Lucky/XI, ante/debt and lock. Show server-confirmed events and state only.

**Acceptance fight.** Stand on 1–10, force a bust, and compare party buffs to the COR's HP/TP and debt. Check excluded cooldowns at jackpot. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from dice, cards and firearms and its signature decision (“Stand or double up”). This is a setting-inspired hook for later writing.

## Buccaneer

COR 3 · BUC · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/cor_specs.lua#L1537) · [existing guide](../../guides/buccaneer.md)

**Player decision.** Use a sword WS and pistol order at close range to build Grapeshot. Choose the Quick Draw element for Salt-Spray utility and turn stacks into a Stoneskin buffer.

**Why choose it.** Pick a close-range tank that converts gun charges into protection or disruption. Spartan spends a polearm WS on its shield wall. Buccaneer needs sword and gun together. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set buccaneer` once the Soul is registered. One-handed sword, gun, bullets, optional buckler. HP and enmity.

Pinned main WS specialization skills: sword. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Phantom Roll (Galleon's Roll), Quick Draw shots |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Phantom Roll, Fire Shot, Ice Shot, Wind Shot, Earth Shot, Thunder Shot, Water Shot, Light Shot, Dark Shot, Grapeshot Broadside, Iron Hull. |
| Existing traits | Buccaneer Bulwark (179). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Galleon's Roll, Quick Draw, Grapeshot Broadside and Iron Hull. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +26% |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| AGI | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| Defense | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +30% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Galleon's Roll (20s CD, self-only): -12% DT, +20% DEF, +25 Enmity for 60s.
- Point-Blank Pistol (1H Sword WS): strictly single-target enmity blast, heals 8/10/12/14% Max HP, +1 Grapeshot (max 3); Quick Draw consumes Grapeshot for 6%/stack Stoneskin + utility.
- Crystal JAs: Grapeshot Broadside (25s CD, single-target 12y enmity + Blind + Slow + 2 Grapeshot), Iron Hull (45s CD, -18% DT, Knockback Immunity, 20% heal + cleanse).

**HUD.** Grapeshot, Stoneskin and active roll. Show server-confirmed events and state only.

**Acceptance fight.** At one and three stacks measure shield size. Remove the gun before the sword WS and verify no pistol proc. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from dice, cards and firearms and its signature decision (“Convert Grapeshot into a shield”). This is a setting-inspired hook for later writing.
