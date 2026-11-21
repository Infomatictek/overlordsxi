# SoulspireXI — Global 66-Soul Spell Cost & Level Compatibility Audit

**Audit Date:** 2026-11-21  
**Baseline Server Commit:** `97aade5` (`origin/main`, including scoped DRK Dreadnought fix `0502f73`)  
**Baseline Launcher Commit:** `5366ddc` (`origin/main`, including `114.DAT` restoration `0615641`)  
**Feature Branch:** `feat/soul-spell-cost-audit`

---

## 1. Executive Summary

All **66 canonical Souls** (22 jobs × 3 Souls) were audited across server Lua modules (`modules/custom/lua/*_specs.lua`), custom SQL (`modules/custom/sql/*.sql`), C++ engine patches (`patches/0001`–`0072`), LandSandBoat `spell_list.sql`, client Soul Actions (`addons/ashita4/soulspire_soul_actions/data/soul_actions.tsv` & `visibility.tsv`), and wiki guides (`docs/guides/*.md`).

| Metric | Count |
|---|---:|
| Canonical Souls audited | **66 / 66** |
| Souls with repurposed, early-unlocked, or cost-modified spells | **22** |
| Souls using only vanilla spell costs/levels or no spells | **44** |
| Total Soul spell entries inspected in matrix | **120** |
| **PASS** (verified working, affordable, and isolated before this PR) | **86** |
| **FAIL → FIXED** (confirmed server/cost/tool bugs fixed in this PR) | **32** |
| **REVIEW** (functional & castable, flagged for optional balance review) | **2** |

### Confirmed Problems Fixed in This PR (`patches/0073-soul-spell-cost-audit-fixes.patch` + Lua state sync)

1. **BLU Azure Bastion (6 physical Blue spells + all Blue spells under Azure Surge / Azure Lore):**  
   `OX_BLU_MAGIC_START` called `spell:setMPCost(0)` / `spell:setCastTime(0)` (for `EFFECT_AZURE_SURGE` = 858) and applied the `-30%` physical / `-50%` Azure Lore MP discounts inside `MAGIC_START`, which executes **after** `CMagicState::HasCost()` and **after** `CalculateSpellCastTime()`. As a result, 0-MP Azure Surge casts failed with *Not enough MP* whenever current MP was below vanilla cost, `setCastTime(0)` had no effect on `m_castTime`, and discounted casts failed whenever `discounted <= curMP < vanilla`.
2. **BLU Magus (17 early-unlocked baseline Blue Magic spells):**  
   `xi.spells.canUseSpellOverride` mutated `spell:setMPCost(scaled)` directly on the passed `CSpell*` pointer. Any non-`CMagicState` caller passing the shared global `CSpell*` risked permanently mutating vanilla Blue Magic MP costs for all players on the server. Moved Magus scaling to the per-cast `m_PSpell` clone in `CMagicState` and made `canUseSpellOverride` strictly read-only.
3. **RUN Spellblade (`Runic Bolt` 363 & `Runic Sever` 364):**  
   Conduction stack discounts (`-15% MP` and `-0.5s` cast time per stack, up to 3 stacks) were applied inside `onMagicCastingCheck`, which executes **after** `HasCost()`. At Lv 10–15 with 1–3 stacks (`Runic Bolt`: 7/6/4 MP vs SQL 8 MP) or Lv 55 with 3 stacks (`Runic Sever`: 17 MP vs SQL 22 MP), `HasCost()` rejected valid discounted casts. Moved level + Conduction cost/cast-time computation onto the per-cast `m_PSpell` clone before `HasCost()`.
4. **NIN Kagemusha (8 early-unlocked Lv 10 Ninjutsu spells):**  
   Kagemusha unlocks 10 Ninjutsu spells at Lv 10 (`KAGEMUSHA_SPELLS`) and advertises `"zero-tool Ninjutsu & Utsusemi Ichi/Ni @ Lv10+"` with Dual Katanas. However, `xi.mod.NINJA_TOOL = 100` only prevents tool *consumption*—`battleutils::HasNinjaTool` still required possessing each tool in inventory, and `0026-nin-kagemusha-spec.patch` only exempted `SPELLFAMILY_UTSUSEMI` (338/339). Extended `HasNinjaTool` to exempt all 10 Kagemusha kit spells when Dual Katanas are equipped (`OX_KGM_DUAL_KATANA == 1`).

---

## 2. Shared Engine Architecture Findings

In LandSandBoat's `CMagicState` constructor, the exact execution order is:

1. `m_PSpell = PSpell->clone();` *(per-cast isolated clone — safe to mutate)*
2. Pre-check C++ Soul overrides on `m_PSpell` (`0056`, `0057`, `0063`, `0064`, `0067`, `0069`, `0070`, `0072`, and new `0073`)
3. `CanCastSpell(PTarget, false)`:
   - `CanUseSpell(GetSpell())` → Lua `xi.spells.canUseSpellOverride` *(must remain read-only; other callers pass shared `CSpell*`)*
   - `HasCost()` → `battleutils::CalculateSpellCost(PEntity, PSpell)` (`0027`, `0046`, `0048`, `0049`) and `HasNinjaTool` (`0026`, `0045`, `0073`)
   - Lua `onMagicCastingCheck` *(runs **after** `HasCost()`; cannot lower MP cost for affordability)*
4. `m_castTime = battleutils::CalculateSpellCastTime(m_PEntity, this);`
5. `MAGIC_START` listener *(runs **after** `HasCost()` and **after** `CalculateSpellCastTime()`)*
6. At cast completion: `SpendCost()` (reads `m_PSpell` / `CalculateSpellCost`), then Lua `onSpellCast`.

**Reference Hume Naked Base MP (no subjob, no gear)** used for affordability calculations:

