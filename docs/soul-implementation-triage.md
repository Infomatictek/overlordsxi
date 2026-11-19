# OverlordsXI: Unimplemented-Soul Triage and Distinct-Loop Design

> Status: implementation-planning document, not a declaration that listed Souls are absent. Updated 2026-11-19. Source of truth is live `main`, not historical weapon tables. The active registry still has a retired Freelancer placeholder; audit before altering persistent branch IDs.

## Completion order
1. **Establish actual missingness**: distinguish (A) canonical registry entry only, (B) runtime registration but passive-only, (C) JAs/traits implemented without SQL or client DAT support, (D) playable but untested, (E) fully integrated. Search across `modules/custom/lua`, SQL, patches, client launcher assets, and crystal registration—not filename alone.
2. **Implement A/B before revisiting D/E.** Avoid edits to Flintlock dual-pistol code (friend-owned), WS talent/Evolution, haste overhaul, and finished Souls.
3. **Batch by one job or self-contained Soul**, use unused IDs confirmed against existing allocations, syntax/static tests, verify Lv10 with ordinary equipment, then verify Lv30/50/70/75 and severe boss fights.
4. **Do not push speculative runtime behavior straight to the only playable main.** Validate prior to push; keep changes reversible and scoped.

## Architectural requirements
- Every Soul needs a distinct *action-selection problem*, not just an alternate resource label. Builder/spender is optional, not universal.
- Avoid \"why bring X over Y\" by giving every Soul meaningful encounter upside and downside without hard-exclusive party necessity or compulsory stacking.
- A Yin/Yang balance loop is welcome where appropriate; perfect balance cannot be universally optimal. Balance should respond to situation, not force mechanical oscillation every few seconds.
- Lore hooks below are *inspirations* based on FFXI jobs and themes, not claims of canonical historical backstory. Full lore sessions are deferred.
- Existing role tiers (Damage, HybridSupport, Support, CombatHealer, Healer, Tank), including modal pet-role changes, must remain intentional.

## Candidate designs pending runtime implementation verification

| Soul | Dominant decisions, no default meter | Advantage | Limitation | FFXI lore/ability hook |
|---|---|---|---|---|
| Chi Weaver (MNK healer) | Yin (guard/restoration) and Yang (striking/vitality) balance; choose orientation for incoming mechanics, not fixed builder/spender | Mobile combat healing, planned damage-to-healing transitions | Less safe at distance; weak while denied melee access | Chakra, martial discipline, counter techniques |
| Black Belt (MNK damage) | Exact martial-form sequences with timing windows and purposeful combo breaks | Reliable close-range sustained pressure | Vulnerable to disengagement; no party-wide defensive package | Monk's hand-to-hand mastery and martial techniques |
| Zealot (WHM damage) | Light-magic cast prioritization responding to enemy debuffs and openings | Strong single-target holy burst | Not a Bishop-quality emergency healer | Banish/Holy, Afflatus duality and divine devotion |
| Valkyrie (WHM support) | Guard an ally and intervene during anticipated dangerous actions | Targeted rescue and coordinated protection | Weaker generalized raid throughput than healing specialists | Holy protection, White Mage divine arts, polearm fantasy |
| Royal Tactician (RDM support) | Plan and time enfeeble/enhance combinations, choose enemy disruption or ally tempo | Tactical boss control, flexible recovery | Lower direct mitigation and damage than RDM siblings | Red Mage enfeebling/enhancing and Convert-inspired tradeoffs |
| Scarlet Weaver (RDM damage) | Weave weapon actions and alternating spell types for openings; not another Crimson Duelist hex tank | Mobile spellblade pressure, tempo shifts | Weak long-duration mitigation and dedicated support | Red Mage martial magic and elemental spellcraft |
| Astromancer (BLM damage) | Prepare elemental alignment to exploit a vulnerability window; advance knowledge, not repetitive stacks | Predictable damage spikes if planned well | Poor response when forced into unexpected movement | Elemental wheel and ancient magic |
| Channeler (BLM support) | Channel and redistribute elemental potency at opportune moments | Magical party coordination | Limited independent killing power | Black Mage elemental mastery and magic-burst traditions |
| Trickster (THF support) | Redirect enmity and create openings, with positional trick choices | Threat control and coordinated boss phases | Reduced solo throughput | Trick Attack and Sneak Attack |
| Bandit (THF damage) | Opportunistic strike chains and weapon-switching windows | Fast target-oriented melee burst | Poor frontal durability, positioning dependency | Thief's quick strikes and treasure-hunting opportunism |
| Phantom (THF tank) | Manage feints, enemy facing, and short evasion windows | Avoidance-based tanking vs rapid attacks | Vulnerable to unavoidable hits and anti-evasion mechanics | Perfect Dodge, evasion, shadowy misdirection |
| Lancer (DRG damage) | Polearm spacing and committed attack timing, coordinating wyvern pressure where relevant | Long-reach single-target bursts | Punished by interruptions/disengagement | Dragoon Jump techniques and wyvern bond |
| Skyborn (DRG tank) | Timed aerial avoidance/re-entry and threat recovery | Avoiding announced boss hits | Weak when jumps are mistimed or unavailable | Jump/High Jump and airborne dragoon tactics |

