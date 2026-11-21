# SoulspireXI — 66-Soul WS Talent Coverage Matrix (Pass 2.1)

Generated from `ws_eligibility_manifest.json`, `ws_talent_contracts.json`, `ws_talent_v21_post_audit.json`, and real live `xi_test` combat evidence (`ws_talent_v21_live_evidence.json`).
Structural validation and live `xi_test` combat validation are tracked **strictly separately**.

## Aggregate Coverage Summary

| Metric | Value |
|---|---|
| Canonical Souls Audited | 66 / 66 |
| Total Eligible Soul × WS Combinations | 1,476 |
| Excluded Base-Job Equipable Combinations | 4,143 (**73.73% reduction**) |
| Estimated Talent Definitions Avoided | **49,716** |
| Total Compiled Talent Contracts | 23,427 |
| **Structural Contract PASS / FAIL** | **23,427 PASS** / 0 FAIL |
| **Unique Effect Handlers (Live `xi_test` Verified)** | **22 / 22** |
| **Souls with All 3 Branches Verified in Live `xi_test`** | **66 / 66** |
| **Live `xi_test` Multi-Level Checks (Lv 10/30/50/75)** | **32 / 32 PASS** |
| **Live `xi_test` Contract PASS** | **211** (321 real `ws_talent_eval` events) |
| **Live `xi_test` Contract FAIL** | **0** |
| **Live `xi_test` Contract BLOCKED** | **0** |
| **Live `xi_test` Contract NOT EXERCISED** | 23,216 |

### Live Combat PASS by Branch

| Branch | Total Contracts | Live `xi_test` PASS |
|---|---:|---:|
| `damage` | 5,832 | 70 |
| `evolution` | 99 | 2 |
| `skillchain` | 5,832 | 0 |
| `soul` | 5,832 | 69 |
| `utility` | 5,832 | 70 |

## Per-Soul Coverage Matrix (All 66 Canonical Souls)

