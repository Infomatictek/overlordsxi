# SoulspireXI — 66-Soul Functional Health Matrix (full-66-repair-pass-v3)

- **Generated:** `2026-11-21T09:53:56.424300+00:00`
- **Summary:** **PASS:** `42` | **FAIL:** `12` | **BLOCKED:** `12` (Total: `66`)

## Baseline Comparison (`nov21-pre-repair-baseline` → `full-66-repair-pass-v3`)
- **Regressions (PASS → FAIL/BLOCKED):** `2`
- **Fixes (FAIL/BLOCKED → PASS):** `40`
- **Remaining Failures:** `11`

| Job | Soul | Role | Overall | Init | Core | WS | Target | Res/CD | Pet | Heal/Sup | Clean | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| BLM | Astromancer | Damage | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (892) did not reach 1000 before encounter ended (33.0s). |
| BLM | Channeler | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| BLM | Necromancer | Tank | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | PASS | NOT APPLICABLE | PASS | Player peak TP (0) did not reach 1000 before encounter ended (1.0s). |
| BLU | Azure Bastion | Tank | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| BLU | Magus | Healer | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| BLU | Warmage | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| BRD | Adventurer | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| BRD | Minstrel | Tank | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| BRD | Musician | Support | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | PASS | PASS | Player peak TP (0) did not reach 1000 before encounter ended (0.0s). |
| BST | Alpha Warden | Tank | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | OK |
| BST | Beastspeaker | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | OK |
| BST | Untamed | Damage | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | PASS | NOT APPLICABLE | PASS | Player peak TP (715) did not reach 1000 before encounter ended (21.0s). |
| COR | Buccaneer | Tank | **FAIL** | PASS | PASS | FAIL | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Zero weapon skills confirmed despite reaching 2216 TP. |
| COR | Flintlock | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| COR | Gambler | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| DNC | Bladewheel | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| DNC | Mirage Sentinel | Tank | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (810) did not reach 1000 before encounter ended (42.0s). |
| DNC | Vampire | Healer | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| DRG | Lancer | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| DRG | Skyborn | Tank | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| DRG | Wyvernheart | Healer | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | OK |
| DRK | Dreadnought | Tank | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (858) did not reach 1000 before encounter ended (17.0s). |
| DRK | Reaper | Damage | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (588) did not reach 1000 before encounter ended (16.0s). |
| DRK | Scourge | Support | **FAIL** | PASS | FAIL | PASS | PASS | PASS | NOT APPLICABLE | FAIL | PASS | No engine-confirmed core Soul ability or spell executed.; Support Soul had no confirmed ac |
| GEO | Diviner | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| GEO | Terramancer | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| GEO | Verdant | Healer | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| MNK | Black Belt | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| MNK | Chi Weaver | Healer | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| MNK | Sensei | Tank | **FAIL** | PASS | PASS | FAIL | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Zero weapon skills confirmed despite reaching 2068 TP. |
| NIN | Kagemusha | Tank | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| NIN | Nightblade | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| NIN | Shinobi | Damage | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | PASS | NOT APPLICABLE | PASS | Player peak TP (870) did not reach 1000 before encounter ended (19.0s). |
| PLD | Defender | Tank | **BLOCKED** | BLOCKED | BLOCKED | BLOCKED | BLOCKED | BLOCKED | NOT APPLICABLE | NOT APPLICABLE | BLOCKED | No automated gauntlet runs recorded yet. |
| PLD | Oathbreaker | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| PLD | Templar | Healer | **FAIL** | PASS | PASS | FAIL | PASS | PASS | NOT APPLICABLE | PASS | PASS | Zero weapon skills confirmed despite reaching 1750 TP. |
| PUP | Animist | Healer | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | OK |
| PUP | Pugilist | Damage | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | PASS | NOT APPLICABLE | PASS | Player peak TP (920) did not reach 1000 before encounter ended (25.0s). |
| PUP | Vanguard | Tank | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | OK |
| RDM | Crimson Duelist | Tank | **FAIL** | PASS | PASS | FAIL | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Zero weapon skills confirmed despite reaching 1819 TP. |
| RDM | Royal Tactician | Support | **FAIL** | PASS | FAIL | PASS | PASS | PASS | NOT APPLICABLE | FAIL | PASS | No engine-confirmed core Soul ability or spell executed.; Support Soul had no confirmed ac |
| RDM | Scarlet Weaver | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| RNG | Arcane Archer | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| RNG | Huntsman | Tank | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | PASS | NOT APPLICABLE | PASS | Player peak TP (985) did not reach 1000 before encounter ended (17.0s). |
| RNG | Sniper | Damage | **FAIL** | PASS | FAIL | FAIL | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | No engine-confirmed core Soul ability or spell executed.; Zero weapon skills confirmed des |
| RUN | Inquisitor | Tank | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| RUN | Lifebinder | Healer | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| RUN | Spellblade | Damage | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (846) did not reach 1000 before encounter ended (18.0s). |
| SAM | Imperial Archer | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| SAM | Ronin | Tank | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| SAM | Warlord | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| SCH | Archivist | Support | **FAIL** | PASS | PASS | FAIL | PASS | PASS | NOT APPLICABLE | PASS | PASS | Zero weapon skills confirmed despite reaching 1636 TP. |
| SCH | Medic | Healer | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | PASS | PASS | PASS | OK |
| SCH | Sage | Damage | **FAIL** | PASS | PASS | FAIL | PASS | PASS | PASS | NOT APPLICABLE | PASS | Zero weapon skills confirmed despite reaching 1837 TP. |
| SMN | Celestial | Healer | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| SMN | Herald | Support | **FAIL** | PASS | PASS | FAIL | PASS | PASS | PASS | PASS | PASS | Zero weapon skills confirmed despite reaching 1779 TP. |
| SMN | Primalist | Damage | **FAIL** | PASS | PASS | FAIL | PASS | PASS | PASS | NOT APPLICABLE | PASS | Zero weapon skills confirmed despite reaching 1681 TP. |
| THF | Bandit | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| THF | Phantom | Tank | **FAIL** | PASS | PASS | FAIL | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Zero weapon skills confirmed despite reaching 1590 TP. |
| THF | Trickster | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| WAR | Berserker | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| WAR | Commander | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| WAR | Spartan | Tank | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| WHM | Bishop | Healer | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| WHM | Valkyrie | Support | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| WHM | Zealot | Damage | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
