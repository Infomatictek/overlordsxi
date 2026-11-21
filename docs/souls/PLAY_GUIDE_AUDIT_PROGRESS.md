# SoulspireXI Play Guide Audit — Progress Tracker

**Scope:** Documentation-only, 66 canonical Souls. Preserve current gameplay and balance. If a Soul is reworked later, revise its guide in that separate workstream.

**Branch:** `feat/soul-guide-audit`  
**Wiki source:** `docs/guides/<soul-key>.md` → `scripts/generate-site-data.py::parse_spec_guides` → `site/data.json` and `site/data.js`.  
**Publishing:** `.github/workflows/update-wiki.yml` validates guide changes on feature branches; main publication follows merge.

## Required guide quality

1. `## At a Glance` — role, identity and limits.
2. `## Setup & Gear` — eligibility, weapons, equipment/stat priorities, any necessary team positioning.
3. `## How to Play (Step-by-Step)` — opener, repeatable combat loop, timing, situational options and level progression.
4. `## Key Mechanics & Stacks` — confirmed numbers, unlocks, restrictions, HUD fields and exact eligibility.
5. `## Common Mistakes (Don't Do This)` — meaningful pitfalls from the actual implementation.

Use **Soul-facing action names only**. Do not expose vanilla action mappings, raw resource IDs, internal Lua variables or test-only commands in the player guide. Do not invent actions/defensive powers to make kits appear larger. Be transparent about limited kits and preserve later rework as separate scope.

## Confirmed completed on branch

| Soul | Commit | Evidence |
| --- | --- | --- |
| Terramancer | `b35f978` | Server GEO module, tests, implementation report; fixed missing parser-recognized loop section |
| Diviner | `fedefc0` | Server GEO module and report; fixed missing parser-recognized loop section |
| Beastspeaker | `a92e422` | Existing completed guide progression; fixed parser structure and expanded instructions |
| Herald | `d37414d` | Existing completed guide progression; fixed parser structure and expanded instructions |
| Untamed | `ba49bd4` | Existing completed guide progression; fixed parser structure and expanded instructions |
| Primalist | `2f9f58d` | Existing completed guide progression; fixed parser structure and expanded instructions |
| Trickster | `ca617b9` | Verified `thf_trickster_specs.lua` |
| Phantom | `63e6f29` | Verified `thf_phantom_specs.lua` |
| Bandit | `bb81fe0` | Verified `thf_bandit_specs.lua` |
| Zealot | `d9f8689` | Verified `whm_zealot_specs.lua` |
| Skyborn | `da4a901` | Verified `drg_skyborn_specs.lua` |
| Reaper | `3349b7c` | Verified `drk_reaper_specs.lua` |
| Oathbreaker | `60ebf19` | Verified `pld_oathbreaker_specs.lua` |
| Valkyrie | `79bb94a` | Verified `whm_valkyrie_specs.lua` |
| Nightblade | `f97846c` | Verified `nin_nightblade_specs.lua` |
| Channeler | `e221ca9` | Verified `blm_channeler_specs.lua` |
| Lancer | `fb365d5` | Verified `drg_lancer_specs.lua` |
| Sniper | `a341a24` | Verified `rng_sniper_specs.lua` |
| Scarlet Weaver | `78f2480` | Verified `rdm_scarlet_weaver_specs.lua` |
| Royal Tactician | `59e1365` | Verified `rdm_royal_tactician_specs.lua` |
| Arcane Archer | `4154052` | Verified `rng_arcane_archer_specs.lua` |
| Archivist | `be63c10` | Verified `sch_archivist_specs.lua` |
| Astromancer | `0252934` | Verified `blm_astromancer_specs.lua` |
| Warmage | `4b99fe1` | Verified `blu_warmage_specs.lua` |
| Scourge | `166fd9b` | Verified `drk_scourge_specs.lua` |
| Berserker | `463988b` | Verified `war_specs.lua` |
| Black Belt | `3cc40de` | Verified `mnk_specs.lua` |
| Vampire | `3483294` | Verified `dnc_healer_specs.lua` |
| Musician | `25cb042` | Verified `brd_specs.lua` |
| Minstrel | `f1616a5` | Verified `brd_specs.lua` |
| Flintlock | `320715d` | Verified `cor_specs.lua` current Gun kit |
| Medic | `a076746` | Verified `sch_specs.lua` and `eos_companion.lua`; radial eligibility needs live verification |
| Sensei | `d16481d` | Verified `mnk_specs.lua` |
| Adventurer | `03d1bd5` | Verified `brd_specs.lua` |
| Sage | `a4e7226` | Verified `sch_specs.lua` and Titania companion definition |
| Bladewheel | `7a8d5ca` | Verified `dnc_specs.lua`; weapon skill detail from existing guide |
| Ronin | `95df46b` | Verified `sam_specs.lua` |
| Commander | `714f8d0` | Existing guide and `war_specs.lua` |
| Imperial Archer | `a64c1ef` | Existing guide and `sam_specs.lua` |
| Buccaneer | `a7931ad` | Existing guide and `cor_specs.lua` |
| Pugilist | `c3ee410` | Verified `pup_specs.lua` |
| Celestial | `a16ea5b` | Verified `smn_specs.lua` |
| Verdant | `6d8f14d` | Verified `geo_specs.lua` |
| Vanguard | `5a802f9` | Existing guide and `pup_specs.lua` |
| Mirage Sentinel | `96c84a2` | Existing guide and `dnc_specs.lua` |
| Gambler | `a62ea5f` | Existing guide and `cor_specs.lua` |
| Magus | `9c7ad57` | Existing guide and `blu_healer_specs.lua` |
| Bishop | `51f3166` | Existing guide and `whm_specs.lua` |
| Templar | `7b499c9` | Existing guide and `pld_healer_specs.lua` |
| Warlord | `5d65191` | Existing guide and `sam_specs.lua` |
| Huntsman | `68e9fb8` | Reviewed current modal companion implementation in `rng_specs.lua` |
| Spellblade | `23cd592` | Reviewed `run_specs.lua` and existing player guide |
| Spartan | `79d867c` | Current guide and `war_specs.lua` |
| Aegis Templar | `11181f8` | Current guide and `pld_specs.lua` |
| Alpha Warden | `b94778d` | Existing guardian pet guide |
| Inquisitor | `7354d0e` | Rune Fencer stance guide and implementation |
| Crimson Duelist | `79b8bdc` | Existing Sword/Hex tank guide |
| Lifebinder | `07d76e2` | Existing Rune-based healing guide |
| Azure Bastion | `73963e1` | Existing Blue Magic tank guide |
| Chi Weaver | `5a01cee` | Existing ranged-chi healer guide |
| Wyvernheart | `73a0662` | Existing Wyvern combat-healer guide |
| Animist | `4ba6ec2` | Existing support automaton guide |
| Dreadnought | `3f1bf69` | Existing Scythe tank guide |
| Kagemusha | `33795fb` | Existing shadow tank guide |
| Necromancer | `2b3ed34` | Existing modal thrall guide |
| Shinobi | `861260a` | `nin_specs.lua`, `kurogane_clones.lua`, existing Shinobi guide; removed internal diagnostics from player guide |

