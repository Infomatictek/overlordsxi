# Final 25 Souls

## Checkpoint

- Server integration branch: `feat/final-25-souls`, based on `180f018caa22f73f7ff2fab4323380901606f738` in `Infomatictek/soulspirexi`.
- Launcher baseline: `919674ea842acb1afbf1f2140f63dfbf50c1d1f2` in `Infomatictek/soulspirexi-launcher`. Launcher branch: `feat/final-25-souls`.
- Completed: 4/25. Current: Scarlet Weaver. Blocked: none.
- Latest pushed Soul implementation commits: server `35ba82c33de819c5b6653e382467758abf95efbb`, launcher `f46f5c1ea82c40730b16b313886f2a56bd20124f`. The server branch also carries this tracker update.

## Implementation queue

| # | Job | Soul | Key | Role | Status |
|---|---|---|---|---|---|
| 1 | WHM | Zealot | zealot | Damage | Pushed. Manual verification required. |
| 2 | WHM | Valkyrie | valkyrie | Support | Pushed. Manual verification required. |
| 3 | BLM | Astromancer | astromancer | Damage | Pushed. Manual verification required. |
| 4 | BLM | Channeler | channeler | Support | Pushed. Manual verification required. |
| 5 | RDM | Scarlet Weaver | scarletweaver | Damage | Current |
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
- **Astromancer checkpoint:** [Implementation report](completed/astromancer.md). Server `4e1ee017c2e53e2b205771dabc7ab89823e780fb`, launcher `2966b5c5b0f2982ef3e25e80733e7d5500620454`. Four focused tests and 58 local non-loopback tests passed. Strict roster audit: 44 registered, 22 planned. Wiki generated all 16 actions. Native patch checked and 11 C++ units syntax-checked. Launcher validator and 1,109 manifest entries passed.
- **Astromancer architecture:** `blm_astromancer_specs.lua` owns probes, selection, cast presentation and Saturation. `0048-astromancer-native-actions.patch` validates virtual grants, costs and Ancient recovery. It applies the bonus in native damage calculation and confirms actual HP loss before claiming the shared target window. Mob spawn resets Saturation.
- **Channeler checkpoint:** [Implementation report](completed/channeler.md). Server `35ba82c33de819c5b6653e382467758abf95efbb`, launcher `f46f5c1ea82c40730b16b313886f2a56bd20124f`. Three focused tests and 61 non-loopback regression tests passed. Strict roster audit: 45 registered, 21 planned. Exact wiki generation validated all three custom actions. Native overlay applied, 11 C++ units syntax-checked, and all 1,109 launcher manifest entries verified.
- **Channeler architecture:** `blm_channeler_specs.lua` owns party targeting, level-dependent link progress and HUD. `0049-channeler-native-actions.patch` reserves benefits inside one native cast, uses the same discount in affordability and actual MP spending, and cleans up on finish/cancel. Shared native spell or ability slots retain the unrelated Soul's behavior.
- **Next step:** reconcile Scarlet Weaver's approved signed Yin/Yang design and role with the Sequence C prototype. Audit emergency defensive actions and surviving penalties at Lv.10, then verify required Sword WS support and select native carriers for its offensive/defensive choices.