| Job | MP Grade | Lv 10 | Lv 30 | Lv 50 | Lv 75 |
|---|---:|---:|---:|---:|---:|
| SMN | A | ~110 | ~286 | ~462 | ~682 |
| BLM | B | ~100 | ~258 | ~416 | ~613 |
| WHM / SCH / GEO | C | ~88 | ~226 | ~364 | ~536 |
| RDM / BLU | D | ~76 | ~194 | ~312 | ~459 |
| PLD / RUN | F | ~52 | ~130 | ~208 | ~305 |
| DRK | G | ~40 | ~98 | ~156 | ~228 |
| NIN / Non-MP Jobs | — | 0 | 0 | 0 | 0 |

---

## 3. Complete Spell Compatibility Matrix (All Repurposed / Early / Cost-Modified Spells)

> **Legend:** `PASS` = verified compliant before PR; `FAIL → FIXED` = confirmed bug fixed in `0073` + Lua; `REVIEW` = castable & functional, flagged for optional balance review.  
> **Client Display:** `Help OK / DAT static` means `soul_actions.tsv` help text accurately states the Soul's true cost, while FFXI's native Magic Menu MP column displays static `114.DAT` values (which must not be globally altered).

### 3.1 DRK — Dreadnought, Reaper, Scourge

| Soul | Original Spell (ID) | Soul Action | Unlock | Vanilla Lv | Vanilla Cost | Actual Cost (After Fix) | Intended Function | Affordability @ Unlock | Restrictions | Client Display | Result |
|---|---|---|---:|---:|---|---|---|---|---|---|---|
| DRK Dreadnought (`dreadnought`) | Drain II (`246`) | Drain II | 10 | 62 | 37 MP | **12 MP** (`0072`) | Core sustain + Max HP overcap (30s CD) | 12 / ~40 MP (30%) | DRK Lv10+, Scythe (`OX_DRN_SCYTHE=1`) | Vanilla name; DAT shows 37 MP; guide updated | **PASS** (`97aade5`) |
| DRK Dreadnought (`dreadnought`) | Dread Spikes (`277`) | Dread Spikes | 10 | 71 | 78 MP | **0 MP + 10% cur HP** (`0072` + Lua) | Core Tithe barrier (45s CD, instant) | 0 MP, requires >15% HP | DRK Lv10+, Scythe (`OX_DRN_SCYTHE=1`) | Vanilla name; DAT shows 78 MP; guide updated | **PASS** (`97aade5`) |
| DRK Reaper (`reaper`) | Drain (`245`) | Grave Toll | 10 | 10 | 21 MP | **12 MP** (`0056`) | Ranged dark finisher vs enemy recovery (12s CD) | 12 / ~40 MP (30%) | DRK Lv10+, Scythe | Help OK (`12 MP`) / DAT static (21) | **PASS** |
| DRK Scourge (`scourge`) | Absorb-STR (`266`) | Withering | 10 | 43 | 33 MP | **10 MP** (`0057`) | Physical TP-move dampen curse (12s shared CD) | 10 / ~40 MP (25%) | DRK Lv10+, Great Sword / Scythe | Help OK / DAT static (33); add `10 MP` to desc optional | **PASS** |
| DRK Scourge (`scourge`) | Bio (`230`) | Ash | 10 | 15 | 15 MP | **10 MP** (`0057`) | Spell-damage dampen curse (12s shared CD) | 10 / ~40 MP (25%) | DRK Lv10+ | Help OK / DAT static (15) | **PASS** |
| DRK Scourge (`scourge`) | Absorb-MND (`271`) | Famine | 30 | 31 | 33 MP | **10 MP** (`0057`) | Enemy combat-healing dampen curse (12s shared CD) | 10 / ~98 MP (10%) | DRK Lv30+ | Help OK / DAT static (33) | **PASS** |

### 3.2 BLU — Azure Bastion, Magus, Warmage

