# SoulspireXI — Cross-Soul Collision Review of the 13 Pending Concepts

**Reviewed:** 2026-11-19 against the current `main` Soul registry and representative implemented modules. **Status: design review, not balance simulation or evidence of deployed playability.** Proposed improvements below supersede ambiguous parts of `docs/remaining-soul-concepts.md`. Preserve level-10 core loops, Lv75 ceiling, tough boss encounters, and avoid making every spec builder/spender.

## How to interpret the verdict

- **Green:** viable separation from the currently inspected same-role and sibling Souls, subject to mechanics testing.
- **Amber:** direct mechanical resemblance; lock down an exclusive *decision pattern* before coding.
- **Red:** currently copies an implemented Soul's signature mechanic or another pending concept's fundamental decision; change the design before implementation.
- These assess **design collisions**, not measured DPS/HPS, performance or real-time player sentiment.

## Damage concepts vs existing Souls

### Oathbreaker — PLD | Damage | AMBER
**Previously:** risk-based Great Sword commitment with a vulnerable offensive window.
**Closest existing:** WAR Berserker (aggressive melee), DRK Dreadnought (Souleater/Drain HP sacrifice), RUN Spellblade (Great Sword spell-conduction), MNK Black Belt (unbroken melee pressure). **Closest upcoming:** DRK Reaper.
**Collision:** generic \"take more damage to deal more\" merely re-skins Berserker/Reaper. Smiting a boss with a Great Sword risks copying Spellblade's magic-after-melee mechanic.
**Revised signature — Broken Oaths:** two *mutually exclusive obligations* chosen at the start of an encounter or when disengaged: **Condemn** (personal boss-execution focus; lose access to defensive intervention) versus **Absolve** (limited reactive punishment after personally taking a threatening hit; less damage). Avoid an alternating meter and avoid HP payments. Changing oath mid-fight should have a meaningful restriction, not a rotational button.
**Why bring it:** dependable, planned damage against a boss whose attacks you understand; optional rescue-style mitigation trade-off but **never** Defender's party interception. Different from Reaper's changing enemy-health execution timings.
**Weakness:** commitment penalty if boss pattern changes, inferior AoE and sustained full-uptime DPS.
**Lv10:** select one vow, execute one consequence with ordinary Great Sword. **Lv30/50/70:** add secondary conditional reactions, boss-phase adaptability, no new meter.
**Lore seed:** a Paladin's vow broken or reinterpreted (original Soul narrative to be developed later).

### Reaper — DRK | Damage | AMBER
**Previously:** Scythe finishing pressure and HP-risk sacrifice.
**Closest existing:** Dreadnought's *already implemented* Drain II, Souleater, Blood Tithe and WS healing; WAR Berserker's aggression; RUN Spellblade's burst spells. **Upcoming:** Oathbreaker.
**Collision:** direct HP-for-damage spending makes it too similar to Dreadnought. Execution damage only at low HP also makes Reaper useless throughout most long boss fights.
**Revised signature — Finality:** use Scythe's deliberate rhythm to identify a **short execution opening after an enemy recovery/vulnerability event**; finishing blow mechanics can improve at low HP, but the fundamental opening is accessible at Lv10 throughout the fight. Offense revolves around *enemy state*, not a personal HP currency. Do not grant Dreadnought Blood Pool, tank Drain loop, or enmity sustain.
**Why bring it:** punish boss recovery, transition and vulnerability windows with exceptional focused finishing damage.
**Weakness:** loses peak DPS on enemies with no clear openings or when timing is missed; fragile; low support.
**Lv10:** one direct reaction to an enemy vulnerability condition; never require a boss to be below 20% HP to work.
**Lore seed:** Souleater and Scythe mortality imagery; differentiate from tanking Dreadnought.

