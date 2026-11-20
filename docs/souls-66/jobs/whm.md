# WHM · Soul specifications

[Bishop](#bishop) · [Zealot](#zealot) · [Valkyrie](#valkyrie) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Bishop | Pre-cure | One ally about to take a lethal hit |
| Zealot | Earn casting MP with a staff | A long fight with alternating melee and divine-cast windows |
| Valkyrie | Escort a retry | A vulnerable caster repeatedly interrupted by enemy hits |

## Bishop

WHM 1 · BSH · Healer · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/whm_specs.lua#L379) · [existing guide](../../guides/bishop.md)

**Player decision.** Pre-cure a threatened ally under Solace. Work a Smite or eligible WS between cures to recover MP and build Sacred Grace for group sustain.

**Why choose it.** Choose for targeted barriers before a lethal hit. Medic covers repeated group damage with Eos and Accession. Late wards cannot reverse a hit. [Role comparison](../roles.md#healer)

**Equip and activate.** At Lv10, select `!spec set bishop` once the Soul is registered. Club and shield for block, or staff for supported WS. MND, MP, cure potency and cast time.

Pinned main WS specialization skills: club, staff. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Single-target Cure and Curaga families, Esuna, Auspice, Banish I–III, Holy, Erase, Poisona, Paralyna, Blindna, Silena, Stona, Viruna, Cursna, Regen, Protect, Shell, Raise and Reraise families. |
| Job abilities and commands | Afflatus Solace, Divine Seal, Martyr, Devotion, Benediction |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Afflatus Solace, Martyr, Devotion, Divine Veil, Sanctuary Pulse. |
| Existing traits | Solace Conduit (169). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Afflatus Solace, Cure, Banish, Divine Veil and Sanctuary Pulse. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Max HP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +28% |
| Max MP | Lv.10 / 30 / 50 / 70+ | +14 / +18 / +22 / +28% |
| MND | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +32 |
| VIT | Lv.10 / 30 / 50 / 70+ | +12 / +18 / +24 / +32 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- Proactive Afflatus Solace: Unlocked @ Lv10+ (0s CD); Cure I-VI grant Solace Ward barrier (35-50% of heal, cap 30% Max HP) + -8% DT for 8s.
- Sacred Grace Smite-Weaving: Banish/Holy or Club/Staff WS grants +1 Sacred Grace (max 3) & +6% Max MP; at 3 stacks, Curaga/Esuna/Auspice triggers a 10s party Regen (15 + 2.2% Max HP/tick).
- JA Enhancements: Divine Seal (20s CD, +15% Max HP barrier), Martyr & Devotion (15s CD, 0 self-HP loss), Benediction (100% party heal/cleanse + 50% MP + -25% DT 15s).
- Divine Veil (25s CD, 22% HP barrier + -12% DT + +30 MEVA + splash next Cure/Erase/Esuna) & Sanctuary Pulse (20s CD, 25% HP AoE heal + 3-debuff cleanse + 1 Sacred Grace).

**Source or integration decision.** Read BISHOP_WS_IDS together with the weapon-skill helper and skill fallbacks. Do not make every WS on every weapon a Smite trigger.

**HUD.** Solace Ward, Grace and Smite return. Show server-confirmed events and state only.

**Acceptance fight.** Repeat the same boss hit with a ward already present and with the cure landed after impact. Track real absorption and overheal. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from divine magic, Solace and protection of allies and its signature decision (“Pre-cure”). This is a setting-inspired hook for later writing.

## Zealot

WHM 2 · ZEL · Damage · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Alternate between fighting in staff reach for MP and stepping clear to land a heavy single-target Holy cast. A miss, WS, additional effect or offhand strike never earns the melee refund.

**Why choose it.** Pick sustained divine damage against one boss when approaching it is feasible. Bishop uses Smites to support healing. Astromancer can deliver its peak hit from range but waits out saturation. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set zealot` once the Soul is registered. Staff main, grip optional. Accuracy first, then MND, divine skill and MAB.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Banish I–III, Holy, Divine Benediction of Light (Soul-local Holy upgrade at 70, same personal Holy recast). |
| Job abilities and commands | Divine Seal (Zealot version empowers the next damaging divine spell by 20%, 90s). |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Staff Communion passive restores max(2, floor(maxMP × 0.035)) on the first landed main-hand regular hit per attack round, personal 2.5s lock. Banish I costs 8% max MP, casts in 2s, recast 6s. Use stock single-target Banish I base before Soul multiplier 1.5. |
| 30–49 | Banish II 2.5s, 12% MP, 8s recast, ×1.6 native base. Refund rises to 4%. |
| 50–69 | Holy 3s, 20% MP, 14s recast, ×1.8 native base. Banish III native base ×1.5, shares Banish II recast. |
| 70–75 | Refund 4.5%. Divine Benediction of Light uses Holy base ×2.0, 22% MP, 3.5s cast, shares 14s Holy timer through 75. Ordinary misses and movement make MP management consequential. |

**HUD.** MP, next eligible staff refund and Holy recast.. Show server-confirmed events and state only.

**Acceptance fight.** Record 20s in melee and out of melee. A multiattack earns one refund, a WS earns zero. Compare sustained divine DPS and healing throughput to Bishop. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from divine magic, Solace and protection of allies and its signature decision (“Earn casting MP with a staff”). This is a setting-inspired hook for later writing.

## Valkyrie

WHM 3 · VLK · Support · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Name an ally as your intervention target. When a boss interrupts that ally's cast, decide whether to escort the retry immediately or save the intervention for a dangerous later cast.

**Why choose it.** Choose a polearm support for a healer or caster fighting under pressure. Defender transfers damage, Bishop wards HP and Channeler accelerates a planned cast. Valkyrie rescues a failed cast. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set valkyrie` once the Soul is registered. Polearm, HP, magic evasion and positioning. No shield required.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Protect I–IV, Shell I–IV, Poisona, Paralyna, Silena; only the learned level-legal ranks plus Protect I from 10. |
| Job abilities and commands | Wingmate (ally selection), Valkyrie's Escort. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Wingmate selects one party PC within 15y, 5s recast. An enemy-damage interruption of that ally arms Escort for 6s. Escort, 25s recast, gives one retry of the same spell within 6s +100% spell interruption resistance. Does not prevent silence, movement cancellation or death. Native spell cost and cast time apply. |
| 30–49 | Escort additionally refunds 15% of the MP actually paid on a completed retry. |
| 50–69 | Escort range 20y. Can designate self when solo, at half MP refund. |
| 70–75 | Refund 25%, same one-retry limit through 75. The first successful Escort claims the interruption for that ally. |

**Source or integration decision.** For solo onboarding allow self Wingmate from 10 using the same interruption rule and zero refund until 50. From 50 use the listed half refund.

**HUD.** Wingmate, interrupted spell, retry deadline.. Show server-confirmed events and state only.

**Acceptance fight.** Interrupt Cure with a hit, then cancel it manually. Only the first event arms Escort. A second Valkyrie cannot consume the same interruption. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from divine magic, Solace and protection of allies and its signature decision (“Escort a retry”). This is a setting-inspired hook for later writing.
