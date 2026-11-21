# DRK · Soul specifications

[Reaper](#reaper) · [Dreadnought](#dreadnought) · [Scourge](#scourge) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Reaper | Strike during recovery | A boss with frequent readable action completions |
| Dreadnought | Drain into a blood pool | Sustained physical hits from a drainable boss |
| Scourge | Curse one dangerous category | One recurring source of boss damage or healing dominates |

## Reaper

DRK 1 · RPR · Damage · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Watch the boss complete a damaging spell or TP move. Put a deliberate scythe execution into the short recovery window. Save it for low HP only if the next opening is close.

**Why choose it.** Choose a finisher when the boss repeatedly exposes itself. Oathbreaker chooses a vow, Bandit exploits Defense Down. Unpredictable recovery and lost melee time reduce Reaper's peak. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set reaper` once the Soul is registered. Scythe, accuracy, STR and WS damage.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Drain I, Aspir I, Bio I–II. |
| Job abilities and commands | Finality, Last Resort, Weapon Bash, Arcane Circle. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Finality, 4y, 16s CD, one single-target noncritical scythe strike at 1.3× normalized swing. Within 5s after that mob completes a damaging spell/TP move use 2.3×. Also open after the target completes its sixth ordinary attack round since last opening so basic mobs teach the loop. Trigger once per action sequence. |
| 30–49 | Recovery strike 2.6×. Show the next ordinary-attack opening to the player. |
| 50–69 | Below 25% enemy HP add 15% to a successful recovery strike. Base hit always available. |
| 70–75 | Recovery strike 3×, low-HP bonus 20%. Never count player actions or periodic ticks as enemy recovery. |

**HUD.** Target recovery timer, six-round count and execute threshold.. Show server-confirmed events and state only.

**Acceptance fight.** Measure identical-HP hits before/during recovery and below threshold. Multi-hit TP moves create one window only. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Dark Magic, Absorb and the scythe and its signature decision (“Strike during recovery”). This is a setting-inspired hook for later writing.

## Dreadnought

DRK 2 · DRN · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/drk_specs.lua#L882) · [existing guide](../../guides/dreadnought.md)

**Player decision.** Use scythe, Drain II and timed Absorbs to overcap HP and build Blood Tithe. Put up Dread Spikes before the physical string so the buffer and returns carry the tank.

**Why choose it.** Choose self-sustain against drainable physical enemies. Ronin can defer damage without draining. Undead or ranged magical pressure erode Dreadnought's advantage. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set dreadnought` once the Soul is registered. Scythe. VIT, HP, dark skill and enmity.

Pinned main WS specialization skills: scythe. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Drain I–III, Dread Spikes, Absorb-STR, Absorb-VIT, Absorb-TP, Absorb-ACC, Stun, Bio. |
| Job abilities and commands | Souleater, Last Resort, Arcane Circle, Weapon Bash, Blood Weapon |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Abyssal Cleave, Dread Bastion. |
| Existing traits | Dreadnought's Carapace (167). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Drain II, Dread Spikes, Abyssal Cleave and Dread Bastion. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +15 / +20 / +25 / +32% |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| INT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| Defense | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +30% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Scythe & Dark Magic Mastery: +15/25/35/50 Scythe & Dark Magic skill, +10/14/18/22% Parry Rate (Inquartata), -20/30/40/50% Dark Magic Cast Time & 100% SIRD on Dark Magic.
- Blood-Pool, Blood Tithe & Dread Spikes: Drain II (12 MP, 30s CD) scales off 12/15/18/22% Max HP + VIT (+25% Max HP overcap 30s); Absorb-STR/VIT/TP/ACC (18s shared CD, instant) restore +6% Max MP & grant +1 Blood Tithe (max 3); Dread Spikes (45s CD, no MP, 10% Current HP cost) builds 25% + 5%/Tithe Max HP shield (up to 40%).
- Scythe WS Reap & Souleater: Scythe WSs heal 5/6/7/8% Max HP (10/12/14/16% w/ Drain II or Souleater; 2x in Dread Bastion), extend Drain II +6s, and inflict Cripple (-15% ATTP / -15 MATT / -20 ACC, 15s); Souleater (45s CD, 12s, -12% DT) spends 2% HP/hit for VE + Blood Tithe + Blood Reap (+20% WS heal).
- JAs: Abyssal Cleave (25s CD, 2s Stun, heavy VE, Breach -15% DEF/-15 MDEF, +8% MP, +1 Blood Tithe); Dread Bastion (60s CD, 12s: -18% DT, Knockback Immune, +35 Enmity, 2s AoE VE pulses, 2x WS heal); Blood Weapon (+4% Max HP/swing, +50 Enmity, -20% DT); Arcane Circle (shared Ward -10% DMG/+25 MEVA).

**HUD.** Blood Tithe, overcap HP and spikes. Show server-confirmed events and state only.

**Acceptance fight.** Compare a living target and undead target. Let temporary overcap expire during damage and check current/max HP. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Dark Magic, Absorb and the scythe and its signature decision (“Drain into a blood pool”). This is a setting-inspired hook for later writing.

## Scourge

DRK 3 · SCR · Support · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Choose a single curse for the boss behavior that matters now. Maintain it through a phase or overwrite it to answer a different threat.

**Why choose it.** Pick surgical suppression when one boss mechanic is dangerous. Crimson Duelist needs many enfeebles to protect itself. Scourge suppresses one outcome for the group. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set scourge` once the Soul is registered. Scythe or great sword. Dark magic accuracy, MP and survival.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Curse of Withering (physical TP moves), Curse of Ash (damaging spells), Curse of Famine (enemy self-heals); Bio I–II, Aspir I, Stun. |
| Job abilities and commands | Dark Seal, Arcane Circle. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Withering and Ash available at 10. Each costs 6% max MP, 2s cast, shared 12s recast, duration 24s. Reduce eligible direct damage 8% after global mods, conditional on matching action category. One Scourge curse slot per enemy; new successful curse replaces previous. On eligible boss hard immunity, grant caster's party half reduction on next matching hit within 8s, once, same target, 24s ICD. |
| 30–49 | Famine reduces actual enemy self-healing by 20%; never affect scripted resets or phase transitions. |
| 50–69 | Damage curses 12%, Famine 25%. Resist duration uses normal dark spell rules; only explicit immunity uses fallback. |
| 70–75 | Damage curses 15%, Famine 30%. Highest same-category mitigation only across Scourges. Never proc fallback on simultaneous existing curse. |

**HUD.** Selected category, target, expiry and immunity fallback.. Show server-confirmed events and state only.

**Acceptance fight.** Alternate Ash and Withering; physical autos and scripted fixed HP transitions stay unchanged. Test hard immunity with two Scourges. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from Dark Magic, Absorb and the scythe and its signature decision (“Curse one dangerous category”). This is a setting-inspired hook for later writing.
