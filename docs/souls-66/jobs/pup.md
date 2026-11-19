# PUP · Soul specifications

[Vanguard](#vanguard) · [Animist](#animist) · [Pugilist](#pugilist) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Vanguard | Maintain the Valoredge tank | A controllable shield automaton must absorb the encounter |
| Animist | Choose a maneuver directive | The healer needs a pet-delivered cure, cleanse or ward on demand |
| Pugilist | Prepare the automaton's next WS | A party needs deliberate master-to-frame skillchain timing |

## Vanguard

PUP 1 · VNG · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/pup_specs.lua#L1201) · [existing guide](../../guides/vanguard.md)

**Player decision.** Deploy Valoredge as the actual tank. Direct Strobe, shield responses and Hydraulic Slam, then use H2H WS and Repair to keep the automaton standing.

**Why choose it.** Pick a tank with a dedicated machine chassis and recurring hate tools. Huntsman chooses between two animal command styles. A disabled or absent frame leaves Vanguard exposed. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set vanguard` once the Soul is registered. H2H or existing bare-fist fallback, Valoredge frame/head. Pet HP, defense and repair.

Pinned main WS specialization skills: hand to hand. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None on master. Preserve Valoredge AI. |
| Job abilities and commands | Registered PUP deployment/maintenance and eight Maneuvers, Overdrive; current Valoredge actions via its AI. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Activate, Deus Ex Automata, Deploy, Retrieve, Repair, Cooldown, Ventriloquy, Fire Maneuver, Ice Maneuver, Wind Maneuver, Earth Maneuver, Thunder Maneuver, Water Maneuver, Light Maneuver, Dark Maneuver, Clockwork Bulwark, Hydraulic Slam. |
| Existing traits | Vanguard's Core (164). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Activate, Deploy, Repair, Clockwork Bulwark and Hydraulic Slam. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +28% |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| DEX | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| Defense | Lv.10 / 30 / 50 / 70+ | +14 / +20 / +26 / +32% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Single-Target Valoredge AI: Strobe (12s CD Provoke + -20 ACC Blind), Shield Bash (18s CD 2s NM-safe Stun), Cannibal Blade (20% Auto Max HP heal + VE), Ventriloquy (20s CD swap + 25% VE + -18% DT 8s).
- H2H WS & Repair: H2H WSs heal Valoredge 18% HP, grant Master 10% Alloy Plating Stoneskin (12s) & inflict EFF_OX_DEB_CRIPPLE; Repair (25s CD, 0 oil) heals Valoredge 50% + Master 18% + 1-debuff cleanse.
- Custom JAs: Clockwork Bulwark (35s CD, 12s 50% hit split reduced by 25%, -15% DT & Knockback Immunity) & Hydraulic Slam (22s CD, ST 6y strike + 2s Stun + EFF_OX_DEB_BREACH).

**HUD.** Frame, pet HP, Strobe and Bulwark. Show server-confirmed events and state only.

**Acceptance fight.** Transfer a target to Valoredge after a large cure. Repair during burst and retest following Retrieve and re-deploy. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from frames, attachments and elemental maneuvers and its signature decision (“Maintain the Valoredge tank”). This is a setting-inspired hook for later writing.

## Animist

PUP 2 · ANM · CombatHealer · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/pup_healer_specs.lua#L789) · [existing guide](../../guides/animist.md)

**Player decision.** Choose Light, Water or Earth Maneuver for a direct heal, cleanse or ward. Attack with H2H to pulse the maneuver and feed Aether Cells, then decide when to Overhaul.

**Why choose it.** Choose a healer able to direct its automaton to a specific response. Medic delegates cleansing to Eos. Wrong maneuver or dead pet costs the intended response. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set animist` once the Soul is registered. H2H and a supported healer frame. MND, repair and cure potency, pet MP.

Pinned main WS specialization skills: hand to hand. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None on master. Preserve the existing medic automaton spell table. |
| Job abilities and commands | Registered PUP controls and eight Maneuvers, Overdrive. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Activate, Deus Ex Automata, Deploy, Retrieve, Repair, Ventriloquy, Cooldown, Fire Maneuver, Ice Maneuver, Wind Maneuver, Earth Maneuver, Thunder Maneuver, Water Maneuver, Light Maneuver, Dark Maneuver, Aether Overhaul, Clockwork Aegis. |
| Existing traits | Clockwork Medic (174). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Activate, Light/Water/Earth Maneuver, Repair and Aether Overhaul. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +28% |
| MND | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| VIT | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| DEX | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Automaton Medic (Harlequin/Stormwaker/Soulsoother): +40/50/60/75% HP/MP, -35% DT, +40/50/60/70% Fast Cast, +6/9/12/16 MP/t Refresh, -60 Enmity, 100% AoE/Breath resist, and built-in Cure I-V, Erase & -na White Magic @ Lv10+.
- Maneuver Directives (10s shared CD): Light (16/19/22/25% single-target mend + 15/30/45% Cure splash), Water (+12% Auto MP, 1 Erase + 12y Hybrid Regen mist), Earth (12% Stoneskin + Cure overheal -> 18% Stoneskin).
- H2H Synchronized Overclock: H2H WSs restore +10% Auto MP, shave -4s Auto recasts, grant +1 Aether Cell (max 3), and fire Light/Water/Earth pulses; Repair (30s CD, 0 oil, 50% Auto HP/MP + 12s Hybrid Regen); Ventriloquy/Cooldown (30s CD, -40% Enmity + 1 Cell).
- Aether Overhaul (45s CD, spends 0..3 Cells for 16/21/26/31% party+pet heal, 2-3 cleanse & Auto reset) & Clockwork Aegis (75s CD, 15s: 18% Stoneskin + shared Ward -12% DMG / +30 MEVA).

**HUD.** Maneuver, Aether Cells, frame HP/MP. Show server-confirmed events and state only.

**Acceptance fight.** Fire the three directives separately, then Overhaul at 0 and 3 cells. Confirm only the chosen directive responds. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from frames, attachments and elemental maneuvers and its signature decision (“Choose a maneuver directive”). This is a setting-inspired hook for later writing.

## Pugilist

PUP 3 · PGL · Damage · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/pup_specs.lua#L1282) · [existing guide](../../guides/pugilist.md)

**Player decision.** Use a master H2H WS to feed TP and create a Tandem Opening. Prepare the frame and maneuvers so its next real WS catches the opening and extends the team's chain.

**Why choose it.** Choose a configurable machine as a skillchain partner. Untamed needs a living beast landing real Ready attacks on the same target and returns tempo in both directions. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set pugilist` once the Soul is registered. H2H and offensive automaton frame. Master/pet accuracy, TP and attack.

Pinned main WS specialization skills: hand to hand. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None on master. Preserve offensive frame AI. |
| Job abilities and commands | Registered PUP controls and eight Maneuvers, Overdrive. |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Activate, Deus Ex Automata, Deploy, Retrieve, Repair, Cooldown, Ventriloquy, Fire Maneuver, Ice Maneuver, Wind Maneuver, Earth Maneuver, Thunder Maneuver, Water Maneuver, Light Maneuver, Dark Maneuver, Tandem Barrage, Limiter Release. |
| Existing traits | Pugilist's Rhythm (180). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Activate, Deploy, H2H starter WS, Tandem Barrage and Limiter Release. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Attack | Lv.10 / 30 / 50 / 70+ | +15 / +22 / +30 / +38% |
| Ranged Attack | Lv.10 / 30 / 50 / 70+ | +15 / +22 / +30 / +38% |
| Martial Arts Delay | Lv.10 / 30 / 50 / 70+ | -10 / -15 / -20 / -25 |
| Double Attack | Lv.10 / 30 / 50 / 70+ | +10 / +15 / +20 / +25% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Tandem Combo Loop: H2H WSs grant +350 Pet TP & 8s single-target Tandem Opening (+25% damage on String Shredder/Armor Shatterer/Arcuballista/Bone Crusher & +3s Skillchain window).
- Custom JAs: Tandem Barrage (25s CD, ST 6y strike, +300 TP both, -15% DEF 10s) & Limiter Release (35s CD, 12s +22% ATK/RATK, +15% DA/Rapid Shot, -15% DEF); Overdrive grants +50 Store TP & 0s Maneuver CDs.

**HUD.** Pet TP, frame, opening and Limiter. Show server-confirmed events and state only.

**Acceptance fight.** Let one opening expire and consume a second with the automaton WS. Compare damage, timing and master/pet attribution. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from frames, attachments and elemental maneuvers and its signature decision (“Prepare the automaton's next WS”). This is a setting-inspired hook for later writing.
