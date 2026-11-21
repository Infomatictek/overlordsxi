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

**Status:** 20/66 documentation revisions committed. Not merged or wiki-published. No automated full wiki regeneration or integration suite has yet been executed for these commits.

## Findings and resume instructions

- The wiki parser only recognizes particular `##` headings. Previously, guides with only `## Level 10 opening` could appear almost blank even when the Markdown contained detail; this was fixed for the six affected canonical guides listed first.
- Existing guides vary greatly in depth; some already follow the required five-heading structure but remain short.
- The 311-byte `docs/guides/kurogane.md` is a retired-name pointer to Shinobi, not a 67th canonical Soul. Do not count auxiliary guide documents as canonical Souls.
- `docs/guides/shinobi.md` uses alternative headings that are partly recognized by the current parser and contains internal diagnostics; it needs a dedicated player-facing review.
- For the next Soul, fetch the guide and the real matching `modules/custom/lua/*_specs.lua` implementation (plus tests/report as needed), verify ability names and mechanics, expand the five wiki-compatible sections, commit the one guide, and append its commit here.
- Before merging: regenerate wiki data with launcher definitions, run strict Soul action + wiki tests, inspect a rendered guide on the site, and check no vanilla action names or internal identifiers leak.