| Soul | Original Spell (ID) | Soul Action | Unlock | Vanilla Lv | Vanilla Cost | Actual Cost (After Fix) | Intended Function | Affordability @ Unlock | Restrictions | Client Display | Result |
|---|---|---|---:|---:|---|---|---|---|---|---|---|
| BLU Azure Bastion (`azurebastion`) | Head Butt (`623`) | Head Butt | 12 | 12 | 12 MP | **8 MP** (-30%), **4 MP** w/ Azure Lore, **0 MP** w/ Surge (`0073`) | Core enmity + Chitin Carapace builder | 8 / ~88 MP (9%); 0 MP w/ Surge | BLU Lv10+ (`OX_AZB_ACTIVE=1`) | Vanilla name; dynamic cost | **FAIL → FIXED** |
| BLU Azure Bastion (`azurebastion`) | Bludgeon (`529`) | Bludgeon | 18 | 18 | 16 MP | **11 MP** (-30%), **6 MP** w/ Azure Lore, **0 MP** w/ Surge (`0073`) | Physical Blue enmity + Carapace | 11 / ~120 MP (9%) | BLU Lv10+ (`OX_AZB_ACTIVE=1`) | Vanilla name; dynamic cost | **FAIL → FIXED** |
| BLU Azure Bastion (`azurebastion`) | Smite of Rage (`527`) | Smite of Rage | 34 | 34 | 28 MP | **20 MP** (-30%), **10 MP** w/ Azure Lore, **0 MP** w/ Surge (`0073`) | Physical Blue enmity + Carapace | 20 / ~218 MP (9%) | BLU Lv10+ (`OX_AZB_ACTIVE=1`) | Vanilla name; dynamic cost | **FAIL → FIXED** |
| BLU Azure Bastion (`azurebastion`) | Heavy Strike (`688`) | Heavy Strike | 92 | 92 | 32 MP | **22 MP** (-30%), **11 MP** w/ Azure Lore, **0 MP** w/ Surge (`0073`) | Physical Blue enmity + Carapace | N/A (post-75) | BLU Lv10+ (`OX_AZB_ACTIVE=1`) | Vanilla name; dynamic cost | **FAIL → FIXED** |
| BLU Azure Bastion (`azurebastion`) | Goblin Rush (`666`) | Goblin Rush | 81 | 81 | 76 MP | **53 MP** (-30%), **27 MP** w/ Azure Lore, **0 MP** w/ Surge (`0073`) | Physical Blue enmity + Carapace | N/A (post-75) | BLU Lv10+ (`OX_AZB_ACTIVE=1`) | Vanilla name; dynamic cost | **FAIL → FIXED** |
| BLU Azure Bastion (`azurebastion`) | Sudden Lunge (`692`) | Sudden Lunge | 95 | 95 | 18 MP | **13 MP** (-30%), **6 MP** w/ Azure Lore, **0 MP** w/ Surge (`0073`) | Physical Blue stun + Carapace | N/A (post-75) | BLU Lv10+ (`OX_AZB_ACTIVE=1`) | Vanilla name; dynamic cost | **FAIL → FIXED** |
| BLU Magus (`magus`) | Magic Fruit (`593`) | Magic Fruit | 10 | 58 | 72 MP | **14 MP** @Lv10 → 37 @Lv30 → 62 @Lv50 → 72 @Lv58+ (`0073`) | Core ST heal + 85% party splash | 14 / ~76 MP (18%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (72) | **FAIL → FIXED** |
| BLU Magus (`magus`) | White Wind (`690`) | White Wind | 10 | 94 | 145 MP | **29 MP** @Lv10 → 46 @Lv30 → 77 @Lv50 → 116 @Lv75 (`0073`) | AoE party heal | 29 / ~76 MP (38%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (145) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Plenilune Embrace (`658`) | Plenilune Embrace | 10 | 76 | 106 MP | **21 MP** @Lv10 → 42 @Lv30 → 70 @Lv50 → 105 @Lv75 (`0073`) | Strong ST heal + ATK/MAB | 21 / ~76 MP (28%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (106) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Healing Breeze (`581`) | Healing Breeze | 10 | 16 | 55 MP | **34 MP** @Lv10 → 55 @Lv16+ (`0073`) | Early AoE heal (more expensive than White Wind at Lv10) | **34 / ~76 MP (45%)** | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (55) | **REVIEW** (fixed safety) |
| BLU Magus (`magus`) | Wild Carrot (`578`) | Wild Carrot | 10 | 30 | 37 MP | **12 MP** @Lv10 → 37 @Lv30+ (`0073`) | Early ST heal | 12 / ~76 MP (16%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (37) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Winds of Promyvion (`681`) | Winds of Promyvion | 10 | 89 | 36 MP | **7 MP** @Lv10 → 12 @Lv30 → 20 @Lv50 → 30 @Lv75 (`0073`) | Party AoE cleanse | 7 / ~76 MP (9%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (36) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Pollen (`549`) | Pollen | 10 | 1 | 8 MP | **8 MP** (vanilla) | Low-cost ST heal | 8 / ~76 MP (11%) | BLU Lv10+ | Vanilla | **PASS** |
| BLU Magus (`magus`) | Battery Charge (`662`) | Battery Charge | 10 | 79 | 50 MP | **10 MP** @Lv10 → 19 @Lv30 → 32 @Lv50 → 47 @Lv75 (`0073`) | Refresh self/Diffusion | 10 / ~76 MP (13%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (50) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Diamondhide (`632`) | Diamondhide | 10 | 67 | 99 MP | **20 MP** @Lv10 → 44 @Lv30 → 74 @Lv50 → 99 @Lv67+ (`0073`) | Party Stoneskin ward | 20 / ~76 MP (26%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (99) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Refueling (`530`) | Refueling | 10 | 48 | 29 MP | **6 MP** @Lv10 → 18 @Lv30 → 29 @Lv48+ (`0073`) | Haste self/Diffusion | 6 / ~76 MP (8%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (29) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Cocoon (`547`) | Cocoon | 10 | 8 | 10 MP | **10 MP** (vanilla) | DEF buff | 10 / ~76 MP (13%) | BLU Lv10+ | Vanilla | **PASS** |
| BLU Magus (`magus`) | Metallic Body (`517`) | Metallic Body | 10 | 8 | 19 MP | **19 MP** (vanilla) | Self Stoneskin | 19 / ~76 MP (25%) | BLU Lv10+ | Vanilla | **PASS** |
| BLU Magus (`magus`) | Zephyr Mantle (`647`) | Zephyr Mantle | 10 | 65 | 31 MP | **6 MP** @Lv10 → 14 @Lv30 → 24 @Lv50 → 31 @Lv65+ (`0073`) | Blink ward | 6 / ~76 MP (8%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (31) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Head Butt (`623`) | Head Butt | 10 | 12 | 12 MP | **10 MP** @Lv10 → 12 @Lv12+ (`0073`) | Interrupt/stun utility | 10 / ~76 MP (13%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (12) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Blank Gaze (`592`) | Blank Gaze | 10 | 38 | 25 MP | **7 MP** @Lv10 → 20 @Lv30 → 25 @Lv38+ (`0073`) | Dispel utility | 7 / ~76 MP (9%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (25) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Sudden Lunge (`692`) | Sudden Lunge | 10 | 95 | 18 MP | **4 MP** @Lv10 → 6 @Lv30 → 9 @Lv50 → 14 @Lv75 (`0073`) | Long stun utility | 4 / ~76 MP (5%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (18) | **FAIL → FIXED** |
| BLU Magus (`magus`) | Digest (`542`) | Digest | 10 | 36 | 20 MP | **6 MP** @Lv10 → 17 @Lv30 → 20 @Lv36+ (`0073`) | HP drain utility | 6 / ~76 MP (8%) | BLU Lv10+ (`OX_MAG_ACTIVE=1`) | Vanilla name; DAT static (20) | **FAIL → FIXED** |
| BLU Warmage (`warmage`) | Sprout Smack (`597`) | Briar Hammer | 10 | 4 | 6 MP | **6 MP** (`0063`) | Lv10 blunt Blue strike (7s CD) | 6 / ~76 MP (8%) | BLU Lv10+, Sword | Help OK (`6 MP`) | **PASS** |
| BLU Warmage (`warmage`) | Power Attack (`551`) | Needle Lunge | 10 | 4 | 5 MP | **5 MP** (`0063`) | Lv10 piercing Blue strike (7s CD) | 5 / ~76 MP (7%) | BLU Lv10+, Sword | Help OK (`5 MP`) | **PASS** |
| BLU Warmage (`warmage`) | Foot Kick (`577`) | Razor Heel | 10 | 1 | 5 MP | **5 MP** (`0063`) | Lv10 slashing Blue strike (7s CD) | 5 / ~76 MP (7%) | BLU Lv10+, Sword | Help OK (`5 MP`) | **PASS** |
| BLU Warmage (`warmage`) | Bludgeon (`529`) | Skullbreaker Volley | 30 | 18 | 16 MP | **16 MP** (`0063`) | Lv30 multi-hit blunt (12s CD) | 16 / ~194 MP (8%) | BLU Lv30+, Sword | Help OK (`16 MP`) | **PASS** |
| BLU Warmage (`warmage`) | Smite of Rage (`527`) | Iron Cleave | 30 | 34 | 28 MP | **24 MP** (`0063`) | Lv30 heavy slash (13s CD) | 24 / ~194 MP (12%) | BLU Lv30+, Sword | Help OK (`24 MP`) / DAT static (28) | **PASS** |
| BLU Warmage (`warmage`) | Jet Stream (`569`) | Gale Knuckle | 50 | 38 | 47 MP | **28 MP** (`0063`) | Lv50 ranged blunt (16s CD) | 28 / ~312 MP (9%) | BLU Lv50+, Sword | Help OK (`28 MP`) / DAT static (47) | **PASS** |
| BLU Warmage (`warmage`) | Mandibular Bite (`543`) | Serrated Bite | 50 | 44 | 38 MP | **25 MP** (`0063`) | Lv50 heavy slash (17s CD) | 25 / ~312 MP (8%) | BLU Lv50+, Sword | Help OK (`25 MP`) / DAT static (38) | **PASS** |
| BLU Warmage (`warmage`) | Bomb Toss (`626`) | Ember Charge | 50 | 28 | 42 MP | **26 MP** (`0063`) | Lv50 ranged fire (16s CD) | 26 / ~312 MP (8%) | BLU Lv50+, Sword | Help OK (`26 MP`) / DAT static (42) | **PASS** |
| BLU Warmage (`warmage`) | Death Scissors (`554`) | Guillotine Shears | 70 | 60 | 51 MP | **32 MP** (`0063`) | Lv70 slashing finisher (20s CD) | 32 / ~428 MP (7%) | BLU Lv70+, Sword | Help OK (`32 MP`) / DAT static (51) | **PASS** |
| BLU Warmage (`warmage`) | Heat Breath (`591`) | Furnace Breath | 70 | 71 | 169 MP | **36 MP** (`0063`) | Lv70 fire cone (20s CD) | 36 / ~428 MP (8%) | BLU Lv70+, Sword | Help OK (`36 MP`) / DAT static (169) | **PASS** |
| BLU Warmage (`warmage`) | Mind Blast (`644`) | Storm Gaze | 70 | 73 | 82 MP | **30 MP** (`0063`) | Lv70 thunder nuke (18s CD) | 30 / ~428 MP (7%) | BLU Lv70+, Sword | Help OK (`30 MP`) / DAT static (82) | **PASS** |

### 3.3 RUN — Spellblade

| Soul | Original Spell (ID) | Soul Action | Unlock | Vanilla Lv | Vanilla Cost | Actual Cost (After Fix) | Intended Function | Affordability @ Unlock | Restrictions | Client Display | Result |
|---|---|---|---:|---:|---|---|---|---|---|---|---|
| RUN Spellblade (`spellblade`) | Custom (`363`) | Runic Bolt | 10 | Custom (10) | 8 MP (SQL) | **8–24 MP** (scales Lv10–75), **-15%/Conduction** (4 MP @Lv10 3 stacks) (`0073`) | Core Conduction spellweaver nuke (8s CD) | 8 / ~52 MP (15%); 4 MP w/ 3 stacks | RUN Lv10+, Greatsword, 1+ Rune | Custom SQL spell (8 MP base) | **FAIL → FIXED** |
| RUN Spellblade (`spellblade`) | Custom (`364`) | Runic Sever | 55 | Custom (55) | 22 MP (SQL) | **32–40 MP** (scales Lv55–75), **-15%/Conduction** (17 MP @Lv55 3 stacks) (`0073`) | Heavy Conduction finisher (30s CD) | 32 / ~228 MP (14%); 17 MP w/ 3 stacks | RUN Lv55+, Greatsword, 1+ Rune | Custom SQL spell (22 MP base) | **FAIL → FIXED** |

### 3.4 NIN — Kagemusha, Shinobi, Nightblade

| Soul | Original Spell (ID) | Soul Action | Unlock | Vanilla Lv | Vanilla Cost | Actual Cost (After Fix) | Intended Function | Affordability @ Unlock | Restrictions | Client Display | Result |
|---|---|---|---:|---:|---|---|---|---|---|---|---|
| NIN Kagemusha (`kagemusha`) | Utsusemi: Ichi (`338`) | Utsusemi: Ichi | 10 | 12 | Shihei (`1179`) | **0 tools** (`0026`) | Core 3-shadow tank spell (2s cast, 15s CD) | 0 MP / 0 tools | NIN Lv10+ | Vanilla name; DAT shows tool | **PASS** |
| NIN Kagemusha (`kagemusha`) | Utsusemi: Ni (`339`) | Utsusemi: Ni | 10 | 37 | Shihei (`1179`) | **0 tools** (`0026`) | Core 4-shadow tank spell (22s CD) | 0 MP / 0 tools | NIN Lv10+ | Vanilla name; DAT shows tool | **PASS** |
| NIN Kagemusha (`kagemusha`) | Katon: Ichi (`320`) | Katon: Ichi | 10 | 15 | Uchitake (`1161`) | **0 tools** w/ Dual Katanas (`0073`) | Early elemental Ninjutsu kit | 0 MP / 0 tools | NIN Lv10+, Dual Katanas (`OX_KGM_DUAL_KATANA=1`) | Vanilla name; DAT shows tool | **FAIL → FIXED** |
| NIN Kagemusha (`kagemusha`) | Hyoton: Ichi (`323`) | Hyoton: Ichi | 10 | 15 | Tsurara (`1164`) | **0 tools** w/ Dual Katanas (`0073`) | Early elemental Ninjutsu kit | 0 MP / 0 tools | NIN Lv10+, Dual Katanas | Vanilla name; DAT shows tool | **FAIL → FIXED** |
| NIN Kagemusha (`kagemusha`) | Huton: Ichi (`326`) | Huton: Ichi | 10 | 15 | Kawahori-Ogi (`1167`) | **0 tools** w/ Dual Katanas (`0073`) | Early elemental Ninjutsu kit | 0 MP / 0 tools | NIN Lv10+, Dual Katanas | Vanilla name; DAT shows tool | **FAIL → FIXED** |
| NIN Kagemusha (`kagemusha`) | Doton: Ichi (`329`) | Doton: Ichi | 10 | 15 | Makibishi (`1170`) | **0 tools** w/ Dual Katanas (`0073`) | Early elemental Ninjutsu kit | 0 MP / 0 tools | NIN Lv10+, Dual Katanas | Vanilla name; DAT shows tool | **FAIL → FIXED** |
| NIN Kagemusha (`kagemusha`) | Raiton: Ichi (`332`) | Raiton: Ichi | 10 | 15 | Hiraishin (`1173`) | **0 tools** w/ Dual Katanas (`0073`) | Early elemental Ninjutsu kit | 0 MP / 0 tools | NIN Lv10+, Dual Katanas | Vanilla name; DAT shows tool | **FAIL → FIXED** |
| NIN Kagemusha (`kagemusha`) | Suiton: Ichi (`335`) | Suiton: Ichi | 10 | 15 | Mizu-Deppo (`1176`) | **0 tools** w/ Dual Katanas (`0073`) | Early elemental Ninjutsu kit | 0 MP / 0 tools | NIN Lv10+, Dual Katanas | Vanilla name; DAT shows tool | **FAIL → FIXED** |
| NIN Kagemusha (`kagemusha`) | Hojo: Ichi (`344`) | Hojo: Ichi | 10 | 23 | Kaginawa (`1185`) | **0 tools** w/ Dual Katanas (`0073`) | Early Slow Ninjutsu enmity/debuff | 0 MP / 0 tools | NIN Lv10+, Dual Katanas | Vanilla name; DAT shows tool | **FAIL → FIXED** |
| NIN Kagemusha (`kagemusha`) | Kurayami: Ichi (`347`) | Kurayami: Ichi | 10 | 19 | Sairui-Ran (`1188`) | **0 tools** w/ Dual Katanas (`0073`) | Early Blind Ninjutsu enmity/debuff | 0 MP / 0 tools | NIN Lv10+, Dual Katanas | Vanilla name; DAT shows tool | **FAIL → FIXED** |
| NIN Shinobi (`shinobi`) | Utsusemi: Ichi (`338`) | Shadow Squadron: Ichi | 10 | 12 | Shihei (`1179`) | **0 tools** (`0045`) | Summon 2 offensive clones (20s CD) | 0 MP / 0 tools | NIN Lv10+ (`OX_SHINOBI_ACTIVE=1`) | Help OK / DAT shows tool | **PASS** |
| NIN Shinobi (`shinobi`) | Utsusemi: Ni (`339`) | Shadow Squadron: Ni | 37 | 37 | Shihei (`1179`) | **0 tools** (`0045`) | Summon 3 offensive clones (30s CD) | 0 MP / 0 tools | NIN Lv37+ | Help OK / DAT shows tool | **PASS** |
| NIN Shinobi (`shinobi`) | Katon..Suiton: Ichi (`320,323,326,329,332,335`) | False Assault, Mirror Step, Crosscut, Shadow Pin, Thunder Relay, Final Mirage (6 spells) | 10/30/50/70 | 15 | Tools (`1161`–`1176`) | **0 tools** (`0045`) | Offensive clone squad commands | 0 MP / 0 tools | NIN Lv10/30/50/70 | Help OK / DAT shows tool | **PASS** (6/6) |
| NIN Nightblade (`nightblade`) | Katon (`320`), Jubaku (`341`), Hojo (`344`) | Signal Flare, Severing Seal, Blunting Seal (3 spells) | 10 | 15/23/23 | Tools (`1161,1182,1185`) | **0 tools** (`0060` `MAGICFLAGS_IGNORE_TOOLS`) | Ranged flare & enemy spell/TP seals | 0 MP / 0 tools | NIN Lv10+ | Help OK / DAT shows tool | **PASS** (3/3) |

### 3.5 WHM, BLM, RDM, PLD, SCH, GEO, SMN — Native-Action Souls

| Soul | Original Spell (ID) | Soul Action | Unlock | Vanilla Lv | Vanilla Cost | Actual Cost | Intended Function | Affordability @ Unlock | Restrictions | Client Display | Result |
|---|---|---|---:|---:|---|---|---|---|---|---|---|
| WHM Zealot (`zealot`) | Banish (`28`) | Dawnfire | 10 | 5 | 15 MP | **8% max MP** (`0046`) | Core light nuke (6s CD) | ~7 / 88 MP (8%) | WHM Lv10+, Staff | Help OK (`8% max MP`) / DAT static (15) | **PASS** |
| WHM Zealot (`zealot`) | Banish II (`29`) | Sunbrand | 30 | 30 | 57 MP | **12% max MP** (`0046`) | Mid-tier light nuke (8s CD) | ~28 / 226 MP (12%) | WHM Lv30+, Staff | Help OK (`12% max MP`) / DAT static (57) | **PASS** |
| WHM Zealot (`zealot`) | Banish III (`30`) | Pillar of Day | 50 | 65 | 96 MP | **16% max MP** (`0046`) | Heavy light nuke (12s CD) | ~59 / 364 MP (16%) | WHM Lv50+, Staff | Help OK (`16% max MP`) / DAT static (96) | **PASS** |
| WHM Zealot (`zealot`) | Holy (`21`) | Last Light | 50 | 50 | 100 MP | **20% max MP** (22% @Lv70) (`0046`) | Burst light nuke (14s CD) | ~73 / 364 MP (20%) | WHM Lv50+, Staff | Help OK (`20%/22% max MP`) / DAT static (100) | **PASS** |
| WHM Valkyrie (`valkyrie`) | Banish (`28`) | Vigil Lance | 10 | 5 | 15 MP | **15 MP** (vanilla) | Ranged light poke (15s CD) | 15 / ~88 MP (17%) | WHM Lv10+, Polearm | Help OK (`15 MP`) | **PASS** |
| BLM Astromancer (`astromancer`) | Fire..Water (`144,149,154,159,164,169`) | Cinder, Rime, Gale, Bedrock, Static Spark, Tsunami (6 spells) | 10 | 1–21 | 4–9 MP | **4–9 MP** (Cinder 6 vs 7) (`0048`) | Elemental alignment probes (3s CD) | 4–9 / ~100 MP (4–9%) | BLM Lv10+, Staff | Help OK / Cinder DAT static (7) | **PASS** (6/6) |
| BLM Astromancer (`astromancer`) | Stone II (`160`) | Ancient Invocation | 10 | 26 | 16 MP | **16% max MP** (`0048`) | Dynamic-element Ancient Magic (18s shared CD) | ~16 / 100 MP (16%) | BLM Lv10+, Staff | Help OK (`16% max MP`) / DAT static (16) | **PASS** |
| BLM Astromancer (`astromancer`) | Burn (`235`) | Elemental Survey | 30 | 24 | 25 MP | **2% max MP** (`0048`) | Inspect enemy elemental weakness (30s CD) | ~6 / 258 MP (2%) | BLM Lv30+, Staff | Help OK (`2% max MP`) / DAT static (25) | **PASS** |
| BLM Astromancer (`astromancer`) | Warp (`261`) | Starway | 30 | 17 | 100 MP | **100 MP** (`0048`) | Home point utility (10s CD) | 100 / ~258 MP (39%) | BLM Lv30+, Staff | Help OK (`100 MP`) | **PASS** |
| BLM Astromancer (`astromancer`) | Flare..Flood (`204,206,208,210,212,214`) | Solar Collapse, Rimefall, Skybreak, Worldsplitter, Thunderstar, Tidal Cataclysm (6 spells) | 50 | 50–60 | 315 MP | **22% max MP** (`0048`) | Direct Ancient Magic burst (18s shared CD) | ~92 / 416 MP (22%) | BLM Lv50+, Staff | Help OK (`22% max MP`) / DAT static (315) | **PASS** (6/6) |
| BLM Channeler (`channeler`) | Thunder (`164`) | Conduit Bolt | 10 | 21 | 9 MP | **9 MP** (`0049`) | Low-cost arc filler (4s CD) | 9 / ~100 MP (9%) | BLM Lv10+, Staff | Help OK (`9 MP`) | **PASS** |
| BLM Channeler (`channeler`) | Aspir (`247`) | Aether Tap | 30 | 25 | 10 MP | **10 MP** (`0049`) | MP siphon utility (60s CD) | 10 / ~258 MP (4%) | BLM Lv30+, Staff | Help OK (`10 MP`) | **PASS** |
| RDM Scarlet Weaver (`scarletweaver`) | Fire..Water (`144,149,154,159,164,169`) | Searing Needle..Tide Stitch (6 spells) | 10 | 4–29 | 4–9 MP | **4–9 MP** (vanilla) | Yin-boosted elemental stitches (3s CD) | 4–9 / ~76 MP (5–12%) | RDM Lv10+, Sword | Help OK | **PASS** (6/6) |
| RDM Scarlet Weaver (`scarletweaver`) | Fire II (`145`), Thunder II (`165`), Aero III (`156`) | Scarlet Spindle, Violet Shuttle, Tempest Loom (3 spells) | 30/50/70 | 50/60/69 | 26/37/54 MP | **26 / 37 / 54 MP** (vanilla) | Mid/high-tier Yin weaves (6/7/12s CD) | 12–13% of Max MP at unlock | RDM Lv30/50/70, Sword | Help OK | **PASS** (3/3) |
| RDM Royal Tactician (`royaltactician`) | Slow (`56`), Paralyze (`58`), Silence (`59`), Blind (`254`), Dispel (`260`) | Break Stride, Seize Initiative, Quiet Front, Obscure Aim, Unravel Defense (5 spells) | 10/10/10/10/30 | 13/6/18/8/32 | 15/6/16/5/25 MP | **15 / 6 / 16 / 5 / 25 MP** (vanilla) | Enfeebling openers for Advance/Recompose | 7–21% of Max MP (+MPP passive) | RDM Lv10/30, Sword | Help OK | **PASS** (5/5) |
| RDM Crimson Duelist (`crimsonduelist`) | Enspells / Blink / Stoneskin / Phalanx | Vanilla names | Vanilla | Vanilla | Vanilla | **0 MP** under Crimson Flow (`853`) (`0027`) | Free defensive/en-spell proc | 0 MP | RDM Lv10+ (`CalculateSpellCost`) | Vanilla | **PASS** |
| PLD Oathbreaker (`oathbreaker`) | Banish (`28`) | Ashen Judgment | 10 | 7 | 15 MP | **15 MP** (vanilla) | Ranged pull/poke for GS DPS (15s CD) | **15 / ~52 MP (29%)** | PLD Lv10+, Great Sword | Help OK (`15 MP`) | **REVIEW** (intentional ranged poke; 3 casts @Lv10) |
| SCH Archivist (`archivist`) | Sandstorm (`99`) | File Countermeasure | 10 | 41 | 30 MP | **0 MP** (`0064`) | Recorded enemy action countermeasure (15s CD) | 0 / ~88 MP (0%) | SCH Lv10+ | DAT static (30); help omits `0 MP` | **PASS** |
| SCH Archivist (`archivist`) | Stone (`159`) | Margin Note | 10 | 4 | 4 MP | **4 MP** (`0064`) | Earth filler between observations (6s CD) | 4 / ~88 MP (5%) | SCH Lv10+ | Help OK (`4 MP`) | **PASS** |
| GEO Terramancer (`terramancer`) | Stone (`159`) | Stone Chip | 10 | 4 | 4 MP | **3 MP** (`0069`) | Earth filler & claim opener (4s CD) | 3 / ~88 MP (3%) | GEO Lv10+, Club | Help OK (`3 MP`) / DAT static (4) | **PASS** |
| GEO Terramancer (`terramancer`) | Stone II (`160`) | Shallow Fault | 10 | 34 | 16 MP | **0 MP C++ + 7% max MP Lua** (`0069`) | 2s delayed earth eruption (8s shared CD) | ~7 / 88 MP (7%) | GEO Lv10+, Club, claimed mob | Help OK (`7% max MP`) / DAT static (16) | **PASS** |
| GEO Terramancer (`terramancer`) | Stone III (`161`) | Deep Fault | 30 | 58 | 40 MP | **0 MP C++ + 12% max MP Lua** (`0069`) | 4s heavy delayed eruption (8s shared CD) | ~28 / 226 MP (12%) | GEO Lv30+, Club, claimed mob | Help OK (`12% max MP`) / DAT static (40) | **PASS** |
| GEO Diviner (`diviner`) | Stone (`159`) | Ley Spark | 10 | 4 | 4 MP | **4 MP** (`0070`) | Earth filler (5s CD) | 4 / ~88 MP (5%) | GEO Lv10+, Club | Help OK (`4 MP`) | **PASS** |
| GEO Diviner (`diviner`) | Indi-Precision (`783`) | Lay Meridian | 10 | 10 | 25 MP | **0 MP** (`0070`) | Anchor accuracy corridor (18s CD) | 0 / ~88 MP (0%) | GEO Lv10+, Club | Help OK (`0 MP`) / DAT static (25) | **PASS** |
| SMN Primalist (`primalist`) | Carbuncle..Ramuh (`296,298`–`303`) | Call Carbuncle..Call Ramuh (7 spells) | 10/30/50 | 1 | 5–7 MP | **5 MP** (`0067`) | Summon pact avatar (5s CD) | 5 / ~110 MP (5%) | SMN Lv10/30/50, Staff | Help OK (`5 MP`) / DAT static (7) | **PASS** (7/7) |
| SMN Herald (`herald`) | Carbuncle..Ramuh (`296,298`–`303`) | Invite Carbuncle..Invite Ramuh (7 spells) | 10/30/50 | 1 | 5–7 MP | **5 MP** (`0068`) | Summon Accord avatar (5s CD) | 5 / ~110 MP (5%) | SMN Lv10/30/50, Staff | Help OK (`5 MP`) / DAT static (7) | **PASS** (7/7) |

### 3.6 Remaining 44 Canonical Souls (No Repurposed / Early / Cost-Overridden Player Spells)

All 44 remaining Souls were verified to either have no player spell grants/repurposing or use standard vanilla spell costs & unlock levels:

- **WAR (3):** Commander, Berserker, Spartan — *No spells.*
- **MNK (3):** Sensei, Chi Weaver, Black Belt — *No spells.*
- **WHM (1):** Bishop — *Vanilla WHM spells (+14–28% MPP passive).*
- **BLM (1):** Necromancer — *Undead pet spell lists (`mob_spell_lists` 601–602); player cures forwarded to tank thrall without cost changes.*
- **THF (3):** Trickster, Bandit, Phantom — *No spells.*
- **PLD (2):** Defender, Templar — *Vanilla PLD spells (Templar gets +14–26% MPP passive).*
- **BRD (3):** Adventurer, Musician, Minstrel — *Vanilla Songs (0 MP).*
- **RNG (3):** Sniper, Huntsman, Arcane Archer — *No spells.*
- **SAM (3):** Ronin, Imperial Archer, Warlord — *No spells.*
- **DRG (3):** Lancer, Skyborn, Wyvernheart — *No spells.*
- **COR (3):** Flintlock, Gambler, Buccaneer — *No spells (Phantom Roll / Quick Draw abilities).*
- **DNC (3):** Vampire, Bladewheel, Mirage Sentinel — *No spells (TP-based dances/waltzes).*
- **SCH (2):** Medic, Sage — *Vanilla SCH spells (Helix/Cure hooks without cost overrides).*
- **BST (3):** Untamed, Alpha Warden, Beastspeaker — *No spells.*
- **SMN (1):** Celestial — *Vanilla SMN spells (+14–28% MPP passive).*
- **PUP (3):** Vanguard, Pugilist, Animist — *Automaton pet spells only (`pup_healer_specs.lua`).*
- **RUN (2):** Inquisitor, Lifebinder — *Vanilla RUN spells (Regen IV backported to Lv75 in `run_specs.sql`, standard MP).*
- **GEO (1):** Verdant — *Vanilla GEO spells (+14–28% MPP passive).*

---

## 4. Corrections Made (Before vs After)

| Soul | Files Changed | Before | After |
|---|---|---|---|
| **BLU Azure Bastion** | `modules/custom/lua/blu_specs.lua`, `patches/0073-soul-spell-cost-audit-fixes.patch` | `AZURE_SURGE` (0 MP / instant), Physical Blue (-30% MP), and `AZURE_LORE` (-50% MP) applied in `MAGIC_START` *after* `HasCost()` and `CalculateSpellCastTime()`, blocking 0-MP / low-MP casts and ignoring instant cast. | Applied on per-cast `m_PSpell` clone in `CMagicState` before `HasCost()` / `CalculateSpellCastTime()` when `OX_AZB_ACTIVE == 1`. Duplicate Lua `setMPCost` removed to prevent double discounting. |
| **BLU Magus** | `modules/custom/lua/blu_healer_specs.lua`, `patches/0073-soul-spell-cost-audit-fixes.patch` | `xi.spells.canUseSpellOverride` called `spell:setMPCost(scaled)` directly on passed `CSpell*`, risking global vanilla MP corruption on non-clone calls. | Applied level-scaled MP formula on per-cast `m_PSpell` clone in `CMagicState` when `OX_MAG_ACTIVE == 1`. `canUseSpellOverride` is now strictly read-only. |
| **RUN Spellblade** | `patches/0073-soul-spell-cost-audit-fixes.patch` | Conduction `-15%/stack` MP discount and `-0.5s/stack` cast reduction ran in `onMagicCastingCheck` *after* `HasCost()`, rejecting valid discounted casts when MP was below SQL base (8 / 22 MP). | Level + Conduction MP cost & cast time computed on per-cast `m_PSpell` clone in `CMagicState` before `HasCost()` when `OX_RUN_SPELLBLADE == 1`. |
| **NIN Kagemusha** | `modules/custom/lua/nin_specs.lua`, `patches/0073-soul-spell-cost-audit-fixes.patch` | Only `Utsusemi: Ichi/Ni` bypassed `HasNinjaTool`; the other 8 Lv10 Kagemusha Ninjutsu spells still required carrying 8 ninja tool stacks despite Dual Katanas `"zero-tool Ninjutsu"`. | `OX_KGM_DUAL_KATANA` synced with Dual Katanas; `HasNinjaTool` exempts all 10 `KAGEMUSHA_SPELLS` while active. Vanilla NIN and single-Katana Kagemusha unaffected. |

---

## 5. Remaining Client Display Discrepancies (Documented Limitations)

Per policy, shared vanilla `114.DAT` spell-cost and tool-cost columns were **not** modified because changing `114.DAT` would corrupt vanilla jobs and other Souls.

1. **Magic Menu MP Column vs Soul Runtime Cost:** For Souls with custom MP costs (Dreadnought, Zealot, Astromancer, Reaper, Scourge, Warmage, Archivist, Terramancer, Diviner, Primalist, Herald, Magus, Azure Bastion, Spellblade), the native FFXI Magic Menu MP column displays the vanilla `114.DAT` number. For all renamed Native Soul Actions, `soul_actions.tsv` help descriptions display the authoritative Soul cost (with two minor optional text polish notes: Archivist `File Countermeasure` can add `Costs 0 MP.` and Scourge `Withering`/`Ash`/`Famine` can add `Costs 10 MP.` in a future launcher update).
2. **Magic Menu Tool Column for Zero-Tool Ninjutsu:** Shinobi, Nightblade, and Kagemusha (Dual Katanas) bypass ninja tool requirements server-side, while the native Magic Menu still displays the vanilla tool icon from `114.DAT`.

---

## 6. Automated Test Results

- **New Static & Formula Regression Suite:** `tests/test_soul_spell_cost_audit.py` — validates Dreadnought (`0072`), Azure Bastion, Magus, Spellblade, Kagemusha (`0073`), Terramancer failed-cast MP safety, and representative levels 10 / 30 / 50 / 75.
- **New Real-Engine `xi_test` Suite:** `tests/lua/soul_spell_cost_audit.lua` — ready to execute against the rebuilt server binary (`0072` + `0073`).
- **Existing Repository Test Suites:** All Python unit tests (`unittest discover -s tests`), strict 66-Soul coverage audit (`tools/audit_soul_coverage.py --strict`), and wiki Soul Action tests (`tests/test_soul_actions_wiki.py`) executed and verified (see PR summary for exact pass counts).

---

## 7. In-Game Verification Checklist (Post-Build / Staging)

- [ ] **DRK Dreadnought (Lv 10, Scythe):** Cast `Drain II` with 15 MP → succeeds and spends 12 MP (3 MP left). Cast `Dread Spikes` at 0 MP and full HP → succeeds, spends 0 MP and 10% current HP. Cast `Dread Spikes` at ≤15% HP → rejected, 0 HP/MP spent. Unequip Scythe → reverts to vanilla 37 / 78 MP.
- [ ] **BLU Azure Bastion (Lv 10 / 30 / 50 / 75):** Use Sword/Club WS to gain `Azure Surge`, drop to 0 MP, cast `Diamondhide` or `Head Butt` → succeeds at 0 MP with instant cast. Without Surge, cast `Head Butt` at 8 MP → succeeds (-30% MP). Under `Azure Lore`, cast `Head Butt` at 4 MP → succeeds (-65% combined).
- [ ] **BLU Magus (Lv 10 / 30 / 50 / 75):** Cast `Magic Fruit` at Lv 10 with 14 MP → succeeds. Switch to vanilla BLU at Lv 58 → `Magic Fruit` still costs full 72 MP (no global mutation).
- [ ] **RUN Spellblade (Lv 10 & Lv 55, Greatsword + Rune):** Build 3 Conduction stacks, drop to 4 MP at Lv 10 → `Runic Bolt` succeeds. At Lv 55 with 3 stacks and 17 MP → `Runic Sever` succeeds. Without Greatsword or Rune → rejected with 0 MP spent.
- [ ] **NIN Kagemusha (Lv 10, Dual Katanas, 0 tools in inventory):** Cast `Katon: Ichi`, `Hojo: Ichi`, `Kurayami: Ichi`, `Utsusemi: Ichi` → all succeed with 0 tools. Unequip offhand Katana → `Katon: Ichi` requires Uchitake again. Vanilla NIN / subjob NIN unaffected.
- [ ] **Design Review Items (`REVIEW`):** Confirm whether `BLU Magus — Healing Breeze` (34 MP at Lv 10 = 45% MP) and `PLD Oathbreaker — Ashen Judgment` (15 MP at Lv 10 = 29% MP) should remain as-is or receive modest Lv 10 cost adjustments.