| Job | Soul | Role / Tier | Primary | Secondary | Elig WS | Excl WS | Struct PASS | Live Branches | Live PASS | Live FAIL | Not Exercised | Soul Mechanic Hook |
|---|---|---|---|---|---:|---:|---:|---|---:|---:|---:|---|
| BLM | `astromancer` (Astromancer) | Damage / Damage | Staff | — | 17 | 60 | 272 | **D/U/S PASS** | 3 | 0 | 269 | `blm_astromancer_celestial` |
| BLM | `channeler` (Channeler) | Support / HybridSupport | Staff | — | 17 | 60 | 272 | **D/U/S PASS** | 3 | 0 | 269 | `blm_channeler_resonance` |
| BLM | `necromancer` (Necromancer) | Tank / Tank | Scythe | — | 14 | 63 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `blm_necromancer_pact` |
| BLU | `azurebastion` (Azure Bastion) | Tank / Tank | Sword | Club | 34 | 0 | 530 | **D/U/S PASS** | 3 | 0 | 527 | `blu_azure_carapace` |
| BLU | `magus` (Magus) | Healer / CombatHealer | Sword | Club | 34 | 0 | 535 | **D/U/S PASS** | 3 | 0 | 532 | `blu_magus_mending` |
| BLU | `warmage` (Warmage) | Damage / Damage | Sword | Club | 34 | 0 | 530 | **D/U/S PASS** | 3 | 0 | 527 | `blu_warmage_surge` |
| BRD | `adventurer` (Adventurer) | Damage / Damage | Dagger | Sword | 36 | 45 | 562 | **D/U/S PASS** | 3 | 0 | 559 | `brd_cadence_encore` |
| BRD | `minstrel` (Minstrel) | Tank / Tank | Dagger | Sword | 36 | 45 | 562 | **D/U/S PASS** | 3 | 0 | 559 | `brd_minstrel_anthem` |
| BRD | `musician` (Musician) | Support / HybridSupport | Dagger | Staff | 35 | 46 | 560 | **D/U/S PASS** | 3 | 0 | 557 | `brd_musician_ballad` |
| BST | `alphawarden` (Alpha Warden) | Tank / Tank | Axe | — | 14 | 80 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `bst_alpha_pack` |
| BST | `beastspeaker` (Beastspeaker) | Support / Support | Axe | — | 14 | 80 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `bst_beastspeaker_rally` |
| BST | `untamed` (Untamed) | Damage / Damage | Great Axe | Axe | 28 | 66 | 448 | **D/U/S PASS** | 3 | 0 | 445 | `bst_untamed_feral` |
| COR | `buccaneer` (Buccaneer) | Tank / Tank | Sword | — | 18 | 43 | 274 | **D/U/S PASS** | 3 | 0 | 271 | `cor_buccaneer_grapeshot` |
| COR | `flintlock` (Flintlock) | Damage / Damage | Marksmanship | — | 13 | 48 | 208 | **D/U/S PASS** | 3 | 0 | 205 | `cor_flintlock_deadeye` |
| COR | `gambler` (Gambler) | Support / Support | Marksmanship | Dagger | 31 | 30 | 496 | **D/U/S PASS** | 3 | 0 | 493 | `cor_gambler_advantage` |
| DNC | `bladewheel` (Bladewheel) | Damage / Damage | Throwing | Dagger | 30 | 34 | 480 | **D/U/S PASS** | 3 | 0 | 477 | `dnc_bladewheel_stance` |
| DNC | `miragesentinel` (Mirage Sentinel) | Tank / Tank | Dagger | — | 18 | 46 | 288 | **D/U/S PASS** | 3 | 0 | 285 | `dnc_mirage_fandance` |
| DNC | `vampire` (Vampire) | Healer / CombatHealer | Dagger | Throwing | 30 | 34 | 480 | **D/U/S PASS** | 3 | 0 | 477 | `dnc_vampire_feast` |
| DRG | `lancer` (Lancer) | Damage / Damage | Polearm | — | 14 | 69 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `drg_lancer_vault` |
| DRG | `skyborn` (Skyborn) | Tank / Tank | Polearm | — | 14 | 69 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `drg_skyborn_guard` |
| DRG | `wyvernheart` (Wyvernheart) | Healer / CombatHealer | Polearm | — | 14 | 69 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `drg_wyrmscale_breath` |
| DRK | `dreadnought` (Dreadnought) | Tank / Tank | Scythe | — | 14 | 107 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `drk_blood_pool` |
| DRK | `reaper` (Reaper) | Damage / Damage | Scythe | — | 14 | 107 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `drk_reaper_finality` |
| DRK | `scourge` (Scourge) | Support / Support | Scythe | — | 14 | 107 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `drk_scourge_curse` |
| GEO | `diviner` (Diviner) | Support / Support | Club | Staff | 33 | 18 | 528 | **D/U/S PASS** | 3 | 0 | 525 | `geo_diviner_meridian` |
| GEO | `terramancer` (Terramancer) | Damage / Damage | Club | Staff | 33 | 18 | 528 | **D/U/S PASS** | 3 | 0 | 525 | `geo_terramancer_fault` |
| GEO | `verdant` (Verdant) | Healer / Healer | Club | Staff | 33 | 18 | 528 | **D/U/S PASS** | 3 | 0 | 525 | `geo_verdant_canopy` |
| MNK | `blackbelt` (Black Belt) | Damage / Damage | Hand-to-Hand | — | 16 | 45 | 250 | **D/U/S PASS** | 4 | 0 | 246 | `mnk_impetus_chain` |
| MNK | `chiweaver` (Chi Weaver) | Healer / Healer | Hand-to-Hand | — | 16 | 45 | 250 | **D/U/S PASS** | 3 | 0 | 247 | `mnk_chi_harmony` |
| MNK | `sensei` (Sensei) | Tank / Tank | Staff | — | 17 | 44 | 272 | **D/U/S PASS** | 3 | 0 | 269 | `mnk_dojo_riposte` |
| NIN | `kagemusha` (Kagemusha) | Tank / Tank | Katana | — | 14 | 118 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `nin_kagemusha_shadows` |
| NIN | `kurogane` (Shinobi) | Damage / Damage | Katana | — | 14 | 118 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `nin_kurogane_clone_sync` |
| NIN | `nightblade` (Nightblade) | Support / Support | Katana | — | 14 | 118 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `nin_nightblade_seal` |
| PLD | `defender` (Defender) | Tank / Tank | Club | Sword | 34 | 63 | 533 | **D/U/S PASS** | 3 | 0 | 530 | `pld_zeal_nova` |
| PLD | `oathbreaker` (Oathbreaker) | Damage / Damage | Great Sword | — | 14 | 83 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `pld_oathbreaker_reckoning` |
| PLD | `templar` (Templar) | Healer / CombatHealer | Club | — | 16 | 81 | 256 | **D/U/S PASS** | 3 | 0 | 253 | `pld_beacon_light` |
| PUP | `animist` (Animist) | Healer / CombatHealer | Hand-to-Hand | — | 16 | 46 | 250 | **D/U/S PASS** | 3 | 0 | 247 | `pup_animist_cells` |
| PUP | `pugilist` (Pugilist) | Damage / Damage | Hand-to-Hand | — | 16 | 46 | 250 | **D/U/S PASS** | 3 | 0 | 247 | `pup_pugilist_tandem` |
| PUP | `vanguard` (Vanguard) | Tank / Tank | Hand-to-Hand | — | 16 | 46 | 250 | **D/U/S PASS** | 3 | 0 | 247 | `pup_vanguard_bulwark` |
| RDM | `crimsonduelist` (Crimson Duelist) | Tank / Tank | Sword | — | 18 | 74 | 279 | **D/U/S PASS** | 3 | 0 | 276 | `rdm_crimson_flow` |
| RDM | `royaltactician` (Royal Tactician) | Support / Support | Sword | — | 18 | 74 | 279 | **D/U/S PASS** | 7 | 0 | 272 | `rdm_tactical_enfeeble` |
| RDM | `scarletweaver` (Scarlet Weaver) | Damage / Damage | Sword | — | 18 | 74 | 279 | **D/U/S PASS** | 4 | 0 | 275 | `rdm_scarlet_weave` |
| RNG | `arcanearcher` (Arcane Archer) | Support / Support | Archery | — | 11 | 91 | 176 | **D/U/S PASS** | 3 | 0 | 173 | `rng_arcane_attune` |
| RNG | `huntsman` (Huntsman) | Tank / Tank | Archery | Marksmanship | 24 | 78 | 384 | **D/U/S PASS** | 3 | 0 | 381 | `rng_huntsman_ration` |
| RNG | `sniper` (Sniper) | Damage / Damage | Marksmanship | — | 13 | 89 | 208 | **D/U/S PASS** | 3 | 0 | 205 | `rng_sniper_sightline` |
| RUN | `inquisitor` (Inquisitor) | Tank / Tank | Great Sword | — | 14 | 62 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `run_inquisitor_riposte` |
| RUN | `lifebinder` (Lifebinder) | Healer / Healer | Great Sword | — | 14 | 62 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `run_lifebinder_lifetap` |
| RUN | `spellblade` (Spellblade) | Damage / Damage | Great Sword | — | 14 | 62 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `run_spellblade_conduction` |
| SAM | `imperialarcher` (Imperial Archer) | Support / Support | Great Katana | Archery | 25 | 78 | 400 | **D/U/S PASS** | 3 | 0 | 397 | `sam_drawn_oisoya` |
| SAM | `ronin` (Ronin) | Tank / Tank | Great Katana | — | 14 | 89 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `sam_ronin_stagger` |
| SAM | `warlord` (Warlord) | Support / HybridSupport | Great Katana | — | 14 | 89 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `sam_ashura_edge` |
| SCH | `archivist` (Archivist) | Support / Support | Staff | Club | 33 | 30 | 528 | **D/U/S PASS** | 3 | 0 | 525 | `sch_archivist_tome` |
| SCH | `medic` (Medic) | Healer / Healer | Club | Staff | 33 | 30 | 528 | **D/U/S PASS** | 3 | 0 | 525 | `sch_medic_eos` |
| SCH | `sage` (Sage) | Damage / Damage | Staff | Club | 33 | 30 | 528 | **D/U/S PASS** | 3 | 0 | 525 | `sch_sage_helix` |
| SMN | `celestial` (Celestial) | Healer / Healer | Staff | Club | 33 | 18 | 528 | **D/U/S PASS** | 3 | 0 | 525 | `smn_celestial_starlight` |
| SMN | `herald` (Herald) | Support / Support | Staff | Club | 33 | 18 | 528 | **D/U/S PASS** | 3 | 0 | 525 | `smn_herald_pact` |
| SMN | `primalist` (Primalist) | Damage / Damage | Staff | Club | 33 | 18 | 528 | **D/U/S PASS** | 3 | 0 | 525 | `smn_primalist_surge` |
| THF | `bandit` (Bandit) | Damage / Damage | Dagger | Sword | 36 | 82 | 562 | **D/U/S PASS** | 3 | 0 | 559 | `thf_bandit_opening` |
| THF | `phantom` (Phantom) | Tank / Tank | Dagger | Katana | 32 | 86 | 512 | **D/U/S PASS** | 3 | 0 | 509 | `thf_phantom_shadow` |
| THF | `trickster` (Trickster) | Support / Support | Dagger | Sword | 36 | 82 | 562 | **D/U/S PASS** | 3 | 0 | 559 | `thf_pass_blame` |
| WAR | `berserker` (Berserker) | Damage / Damage | Great Axe | Axe | 28 | 163 | 448 | **D/U/S PASS** | 6 | 0 | 442 | `war_bloodlust_surge` |
| WAR | `commander` (Commander) | Support / Support | Great Axe | Sword | 32 | 159 | 498 | **D/U/S PASS** | 3 | 0 | 495 | `war_tactical_breach` |
| WAR | `spartan` (Spartan) | Tank / Tank | Polearm | — | 14 | 177 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `war_spartan_grit` |
| WHM | `bishop` (Bishop) | Healer / Healer | Club | Staff | 33 | 26 | 528 | **D/U/S PASS** | 7 | 0 | 521 | `whm_solace_mend` |
| WHM | `valkyrie` (Valkyrie) | Support / Support | Polearm | — | 14 | 45 | 224 | **D/U/S PASS** | 3 | 0 | 221 | `whm_valkyrie_wingmate` |
| WHM | `zealot` (Zealot) | Damage / Damage | Staff | — | 17 | 42 | 272 | **D/U/S PASS** | 3 | 0 | 269 | `whm_zealot_sanctify` |