**Status:** 66/66 documentation revisions committed. GitHub Actions generated-wiki validation and CI tooling/Soul action wiki unit tests passed. Rendered live site review still pending. Not merged or wiki-published. Latest wiki-data generator and CI tooling/Soul Action wiki tests passed on the feature branch.

## Findings and resume instructions

- The wiki parser only recognizes particular `##` headings. Previously, guides with only `## Level 10 opening` could appear almost blank even when the Markdown contained detail; this was fixed for the six affected canonical guides listed first.
- Existing guides vary greatly in depth; some already follow the required five-heading structure but remain short.
- The 311-byte `docs/guides/kurogane.md` is a retired-name pointer to Shinobi, not a 67th canonical Soul. Do not count auxiliary guide documents as canonical Souls.
- `docs/guides/shinobi.md` uses alternative headings that are partly recognized by the current parser and contains internal diagnostics; it needs a dedicated player-facing review.
- For the next Soul, fetch the guide and the real matching `modules/custom/lua/*_specs.lua` implementation (plus tests/report as needed), verify ability names and mechanics, expand the five wiki-compatible sections, commit the one guide, and append its commit here.
- Before merging: regenerate wiki data with launcher definitions, run strict Soul action + wiki tests, inspect a rendered guide on the site, and check no vanilla action names or internal identifiers leak.

## Current audit completion and remaining release gates

- All **66 canonical `docs/guides/<soul>.md`** entries have expanded player-facing revisions on this feature branch.
- No server or launcher gameplay implementation was modified.
- Most of the revisions have been checked against current implementation or existing completed-guide mechanics; detailed game-client behavior is not independently live-tested.
- **CI validation succeeded:** GitHub Actions run 44864752017 generated wiki data with current launcher action definitions and passed the CI tooling/Soul action wiki unit tests. Manual rendered-site spot checks and in-game behavior verification remain separate tasks.
- Perform a focused technical check on the six originally misparsed guides (Terramancer, Diviner, Beastspeaker, Herald, Untamed, Primalist) and Shinobi, whose original file used nonstandard sections and internal-only diagnostics.

## CI verification

- GitHub Actions: [Update SoulspireXI Wiki Data, run 44864752017](https://github.com/Infomatictek/soulspirexi/actions/runs/44864752017).
- `Generate and validate site/data.json and site/data.js`: **success**.
- `Run CI tooling and Soul action wiki unit tests`: **success**.
- Validation job: **success**. Publish job skipped correctly because this was a feature-branch run.
