# BRD · Soul specifications

[Adventurer](#adventurer) · [Musician](#musician) · [Minstrel](#minstrel) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Adventurer | Turn melee cadence into sonic WS | A melee slot must keep songs up during sustained contact |
| Musician | Burst with hostile songs | Frequent allied skillchains and time to sing |
| Minstrel | Sing for enmity | Ranged threat while sustaining personal defensive songs |

## Adventurer

BRD 1 · ADV · Damage · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/brd_specs.lua#L758) · [existing guide](../../guides/adventurer.md)

**Player decision.** Keep useful songs rolling, dual-wield dagger/sword to build Cadence and release the sonic follow-up and Encore with a WS.

**Why choose it.** Choose melee DPS that maintains songs while fighting. Musician spends its windows actually casting offensive songs. Losing melee access stalls Cadence. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set adventurer` once the Soul is registered. Dagger or sword in main and offhand, instrument. CHR, accuracy and melee stats.

Main has no explicit WS profile row for this key. Preserve currently legal WS; use the listed weapon conditions for signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Minuet, Madrigal, March, Minne, Mambo, Paeon, Ballad, Carol and Prelude song families. |
| Job abilities and commands | Pianissimo, Nightingale, Troubadour, Soul Voice |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Lunge Flourish, Troubadour's Encore. |
| Existing traits | Dual Wield (18), Adventurer's Tempo (155). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: One learned buff song, Lunge & Flourish and starter WS. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| DEX | Lv.10 / 30 / 50 / 70+ | +5 / +10 / +16 / +22 |
| CHR | Lv.10 / 30 / 50 / 70+ | +4 / +8 / +14 / +18 |
| Attack | Lv.10 / 30 / 50 / 70+ | +12 / +24 / +42 / +60 |
| Accuracy | Lv.10 / 30 / 50 / 70+ | +10 / +20 / +32 / +45 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Grants Dual Wield, DEX/CHR, Attack, Accuracy, and Crit Rate scaling.
- Dagger/Sword hits build Cadence; Weapon Skills unleash Sonic follow-up damage + Encore.
- Unlocks Lunge & Flourish (20s) and Troubadour's Encore (45s) without overwriting buffs.

**HUD.** Cadence count and Encore time. Show server-confirmed events and state only.

**Acceptance fight.** Check that a qualifying WS produces one sonic follow-up and no recursive skillchain. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from instruments, songs and martial performance and its signature decision (“Turn melee cadence into sonic WS”). This is a setting-inspired hook for later writing.

## Musician

BRD 2 · MUS · HybridSupport · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/brd_specs.lua#L799) · [existing guide](../../guides/musician.md)

**Player decision.** Protect the party's buff songs, then time a Threnody, Requiem or Elegy to burst. Choose when to detonate three Resonance stacks with Grand Finale.

**Why choose it.** Bring offensive song bursts to a magic-burst party. Channeler lends one ally a casting opportunity. Musician contributes damage directly and needs cast time. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set musician` once the Soul is registered. Any legally equippable BRD main weapon and instrument. CHR, MAB and magic accuracy.

Main has no explicit WS profile row for this key. Preserve currently legal WS; use the listed weapon conditions for signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Threnody, Requiem, Elegy, Finale, Minuet, Madrigal, March, Minne, Mambo, Paeon, Ballad, Carol, Scherzo and Prelude families. |
| Job abilities and commands | Pianissimo, Nightingale, Troubadour, Soul Voice |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Grand Finale, Lyrical Overdrive. |
| Existing traits | Musician's Resonance (156). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: An offensive song, one buff song, Grand Finale and Lyrical Overdrive. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| CHR | Lv.10 / 30 / 50 / 70+ | +6 / +12 / +18 / +25 |
| Magic Atk. Bonus | Lv.10 / 30 / 50 / 70+ | +18 / +30 / +42 / +55 |
| Magic Accuracy | Lv.10 / 30 / 50 / 70+ | +15 / +25 / +35 / +45 |
| Singing Skill | Lv.10 / 30 / 50 / 70+ | +10 / +18 / +26 / +35 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Threnodies, Requiems, Elegies, and Finale deal CHR + MAB magic damage and can Magic Burst.
- Offensive songs never overwrite your Ballad/Scherzo party buffs.
- Unlocks Grand Finale (20s Resonance burst) and Lyrical Overdrive (45s).

**HUD.** Resonance, protected songs and burst timing. Show server-confirmed events and state only.

**Acceptance fight.** Compare in-window and out-of-window song hits. Confirm offensive casts preserve the party's existing buff slots. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from instruments, songs and martial performance and its signature decision (“Burst with hostile songs”). This is a setting-inspired hook for later writing.

## Minstrel

BRD 3 · MIN · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/brd_specs.lua#L842) · [existing guide](../../guides/minstrel.md)

**Player decision.** Cycle hostile songs for hate and defensive songs for personal mitigation. Use Dissonant Chord when a healer pulls attention and Iron Aria before heavy damage.

**Why choose it.** Pick a tank that can regain attention by singing at range. Phantom needs a miss, and Defender wants the party nearby. Interruptions cost this tank threat. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set minstrel` once the Soul is registered. Any legally equippable BRD main weapon. Shield and instrument with CHR, song skill, HP and enmity.

Main has no explicit WS profile row for this key. Preserve currently legal WS; use the listed weapon conditions for signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Minne, Paeon, Scherzo, Lullaby, Elegy, Requiem, Threnody, Finale, Mambo, Ballad, March and Carol families. |
| Job abilities and commands | Pianissimo, Nightingale, Troubadour, Soul Voice |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Dissonant Chord, Iron Aria. |
| Existing traits | Minstrel's Bulwark (157). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Minne, Paeon, one hostile song, Dissonant Chord and Iron Aria. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| VIT | Lv.10 / 30 / 50 / 70+ | +6 / +12 / +18 / +24 |
| CHR | Lv.10 / 30 / 50 / 70+ | +4 / +8 / +12 / +16 |
| Max HP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| Defense | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +30% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Lullabies, Elegies, Requiems, and Finale generate heavy pre-nerf Volatile & Cumulative Enmity.
- Passively empowers Minne (PDT), Paeon (Regen), and Scherzo (tank-buster dampening) without re-casting.
- Unlocks Dissonant Chord (15s snap taunt) and Iron Aria (45s mitigation & sonic reflect).

**HUD.** Defensive songs, Chord and Aria. Show server-confirmed events and state only.

**Acceptance fight.** From zero TP acquire one boss, recover it after a large cure and check control on a sleep-immune target. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from instruments, songs and martial performance and its signature decision (“Sing for enmity”). This is a setting-inspired hook for later writing.
