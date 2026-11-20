# SoulspireXI — Corrected Whole-Roster Soul Design and Implementation Queue

**Updated:** 2026-11-19. **Purpose:** Correct the misleading 13-Soul scope; cover all active Souls without redesigning already playable work.

## What the automated report actually establishes
The latest [Issue #20 automated static audit](https://github.com/Infomatictek/overlordsxi/issues/20) reports **27 entries** without recognized registration evidence. Those are *not* 27 definitely unimplemented Souls:
- **Freelancer (DNC)** is retired and is excluded from the target 66 active roster.
- **Defender (PLD)** is represented by the existing legacy `aegistemplar` implementation; alias/registration still requires a naming verification.
- **Untamed (BST)** and **Trickster/Bandit/Phantom (THF)** have staged prototypes on separate feature branches, *not* live `main`.
- Static scan can miss alternate registration or legacy keys; no missingness claim is conclusive without runtime/client/SQL checks.

That leaves **25 active review candidates** in this specific audit (27 - Freelancer - Defender). Of these, 13 got a complete recent concept pass, 11 were omitted from that pass, and one (Untamed) is separately staged/concepted. The remaining 11 need an equally explicit concept + existing-Soul collision review.

## Eleven omitted from the previous 13-Soul review

| Job | Soul | Role | Preliminary differentiator to validate |
|---|---|---|---|
| WHM | Zealot | Damage | **Staff Holy Battlemage**: sustained melee staff hits restore MP for large divine-magic hits; not Bishop's barrier-to-Curaga healing loop |
| WHM | Valkyrie | Support | Polearm protector with an intervention decision; not Defender interception or Bishop/Aegis Templar barriers |
| BLM | Astromancer | Damage | Elemental forecasting and committed spell timing; not Sage Helix attrition or Musician offensive songs |
| BLM | Channeler | Support | Direct magical throughput or magic-burst preparation for allies; avoid Musician Threnodies and Herald accord duplication |
| RDM | Royal Tactician | Support | Tactical enfeeble/enhance sequencing with adaptive ally/enemy choices; not Commander formations or Scourge curse selection |
| RDM | Scarlet Weaver | Damage | RDM spell-and-sword adaptive pressure, separated from RUN Spellblade's Rune Edge/Conduction engine |
| THF | Trickster | Support | Planned enmity geometry and tactical disruption; staged prototype only, not yet live |
| THF | Bandit | Damage | Opportunistic melee exploitation of existing enemy weakness; staged prototype only |
| THF | Phantom | Tank | Evasion-fueled threat rather than Kagemusha shadows or Sensei counter-ripostes; staged prototype only |
| DRG | Lancer | Damage | Committed polearm strike / jump positioning, without reusing Pugilist/Untamed's pet tandem TP engine |
| DRG | Skyborn | Tank | Aerial timed avoidance and controlled re-entry, not Phantom evasion rolls or Kagemusha shadow/decoy |

## Thirteen already reviewed (do not drop from queue)
Oathbreaker (PLD), Reaper and Scourge (DRK), Sniper and Arcane Archer (RNG), Nightblade (NIN), Warmage (BLU), Archivist (SCH), Beastspeaker (BST), Primalist and Herald (SMN), Diviner and Terramancer (GEO).

Their [concepts](remaining-soul-concepts.md) and [collision revision](soul-cross-role-collision-review.md) are design baselines, not proof of implementation.

## One additional staged candidate
**Untamed (BST)** is staged in `feature/bst-untamed-feral-sync`; design confirmed as coordinated feral master + pet DPS, *not* Huntsman pet-tank or Alpha Warden guardian Soul-Link. This remains untested and unmerged.

## Canonical by-job cross-check
All **22 jobs**, not merely 13 pending concepts, must be checked. Already registered names are not automatically declared gameplay-complete. User-confirmed playable: MNK Chi Weaver and Black Belt. Other recent examples of implemented Souls: WAR Commander/Berserker/Spartan, RUN Inquisitor/Spellblade/Lifebinder, BRD Adventurer/Musician/Minstrel, SCH Medic/Sage (registered centrally), NIN Shinobi/Kagemusha, and others documented in Issue #20.

## Rules for completing the audit
1. Use real registration and gameplay plus `main` client/SQL evidence to distinguish missing code from a scan false-positive.
2. No duplicate Defender; do not revive Freelancer.
3. Reserve concept entries for all **25 candidate** active Souls, and make a compact same-role comparison for each. Each must have *how it plays*, *why choose it*, *weakness*, Lv10 loop, Lv75 payoff, FFXI ability/lore hook, and overlap exclusions.
4. All 66 active Souls must ultimately receive a standardized completion status: concept / registration / JAs / runtime / client/DAT / gear / Lv10 testing / Lv75 testing.
5. Leave Flintlock's friend-owned dual-pistol subsystem alone and keep the existing playable Souls intact.

## Zealot design correction (user-owned vision)
**WHM Zealot is a staff-wielding Holy magic DPS who restores MP through melee.** The melee phase is vital, not a cosmetic staff requirement; high-damage Holy/Banish-family casts are the payoff. Prefer existing MP over an added soul resource meter. At Lv10, basic staff-hit MP recovery and an appropriately accessible low-level divine offensive spell must make the loop playable; avoid assuming endgame Holy access. As it levels, improve magic potency and recovery efficiency without turning it into a primary healer. Compare explicitly to Bishop's barrier/cure gameplay, Astromancer ranged magic burst, and RUN Spellblade rune conduction. Its tradeoff is having to approach dangerous boss melee ranges for sustain. Exact MP refunds, damage budget, staff skill whitelist and spell unlock timing require balance/runtime validation.
