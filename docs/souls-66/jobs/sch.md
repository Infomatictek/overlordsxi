# SCH · Soul specifications

[Medic](#medic) · [Sage](#sage) · [Archivist](#archivist) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Medic | Heal with Light Arts and Eos | Repeated group wounds and removable status effects |
| Sage | Maintain Helix with Titania | Long fights with forced movement and durable targets |
| Archivist | File a countermeasure | A known enemy repeats a specific move on a predictable victim |

## Medic

SCH 1 · MDC · Healer · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/overlords_job_specs.lua#L1578) · [existing guide](../../guides/medic.md)

**Player decision.** Summon Eos, maintain Light Arts and spend fast, safe Sublimation between group Cure/Regen casts. Let Eos clean minor statuses while you triage the next hit.

**Why choose it.** Choose a backline group healer for repeated area damage and status pressure. Bishop needs advance wards and Chi Weaver needs an attack target. Pet loss removes automated care. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set medic` once the Soul is registered. Dagger, club or staff. MND, MP, cure potency and fast cast. Orphic Egg is a companion option.

Pinned main WS specialization skills: dagger, club, staff. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Cure I–IV, Regen I–IV, Erase, -na removals, Protect, Shell, Raise, Reraise, Stoneskin, Aquaveil. |
| Job abilities and commands | Light Arts, Addendum: White, Sublimation, Accession, Penury, Celerity, Rapture, Tabula Rasa |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Call Eos. |
| Existing traits | Medic's Grace (144). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Call Eos, Light Arts, Addendum: White, Cure and Regen. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Unlocks Call Eos faerie companion (auto -na/Erase & stackable Regen).
- Addendum: White lasts 2 hours.
- Sublimation charges 2x faster with no HP drain.
- Cure & Regen spells gain free 10y Accession AoE without Stratagem cost.

**Source or integration decision.** The central registration grants Call Eos 231 and trait 144. Preserve stackable Eos Regen, automatic status removal, free party spread on Cure/Regen, and double-speed Sublimation with no HP drain. At 30 test longer Regen coverage; at 50 triage concurrent HP/status loss; at 70/75 maintain Eos and cycle the highest legal Cure/Regen ranks during sustained group damage.

**HUD.** Eos health, Sublimation, Regen and Accession coverage. Show server-confirmed events and state only.

**Acceptance fight.** Cast the same single cure near two wounded allies. Verify Eos cleansing/regen and Sublimation with no HP drain. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from grimoires, Arts and stratagems and its signature decision (“Heal with Light Arts and Eos”). This is a setting-inspired hook for later writing.

## Sage

SCH 2 · SAG · Damage · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/overlords_job_specs.lua#L1595) · [existing guide](../../guides/sage.md)

**Player decision.** Keep Titania active, lay down the right enhanced Helix under Dark Arts, then use Ebullience-driven elemental spells while the DoT works.

**Why choose it.** Choose long-fight elemental pressure that keeps ticking through movement. Astromancer wins a brief opening with a huge impact and saturates that target. Short-lived enemies waste Sage's Helix duration. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set sage` once the Soul is registered. Dagger, sword, club or staff. INT, MAB, magic accuracy and elemental skill. Orphic Egg supports Titania.

Pinned main WS specialization skills: dagger, sword, club, staff. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Eight elemental Helix families and the six single-target elemental nuke lines at existing grants/learned levels, Drain, Aspir, weather storms of matching elements. |
| Job abilities and commands | Dark Arts, Addendum: Black, Ebullience, Alacrity, Parsimony, Immanence, Sublimation, Tabula Rasa |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Call Titania. |
| Existing traits | Sage's Wisdom (145). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Call Titania, Dark Arts, Addendum: Black, Geohelix at starter-scaled MP cost if it otherwise cannot be cast at 10 and elemental filler. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Unlocks Call Titania dark faerie companion (enfeebling & elemental nuking).
- Addendum: Black lasts 2 hours.
- Permanent Ebullience active for black magic.
- Helix damage +50% and Helix duration extended to 2 hours.
- Magic Attack Bonus +30 and elemental spells bypass 10% target MEVA.

**Source or integration decision.** The server registers Call Titania 289 centrally and loads sch_specs and eos_companion. Baseline keeps +50% Helix damage, extended 2h duration and Ebullience with Dark Arts/Addendum: Black. For progression, at 30 rotate Helix element on resistant targets; at 50 time a legal elemental spell into a party burst; at 70/75 retain the enhanced Helix and companion during movement. No new Sage meter.

**HUD.** Titania target, Helix element/tick/expiry, Dark Arts. Show server-confirmed events and state only.

**Acceptance fight.** Separate Helix ticks, Titania casts and player nukes over five minutes. A second Astromancer's saturation must leave all three streams untouched. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from grimoires, Arts and stratagems and its signature decision (“Maintain Helix with Titania”). This is a setting-inspired hook for later writing.

## Archivist

SCH 3 · ARC · Support · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Observe an enemy action before writing a countermeasure for its next occurrence. Predict which party member will need it, then spend the prepared page before impact.

**Why choose it.** Choose prevention against a repeated identifiable mechanic. Bishop can ward an unknown hit immediately. Nightblade needs a current telegraph and a fast reaction. A new boss opens with an information disadvantage. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set archivist` once the Soul is registered. Staff or club. MP, survival and casting speed.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Record, File Countermeasure, Protect I–IV, Shell I–IV, Dispel. |
| Job abilities and commands | Libra, Light Arts, Penury. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Record, 1s cast, 2% max MP, 6s recast: sample the next hostile non-auto action completed by the selected enemy in 12s, storing its action ID plus physical/magical category for 60s. File Countermeasure, 1s cast, 5% MP, 15s recast: apply to one party PC in 15y for 20s. Reduce next matching action from that enemy by 20% for that PC. One record and one filed page per Archivist. Solo can file on self. |
| 30–49 | File range 20y, protection 25%. |
| 50–69 | May record a second distinct action; Filing explicitly selects record A or B. Only one filed page active. Recording a third replaces the older unused record. |
| 70–75 | Protection 30%; page duration 25s. Scripted HP sets excluded. Multiple pages on one victim consume only the highest on that action. A wrong action never consumes it. |

**HUD.** Enemy/action ID rendered as its visible name, record time, page owner and expiry.. Show server-confirmed events and state only.

**Acceptance fight.** Record two different same-element spells. Only the exact sampled action from the same enemy can consume the chosen page. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from grimoires, Arts and stratagems and its signature decision (“File a countermeasure”). This is a setting-inspired hook for later writing.
