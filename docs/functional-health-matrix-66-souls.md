# SoulspireXI — 66-Soul × 4-Level Functional Health Matrix (cert-4level-264-final)

- **Generated:** `2026-11-21T10:34:14.833487+00:00`
- **Latest-Run Summary:** **PASS:** `50` | **FAIL:** `4` | **BLOCKED:** `12` (Total: `66`)
- **4-Level Certification Evaluations:** `228 / 264` PASS
- **Per-Level Breakdown:** Lv.10: 65P/1F/0B | Lv.30: 55P/1F/10B | Lv.50: 56P/1F/9B | Lv.75: 52P/3F/11B
- **Server Ability Registry Audit:** `720` unique (`624` core + `105` custom - `9` overlapping ID overrides)

## Baseline Comparison (`full-66-repair-pass-v3` → `cert-4level-264-final`)
- **Regressions (PASS → FAIL/BLOCKED):** `7`
- **Fixes (FAIL/BLOCKED → PASS):** `13` (Previously BLOCKED → PASS: `6`)
- **Remaining Failures:** `3`

| Job | Soul | Role | Lv10 | Lv30 | Lv50 | Lv75 | Cov% | Overall | Init | Core | WS | Target | Res/CD | Pet | Heal/Sup | Clean | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| BLM | Astromancer | Damage | PASS | PASS | BLOCKED | BLOCKED | 39.4% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (722) did not reach 1000 before encounter ended (23.0s). |
| BLM | Channeler | Support | PASS | PASS | PASS | BLOCKED | 51.9% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | PASS | PASS | Player peak TP (820) did not reach 1000 before encounter ended (19.0s). |
| BLM | Necromancer | Tank | PASS | BLOCKED | BLOCKED | BLOCKED | 26.6% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | PASS | NOT APPLICABLE | PASS | Player peak TP (538) did not reach 1000 before encounter ended (9.0s). |
| BLU | Azure Bastion | Tank | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| BLU | Magus | Healer | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| BLU | Warmage | Damage | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| BRD | Adventurer | Damage | PASS | PASS | BLOCKED | PASS | 85.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| BRD | Minstrel | Tank | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| BRD | Musician | Support | PASS | BLOCKED | BLOCKED | BLOCKED | 55.8% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | PASS | PASS | Player peak TP (665) did not reach 1000 before encounter ended (10.0s). |
| BST | Alpha Warden | Tank | PASS | PASS | PASS | PASS | 89.3% | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | OK |
| BST | Beastspeaker | Support | PASS | PASS | PASS | PASS | 89.1% | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | OK |
| BST | Untamed | Damage | PASS | PASS | PASS | PASS | 76.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | OK |
| COR | Buccaneer | Tank | PASS | PASS | PASS | PASS | 81.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| COR | Flintlock | Damage | PASS | BLOCKED | PASS | BLOCKED | 75.7% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (542) did not reach 1000 before encounter ended (8.0s). |
| COR | Gambler | Support | PASS | PASS | PASS | PASS | 86.3% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| DNC | Bladewheel | Damage | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| DNC | Mirage Sentinel | Tank | PASS | PASS | PASS | PASS | 68.7% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| DNC | Vampire | Healer | PASS | PASS | PASS | PASS | 72.7% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| DRG | Lancer | Damage | PASS | PASS | PASS | BLOCKED | 59.6% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (580) did not reach 1000 before encounter ended (6.0s). |
| DRG | Skyborn | Tank | PASS | PASS | PASS | PASS | 92.2% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| DRG | Wyvernheart | Healer | PASS | PASS | PASS | PASS | 84.3% | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | OK |
| DRK | Dreadnought | Tank | PASS | PASS | PASS | PASS | 90.5% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| DRK | Reaper | Damage | PASS | PASS | BLOCKED | BLOCKED | 35.9% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (601) did not reach 1000 before encounter ended (8.0s). |
| DRK | Scourge | Support | PASS | BLOCKED | PASS | BLOCKED | 43.9% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | PASS | PASS | Player peak TP (635) did not reach 1000 before encounter ended (11.0s). |
| GEO | Diviner | Support | PASS | PASS | PASS | PASS | 84.6% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| GEO | Terramancer | Damage | PASS | BLOCKED | BLOCKED | PASS | 64.6% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (502) did not reach 1000 before encounter ended (11.0s). |
| GEO | Verdant | Healer | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| MNK | Black Belt | Damage | PASS | PASS | PASS | PASS | 96.9% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| MNK | Chi Weaver | Healer | PASS | PASS | PASS | PASS | 96.4% | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| MNK | Sensei | Tank | PASS | PASS | PASS | PASS | 69.8% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| NIN | Kagemusha | Tank | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| NIN | Nightblade | Support | PASS | BLOCKED | BLOCKED | PASS | 72.5% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| NIN | Shinobi | Damage | PASS | BLOCKED | PASS | FAIL | 53.0% | **FAIL** | PASS | PASS | FAIL | PASS | PASS | PASS | NOT APPLICABLE | PASS | Zero weapon skills confirmed despite reaching 2296 TP. |
| PLD | Defender | Tank | PASS | PASS | PASS | PASS | 95.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| PLD | Oathbreaker | Damage | PASS | PASS | PASS | PASS | 57.4% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| PLD | Templar | Healer | PASS | PASS | PASS | PASS | 60.1% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| PUP | Animist | Healer | PASS | PASS | PASS | PASS | 51.2% | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | OK |
| PUP | Pugilist | Damage | PASS | PASS | PASS | PASS | 51.2% | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | OK |
| PUP | Vanguard | Tank | PASS | PASS | PASS | PASS | 51.2% | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | OK |
| RDM | Crimson Duelist | Tank | PASS | PASS | PASS | PASS | 81.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| RDM | Royal Tactician | Support | PASS | BLOCKED | BLOCKED | FAIL | 48.4% | **FAIL** | PASS | PASS | FAIL | PASS | PASS | NOT APPLICABLE | PASS | PASS | Zero weapon skills confirmed despite reaching 1126 TP. |
| RDM | Scarlet Weaver | Damage | PASS | PASS | PASS | PASS | 62.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| RNG | Arcane Archer | Support | PASS | PASS | PASS | PASS | 72.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| RNG | Huntsman | Tank | PASS | PASS | PASS | PASS | 77.1% | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | OK |
| RNG | Sniper | Damage | FAIL | FAIL | PASS | FAIL | 53.3% | **FAIL** | PASS | PASS | FAIL | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Zero weapon skills confirmed despite reaching 1360 TP. |
| RUN | Inquisitor | Tank | PASS | PASS | PASS | PASS | 86.1% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| RUN | Lifebinder | Healer | PASS | PASS | PASS | PASS | 91.7% | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| RUN | Spellblade | Damage | PASS | BLOCKED | FAIL | PASS | 83.3% | **FAIL** | PASS | PASS | FAIL | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Zero weapon skills confirmed despite reaching 1015 TP. |
| SAM | Imperial Archer | Support | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| SAM | Ronin | Tank | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| SAM | Warlord | Support | PASS | PASS | PASS | PASS | 92.1% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| SCH | Archivist | Support | PASS | PASS | PASS | BLOCKED | 74.2% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | PASS | PASS | Player peak TP (722) did not reach 1000 before encounter ended (23.0s). |
| SCH | Medic | Healer | PASS | PASS | PASS | PASS | 75.0% | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | PASS | PASS | PASS | OK |
| SCH | Sage | Damage | PASS | PASS | PASS | BLOCKED | 80.0% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | PASS | NOT APPLICABLE | PASS | Player peak TP (702) did not reach 1000 before encounter ended (21.0s). |
| SMN | Celestial | Healer | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| SMN | Herald | Support | PASS | PASS | PASS | PASS | 48.1% | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | PASS | PASS | OK |
| SMN | Primalist | Damage | PASS | PASS | PASS | PASS | 55.9% | **PASS** | PASS | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | OK |
| THF | Bandit | Damage | PASS | PASS | PASS | PASS | 87.2% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| THF | Phantom | Tank | PASS | PASS | PASS | PASS | 74.5% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| THF | Trickster | Support | PASS | PASS | PASS | PASS | 84.6% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| WAR | Berserker | Damage | PASS | BLOCKED | BLOCKED | BLOCKED | 66.8% | **BLOCKED** | PASS | PASS | BLOCKED | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | Player peak TP (433) did not reach 1000 before encounter ended (4.0s). |
| WAR | Commander | Support | PASS | PASS | PASS | PASS | 87.9% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| WAR | Spartan | Tank | PASS | PASS | PASS | PASS | 89.1% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
| WHM | Bishop | Healer | PASS | PASS | PASS | PASS | 56.5% | **PASS** | PASS | PASS | NOT APPLICABLE | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| WHM | Valkyrie | Support | PASS | PASS | PASS | PASS | 76.2% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | PASS | PASS | OK |
| WHM | Zealot | Damage | PASS | PASS | PASS | PASS | 100.0% | **PASS** | PASS | PASS | PASS | PASS | PASS | NOT APPLICABLE | NOT APPLICABLE | PASS | OK |
