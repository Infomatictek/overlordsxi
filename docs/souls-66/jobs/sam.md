# SAM · Soul specifications

[Ronin](#ronin) · [Imperial Archer](#imperial-archer) · [Warlord](#warlord) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Ronin | Purify stagger | Large hits that leave time to clear deferred damage |
| Imperial Archer | Alternate bow and blade WS | A chain needs both archery and Tachi steps |
| Warlord | Close chains for an aura | Melee allies can exploit a closer's sustained aura |

## Ronin

SAM 1 · RON · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/sam_specs.lua#L1814) · [existing guide](../../guides/ronin.md)

**Player decision.** Keep Seigan and Third Eye up. Read deferred Mushin Stagger, then purify with a Tachi WS, Meditate or Blade Bash before the next blow.

**Why choose it.** Choose a tank that spreads a large hit over time and can clear the debt. Spartan needs advance shielding. Spending purification too early leaves Ronin owing damage later. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set ronin` once the Soul is registered. Great katana. HP, parry, accuracy and TP gain.

Pinned main WS specialization skills: great katana. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Seigan, Third Eye, Meditate, Blade Bash, Konzen-ittai, Hamanoha, Meikyo Shisui |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Seigan (Mushin Tank Stance), Third Eye (Mind's Eye), Meditate, Blade Bash (Purify Interrupt), Konzen-ittai, Hamanoha. |
| Existing traits | Ronin's Mushin (158). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Seigan, Third Eye, Meditate, Blade Bash and a Tachi WS. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +24% |
| Defense | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +26% |
| Damage Taken | Lv.10 / 30 / 50 / 70+ | -12 / -15 / -18 / -22% |
| Magic Evasion | Lv.10 / 30 / 50 / 70+ | +10 / +18 / +26 / +36 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Open weapon choice; requires Great Katana for Ronin passives, Stagger, and JA upgrades.
- Unlocks Seigan, Third Eye (15s CD, 2-3 Mind's Eye charges), Meditate, and Blade Bash at Lv.10+.
- Mind's Eye anticipates melee swings and single-target mob TP moves, countering for +60 TP & high Enmity.
- Mushin Poise defers 25-30% of hit damage into a 9s Stagger pool, purified by Tachi WSs, Blade Bash, and Meditate.
- Warding Circle (120s CD) grants party -8% DT & +15 MEVA; Meikyo Shisui grants -20% DT & instant Mind's Eye.

**HUD.** Stagger amount/time, Third Eye. Show server-confirmed events and state only.

**Acceptance fight.** Delay purification, record direct and deferred damage, then clear it halfway. Test nonlethal ticks and real incoming damage together. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from meditation, anticipation and skillchain timing and its signature decision (“Purify stagger”). This is a setting-inspired hook for later writing.

## Imperial Archer

SAM 2 · IMP · Support · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/sam_specs.lua#L1869) · [existing guide](../../guides/imperialarcher.md)

**Player decision.** Open a Tachi-to-bow sequence, then use Drawn Oisoya and Cosmic Brand to feed the return Tachi WS. Match your two WS timings to allies.

**Why choose it.** Choose a single player who can bridge archery and melee portions of a chain. Arcane Archer spends its shot on another player's elemental hit. Losing either weapon breaks the weave. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set imperialarcher` once the Soul is registered. Great katana, bow and arrows. Ranged and melee accuracy, Store TP.

Pinned main WS specialization skills: great katana, archery. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Hasso, Meditate, Sengikori, Konzen-ittai, Shikikoyo, Meikyo Shisui |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Oisoya Shot, Hasso (Bow & Blade), Meditate, Sengikori, Konzen-ittai, Shikikoyo. |
| Existing traits | Oisoya Mastery (159). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Hasso, Oisoya Shot, Meditate and one affordable WS in each skill. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Archery Skill | Lv.10 / 30 / 50 / 70+ | +6 / +16 / +26 / +66 |
| Ranged Accuracy | Lv.10 / 30 / 50 / 70+ | +12 / +22 / +34 / +46 |
| Ranged Attack | Lv.10 / 30 / 50 / 70+ | +8 / +13 / +18 / +24% |
| Snapshot | Lv.10 / 30 / 50 / 70+ | +6 / +10 / +15 / +20% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Open weapon choice; equipping a Bow grants A+ Archery skill, 100% Recycle (0 arrows used), +R.Acc/R.Atk/Snapshot.
- Auto-attacks with Bow + Arrow up to 20y outside melee range and suffers zero point-blank Bow penalty.
- Oisoya Shot (25s CD, 20y): ranged piercing arrow that restores +200-350 TP, primes Chainbound, and grants Drawn Oisoya & Cosmic Brand.
- Tachi WS -> Drawn Oisoya (+TP Bonus, +WSD, +R.Atk%, +125 TP refund on next Archery WS); Archery WS -> Cosmic Brand (+TP Bonus, +WSD, +SC Dmg on next Tachi).
- Hasso works with Bow or Great Katana (+Snapshot, +R.Atk%, +R.Acc, +AGI); Sengikori & Meikyo empower Bow + Blade chains.

**HUD.** Drawn Oisoya and Cosmic Brand. Show server-confirmed events and state only.

**Acceptance fight.** Repeat Tachi→Archery→Tachi and same-skill WS twice. Verify the intended refund and chain properties. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from meditation, anticipation and skillchain timing and its signature decision (“Alternate bow and blade WS”). This is a setting-inspired hook for later writing.

## Warlord

SAM 3 · WRL · HybridSupport · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/sam_specs.lua#L1957) · [existing guide](../../guides/warlord.md)

**Player decision.** Support the party with Hasso and Ashura's Edge while closing chains. Choose when Hagakure's draw-slash or Onimaru Tithe will maintain the aura through the next window.

**Why choose it.** Choose a closer who generates group benefit while doing melee damage. Commander can call a ward on demand. Warlord loses uptime when it cannot reach the target. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set warlord` once the Soul is registered. Great katana, accuracy, Store TP and WS gear.

Pinned main WS specialization skills: great katana. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | None |
| Job abilities and commands | Hasso, Meditate, Hagakure, Sengikori, Blade Bash, Konzen-ittai, Shikikoyo, Meikyo Shisui |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Hasso, Meditate, Hagakure (Iaijutsu Sundering Noto), Onimaru Tithe, Sengikori, Blade Bash, Konzen-ittai, Shikikoyo. |
| Existing traits | Onimaru's Command (160). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Hasso, Meditate, Hagakure, Onimaru Tithe and Tachi WS. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| STR | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| DEX | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| VIT | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Open weapon choice; requires Great Katana for +Accuracy, +Store TP, +Zanshin, +Subtle Blow, and Iaijutsu support effects.
- Hagakure (20s CD): sheathes into Noto stance (15s), turning your next Tachi into an Iaijutsu Draw-Slash (+35..100% Crit, +250..600 TP Bonus, Save TP, Chainbound) inflicting Onimaru Sundering (-15% DEF, -10% MDEF, -25 EVA for 15s).
- Ashura's Edge (up to 3x, 20s): 15y party aura (+10/16/24% Subtle Blow, +6/10/15% WSD, +8/14/20 Acc/MAcc, +8/12/16 Regain); at 3 stacks melee swings restore +15 HP & +5 MP to party within 15y.
- Onimaru Blood-Quench: closing a Skillchain boosts SC damage by +20-35% and restores 10% Max HP, 8% Max MP, and +250 TP to party within 15y.
- Onimaru Tithe (25s CD, 15y, 12s): grants party +350 TP, +12% WSD, and +15% Lifesteal, and refreshes Ashura's Edge to 3 stacks.

**HUD.** Ashura's Edge, aura radius and Noto. Show server-confirmed events and state only.

**Acceptance fight.** Compare an actual skillchain close with the same WS fired alone. Move one party member outside aura range. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from meditation, anticipation and skillchain timing and its signature decision (“Close chains for an aura”). This is a setting-inspired hook for later writing.
