# BLM · Soul specifications

[Astromancer](#astromancer) · [Channeler](#channeler) · [Necromancer](#necromancer) · [Action and progression rules](../rules.md) · [Implementation audit](../audit.md)

| Choose | Combat decision | Best encounter or party condition |
|---|---|---|
| Astromancer | Commit Ancient Magic | One brief elemental burst check on an unsaturated boss |
| Channeler | Channel for one caster | One ally whose cast time or MP is limiting |
| Necromancer | Choose undead thrall | One slot must alternate between a proxy tank and caster pet |

## Astromancer

BLM 1 · AST · Damage · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Probe elemental resistance, move into position, then commit to one very large Ancient Magic impact. Read the target's shared Astral Saturation before starting the cast.

**Why choose it.** Pick the strongest deliberate spell for a short damage check. Sage's Titania and Helix keep dealing damage through movement. A second Astromancer on the same target gets sharply diminishing bonus damage. [Role comparison](../roles.md#damage)

**Equip and activate.** At Lv10, select `!spec set astromancer` once the Soul is registered. Staff. INT, magic accuracy, MP and cast reliability.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Six basic single-target elemental probes, Ancient Invocation, Elemental Survey, Freeze, Tornado, Quake, Burst, Flood and the fire Ancient aspect (Flare). The water Ancient aspect displays Tsunami. Reserve the owner-directed Water→Tsunami identity for that signature; water probe uses a separate unused mapping (the demo numeric ID is not an allocation). |
| Job abilities and commands | Elemental Seal; no Manafont/instant-cast override on empowered Ancient casts. |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Ancient Invocation is single-target, 5s cast, 15% max MP. Base B = normal level-appropriate probe damage for that element after stats/resist. Unsaturated damage = 3B, saturated = B + 0.10 × (3B − B). On positive damage, atomically claim a 20s target window. Saturated hits neither extend nor refresh it. All empowered casts share 18s personal recovery at resolution. Starter probes cost ordinary MP. |
| 30–49 | Elemental Survey (1s cast, 30s recast, 2% MP) reveals the least-resistant of the six elements from current server resistances for 12s. Training cast can use the last probed element; defaults to earth. |
| 50–69 | Unlock six named Ancient aspects with B equal to native matching Ancient I damage, 6s cast, 22% max MP, multiplier 2.0 before saturation. All share recovery with Invocation. Water aspect displays Tsunami; one underlying ID cannot resolve to two actions in the same profile. |
| 70–75 | Named casts 7s, 25% max MP, unsaturated 2.5B. For bosses, cap only added Soul bonus at 3% of encounter-start max HP per unsaturated impact. Preserve ordinary damage and phase HP floors. Level 75 retains shared windows. |

**Source or integration decision.** Use one target-owned saturation record and an atomic resolve step. The launcher's demonstration uses example ID 1; never install that number as Water. Bind the intended Water→Tsunami presentation with a verified source ID; if a starter water probe needs a distinct key allocate it outside all existing/reserved maps.

**HUD.** Cast commitment, personal recovery and server-reported target saturation.. Show server-confirmed events and state only.

**Acceptance fight.** Resolve two same-tick impacts on one boss: exactly one full bonus, one reduced. Repeat on separate bosses, resist to zero, despawn and respawn. Helix, non-Astro magic and normal burst damage are unaffected. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from elemental magic, Dark Magic and long spell commitments and its signature decision (“Commit Ancient Magic”). This is a setting-inspired hook for later writing.

## Channeler

BLM 2 · CHN · HybridSupport · Concept Only · [prior concept reconciliation](../../whole-roster-soul-gap-reconciliation.md)

**Player decision.** Choose one caster and lend it a short, interruptible casting conduit. The Channeler gives up its own casting opportunity while the ally lines up one expensive spell.

**Why choose it.** Choose for a specific ally's MP and cast-time bottleneck. Arcane Archer marks an enemy and Herald coordinates several casters. Channeler assists even if the ally targets a friend. [Role comparison](../roles.md#support)

**Equip and activate.** At Lv10, select `!spec set channeler` once the Soul is registered. Staff or club. MP, survivability and positioning.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Six single-target tier-I/II elemental fillers; Aspir, Bind and Conduit Link. |
| Job abilities and commands | Elemental Seal, Break Link (free cancel). |
| Passive / WS integration | Apply the conditional effects in the level schedule. No new WS or trait ID is required solely for display. Use legal WS of the approved weapon(s); secondary or sidearm WS only trigger effects when explicitly named. |

**Levels 10–75**

| Effective level | Playable contract and initial tuning |
|---|---|
| 10–29 | Conduit Link: select one party PC other than self at ≤15y, 2s startup, lasts up to 8s, 24s recast. Channeler pays 8% max MP and cannot attack/cast while holding. First eligible spell started by ally during link casts 20% faster and costs 15% less; one cast per link. Move, incapacity, range loss or manual cancel ends it. Solo may link self for cost saving only, releasing control after startup. |
| 30–49 | Cast saving 25%. Relay 5% of ally's actual MP expenditure back to Channeler on successful completion. |
| 50–69 | Cost saving 25%. Link range becomes 20y. Never accelerate Ancient Magic, Soul emergency casts, instant actions or item casts. |
| 70–75 | Cast saving 30%, cost saving stays 25%. Keep one link per ally, strongest value once. No recursive refund through a second Channeler. |

**HUD.** Recipient, valid range, channel remaining and eligible cast.. Show server-confirmed events and state only.

**Acceptance fight.** Pair with healer and nuker separately. Interrupt link before ally starts. Confirm one cast, no instant grant and no acceleration of Astromancer. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from elemental magic, Dark Magic and long spell commitments and its signature decision (“Channel for one caster”). This is a setting-inspired hook for later writing.

## Necromancer

BLM 3 · NEC · Tank / HybridSupport, thrall-dependent · Implemented / Needs Tuning · [server registration and hooks](../../../modules/custom/lua/blm_specs.lua#L1382) · [existing guide](../../guides/necromancer.md)

**Player decision.** Select an undead warrior to hold hate or a caster to pressure a target. Use scythe WS to sustain the thrall and order its appropriate action for the phase.

**Why choose it.** Bring it when switching between a spellcasting thrall and a threat anchor matters. Huntsman commands living beasts and Alpha Warden personally holds the boss. Losing a warrior can expose the BLM. [Role comparison](../roles.md#tank)

**Equip and activate.** At Lv10, select `!spec set necromancer` once the Soul is registered. Scythe. HP and pet survival in tank mode, INT, accuracy and MP in caster mode.

Pinned main WS specialization skills: scythe. The equipped-item requirements above govern signature procs.

**Approved action profile**

| Kind | Allowed design scope |
|---|---|
| Player spells | Drain, Aspir, Bio, the six single-target elemental lines I–III, Sleep, Bind, Blind. |
| Job abilities and commands | Elemental Seal, Mana Wall; pet orders in the registration |
| Existing Soul grants | Union the pinned registration’s level-evaluated extraAbilities, Soul-specific spell helpers and hooked native actions with the list above. Named action cross-check from the wiki: Fight, Heel, Sic, Stay, Summon Undead Warrior, Summon Undead Mage, Corpse Explosion, Grim Reaping, Grim Incantations, Grave Provoke, Necrotic Bolt, Black Cloud, Covenant of Ash, Bone Aegis, Curse of the Fallen, Blood Saber, Soul Harvest, Summon Corse (Lv.75), Summon Dullahan (Lv.75), Aegis Schism, Danse Macabre. |
| Existing traits | Harbinger's Drain (147), Dark Pact (148), Grim Conversion (149). Retain the authoritative Lua and engine trait IDs. |

**Levels 10–75**

At 10, make the following starter kit usable with ordinary equipment: Summon Undead Warrior or Mage, Fight, Heel and that form's opening command. Keep the source's native and Soul-granted unlocks between milestones. Starter loans described in the shared rules apply only to a demonstrated onboarding gap.

| Current-main progression reference | Recorded brackets | Values in bracket order |
|---|---|---|
| Scythe Skill | Lv.10 / 30 / 50 / 70+ | +33 / +93 / +153 / +276 |
| Occult Acumen | Lv.10 / 30 / 50 / 70+ | +25 / +40 / +55 / +75 |

Use the 10/30/50/70 bands shown above. A three-band passive holds its Lv50 value through 75. An explicit later unlock or live handler takes precedence over this wiki sample.

**Registered mechanics to preserve.** These are the entry’s own descriptions. For coefficients and eligibility use the executable handler if its text differs.

- HP +10%, Scythe Skill raised to A+, and enhanced Occult Acumen.
- Undead Warrior & Dullahan (Tank Mode): Tier 6 -60% DMG Dealt (0.12x WS), 100% Thrall AoE/Conal boss immunity, 100% Master-to-Thrall single-target enmity transfer, and 80% Cure (+100% overheal) forwarding.
- Undead Mage & Corse (Caster Mode / No Pet): Tier 2 Hybrid -25% DMG Dealt (0.50x WS) & -20 Enmity; ranged Dark casters that empower party DPS via Grim Incantations.
- Harbinger's Drain: Scythe WSs heal Tank Thralls for 16/18/20/22% Max HP (clamp-proof) or Caster Thralls for 25-50% of WS damage.
- Dark Pact: While an undead summon is alive, gain Double Attack, Store TP, and Accuracy.

**Source or integration decision.** Preserve the actual 20/other intermediate unlock gates in extraAbilities; Lv75 summons Corse or Dullahan. A creature with no living tank thrall resolves to HybridSupport.

**HUD.** Thrall form, role, HP, active order. Show server-confirmed events and state only.

**Acceptance fight.** Switch forms during controlled pulls. Compare enmity recipient and spell pressure, then kill or dismiss the thrall and check tier restoration. Run at 10 and 75 in ordinary gear. Repeat at 30, 50 and 70 with level sync to verify the stated brackets.

**Lore hook.** Build the Soul's story from elemental magic, Dark Magic and long spell commitments and its signature decision (“Choose undead thrall”). This is a setting-inspired hook for later writing.
