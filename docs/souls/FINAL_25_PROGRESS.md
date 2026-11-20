# Final 25 Souls

## Checkpoint

- Server integration branch: `feat/final-25-souls`, based on `180f018caa22f73f7ff2fab4323380901606f738` in `Infomatictek/soulspirexi`.
- Launcher baseline: `919674ea842acb1afbf1f2140f63dfbf50c1d1f2` in `Infomatictek/soulspirexi-launcher`. Launcher branch: `feat/final-25-souls`.
- Completed: 2/25. Current: Astromancer. Blocked: none.
- Latest pushed Soul implementation commits: server `57285260d8b2604a50cf779331cfee1a20ef86e7`, launcher `463d7b43b040f48a47e34aaf0cc672e089577b9c`. The server branch also carries this tracker update.

## Implementation queue

| # | Job | Soul | Key | Role | Status |
|---|---|---|---|---|---|
| 1 | WHM | Zealot | zealot | Damage | Pushed. Manual verification required. |
| 2 | WHM | Valkyrie | valkyrie | Support | Pushed. Manual verification required. |
| 3 | BLM | Astromancer | astromancer | Damage | Current |
| 4 | BLM | Channeler | channeler | Support | Pending |
| 5 | RDM | Scarlet Weaver | scarletweaver | Damage | Pending |
| 6 | RDM | Royal Tactician | royaltactician | Support | Pending |
| 7 | THF | Bandit | bandit | Damage | Pending |
| 8 | THF | Trickster | trickster | Support | Pending |
| 9 | THF | Phantom | phantom | Tank | Pending |
| 10 | PLD | Oathbreaker | oathbreaker | Damage | Pending |
| 11 | DRK | Reaper | reaper | Damage | Pending |
| 12 | DRK | Scourge | scourge | Support | Pending |
| 13 | RNG | Sniper | sniper | Damage | Pending |
| 14 | RNG | Arcane Archer | arcanearcher | Support | Pending |
| 15 | NIN | Nightblade | nightblade | Support | Pending |
| 16 | DRG | Lancer | lancer | Damage | Pending |
| 17 | DRG | Skyborn | skyborn | Tank | Pending |
| 18 | BLU | Warmage | warmage | Damage | Pending |
| 19 | SCH | Archivist | archivist | Support | Pending |
| 20 | BST | Untamed | untamed | Damage | Pending |
| 21 | BST | Beastspeaker | beastspeaker | Support | Pending |
| 22 | SMN | Primalist | primalist | Damage | Pending |
| 23 | SMN | Herald | herald | Support | Pending |
| 24 | GEO | Terramancer | terramancer | Damage | Pending |
| 25 | GEO | Diviner | diviner | Support | Pending |

## Audit and shared patterns

- The 25 keys match the canonical planned roster in `modules/custom/lua/soulspire_job_specs.lua` and `docs/whole-roster-soul-gap-reconciliation.md`. Static coverage on the available local snapshot identifies 41 registered Souls and 25 planned. The pinned server base is 15 commits ahead of that snapshot; its comparison leaves the registry and module loader unchanged. Defender resolves to the legacy Aegis Templar registration. Freelancer is retired.
- `feat/souls-66-integration` contains Sequence B–E prototype code and acceptance notes. Consult the individual Soul implementation for approved behavior. Its module list diverges from current development and the branch is a reference for individual ports.
- Start with a single-target caster with no pet dependency to establish the action integration. Keep same-job Souls adjacent so spells, shared recasts, weapon access, and lifecycle can be tested together. Pair pet families and field-based GEO work near the end.
- Use the assembled template for each report: canonical identity/command/Crystal, tier and power budget, strict weapon and WS whitelist, passives and level breakpoints, playable loop and tradeoffs, native action IDs and behavior, talent/attack-rate compatibility, HUD, client delivery, pet lifecycle where relevant, and automated/manual verification.
- Use `modules/custom/lua/nin_specs.lua` and `patches/0045-shinobi-ninjutsu-kit.patch` as the live reference for scoped native overrides and effective-level gating. `soulspire_soul_actions.lua` is a data registry. Authoritative casting, ability behavior and gating require runtime hooks. Preserve unrelated Souls’ original behavior, learned spells, and recasts. Check effective levels and subjob action leakage.
- Keep client action names/descriptions and visibility in `addons/ashita4/soulspire_soul_actions/data/` in the launcher. Verify ability ID conversion from server to client, and regenerate the launcher manifest. In-game native menus, macros, casting bars and multiplayer presentation require a client check.
- Register actual resource collectors with `soulspire_soul_hud.lua` and render the matching launcher provider keys. Apply strict WS skill policy through `soulspire_ws_spec_profiles.lua`. Verify baseline function at zero talent points and avoid unintended changes to shared WS foundations.
- The wiki consumes `docs/guides/<key>.md`, server registrations and launcher action TSVs. Verify against `scripts/soul_actions_wiki.py` and `.github/workflows/update-wiki.yml`. Record each completed Soul in `docs/souls/completed/<key>.md`.

## Verification and resume

- Initial comparison: remote main is 15 commits ahead of local `3266e65`; registry and loader match. Local roster audit: `python tools/audit_soul_coverage.py . --strict`.
- Per Soul: run focused mechanics and action checks, `python -m unittest discover -s tests -v`, strict roster audit, wiki action tests, and launcher action/manifest checks. Record commands, results and exact pushed commit hashes after each Soul.
- **Manual Verification Required:** step through levels 10/30/50/75, zone/relogin, level sync, Soul switching, menu and error presentation, nearby-player action identity, and hard-boss combat. Use ordinary gear and zero talent points for the level-10 acceptance run.
- **Zealot checkpoint:** [Implementation report](completed/zealot.md). Four focused tests and nine wiki tests passed. Strict roster audit: 42 registered, 24 planned. Strict wiki build: zero errors. Clean overlay verification and eight MSVC C++ syntax checks passed. Launcher TSVs and 1,109 manifest entries verified. Four unrelated Combat Analytics integration tests need loopback sockets, blocked on the local baseline too.
- **Zealot architecture:** `whm_zealot_specs.lua` exposes its spell table to the wiki exporter and uses the existing Soul Action registry. `0046-zealot-native-actions.patch` handles virtual spell grants, filtered native menus, scoped action permission and cast/ability swap invalidation. It also exposes a staff-hit event after positive main-hand damage. Launcher rules require the corresponding branch for wiki verification.
- **Valkyrie checkpoint:** [Implementation report](completed/valkyrie.md). Server `57285260d8b2604a50cf779331cfee1a20ef86e7`, launcher `463d7b43b040f48a47e34aaf0cc672e089577b9c`. Seven focused WHM tests and 54 non-loopback tests passed. Strict roster audit: 43 registered, 23 planned. Strict wiki generation and nine action wiki tests passed. Native patch application, nine C++ syntax checks, launcher TSVs and 1,109 manifest entries verified.
- **Valkyrie architecture:** `whm_valkyrie_specs.lua` registers Wingmate and Escort. `0047-valkyrie-native-actions.patch` records a hostile interruption, scopes one protected retry to the original spell and tracks actual MP spent. Scoped Polearm equipment/skill and `!gear` support are included. `!gear` also now selects Staff for Zealot.
- **Next step:** reconcile the approved Astromancer Ancient Magic design in `docs/soul-action-whitelist-and-astromancer.md` with the Sequence C prototype. Verify current single-target cast, cost and resolve hooks. Implement a complete Lv.10 filler/Ancient Magic loop including shared per-target Astral Saturation, with a matched native action catalog and HUD.