### Sniper — RNG | Damage | GREEN
**Closest existing:** COR Flintlock (Deadeye/Quick Draw now, friend's independent dual pistols forthcoming), DNC Bladewheel (ranged chakram and Steps), SAM Imperial Archer (Bow/Great Katana alternating WS), COR Buccaneer (point-blank pistol tank). 
**Collision:** \"Barrage\" as rapid multi-bullet output collides directly with Flintlock's desired bullet-swarm fantasy.
**Revised signature — Sightline:** the player chooses a safe firing lane and a single high-value target; a **deliberate, long-commitment shot** rewards uninterrupted aim and correct target choice, not multi-projectile volume. Never claim an immobile character can avoid boss damage; allow deliberate relocation with opportunity cost.
**Why bring it:** high-range single-target precision and low-ammo shot efficiency with predictable vulnerable moments, against Flintlock's sustained fire and Imperial Archer's bow-to-katana rhythm.
**Weakness:** movement and misses; especially punished by teleports/line-of-sight disruptions.
**Lv10:** aim/shot timing works with attainable crossbow or firearm; no rare rifles required.
**Lore seed:** Ranger Sharpshot, Eagle Eye Shot precision.

### Warmage — BLU | Damage | AMBER
**Closest existing:** BLU Azure Bastion (physical Blue Magic grants Chitin, Sword/Club WS primes instant/free next Blue Magic), RUN Spellblade (enchanted autoattacks and prepared runic magic), RDM Scarlet Weaver pending, SCH Sage (Titania and Helix nukes).
**Collision:** \"weapon hit primes instant spell\" is already Azure Bastion's Azure Assimilation; magical/physical alternating may copy Spellblade.
**Revised signature — Monster's Answer:** *match a monster spell to the enemy's current vulnerability or threatened action*, using Blue Magic's broad catalogue and native Blue Magic set constraints. Differentiate single-target blunt/slashing/magical choices instead of a preset spell→WS→spell pattern. Reward useful **spell selection**, not resource generation.
**Why bring it:** counter-adaptive damage across enemy resistances/mechanics without being the strongest at one damage type.
**Weakness:** preparation/set limitations, skill complexity and less raw maximum damage than pure specialists.
**Lv10:** two meaningfully different attainable Blue Magic solutions; don't rely on endgame spell collections.
**Lore seed:** Blue Mage learns monster techniques, Chain/Burst Affinity.

### Primalist — SMN | Damage | AMBER
**Closest existing:** SMN Celestial (avatar sanctuary, Blood Pact: Ward reset, heals), BLM Necromancer (undead pet tank/caster modes), PUP Pugilist (master/automaton tandem openings), BST Untamed staged (master/beast reciprocal TP).
**Collision:** \"summon right pet for boss phase\" is not enough unless distinct from Celestial's avatar-dependent gameplay and generic pet management.
**Revised signature — Elemental Challenger:** proactively **commit one avatar's Rage element to the next boss vulnerability phase**; optimal play is timing elemental Blood Pact: Rage and exploiting resistance, rather than managing dozens of pets or Ward cooldowns. Do not use Celestial's healing Ward reset or Untamed's reciprocal melee pet combos.
**Why bring it:** elemental burst that can switch damage profiles when an encounter changes resistance.
**Weakness:** resistant enemies or badly timed avatar changes; weak personal DPS and support.
**Lv10:** at least one reliable damage pact available and practical; don't require a full avatar collection to function.
**Lore seed:** avatars, elemental opposition and Astral Flow.

### Terramancer — GEO | Damage | AMBER
**Closest existing:** GEO Verdant (Luopan as moving healing sanctuary), RUN Spellblade (damage from spellcasting), SCH Sage (DoT/Helix), BRD Musician (magical song damage), proposed GEO Diviner.
**Collision:** placing a field and waiting for pulses turns into a damage version of Verdant's pulsing luopan and Diviner's zones.
**Revised signature — Fault Prediction:** place a **single-target fault point** under the selected enemy with a telegraphed delayed detonation; the challenge is committing to the future enemy position/phase. The point is not a persistent aura or a generic DoT. Damage must follow explicit target ownership to avoid collateral AoE pulls.
**Why bring it:** burst reward for knowing stationary boss windows and enemy movement; unlike pure caster procs or sustained ground auras.
**Weakness:** mobile targets negate timing, vulnerable to knockback/interruption.
**Lv10:** one predictable, single-target delayed eruption with clear warning/feedback.
**Lore seed:** earth currents and Geomancy rather than literal canon \"fault magic\".

## Support concepts vs existing Souls

### Scourge — DRK | Support | AMBER
**Closest existing:** RDM Crimson Duelist (up to five enfeebles directly lower enemy damage, Hex-Mitigation), BRD Musician (Threnody/Requiem/Elegy magical pressure), WAR Commander (breach/party buffs), THF Trickster staged (short Attack Down).
**Collision:** stacking debuffs for generic mitigation duplicates Crimson Duelist's \"five enfeebles = protection\" engine; an Attack Down on a timer duplicates Trickster.
**Revised signature — Curse Selection:** one *exclusive* specialized curse per target: casting/power, physical pressure or recovery suppression. The decision is **which fight mechanism to sabotage**, not how many debuffs to stack. Effects should respect boss resistances and allow a limited fallback so Scourge isn't completely dead on immune fights.
**Why bring it:** surgical suppression of one devastating boss behavior, not a wide -DT aura or universal enfeeble superiority.
**Weakness:** immunity and boss variance; weaker broad support than Commander/Musician.
**Lv10:** one curse choice with a second situational choice accessible promptly.
**Lore seed:** Dark Magic Absorb/Bio, hexcraft.

### Arcane Archer — RNG | Support | AMBER
**Closest existing:** SAM Imperial Archer (A+ Archery, Bow+Great Katana weaving, Oisoya/cosmic brand), BRD Musician (Threnodies and magic bursts), COR Gambler (roll/Quick Draw party boosts), planned BLM Channeler (elemental party support).
**Collision:** \"bow arrows that set up skillchains\" overlaps Imperial Archer; raw elemental resistance debuffs compete with Musician's Threnodies.
**Revised signature — Attunement Arrow:** **mark one enemy for one selected elemental interaction**. Landing a precise arrow enables the *next allied* matching elemental hit/skillchain interaction to gain a bounded benefit; it is consumed by party execution, not stacked and not simply -elemental resistance. No archery→katana dual rotation.
**Why bring it:** targeted ranged **team coordination** for a party actively performing elemental actions; unlike Imperial Archer's personal hybrid skirmish and Musician's song-based magical pressure.
**Weakness:** weak when allies don't coordinate; significant opportunity cost to change marked element.
**Lv10:** accessible bow and one attunement effect; clear message on match/mismatch.
**Lore seed:** elemental arrows and skillchain collaboration, not canon claims of magical arrows.

### Nightblade — NIN | Support | AMBER
**Closest existing:** NIN Kagemusha (shadow/decoy enmity tank), Shinobi (offensive clones), THF Trickster staged (position plus enmity/debuff), THF Phantom staged (evasion threat), COR Buccaneer (point-blank control).
**Collision:** enemy backstab and enmity redirect copies Trickster; shadow clone utility copies Shinobi; shadow absorption copies Kagemusha.
**Revised signature — Counterintel:** **react to a boss's attempted action** with short ninjutsu sabotage, such as interrupting a cast under fair resistance/cooldown rules or temporarily weakening a specific damaging action. No clones, no persistent stealth bonus loop, no positional enmity funnel.
**Why bring it:** reactive anti-caster/anti-technique control on clear telegraphs; Trickster instead arranges party threat and offensive disruption proactively.
**Weakness:** control-immune bosses, fast casts, and inconsistent fight patterns. Provide a modest non-interrupt fallback (e.g. a short debuff), not universal denial.
**Lv10:** one telegraphed counter tool and the ordinary Ninjutsu baseline.
**Lore seed:** elemental/enfeebling Ninjutsu, espionage/stealth.

### Archivist — SCH | Support | AMBER
**Closest existing:** SCH Medic (Eos/Accession cure/regen), RUN Lifebinder (Vivacious Pulse/rune cleanse ward), WHM Bishop (preemptive barriers), GEO Verdant (luopan auto-heal), upcoming SMN Herald (timed wards), RDM Royal Tactician (magic tactical planning).
**Collision:** \"place a barrier before boss hit\" duplicates Bishop, Lifebinder and Herald. Any broad mitigation/regen addition competes with healer support.
**Revised signature — Countermeasure Research:** **observe/identify a boss attack category**, prepare one grimoire countermeasure, and use it to reduce the *next instance of that category*; limited number of prepared answers and real preparation opportunity cost. Not reactive spam, not another party-wide Stoneskin source.
**Why bring it:** learned, encounter-specific prevention against recurring boss mechanics. Best in predictable scripted fights; inferior on blind progression and random damage.
**Weakness:** preparation time and incorrect prediction. Must not trivialize unblockable boss mechanics or permanently negate a damage category.
**Lv10:** one clearly labeled preparation for a common category (physical, magical, or status); avoid dat/ID requirements where normal UI works.
**Lore seed:** Scholar stratagems, grimoires, research.

### Beastspeaker — BST | Support | RED in initial form
**Closest existing:** BST Alpha Warden (pet Soul-Link tank and commands), RNG Huntsman (**already modal pet-tank + offensive support aura**), BST Untamed staged (master/pet offensive timing), PUP Vanguard/Pugilist (pet tactical coordination).
**Collision:** \"pet commands give party buffs and short protection\" copies Huntsman's Saurian offensive support mode and Alpha Warden's pet defense.
**Revised signature — Bestiary Reader:** **read an enemy's beast family/behavior** then direct an allied pet to expose *one boss-specific behavior* (e.g. precise marking/insight that rewards selected physical attacks) without shifting tank threat or granting passive auras. For non-beast bosses, use a small universal **observation** mechanic; avoid absurd auto-win family counters. Interaction involves *knowledge and response*, not beast-command defensive orders.
**Why bring it:** valuable information and coordinated single-target exposure, especially in varied monster-family encounters; Huntsman commands the hunt for protection and Alpha Warden guards.
**Weakness:** pet reliance, reduced effect against unknown or unclassifiable bosses; no tank mitigation.
**Lv10:** one mark/read action usable on all bosses, with optional family mastery after Lv30.
**Lore seed:** Beastmaster ecological familiarity, monster families and Charm.

### Herald — SMN | Support | RED in initial form
**Closest existing:** SMN Celestial (**already** avatar-dependent sanctuary, ward recast reductions, mass healing and protection), WHM Bishop (party barriers), RUN Lifebinder (rune heal/cleanse/refresh), upcoming SCH Archivist (prepare a counter).
**Collision:** timed beneficial avatar wards are Celestial's **core gameplay already**. Simply changing ward timing will not distinguish Herald.
**Revised signature — Astral Accord:** the **avatar determines one offensive teamwork contract** for the group, e.g. a bounded reaction that rewards party members exploiting the matching elemental affinity. Herald emphasizes **party follow-through**, not passive regeneration, damage barriers or accelerated Blood Pact: Ward. Limit buffs to one active accord/target, and do not copy Arcane Archer's **one-enemy arrow mark consumed by one ally**: Herald is a short **party coordination window** defined by the current avatar, not a single-target consumed arrow mark.
**Why bring it:** coordinated elemental group damage and tactical party timing when the team is prepared; Celestial remains the healing/sanctuary avatar Soul, Primalist personal avatar burst.
**Weakness:** weaker with uncoordinated or mostly physical groups; poor personal DPS and emergency healing.
**Lv10:** choose one attainable avatar accord with clear team reward, no mandatory avatar-switch rotation.
**Lore seed:** avatar pacts, elemental resonance, astral bonds.

### Diviner — GEO | Support | AMBER
**Closest existing:** GEO Verdant (**already luopan/Indi-/Geo- healing aura and pulses**), BRD Musician (portable song magic), COR Gambler (roll buffs), WAR Commander (formation and tactical group buffs), proposed Terramancer.
**Collision:** persistent positioning field = Verdant with offensive numbers, especially if it heals or pulses automatically. Raw buffs are also generic Bard/Gambler alternatives.
**Revised signature — Crossing Lines:** use **two constrained field anchors** whose relative placement grants a *specific positional advantage* in a chosen corridor, not globally. Players must actively decide whether to hold or reposition as bosses move. No passive healing or universal strongest buff. Technical feasibility of multiple simultaneous native luopans needs verification; could express the second anchor as a temporary player-centric point instead of spawning extra pets.
**Why bring it:** highly valuable when a fight rewards holding specific space/lines; unlike mobile songs or roll buffs.
**Weakness:** movement-heavy fights and widespread party positioning; no Verdant heal engine.
**Lv10:** one anchor plus player position forms a usable line; add a second deployable concept only if engine supports it.
**Lore seed:** geomantic placements and spatial alignment.

## Pending vs pending: collision matrix
| Pair | Verdict | Non-overlap requirement |
|---|---|---|
| Oathbreaker / Reaper | AMBER | **Vow commitment** vs **enemy recovery/execute**; no shared HP-sacrifice currency |
| Arcane Archer / Herald | AMBER | **One-target arrow mark consumed by next matching allied effect** vs **brief avatar-defined party-wide cooperation window** |
| Archivist / Herald | GREEN after revision | **Pre-researched defensive countermeasure** vs **offensive elemental party accord** |
| Diviner / Terramancer | GREEN after revision | **Persistent positional corridor for allies** vs **one-off predictive delayed single-target eruption** |
| Warmage / Reaper / Oathbreaker | GREEN after revision | **Adapt spell to enemy state** vs **execution trigger** vs **commit to vow** |
| Primalist / Herald / Celestial | GREEN after revision | **Own avatar Rage burst** vs **party astral accord** vs **healing Ward sanctuary** |
| Beastspeaker / Untamed / Huntsman / Alpha Warden | GREEN after revision | **Bestiary observation/exposure** vs **reciprocal melee DPS** vs **RNG beast commander tank** vs **BST Soul-Link tank** |
| Nightblade / Scourge / Archivist | AMBER | **React to imminent cast/action** vs **choose sustained curse** vs **prepare one category counter before mechanic** |
| Sniper / Arcane Archer / Imperial Archer / Flintlock | GREEN after revision | **Single heavy aimed shot** vs **team elemental arrow mark** vs **bow+katana WS weave** vs **sustained dual pistols** |

## Implementation gates
1. **Resolve RED concepts before creating live code.** Herald and Beastspeaker revised above; old concept wording is superseded.
2. **At Lv10**, identify at least two decisions the player actually makes and one disadvantage visible in combat. If the gameplay reduces to autoattack + 1 generic buff, reject.
3. **At Lv75**, compare one same-role real fight, including latency, boss resistances, gear availability, tank threat, and pet losses. Do not declare balance from module descriptions.
4. Role offense scalars and custom skill whitelists must be reconciled with actual scripts. Never evaluate a tank, healer or support as though DPS is its only value.
5. Protect existing `main` and friend's Flintlock dual-pistol changes; design/documentation commits only until separate validation.
