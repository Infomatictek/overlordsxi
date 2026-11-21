# SoulspireXI — 66-Soul WS Talent Coverage Matrix

Generated from `modules/custom/data/ws_eligibility_manifest.json` and `modules/custom/data/ws_talent_contracts.json`.
Coverage is measured strictly against **approved eligible weapons** (excluded weapon families generate **zero** talent definitions).

## Aggregate Coverage Summary

| Metric | Value |
|---|---|
| Canonical Souls Audited | 66 / 66 |
| Total Eligible Soul × WS Combinations | 1,476 |
| Excluded Base-Job Equipable Combinations | 4,143 (**73.73% reduction**) |
| Estimated Talent Definitions Avoided | **49,716** |
| Total Compiled Talent Contracts | 23,427 |
| Reusable Effect Taxonomy Types | 22 |
| Machine-Readable Contract Coverage | **100.0%** |
| LuaJIT Runtime & Role-Guardrail Verified | **100.0%** |
| Live `xi_test` Combat Gauntlet Validation | `NOT EXERCISED (instrumentation & Autoparser contracts ready)` |

### Branch Distribution

| Branch | Contract Count |
|---|---|
| `damage` | 5,832 |
| `evolution` | 99 |
| `skillchain` | 5,832 |
| `soul` | 5,832 |
| `utility` | 5,832 |

## Per-Soul Coverage Matrix (All 66 Canonical Souls)