### Adjacent-Soul collision boundaries
- **Chi Weaver vs Lifebinder**: stance-equilibrium restorative martial combat vs RUN's rune-conduction/rune-based healing. No rune mechanics copied into MNK.
- **Zealot vs Scarlet Weaver**: holy debuff-responsive casting vs sword-and-spell tempo.
- **Valkyrie vs Templar vs Bishop**: ally intervention vs combat-healing holy bastion vs traditional WHM cure throughput.
- **Royal Tactician vs Commander vs Gambler**: tactical enfeeble/ward choices vs formations/command cadence vs real-risk Corsair rolls.
- **Phantom vs Kagemusha vs Shinobi**: avoidance/feint enmity tank vs shadow/decoy tank vs offensive clone control.
- **Astromancer vs Spellblade vs Sage**: deliberate pure elemental windows vs RUN melee spell conduction vs SCH faerie/other established mechanics (verify Sage behavior before finalizing).
- **Sniper vs Flintlock**: deliberate precision shots vs friend-owned dual-pistol fast barrages; do not modify dual-wield implementation.

## Acceptance checklist for each new Soul
- [ ] Runtime `registerCrystal` recognized, Lv10 crystal equip/unlock, safe swap/logout/zone
- [ ] Lore hook + no-overlap contract with named rivals
- [ ] Native plus custom JA/trait/spell/passive rules; server IDs collision checked
- [ ] Weapon whitelist reconciled with actual permitted gear and WS behavior
- [ ] Distinct combat decisions at Lv10 *without endgame items*
- [ ] Passive tiers and utility balanced at Lv10/30/50/70/75
- [ ] Threat, mitigation, healing uptime, DPS and TP measured, not inferred from role tier
- [ ] Client DAT/ability text/HUD/resource state exposed if actually needed
- [ ] Party use case and explicit trade-off; hard boss encounter tests
- [ ] Reproducible tests and installation/deployment instructions
- [ ] No regression to sibling Souls, talent UI or haste work

## Verified repository pointers
- `modules/custom/lua/overlords_job_specs.lua`: current 22-job canonical catalog and tiers
- `modules/custom/lua/run_specs.lua`: three RUN implementations; reference for lore-linked differentiation
- `modules/custom/lua/whm_specs.lua`: Bishop-focused implementation
- `modules/custom/lua/rdm_specs.lua`: Crimson Duelist-focused implementation
- `modules/custom/lua/nin_specs.lua`: Kagemusha-focused implementation
- `modules/custom/lua/cor_specs.lua`: three COR Souls; leave Flintlock dual-pistol subsystem to external contributor
- `modules/custom/lua/overlords_healer_helpers.lua`: existing shared healer primitives, do not create a competing utility layer

These design sketches require comparison to all currently registered Soul runtime modules before code generation. Do not overwrite extant mechanics solely to match this page.
