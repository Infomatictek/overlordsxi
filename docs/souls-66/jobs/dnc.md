# DNC · Soul specifications

[Vampire](#vampire) · [Bladewheel](#bladewheel) · [Mirage Sentinel](#mirage-sentinel) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Vampire | Heal through landed attacks | A long damageable target supports MP-free group sustain |
| Bladewheel | Dance at chakram range | Melee is hazardous but Dazes and Sambas need upkeep |
| Mirage Sentinel | Parry and choose a Flourish | Frequent single-target hate snaps and short interrupts |

## Vampire

DNC 2 · VMP · CombatHealer · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/dnc_healer_specs.lua#L259) · [existing guide](../../guides/vampire.md)

**Player decision.** Use Drain Samba, hits and Steps for group sustain, converting overheal to Crimson Veil. Spend Finishing Moves with dagger/throwing WS when someone needs a burst or cleanse.

**Why choose it.** Choose a zero-MP healer that profits from sustained damage contact. Chi Weaver heals from range with pulse placement. High defenses and lost contact punish Vampire. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set vampire` once the Soul is registered. Dual daggers or throwing chakram. Accuracy, HP and healing output.

Pinned main WS specialization skills: dagger, throwing. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Drain Samba I–III, Steps, Curing Waltz I–V, Healing Waltz, Divine Waltz I–II, Reverse Flourish, Trance, Contradance |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Drain Samba, Drain Samba II, Drain Samba III, Sanguine Waltz, Nocturne Feast. |
| Existing traits | Crimson Waltz (172). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Drain Samba, Quickstep, starter WS, Sanguine Waltz and Nocturne Feast. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +28% |
| DEX | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| AGI | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| CHR | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Crimson Drain Samba: Party (15y) heals for 18/24/30/36% of physical damage dealt; overhealing converts into Crimson Veil Stoneskin (up to 20% Max HP).
- Sanguine Flourish: Steps grant +2 FM & 10% party heal; Dagger/Throwing WSs consume up to 5 FM for 6%/FM AoE heal + party cleanse.
- JA Enhancements: Trance (0 TP Waltzes, infinite FMs, 2x Drain Samba) & Contradance (15s CD, +100% Waltz & -15% DT 10s).
- Sanguine Waltz (18s CD, 200 TP: 30% HP AoE heal + 2-debuff cleanse + 25 + 3.5% Max HP/t Regen) & Nocturne Feast (25s CD: drains 15% foe HP into party HP + 250 TP + 5 FMs).

**HUD.** Finishing Moves, Veil and Samba. Show server-confirmed events and state only.

**Acceptance fight.** Compare one weak and one hard-hitting attack on equally injured allies. Check overheal conversion and no hostile splash. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Steps, Flourishes, Waltzes and Sambas and its signature decision (“Heal through landed attacks”). This is a setting-inspired hook for later writing.

## Bladewheel

DNC 3 · BLW · Damage · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/dnc_specs.lua#L779) · [existing guide](../../guides/bladewheel.md)

**Player decision.** Set Throwing Stance to fight with a chakram. Keep Dazes and Samba active at range, then decide when to spend Finishing Moves on a throwing finisher.

**Why choose it.** Choose a ranged physical skirmisher who continues dancing outside melee. Sniper waits still for one shot. Bladewheel needs the correct ranged slot and dance timing. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set bladewheel` once the Soul is registered. Chakram in ranged, ammo empty; dagger/sword for melee fallback. Throwing skill, accuracy and DEX.

Pinned main WS specialization skills: throwing, dagger, sword. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Throwing Stance, Steps, Sambas, Flourishes, Curing Waltz family, Saber Dance, Trance |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Throwing Stance. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Throwing Stance, starter throwing WS, Quickstep and Drain Samba. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Ranged Accuracy | Lv.10 / 30 / 50 / 70+ | +10 / +22 / +36 / +48 |
| Ranged Attack | Lv.10 / 30 / 50 / 70+ | +10 / +24 / +40 / +54 |
| Snapshot | Lv.10 / 30 / 50 / 70+ | +5 / +10 / +15 / +20% |
| AGI | Lv.10 / 30 / 50 / 70+ | +3 / +6 / +10 / +14 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Auto-attacks with equipped chakram when outside melee range.
- Throwing Stance (JA): overrides melee auto-attacks with chakram throws at all ranges.
- Unlocks 12 custom Dancer Throwing weaponskills (Lv 5-75).
- Steps and offensive Flourishes work up to 20 yalms.
- Drain, Aspir, and Haste Samba trigger on ranged chakram hits.

**HUD.** Stance, Dazes, Finishing Moves and finisher. Show server-confirmed events and state only.

**Acceptance fight.** Test first throwing WS at 20y with ammo empty. Toggle stance and check correct range/cadence after losing target. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Steps, Flourishes, Waltzes and Sambas and its signature decision (“Dance at chakram range”). This is a setting-inspired hook for later writing.

## Mirage Sentinel

DNC 4 · MRS · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/dnc_specs.lua#L817) · [existing guide](../../guides/miragesentinel.md)

**Player decision.** Maintain Fan Dance with dual daggers. Parry, Step, then choose the Flourish that pulls, interrupts or converts moves into an Aegis Waltz shield.

**Why choose it.** Choose a tank with frequent control and Waltzes while Fan Dance is active. Sensei heals on counters. Mirage needs moves and timing for the right shield. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set miragesentinel` once the Soul is registered. Dual daggers. Parry, HP, accuracy and enmity.

Pinned main WS specialization skills: dagger. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Fan Dance, Steps, Animated/Building/Violent/Desperate Flourish, Curing Waltzes, Healing Waltz, Pirouette Deflect, Dazzling Cadence, Trance |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Curing Waltz, Quickstep, Box Step, Animated Flourish, Desperate Flourish, Violent Flourish, Fan Dance, Pirouette Deflect, Dazzling Cadence. |
| Existing traits | Mirage Rhythm (168), Dual Wield (18). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Animated Flourish, Violent Flourish, Fan Dance, Curing Waltz I–III, Quickstep and Box Step. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| DEX | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| Defense | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +30% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Dual Dagger Mastery: Dual Wield (-15/20/25/30% delay), +12/16/20/24% Parry Rate, +15/20/25/30 Subtle Blow, +15/25/35/50 Dagger & Parrying.
- Fan Dance Rhythm (15s CD, does not lock Waltzes): -30% Phys/Mag DT (decays 5%/hit, floor -10%); Dagger WSs restore +10% & +1 FM.
- Steps (5s CD, 0 TP): +2 FMs, snap enmity, EFF_OX_DEB_CRIPPLE (-5% ATTP/MATT & -7 ACC/stack, max 3); Flourishes grant 3% Max HP/FM Stoneskin + cleanse.
- Pirouette Deflect (40s CD, Self 8s) & Dazzling Cadence (25s CD, Single-Target 6y): reset Fan Dance, +20% Parry + Knockback Immunity; 2s Stun + Blind + Slow + 3 FMs.

**Source or integration decision.** Registration exposes named constants including BUILDING_FLOURISH; wiki lists a differently named flourish. Bind against actual local enum and resource row. Curing Waltz I–III at 10 is the owner's target even if the current extra grant only includes one ID. Preserve branch 4.

**HUD.** Finishing Moves, shield, provoke and stun recasts. Show server-confirmed events and state only.

**Acceptance fight.** Pull without a WAR subjob, Waltz under Fan Dance and test a parry string. Check server branch 4 across socket and search displays. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Steps, Flourishes, Waltzes and Sambas and its signature decision (“Parry and choose a Flourish”). This is a setting-inspired hook for later writing.