| Job | Soul | Role / Tier | Primary | Secondary | Elig WS | Excl WS | Contracts | Non-SC | Soul Mechanic Hook | Live Gauntlet |
|---|---|---|---|---|---:|---:|---:|---:|---|---|
| BLM | `astromancer` (Astromancer) | Damage / Damage | Staff | — | 17 | 60 | 272 | 204 | `blm_astromancer_celestial` | NOT EXERCISED |
| BLM | `channeler` (Channeler) | Support / HybridSupport | Staff | — | 17 | 60 | 272 | 204 | `blm_channeler_resonance` | NOT EXERCISED |
| BLM | `necromancer` (Necromancer) | Tank / Tank | Scythe | — | 14 | 63 | 224 | 168 | `blm_necromancer_pact` | NOT EXERCISED |
| BLU | `azurebastion` (Azure Bastion) | Tank / Tank | Sword | Club | 34 | 0 | 530 | 398 | `blu_azure_carapace` | NOT EXERCISED |
| BLU | `magus` (Magus) | Healer / CombatHealer | Sword | Club | 34 | 0 | 535 | 403 | `blu_magus_mending` | NOT EXERCISED |
| BLU | `warmage` (Warmage) | Damage / Damage | Sword | Club | 34 | 0 | 530 | 398 | `blu_warmage_surge` | NOT EXERCISED |
| BRD | `adventurer` (Adventurer) | Damage / Damage | Dagger | Sword | 36 | 45 | 562 | 422 | `brd_cadence_encore` | NOT EXERCISED |
| BRD | `minstrel` (Minstrel) | Tank / Tank | Dagger | Sword | 36 | 45 | 562 | 422 | `brd_minstrel_anthem` | NOT EXERCISED |
| BRD | `musician` (Musician) | Support / HybridSupport | Dagger | Staff | 35 | 46 | 560 | 420 | `brd_musician_ballad` | NOT EXERCISED |
| BST | `alphawarden` (Alpha Warden) | Tank / Tank | Axe | — | 14 | 80 | 224 | 168 | `bst_alpha_pack` | NOT EXERCISED |
| BST | `beastspeaker` (Beastspeaker) | Support / Support | Axe | — | 14 | 80 | 224 | 168 | `bst_beastspeaker_rally` | NOT EXERCISED |
| BST | `untamed` (Untamed) | Damage / Damage | Great Axe | Axe | 28 | 66 | 448 | 336 | `bst_untamed_feral` | NOT EXERCISED |
| COR | `buccaneer` (Buccaneer) | Tank / Tank | Sword | — | 18 | 43 | 274 | 206 | `cor_buccaneer_grapeshot` | NOT EXERCISED |
| COR | `flintlock` (Flintlock) | Damage / Damage | Marksmanship | — | 13 | 48 | 208 | 156 | `cor_flintlock_deadeye` | NOT EXERCISED |
| COR | `gambler` (Gambler) | Support / Support | Marksmanship | Dagger | 31 | 30 | 496 | 372 | `cor_gambler_advantage` | NOT EXERCISED |
| DNC | `bladewheel` (Bladewheel) | Damage / Damage | Throwing | Dagger | 30 | 34 | 480 | 360 | `dnc_bladewheel_stance` | NOT EXERCISED |
| DNC | `miragesentinel` (Mirage Sentinel) | Tank / Tank | Dagger | — | 18 | 46 | 288 | 216 | `dnc_mirage_fandance` | NOT EXERCISED |
| DNC | `vampire` (Vampire) | Healer / CombatHealer | Dagger | Throwing | 30 | 34 | 480 | 360 | `dnc_vampire_feast` | NOT EXERCISED |
| DRG | `lancer` (Lancer) | Damage / Damage | Polearm | — | 14 | 69 | 224 | 168 | `drg_lancer_vault` | NOT EXERCISED |
| DRG | `skyborn` (Skyborn) | Tank / Tank | Polearm | — | 14 | 69 | 224 | 168 | `drg_skyborn_guard` | NOT EXERCISED |
| DRG | `wyvernheart` (Wyvernheart) | Healer / CombatHealer | Polearm | — | 14 | 69 | 224 | 168 | `drg_wyrmscale_breath` | NOT EXERCISED |
| DRK | `dreadnought` (Dreadnought) | Tank / Tank | Scythe | — | 14 | 107 | 224 | 168 | `drk_blood_pool` | NOT EXERCISED |
| DRK | `reaper` (Reaper) | Damage / Damage | Scythe | — | 14 | 107 | 224 | 168 | `drk_reaper_finality` | NOT EXERCISED |
| DRK | `scourge` (Scourge) | Support / Support | Scythe | — | 14 | 107 | 224 | 168 | `drk_scourge_curse` | NOT EXERCISED |
| GEO | `diviner` (Diviner) | Support / Support | Club | Staff | 33 | 18 | 528 | 396 | `geo_diviner_meridian` | NOT EXERCISED |
| GEO | `terramancer` (Terramancer) | Damage / Damage | Club | Staff | 33 | 18 | 528 | 396 | `geo_terramancer_fault` | NOT EXERCISED |
| GEO | `verdant` (Verdant) | Healer / Healer | Club | Staff | 33 | 18 | 528 | 396 | `geo_verdant_canopy` | NOT EXERCISED |
| MNK | `blackbelt` (Black Belt) | Damage / Damage | Hand-to-Hand | — | 16 | 45 | 250 | 190 | `mnk_impetus_chain` | NOT EXERCISED |
| MNK | `chiweaver` (Chi Weaver) | Healer / Healer | Hand-to-Hand | — | 16 | 45 | 250 | 190 | `mnk_chi_harmony` | NOT EXERCISED |
| MNK | `sensei` (Sensei) | Tank / Tank | Staff | — | 17 | 44 | 272 | 204 | `mnk_dojo_riposte` | NOT EXERCISED |
| NIN | `kagemusha` (Kagemusha) | Tank / Tank | Katana | — | 14 | 118 | 224 | 168 | `nin_kagemusha_shadows` | NOT EXERCISED |
| NIN | `kurogane` (Shinobi) | Damage / Damage | Katana | — | 14 | 118 | 224 | 168 | `nin_kurogane_clone_sync` | NOT EXERCISED |
| NIN | `nightblade` (Nightblade) | Support / Support | Katana | — | 14 | 118 | 224 | 168 | `nin_nightblade_seal` | NOT EXERCISED |
| PLD | `defender` (Defender) | Tank / Tank | Club | Sword | 34 | 63 | 533 | 401 | `pld_zeal_nova` | NOT EXERCISED |
| PLD | `oathbreaker` (Oathbreaker) | Damage / Damage | Great Sword | — | 14 | 83 | 224 | 168 | `pld_oathbreaker_reckoning` | NOT EXERCISED |
| PLD | `templar` (Templar) | Healer / CombatHealer | Club | — | 16 | 81 | 256 | 192 | `pld_beacon_light` | NOT EXERCISED |
| PUP | `animist` (Animist) | Healer / CombatHealer | Hand-to-Hand | — | 16 | 46 | 250 | 190 | `pup_animist_cells` | NOT EXERCISED |
| PUP | `pugilist` (Pugilist) | Damage / Damage | Hand-to-Hand | — | 16 | 46 | 250 | 190 | `pup_pugilist_tandem` | NOT EXERCISED |
| PUP | `vanguard` (Vanguard) | Tank / Tank | Hand-to-Hand | — | 16 | 46 | 250 | 190 | `pup_vanguard_bulwark` | NOT EXERCISED |
| RDM | `crimsonduelist` (Crimson Duelist) | Tank / Tank | Sword | — | 18 | 74 | 279 | 211 | `rdm_crimson_flow` | NOT EXERCISED |
| RDM | `royaltactician` (Royal Tactician) | Support / Support | Sword | — | 18 | 74 | 279 | 211 | `rdm_tactical_enfeeble` | NOT EXERCISED |
| RDM | `scarletweaver` (Scarlet Weaver) | Damage / Damage | Sword | — | 18 | 74 | 279 | 211 | `rdm_scarlet_weave` | NOT EXERCISED |
| RNG | `arcanearcher` (Arcane Archer) | Support / Support | Archery | — | 11 | 91 | 176 | 132 | `rng_arcane_attune` | NOT EXERCISED |
| RNG | `huntsman` (Huntsman) | Tank / Tank | Archery | Marksmanship | 24 | 78 | 384 | 288 | `rng_huntsman_ration` | NOT EXERCISED |
| RNG | `sniper` (Sniper) | Damage / Damage | Marksmanship | — | 13 | 89 | 208 | 156 | `rng_sniper_sightline` | NOT EXERCISED |
| RUN | `inquisitor` (Inquisitor) | Tank / Tank | Great Sword | — | 14 | 62 | 224 | 168 | `run_inquisitor_riposte` | NOT EXERCISED |
| RUN | `lifebinder` (Lifebinder) | Healer / Healer | Great Sword | — | 14 | 62 | 224 | 168 | `run_lifebinder_lifetap` | NOT EXERCISED |
| RUN | `spellblade` (Spellblade) | Damage / Damage | Great Sword | — | 14 | 62 | 224 | 168 | `run_spellblade_conduction` | NOT EXERCISED |
| SAM | `imperialarcher` (Imperial Archer) | Support / Support | Great Katana | Archery | 25 | 78 | 400 | 300 | `sam_drawn_oisoya` | NOT EXERCISED |
| SAM | `ronin` (Ronin) | Tank / Tank | Great Katana | — | 14 | 89 | 224 | 168 | `sam_ronin_stagger` | NOT EXERCISED |
| SAM | `warlord` (Warlord) | Support / HybridSupport | Great Katana | — | 14 | 89 | 224 | 168 | `sam_ashura_edge` | NOT EXERCISED |
| SCH | `archivist` (Archivist) | Support / Support | Staff | Club | 33 | 30 | 528 | 396 | `sch_archivist_tome` | NOT EXERCISED |
| SCH | `medic` (Medic) | Healer / Healer | Club | Staff | 33 | 30 | 528 | 396 | `sch_medic_eos` | NOT EXERCISED |
| SCH | `sage` (Sage) | Damage / Damage | Staff | Club | 33 | 30 | 528 | 396 | `sch_sage_helix` | NOT EXERCISED |
| SMN | `celestial` (Celestial) | Healer / Healer | Staff | Club | 33 | 18 | 528 | 396 | `smn_celestial_starlight` | NOT EXERCISED |
| SMN | `herald` (Herald) | Support / Support | Staff | Club | 33 | 18 | 528 | 396 | `smn_herald_pact` | NOT EXERCISED |
| SMN | `primalist` (Primalist) | Damage / Damage | Staff | Club | 33 | 18 | 528 | 396 | `smn_primalist_surge` | NOT EXERCISED |
| THF | `bandit` (Bandit) | Damage / Damage | Dagger | Sword | 36 | 82 | 562 | 422 | `thf_bandit_opening` | NOT EXERCISED |
| THF | `phantom` (Phantom) | Tank / Tank | Dagger | Katana | 32 | 86 | 512 | 384 | `thf_phantom_shadow` | NOT EXERCISED |
| THF | `trickster` (Trickster) | Support / Support | Dagger | Sword | 36 | 82 | 562 | 422 | `thf_pass_blame` | NOT EXERCISED |
| WAR | `berserker` (Berserker) | Damage / Damage | Great Axe | Axe | 28 | 163 | 448 | 336 | `war_bloodlust_surge` | NOT EXERCISED |
| WAR | `commander` (Commander) | Support / Support | Great Axe | Sword | 32 | 159 | 498 | 374 | `war_tactical_breach` | NOT EXERCISED |
| WAR | `spartan` (Spartan) | Tank / Tank | Polearm | — | 14 | 177 | 224 | 168 | `war_spartan_grit` | NOT EXERCISED |
| WHM | `bishop` (Bishop) | Healer / Healer | Club | Staff | 33 | 26 | 528 | 396 | `whm_solace_mend` | NOT EXERCISED |
| WHM | `valkyrie` (Valkyrie) | Support / Support | Polearm | — | 14 | 45 | 224 | 168 | `whm_valkyrie_wingmate` | NOT EXERCISED |
| WHM | `zealot` (Zealot) | Damage / Damage | Staff | — | 17 | 42 | 272 | 204 | `whm_zealot_sanctify` | NOT EXERCISED |
