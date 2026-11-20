# NIN · Soul specifications

[Shinobi](#shinobi) · [Kagemusha](#kagemusha) · [Nightblade](#nightblade) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Shinobi | Maintain a living clone squad | Rebuild windows between boss area attacks |
| Kagemusha | Convert broken shadows into Ash | Absorbable single hits with time to restore images |
| Nightblade | Seal the current telegraph | Slow, readable enemy casts or techniques |

## Shinobi

NIN 1 · KRG · Damage · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/nin_specs.lua#L1000) · [existing guide](../../guides/shinobi.md)

**Player decision.** Time Ichi and Ni to maintain up to five short-lived attackers. Save Shadow Legion for living clones on a stable target and Phantom Assault for clones with time to swing.

**Why choose it.** Pick an offensive squad whose survival and replacement you personally manage. Kagemusha consumes defensive images instead. Boss spikes and movement cost damage. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set kurogane` once the Soul is registered. Katana. Accuracy, STR/DEX, attack and WS damage.

Pinned main WS specialization skills: katana. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Utsusemi: Ichi and Ni; native level-eligible elemental Ichi/Ni ninjutsu. |
| Job abilities and commands | Innin, Futae, Sange, Mikage |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Shadow Legion, Phantom Assault. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Offensive Utsusemi Ichi/Ni, Shadow Legion, Phantom Assault and a katana WS. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| STR | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| DEX | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28 |
| Katana Skill | Lv.10 / 30 / 50 / 70+ | +15 / +25 / +35 / +50 |
| Attack | Lv.10 / 30 / 50 / 70+ | +8 / +12 / +16 / +20% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Offensive Utsusemi (Shadow Squadron): Utsusemi: Ichi summons 2 offensive clones and Utsusemi: Ni summons 3 (max 5 active, 25-30s lifetime, up to 170 HP at Lv75); clones copy your look and attack your engaged target independently.
- Shadow Legion (90s CD): Every surviving shadow launches a staggered single-target coordinated strike at your engaged enemy.
- Phantom Assault (30s CD, 8s): Reduces the native autoattack interval of all currently living shadows by 25% (~33.3% faster attacks) for 8 seconds.

**Source or integration decision.** The guide calls production actions pending. The current code actually dispatches both JAs and defaults the clone backend on. The level bypass for ninjutsu in nin_specs checks Kagemusha. Verify that a fresh Lv10 Shinobi can actually use Ichi and Ni before accepting this row. If needed, lend these two actions only while Shinobi is eligible.

**HUD.** Live clone count, next expiry, Assault duration and shared target. Show server-confirmed events and state only.

**Acceptance fight.** Spawn 2 then 3, refresh at cap, interrupt a cast, lose a clone mid-Legion, zone during Assault. Check attribution once per landed strike and no defensive images. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from ninjutsu, shadows and deception and its signature decision (“Maintain a living clone squad”). This is a setting-inspired hook for later writing.

## Kagemusha

NIN 2 · KGM · Tank · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/nin_specs.lua#L940) · [existing guide](../../guides/kagemusha.md)

**Player decision.** Refresh defensive Utsusemi and use broken images to accumulate Ash and spread Shadow Smoke. Time a katana WS to restore shadows and HP before a dangerous hit.

**Why choose it.** Choose a tank for absorbable single hits and decoy timing. Shinobi's copies contribute damage. Multi-hit strings can strip Kagemusha's protection quickly. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set kagemusha` once the Soul is registered. Dual katanas, HP, ninjutsu skill and enmity.

Pinned main WS specialization skills: katana. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | All ninjutsu the character can currently execute on Kagemusha, enumerated from the NINJUTSU spell group plus KAGEMUSHA_SPELLS using this module’s explicit Soul override. Preserve backports, Utsusemi and Migawari. |
| Job abilities and commands | Yonin, Futae, Issekigan, Mijin Gakure |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Yonin, Futae, Kage Bunshin, Smoke Lotus. |
| Existing traits | Kagemusha Phantom (161). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Yonin, Utsusemi Ichi/Ni, Kage Bunshin and Smoke Lotus. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +12 / +16 / +20 / +25% |
| VIT | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| AGI | Lv.10 / 30 / 50 / 70+ | +8 / +14 / +20 / +26 |
| Defense | Lv.10 / 30 / 50 / 70+ | +10 / +16 / +22 / +28% |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Dual Katana & Ninjutsu Mastery: +15/25/35/50 Katana & Ninjutsu skill, +15/22/30/38 Subtle Blow, -20/30/40/50% Ninjutsu Cast Time, 100% SIRD, and 0 Ninja Tool consumption.
- Shadow Economy & Kawarimi Ash: Ichi (3 shadows, 1.5s/18s) & Ni (4 shadows, 1.2s/28s) overwrite cleanly; broken shadows grant +35 TP, VE, Shadow Smoke (-4% ATTP/MATT, -6 ACC/stack, max 4), and +1 Kawarimi Ash; AoEs consume max 2 shadows w/ 50% bleedthrough.
- Katana WS Sustain & Custom JAs: Katana WSs refresh Shadow Smoke & spend 3 Ash for +1 shadow + 8/10/12/14% HP; Kage Bunshin (45s CD: +3 shadows, 1 cleanse, -15% MDT 6s); Smoke Lotus (30s CD: 4x Shadow Smoke, 20% Slow, +2 Ash).
- Tank JAs: Yonin (15s CD: +30 Enmity, +25 MACC, -18% DT & +15% Parry at 0 shadows); Futae (45s CD: instant Ninjutsu, 2.5x VE, 2s Stun, Expose -25 MEVA); Mijin Gakure (120s CD: 12s Migawari intercept negating >30% HP hits, +25% HP, +4 shadows).

**HUD.** Images, Ash and Smoke. Show server-confirmed events and state only.

**Acceptance fight.** Consume images with single and multi-hit attacks. Compare decoy expiry with genuine shadow-break events. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from ninjutsu, shadows and deception and its signature decision (“Convert broken shadows into Ash”). This is a setting-inspired hook for later writing.

## Nightblade

NIN 3 · NGB · Support · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Watch the enemy's telegraph and choose whether to interrupt a spell or weaken a physical technique. A premature ninjutsu leaves no protection for the real cast.

**Why choose it.** Choose reactive control when boss tells can be read. Archivist prepares for a repeated category beforehand. Trickster manipulates ally threat proactively. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set nightblade` once the Soul is registered. Katana or dagger. Ninjutsu skill, magic accuracy and cast time.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Severing Seal (spell), Blunting Seal (physical TP move), Hojo: Ichi and Kurayami: Ichi. |
| Job abilities and commands | Futae, Innin. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Seals are Soul ninjutsu, 0.5s cast, no tools, shared recast 20s, 15y. Check matching hostile action in progress at completion. Severing makes one normal interrupt check; if the action is flagged uninterruptible, lower eligible direct damage of that same cast by 8%. Blunting lowers that single physical technique by 10%. No effect on scripted executions. No matching event gives no effect and 3s retry. |
| 30–49 | Blunting 13%; Severing fallback 10%. |
| 50–69 | Shared recast 18s. Single-target weakened cast covers its victims once per victim, expires on resolve/cancel or after 8s. |
| 70–75 | Blunting 16%, fallback 12%. One seal per cast sequence; another Nightblade cannot layer it. |

**HUD.** Telegraph category, matching seal, expiry.. Show server-confirmed events and state only.

**Acceptance fight.** Seal a cast already canceled, an interruptible spell and a scripted immune attack. Never interrupt by repeatedly fishing mismatches. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from ninjutsu, shadows and deception and its signature decision (“Seal the current telegraph”). This is a setting-inspired hook for later writing.
