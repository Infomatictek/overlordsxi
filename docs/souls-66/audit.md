# Issue 20 · Implementation audit before design

**Baselines** · [Server c34cd4f](https://github.com/Infomatictek/overlordsxi/tree/c34cd4f66ae890d0598884e69f961fa15eead219) · [Launcher d386532](https://github.com/Infomatictek/overlordsxi-launcher/tree/d3865320c9768c5f2789eb9ebc32ce9345de9dd4) · [Issue and history](https://github.com/Infomatictek/overlordsxi/issues/20)

22 jobs × 3 active Souls. The server catalog has 67 entries. Freelancer is a reserved historical slot and excluded here. The 41 implementation entries in the generated site snapshot (identified there as 999dc6d) reconcile to 41 entries in Lua modules named in the pinned loader. The other 25 have documented design evidence. Four also have immutable prototype sources. The inventory cross-check includes the central SCH registry, all custom Lua/SQL/C++ and patch paths, guide aliases, gear and WS references, launcher roster, native branch table and manifest. A name in an item, regen policy, wiki, or label supplies no active combat loop by itself.

**Classification at these revisions**

| Class | Count | Evidence rule |
|---|---:|---|
| Completed / Playable | 2 | Owner confirms play and the normal loop is present. Preserve. |
| Implemented / Needs Tuning | 37 | Integrated gameplay in source. Preserve it and check the Soul-specific performance or compatibility question in its design card. This category does not establish a defect or prove a live combat result. |
| Partially Implemented | 6 | Four staged prototypes, plus Huntsman and Flintlock whose current server kits implement earlier designs. Preserve both playable baselines. |
| Concept Only | 21 | Design is documented. Cross-repository review found no implementation of that signature in the audited snapshots. |
| Missing | 0 | Every active identity has at least design evidence. |

**Reading the matrix.** Branch is the position used by server `buildEntry` and stored by `spec.set` in `OX_SPEC_<JOB>`. Source links locate the runtime entry or staged module. “Design” links to pre-existing documents. Client columns separately track native label at that exact job/branch, HUD key, and named Crystal Socket PNG in launcher manifest. An icon or DAT file in a manifest cannot certify its contents, a running DLL or an action. Distinct action IDs, weapon paths, survival/utility, progression, player choice, lore roots and per-Soul test cases are addressed in the job cards. For **every row**, Lv10 and Lv75 acceptance on these exact builds is **unverified**. Owner confirmation establishes general playability for the two MNK Souls, without an invented level-specific test.

| Job / branch | Soul / stored or catalog key | Implementation class | Evidence | Native label | HUD key / icon |
|---|---|---|---|---|---|
| WAR 1 | Commander · `commander` | Implemented / Needs Tuning | [war_specs.lua](../../modules/custom/lua/war_specs.lua#L557) | Commander | yes / yes |
| WAR 2 | Berserker · `berserker` | Implemented / Needs Tuning | [war_specs.lua](../../modules/custom/lua/war_specs.lua#L596) | Berserker | yes / yes |
| WAR 3 | Spartan · `spartan` | Implemented / Needs Tuning | [war_specs.lua](../../modules/custom/lua/war_specs.lua#L630) | Spartan | yes / yes |
| MNK 1 | Sensei · `sensei` | Implemented / Needs Tuning | [mnk_specs.lua](../../modules/custom/lua/mnk_specs.lua#L851) | Sensei | yes / yes |
| MNK 2 | Chi Weaver · `chiweaver` | Completed / Playable | [mnk_specs.lua](../../modules/custom/lua/mnk_specs.lua#L938) | Chi Weaver | yes / yes |
| MNK 3 | Black Belt · `blackbelt` | Completed / Playable | [mnk_specs.lua](../../modules/custom/lua/mnk_specs.lua#L895) | Black Belt | yes / yes |
| WHM 1 | Bishop · `bishop` | Implemented / Needs Tuning | [whm_specs.lua](../../modules/custom/lua/whm_specs.lua#L379) | Bishop | yes / yes |
| WHM 2 | Zealot · `zealot` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Zealot | yes / unlisted |
| WHM 3 | Valkyrie · `valkyrie` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Valkyrie | yes / unlisted |
| BLM 1 | Astromancer · `astromancer` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Astromancer | yes / unlisted |
| BLM 2 | Channeler · `channeler` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Channeler | yes / unlisted |
| BLM 3 | Necromancer · `necromancer` | Implemented / Needs Tuning | [blm_specs.lua](../../modules/custom/lua/blm_specs.lua#L1382) | Necromancer | yes / yes |
| RDM 1 | Crimson Duelist · `crimsonduelist` | Implemented / Needs Tuning | [rdm_specs.lua](../../modules/custom/lua/rdm_specs.lua#L699) | Crimson Duelist | yes / yes |
| RDM 2 | Royal Tactician · `royaltactician` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Royal Tactician | yes / unlisted |
| RDM 3 | Scarlet Weaver · `scarletweaver` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Scarlet Weaver | yes / unlisted |
| THF 1 | Trickster · `trickster` | Partially Implemented | [prototype](https://github.com/Infomatictek/overlordsxi/blob/de974135babab04aa47d017a8a97c128cb5f9de2/modules/custom/lua/thf_specs.lua) | Trickster | yes / unlisted |
| THF 2 | Bandit · `bandit` | Partially Implemented | [prototype](https://github.com/Infomatictek/overlordsxi/blob/de974135babab04aa47d017a8a97c128cb5f9de2/modules/custom/lua/thf_specs.lua) | Bandit | yes / unlisted |
| THF 3 | Phantom · `phantom` | Partially Implemented | [prototype](https://github.com/Infomatictek/overlordsxi/blob/de974135babab04aa47d017a8a97c128cb5f9de2/modules/custom/lua/thf_specs.lua) | Phantom | yes / unlisted |
| PLD 1 | Templar · `templar` | Implemented / Needs Tuning | [pld_healer_specs.lua](../../modules/custom/lua/pld_healer_specs.lua#L329) | Templar | yes / yes |
| PLD 2 | Defender · `defender` | Implemented / Needs Tuning | [pld_specs.lua](../../modules/custom/lua/pld_specs.lua#L774) | Defender | yes / yes |
| PLD 3 | Oathbreaker · `oathbreaker` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Oathbreaker | yes / unlisted |
| DRK 1 | Reaper · `reaper` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Reaper | yes / unlisted |
| DRK 2 | Dreadnought · `dreadnought` | Implemented / Needs Tuning | [drk_specs.lua](../../modules/custom/lua/drk_specs.lua#L882) | Dreadnought | yes / yes |
| DRK 3 | Scourge · `scourge` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Scourge | yes / unlisted |
| BRD 1 | Adventurer · `adventurer` | Implemented / Needs Tuning | [brd_specs.lua](../../modules/custom/lua/brd_specs.lua#L758) | Adventurer | yes / unlisted |
| BRD 2 | Musician · `musician` | Implemented / Needs Tuning | [brd_specs.lua](../../modules/custom/lua/brd_specs.lua#L799) | Musician | yes / unlisted |
| BRD 3 | Minstrel · `minstrel` | Implemented / Needs Tuning | [brd_specs.lua](../../modules/custom/lua/brd_specs.lua#L842) | Minstrel | yes / unlisted |
| RNG 1 | Sniper · `sniper` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Sniper | yes / unlisted |
| RNG 2 | Huntsman · `huntsman` | Partially Implemented | [rng_specs.lua](../../modules/custom/lua/rng_specs.lua#L952) | Huntsman | yes / yes |
| RNG 3 | Arcane Archer · `arcanearcher` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Arcane Archer | yes / unlisted |
| SAM 1 | Ronin · `ronin` | Implemented / Needs Tuning | [sam_specs.lua](../../modules/custom/lua/sam_specs.lua#L1814) | Ronin | yes / yes |
| SAM 2 | Imperial Archer · `imperialarcher` | Implemented / Needs Tuning | [sam_specs.lua](../../modules/custom/lua/sam_specs.lua#L1869) | Imperial Archer | yes / yes |
| SAM 3 | Warlord · `warlord` | Implemented / Needs Tuning | [sam_specs.lua](../../modules/custom/lua/sam_specs.lua#L1957) | Warlord | yes / yes |
| NIN 1 | Shinobi · `kurogane` | Implemented / Needs Tuning | [nin_specs.lua](../../modules/custom/lua/nin_specs.lua#L1000) | Shinobi | yes / yes |
| NIN 2 | Kagemusha · `kagemusha` | Implemented / Needs Tuning | [nin_specs.lua](../../modules/custom/lua/nin_specs.lua#L940) | Kagemusha | yes / yes |
| NIN 3 | Nightblade · `nightblade` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Nightblade | yes / unlisted |
| DRG 1 | Lancer · `lancer` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Lancer | yes / unlisted |
| DRG 2 | Skyborn · `skyborn` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Skyborn | yes / unlisted |
| DRG 3 | Wyvernheart · `wyvernheart` | Implemented / Needs Tuning | [drg_specs.lua](../../modules/custom/lua/drg_specs.lua#L481) | Wyvernheart | yes / yes |
| BLU 1 | Warmage · `warmage` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Warmage | yes / unlisted |
| BLU 2 | Magus · `magus` | Implemented / Needs Tuning | [blu_healer_specs.lua](../../modules/custom/lua/blu_healer_specs.lua#L603) | Magus | yes / yes |
| BLU 3 | Azure Bastion · `azurebastion` | Implemented / Needs Tuning | [blu_specs.lua](../../modules/custom/lua/blu_specs.lua#L602) | Azure Bastion | yes / yes |
| COR 1 | Flintlock · `flintlock` | Partially Implemented | [cor_specs.lua](../../modules/custom/lua/cor_specs.lua#L1410) | Flintlock | yes / yes |
| COR 2 | Gambler · `gambler` | Implemented / Needs Tuning | [cor_specs.lua](../../modules/custom/lua/cor_specs.lua#L1463) | Gambler | yes / yes |
| COR 3 | Buccaneer · `buccaneer` | Implemented / Needs Tuning | [cor_specs.lua](../../modules/custom/lua/cor_specs.lua#L1537) | Buccaneer | yes / yes |
| DNC 2 | Vampire · `vampire` | Implemented / Needs Tuning | [dnc_healer_specs.lua](../../modules/custom/lua/dnc_healer_specs.lua#L259) | Vampire | yes / yes |
| DNC 3 | Bladewheel · `bladewheel` | Implemented / Needs Tuning | [dnc_specs.lua](../../modules/custom/lua/dnc_specs.lua#L779) | Bladewheel | yes / yes |
| DNC 4 | Mirage Sentinel · `miragesentinel` | Implemented / Needs Tuning | [dnc_specs.lua](../../modules/custom/lua/dnc_specs.lua#L817) | — | yes / yes |
| SCH 1 | Medic · `medic` | Implemented / Needs Tuning | [overlords_job_specs.lua](../../modules/custom/lua/overlords_job_specs.lua#L1578) | Medic | yes / yes |
| SCH 2 | Sage · `sage` | Implemented / Needs Tuning | [overlords_job_specs.lua](../../modules/custom/lua/overlords_job_specs.lua#L1595) | Sage | yes / yes |
| SCH 3 | Archivist · `archivist` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Archivist | yes / unlisted |
| BST 1 | Untamed · `untamed` | Partially Implemented | [prototype](https://github.com/Infomatictek/overlordsxi/blob/a9de23d38a041653bf1dcee565b8b6b688fe2eb4/modules/custom/lua/bst_untamed.lua) | Untamed | yes / unlisted |
| BST 2 | Alpha Warden · `alphawarden` | Implemented / Needs Tuning | [bst_specs.lua](../../modules/custom/lua/bst_specs.lua#L1191) | Soulbeast | yes / yes |
| BST 3 | Beastspeaker · `beastspeaker` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Beastspeaker | yes / unlisted |
| SMN 1 | Primalist · `primalist` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Primalist | yes / unlisted |
| SMN 2 | Celestial · `celestial` | Implemented / Needs Tuning | [smn_specs.lua](../../modules/custom/lua/smn_specs.lua#L242) | Celestial | yes / yes |
| SMN 3 | Herald · `herald` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Herald | yes / unlisted |
| PUP 1 | Vanguard · `vanguard` | Implemented / Needs Tuning | [pup_specs.lua](../../modules/custom/lua/pup_specs.lua#L1201) | Vanguard | yes / yes |
| PUP 2 | Animist · `animist` | Implemented / Needs Tuning | [pup_healer_specs.lua](../../modules/custom/lua/pup_healer_specs.lua#L789) | Pugilist | yes / yes |
| PUP 3 | Pugilist · `pugilist` | Implemented / Needs Tuning | [pup_specs.lua](../../modules/custom/lua/pup_specs.lua#L1282) | Animist | yes / yes |
| RUN 1 | Spellblade · `spellblade` | Implemented / Needs Tuning | [run_specs.lua](../../modules/custom/lua/run_specs.lua#L1290) | Spellblade | yes / yes |
| RUN 2 | Lifebinder · `lifebinder` | Implemented / Needs Tuning | [run_specs.lua](../../modules/custom/lua/run_specs.lua#L1373) | Lifebinder | yes / yes |
| RUN 3 | Inquisitor · `inquisitor` | Implemented / Needs Tuning | [run_specs.lua](../../modules/custom/lua/run_specs.lua#L1231) | Inquisitor | yes / yes |
| GEO 1 | Diviner · `diviner` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Diviner | yes / unlisted |
| GEO 2 | Verdant · `verdant` | Implemented / Needs Tuning | [geo_specs.lua](../../modules/custom/lua/geo_specs.lua#L228) | Verdant | yes / yes |
| GEO 3 | Terramancer · `terramancer` | Concept Only | [design](../whole-roster-soul-gap-reconciliation.md) | Terramancer | yes / unlisted |

## Discrepancies and preservation decisions

- **DNC.** Server Mirage Sentinel resolves to 4. Native labels support branches 1–3 and display Mirage Sentinel at 1. Server `!spec list` uses registered entries. Removing the first catalog entry would renumber Vampire, Bladewheel and Mirage Sentinel and reinterpret saved values. Retire Freelancer from new selection/public lists by key. Preserve numeric values, including historical 1. If 1 has no resolvable live entry, keep raw storage intact and offer normal re-selection. Do not assign old 1 to Mirage automatically.
- **PUP/BST.** Native PUP labels invert 2 Animist and 3 Pugilist. Native BST 2 still says Soulbeast/SLB. Correct presentation against the saved server branch. Preserve legacy inputs and translation in display surfaces. An installed binary needs its own acceptance check.
- **PLD/NIN.** Defender is the existing Aegis Templar handler (`aegistemplar`), distinct from the healer Templar. Shinobi is `kurogane`, branch 1, KRG. The old Shinobi guide calls clone summoning and production JAs pending. Current nin_specs hooks Ichi/Ni and dispatches 487/488. The clone backend defaults enabled, SQL has both rows, and Metrics names them at 999/1000. Validate normal client selection, capped replacement, attribution and duration. Reuse these allocations.
- **RNG.** Main implements ranged WS pet healing, with Tusker tank and Saurian support. The [melee redesign](https://github.com/Infomatictek/overlordsxi/blob/18bb7e3168d825e715f21fd557a8464fb038275d/docs/guides/huntsman.md) places both beasts in tank roles, gives single axe/optional dagger, command JAs without a required horn item and 8y Beastguard. The main wiki describes its own ranged snapshot. Publish the new guide/wiki and labels together with an accepted redesign.
- **COR.** Current Flintlock uses Deadeye Chamber, Quick Draw/Powder Mark and gun WS. The older guide calls it a sniper. Independent twin pistols are the intended high-volume single-target system. Sniper's target design is low-volume committed aim. No twin-pistol internals are assigned to this project.
- **BST/THF.** At the linked feature heads neither prototype file is present in its branch loader list. Their event hooks, targeting and numbers are concrete staging evidence. Player access and real combat are unverified.
- **Ws and equipment.** The table in `overlords_ws_spec_profiles.lua` controls skill-specific talent eligibility. A missing table currently returns true. It cannot establish universal equipment permission. Chi Weaver is intentionally bare handed despite H2H WS eligibility. DNC Ammo and COR gun slots have independent rules.
- **Action approval.** The server action registry is opt-in. Additive grants and level-255 custom SQL rows do not filter learned spells or subjobs. The launcher has profile parsing and a demonstration Tsunami entry. Native menu/animation/description coverage and a matching installed profile must be tested separately.
- **Chi Weaver.** Registration prose advertises a negative Attack% alongside a WS penalty. Preserve the empty-hand pulse/heal loop and existing thresholds. Check actual applied modifiers against the project's non-DPS accuracy/attack floor before adjusting numbers. Never implement a negative mod merely to match prose.
- **Guide coverage.** The wiki supplies registered Templar and Magus entries even without standalone same-key guide files. SCH Medic/Sage register in the central file. A job module name or absent guide cannot stand in for a missingness verdict.

## Open evidence

Installed server patch set, DB contents, live character variables, binary DAT slot contents, field performance, client locale and the independent twin-pistol build cannot be certified from Git trees. Preserve each as a release gate. The design scope uses the named snapshots and staged targets. No migration, SQL, addon or combat file is part of this audit.
