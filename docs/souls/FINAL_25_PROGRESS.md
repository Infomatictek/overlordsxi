# Final 25 Souls

## Checkpoint

- Server integration branch: `feat/final-25-souls`, based on `180f018caa22f73f7ff2fab4323380901606f738` in `Infomatictek/soulspirexi`.
- Launcher baseline: `919674ea842acb1afbf1f2140f63dfbf50c1d1f2` in `Infomatictek/soulspirexi-launcher`. Launcher branch: `feat/final-25-souls`.
- Completed: 15/25. Current: Lancer. Blocked: none.
- Latest pushed Soul implementation commits: server `672e2d63114373441719e49e0fcad2e0d54f3b69`, launcher `773f9cf1e683e26324f1e9e4d12422f2cf788d98`. The server branch also carries this tracker update.

## Implementation queue

| # | Job | Soul | Key | Role | Status |
|---|---|---|---|---|---|
| 1 | WHM | Zealot | zealot | Damage | Pushed. Manual verification required. |
| 2 | WHM | Valkyrie | valkyrie | Support | Pushed. Manual verification required. |
| 3 | BLM | Astromancer | astromancer | Damage | Pushed. Manual verification required. |
| 4 | BLM | Channeler | channeler | Support | Pushed. Manual verification required. |
| 5 | RDM | Scarlet Weaver | scarletweaver | Damage | Pushed. Manual verification required. |
| 6 | RDM | Royal Tactician | royaltactician | Support | Pushed. Manual verification required. |
| 7 | THF | Bandit | bandit | Damage | Pushed. Manual verification required. |
| 8 | THF | Trickster | trickster | Support | Pushed. Manual verification required. |
| 9 | THF | Phantom | phantom | Tank | Pushed. Manual verification required. |
| 10 | PLD | Oathbreaker | oathbreaker | Damage | Pushed. Manual verification required. |
| 11 | DRK | Reaper | reaper | Damage | Pushed. Manual verification required. |
| 12 | DRK | Scourge | scourge | Support | Pushed. Manual verification required. |
| 13 | RNG | Sniper | sniper | Damage | Pushed. Manual verification required. |
| 14 | RNG | Arcane Archer | arcanearcher | Support | Pushed. Manual verification required. |
| 15 | NIN | Nightblade | nightblade | Support | Pushed. Manual verification required. |
| 16 | DRG | Lancer | lancer | Damage | Current |
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
- **Scarlet Weaver checkpoint:** [Implementation report](completed/scarletweaver.md). Server `6c145210406300a6052d2c5decfe9a42d3ad1bd6`, launcher `571a4da93dcd285c4c46b7d8fd2bb1442b3d9b74`. Three focused tests and 64 non-loopback regression tests passed. Strict roster audit: 46 registered, 20 planned. Wiki generated 11 native actions. Eleven C++ checks and 1,109 launcher manifest entries passed.
- **Scarlet Weaver architecture:** The approved RDM design is an offensive two-form choice. `rdm_scarlet_weaver_specs.lua` owns form and timing, and `0050-scarlet-weaver-native-actions.patch` scopes Yang to normal main-hand Sword hits and Yin to the Soul's spell set. The signed defense-cost design belongs to the separate RUN Spellblade discussion.
- **Royal Tactician checkpoint:** [Implementation report](completed/royaltactician.md). Server `b505bd6ee0e796943baefa4f4cd91b24d956622d`, launcher `69916af58954ba4fc0e077eb4c4d7b25b8686c6a`. Three focused tests and 67 non-loopback regression tests passed. Audit found 47 registered and 19 planned. Six wiki actions, 11 C++ units and 1,109 launcher manifest entries verified.
- **Royal Tactician architecture:** Successful enfeebles use the native outcome message to open the latest order, and the server's completed cast path accounts for actual MP spent. Mutually exclusive recipient orders enforce strongest-wins for the same type, with timed cleanup of Advance's flat Accuracy and Store TP.
- **Bandit checkpoint:** [Implementation report](completed/bandit.md). Server `418959873209adb67c7f31b106ee742a22670bbe`, launcher `3430706a43f05f9844dd0784c076f9e94026873e`. Three focused tests and 70 non-loopback regression tests passed. Audit found 48 registered, 18 planned. Both wiki actions, 12 C++ units and 1,109 manifest entries verified.
- **Bandit architecture:** At the native weapon-skill start event, Bandit snapshots an existing Defense Down or private opening. A landed qualifying weapon skill refunds TP. Find the Gap provides the solo Lv.10 path. It gives no allied debuff or bonus.
- **Trickster checkpoint:** [Implementation report](completed/trickster.md). Server `67c11d47fb93c1347218f8b6cedab001b3a2a960`, launcher `860f5cacf6c17ec5c264b34a2d9cad85e3449648`. Three focused tests and 73 non-loopback regression tests passed. Audit found 49 registered, 17 planned. Wiki, 12 C++ units and 1,109 manifest entries verified. The planned-Soul wiki test uses an explicit planned fixture so it remains useful as the roster fills out.
- **Trickster architecture:** Scoped native positional threat routing plus a weapon-skill-triggered Attack Down. Existing or rejected debuffs and missed hits preserve the cooldown.
- **Phantom checkpoint:** [Implementation report](completed/phantom.md). Server `c91de0d5de647ce1c8f704171eaa58342590ee4e`, launcher `39e03537d8b4b0d3ceeb58afcce8062efd7bb4a0`. Three focused tests and 76 non-loopback regression tests passed. Audit found 50 registered, 16 planned. Strict wiki, 12 C++ units and 1,109 launcher manifest entries checked.
- **Phantom architecture:** The opener uses the normal enmity and claim path with a scoped Steal-slot repurpose. Native regular melee misses drive enmity. The one-hit guard uses the shared pre-damage hook. Dagger/Katana restrictions, ordinary scoped Katanas and THF test gear follow the existing weapon path.
- **Oathbreaker checkpoint:** [Implementation report](completed/oathbreaker.md). Server `b94e0547755cb75c3f2d0bd4acbadcbf61084eea`, launcher `7c372adf1535e52cc1699f8b0958f9cbce755a47`. Three focused tests, 79 accessible regression tests, strict roster and Lua wiki, 12 native syntax checks and 1,109 launcher entries passed. Live gameplay requires manual verification.
- **Oathbreaker architecture:** Use Soul Action registry recast overrides for wiki output when a Soul reuses a native ability. Record retaliation from actual hostile HP lost after absorption.
- **Reaper checkpoint:** [Implementation report](completed/reaper.md). Server `48e28bad527f0b4b92480d95d07881c38eae6c83`, launcher `1622283d608cdefad89cb4aea43ec4d241c496dd`. Three focused tests, 82 accessible regression tests, strict Lua wiki and roster, 12 native syntax checks and 1,109 launcher entries passed. Live gameplay requires manual verification.
- **Reaper architecture:** Count one mob attack round or completed damaging action at the native callback boundary. Lua resolves target recovery and a Reaper's individual opportunity. Use cloned spell timings and costs to leave the native action unchanged for other Souls.
- **Scourge checkpoint:** [Implementation report](completed/scourge.md). Server `ebbb8bc568948b18608f639e9da197d5a0dc8f64`, launcher `2229742f63489e0dac751cfae774fed09d2dc002`. Four focused tests, 86 accessible regression tests, strict Lua wiki and roster, 12 native syntax checks and 1,109 launcher entries passed. Live gameplay requires manual verification.
- **Scourge architecture:** Use native mob action scope to distinguish physical TP damage and spell damage from ordinary swings. Apply Famine only inside standard cure and healing-move calculations, and keep party fallback separate from the enemy-wide curse slot.
- **Sniper checkpoint:** [Implementation report](completed/sniper.md). Server `dfa5aab1bf4a1dad768fc7ba9f5ed4d951df2598`, launcher `38862b165b8d4964bc31f43086410c12f1f5aaf9`. Three focused tests, 89 accessible regression tests, strict Lua wiki and roster, 15 native syntax checks and 1,109 launcher entries passed. Live gameplay requires manual verification.
- **Sniper architecture:** Route the repurposed action through native ranged state and the ordinary ammo/damage resolver with an explicitly scoped one-projectile profile. Validate the target and equipment again at release. Keep the stock ranged animation and result line for the aimed shot.
- **Arcane Archer checkpoint:** [Implementation report](completed/arcanearcher.md). Server `b040bf127776d1cc23fb95413548f417660afca0`, launcher `53ed85a9a1517ff95cc1a3792b258c2e2963ba07`. Four focused tests, 93 accessible regression tests, strict Lua wiki and roster, 15 native syntax checks, three shared Lua syntax checks and 1,109 launcher entries passed. Live gameplay requires manual verification.
- **Arcane Archer architecture:** Distinct ranged action profiles share native aim and ammo handling. Reserve one matching elemental mark before damage and finish the claim only after actual HP loss; prove spell, skillchain and solo bow WS contexts explicitly.
- **Nightblade checkpoint:** [Implementation report](completed/nightblade.md). Server `672e2d63114373441719e49e0fcad2e0d54f3b69`, launcher `773f9cf1e683e26324f1e9e4d12422f2cf788d98`. Four focused tests, 97 accessible regression tests, strict Lua wiki and roster, 16 native syntax checks and 1,109 launcher entries passed. Live gameplay requires manual verification.
- **Nightblade architecture:** Read native spell and technique sequence IDs and clear them on completion, interruption or disengage. Scope reduction to classified damage from that same sequence. Confirm TP damage type at resolution and refund the long recast when Blunting mismatches.
- **Next step:** Implement Lancer's Polearm vault and native Jump follow-through, verify distance and terrain checks and document the Lv. 10–75 rotation.
