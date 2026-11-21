# SoulspireXI — Soul Weapon Configuration System

## 1. Phase 1 Audit — Confirmed Root Cause & Architecture

### 1.1 Empirical Reproduction: `Rin` (`BRD10/WAR5`, Soul: `Adventurer`)

Inspected live DB (`chars` / `char_stats` / `char_vars` / `char_equip` / `char_inventory`) and executed authoritative headless LandSandBoat tests (`xi_test` against `xidb_staging`) reproducing `Rin`'s exact setup:

- **Character state**: `BRD` Lv.10 / `WAR` Lv.5, `OX_SPEC_BRD = 1` (`adventurer`), carrying `wind_knife_+1` (ID `20568`, Dagger, `slot=3`, all jobs) and `onion_sword` (ID `16534`, Sword, `slot=3`, BRD-equippable).
- **Verified Server Behavior (Before Changes)**:
  - `charutils::BuildingCharTraitsTable` + patch `0010` (`GetExtraSpecTraits`) already grants `TRAIT_DUAL_WIELD` (`18`) to `BRD10/WAR5` Adventurer and sets bit `18` in `PChar->m_TraitList`.
  - `GP_SERV_COMMAND_COMMAND_DATA` (`0x0AC`) transmits `m_TraitList` with bit `18` set (`true`).
  - `charutils::EquipItem` / `charutils::EquipArmor` **accept** `wind_knife_+1` (`MAIN`) + `onion_sword` (`SUB`), set `PChar->m_dualWield = true`, apply `xi.mod.DUAL_WIELD = 10`, and execute real two-swing Dual Wield attack rounds (`hits=2` in 1 `0x028` action round, 154 TP).
- **Confirmed Primary Blocker — Client Layer (`FFXiMain.dll` + Ashita v4 Addons)**:
  - The retail FFXI client (`FFXiMain.dll`) does **not** use packet `0x0AC` trait bit `18` to gate offhand weapons in the Equipment menu or `/equip sub`. As documented in upstream LandSandBoat (`src/map/utils/charutils.cpp:3062`), the client restricts Sub-slot weapon selection to hardcoded vanilla Dual Wield jobs (`NIN`, `DNC`, `THF`, `BLU`, or `/NIN`, `/DNC`).
  - Because neither `BRD` (`10`) nor `WAR` (`1`) is in the client's vanilla Dual Wield job list, the native Equipment menu filters all 1H weapons out of the Sub slot and `/equip sub "Onion Sword"` is rejected locally by the client before any `0x050` packet is ever sent to the server.
  - Meanwhile, the Ashita v4 `crystalsocket` addon only had a one-off `buckler.lua` Sub-slot handler hardcoded to `WAR Spartan/Gladiator + 2H Polearm + Size-1 Shield`.
- **Confirmed Secondary Server Bugs Found During Audit**:
  1. **Missing Equipment Reconciliation on Soul Swap / Unsocket**: Switching `Rin` from `adventurer` to `musician` (or clearing the Soul) dropped `TRAIT_DUAL_WIELD` (`hasTrait(18) == false`), **yet `onion_sword` remained equipped in `SLOT_SUB` with `m_dualWield = true`** because `syncAbilitiesTable()` called `recalculateAbilitiesTable()` without calling `charutils::CheckValidEquipment()`.
  2. **Unrestricted Sub-Weapon Access**: Granting blanket `TRAIT_DUAL_WIELD` allowed BRD Adventurer to offhand non-whitelisted 1H weapon categories (e.g., Clubs like `ash_club_+1`) and lacked a reusable rule engine for Soul-specific pairings.
  3. **Login / Cross-Process Zoning Initialization Order**: Patch `0010` skips `OnTraitsTableBuilt` when `OX_SPEC_SYNCED == 0` during `charutils::LoadChar`, meaning any weapon permission stored solely in a local var set during `onGameIn` (such as `0030`'s `OX_POLEARM_BUCKLER`) was not yet initialized when `charutils::LoadEquip` ran.

### 1.2 LandSandBoat & SoulspireXI Equipment / Combat Architecture Audit

| Subsystem | Current Location | Existing Behavior | Required Work |
|---|---|---|---|
| Server equip pre-check | `src/map/utils/charutils.cpp` (`EquipItem`, L3049–3083) | Rejects non-grip `SLOT_SUB` weapons unless `PChar->hasTrait(TRAIT_DUAL_WIELD)` and 1H `SLOT_MAIN`. | Consult authoritative `luautils::EvaluateSoulWeaponPair` before vanilla fallback. |
| Server equip slot rules | `src/map/utils/charutils.cpp` (`EquipArmor`, L2081–2270) | Checks `getJobs()`, `getReqLvl()`, `getEquipSlotId() & (1 << equipSlotID)`, then switches on main weapon skill. Patch `0030` hardcodes WAR Polearm+Buckler. | Consult `EvaluateSoulWeaponPair` on both `SLOT_MAIN` (unequip incompatible `SUB`) and `SLOT_SUB` (allow/deny Soul pairings & set `m_dualWield`). |
| Server equip reconciliation | `src/map/utils/charutils.cpp` (`CheckValidEquipment`, L3200–3242) | Runs on delevel (`L4996`) and job change (`L1754`), **not** on Soul swap. | Expose `player:checkValidEquipment()` to Lua, consult `EvaluateSoulWeaponPair`, and call on Soul swap, clear, login, and level-down. |
| Equip packets | `0x050_equip_set.cpp`, `0x051_equipset_set.cpp` | Both route directly through `charutils::EquipItem`. | Automatically protected by `EquipItem`/`EquipArmor`; zero packet-spoof bypasses. |
| Attack rounds & DW swings | `src/map/attackround.cpp` (L51–80) | Adds `CreateAttacks(PSub, LEFTATTACK)` when `PSub && attacker->IsDualWielding()`. | Works natively for `dual_1h`. Phase 5 `dual_2h` requires configurable damage/TP/multi-attack budgets. |
| Delay & Haste | `src/map/entities/battle_entity.cpp` (`GetWeaponDelay`, L471–576) + patch `0044` | Sums `mainDelay + subDelay`, multiplies by `(1 - DUAL_WIELD/100)`, then applies unified SoulspireXI haste curve (`0044`). | Works natively for `dual_1h`. Phase 5 `dual_2h` requires configurable delay formula (`weighted_avg` / `sum_scaled`) to avoid 2x delay or broken TP scaling. |
| 2H Stat Bonuses | `battle_entity.cpp` (`STR` L1135, `ATT` L1193/1232, `ACC` L1548) | Checks `m_Weapons[SLOT_MAIN]->isTwoHanded()` for `TWOHAND_STR`, `TWO_HANDED_STR_ATTACK_MULTIPLIER`, `SMITE`, `TWO_HANDED_DEX_ACCURACY_MULTIPLIER`, `TWOHAND_ACC`, `TWOHAND_HASTE_ABILITY`. | Phase 5 `twohand_shield` / `dual_2h` need configurable opt-in scaling so 2H bonuses do not stack uncontrollably with shields or offhand 2H weapons. |
| Shield Blocking | `scripts/combat/physical_utilities.lua` + `soulspire_polearm_buckler.lua` | `canBlock` and `calculateBlockRate` inspect `SLOT_SUB` (`shield:isShield()`, `shield:getShieldSize()`) and `getSkillRank(xi.skill.SHIELD) > 0`. | Works for real shields in `SLOT_SUB` if the job has Shield skill rank > 0; Phase 5 `twohand_shield` must verify job Shield skill rank and configurable mitigation scaling. |
| Weapon Skills & Talents | `patches/0019`, `patches/0034`, `soulspire_ws_talents.lua`, `soulspire_ws_overrides.lua` | `BuildingCharWeaponSkills` inspects `SLOT_MAIN` skill and gates via `CanUseTalentWeaponskill`. | Preserved untouched; Soul weapon configs do not alter WS talent trees or spell authorization hooks. |
| Client Ashita v4 + `crystaljobs` | `soulspirexi-launcher/addons/ashita4/crystalsocket/`, `native/crystaljobs/` | `crystalsocket` already intercepts Equipment menu Sub-slot (`SUB_NATIVE_SLOT = 5`) and `/equip sub` to emit raw `0x050` packets (proven by `buckler.lua`). `crystaljobs.dll` has 23 verified signature-gated hooks for job labels & action visibility; **no** FFXiMain Sub-slot filter hook yet (requires Windows `FFXiMain.dll` disassembly). | Generalize `crystalsocket` with data-driven `weapon_config.lua` (zero per-frame scans, zero guessed native offsets, authoritative server validation). |

---

## 2. Phase 2 — Reusable Soul Weapon Configuration Schema

Authoritative server module: `modules/custom/lua/soulspire_weapon_config.lua` (`xi.soulspire.weaponConfig`).

Each Soul spec may declare an optional `weaponConfig` table (or register via `xi.soulspire.weaponConfig.register(jobId, specKey, cfg)`). Souls without a `weaponConfig` retain **100% vanilla LandSandBoat equipment behavior**.

```lua
weaponConfig = {
    -- Minimum effective main-job level required for this configuration (defaults to spec minLevel / 10).
    minLevel = 10,

    -- Optional explicit main-hand / offhand category whitelists.
    -- Categories:
    --   1H:      'dagger', 'sword', 'axe', 'katana', 'club', 'h2h'
    --   2H:      'great_sword', 'great_axe', 'scythe', 'polearm', 'great_katana', 'staff'
    --   Offhand: 'shield', 'buckler' (Size-1 shield), 'grip', 'none'
    mainWhitelist = { 'dagger', 'sword' },           -- optional
    subWhitelist  = { 'dagger', 'sword', 'shield' }, -- optional

    -- Explicit permitted (main, sub) pairings.
    pairings = {
        {
            main          = { 'dagger', 'sword' }, -- string or list of categories
            sub           = { 'dagger', 'sword' }, -- string or list of categories
            mode          = 'dual_1h',             -- 'dual_1h' | 'twohand_shield' | 'dual_2h' | 'vanilla'
            minLevel      = 10,                    -- optional per-pairing unlock level
            subShieldSize = nil,                   -- optional: { exact = 1 } or { max = 2 }
            mainItemIds   = nil,                   -- optional exact item ID whitelist for MAIN
            subItemIds    = nil,                   -- optional exact item ID whitelist for SUB
        },
    },

    -- When true, Soul-granted Dual Wield ONLY permits weapon pairings listed in `pairings`
    -- (native main/subjob Dual Wield such as /NIN or /DNC still follows vanilla rules).
    restrictSoulDualWieldToPairings = true,

    -- Whether standard vanilla 1H + Shield remains permitted alongside Soul pairings (default: true).
    allowVanillaShield = true,

    -- Optional Phase 3 combat balance overrides (inert unless explicitly enabled for advanced modes).
    combat = {
        -- dual_2h / twohand_shield configurable parameters (see Section 3).
    },
}
```

### Supported Configuration Examples (Not Universally Enabled)

| Example Pairing | `mode` | Status |
|---|---|---|
| `MAIN: Dagger \| SUB: Sword` / `MAIN: Sword \| SUB: Dagger` | `dual_1h` | **Enabled in Phase 4 for BRD Adventurer only** |
| `MAIN: Polearm \| SUB: Buckler (Size 1)` | `twohand_shield` | Existing WAR Spartan/Gladiator (`0030` + `buckler.lua`, preserved) |
| `MAIN: Great Sword \| SUB: Shield` | `twohand_shield` | Schema-supported; **Phase 5 (disabled until Phase 4 verified)** |
| `MAIN: Scythe \| SUB: Shield` | `twohand_shield` | Schema-supported; **Phase 5 (disabled until Phase 4 verified)** |
| `MAIN: Great Sword \| SUB: Great Sword` | `dual_2h` | Schema-supported; **Phase 5 (disabled until Phase 4 verified)** |
| `MAIN: Great Axe \| SUB: Great Axe` | `dual_2h` | Schema-supported; **Phase 5 (disabled until Phase 4 verified)** |

### Evaluation Contract (`C++ <-> Lua`)

`xi.soulspire.weaponConfig.evaluatePair(player, mainItem, subItem)` returns one integer status code:

- `0` (`VANILLA`): Active Soul has no `weaponConfig` (or character is below `minLevel` / wrong main job) -> execute stock LandSandBoat rules unchanged.
- `1` (`ALLOW_DUAL_WIELD`): Active Soul explicitly authorizes `(mainItem, subItem)` as a Dual Wield pair (`m_dualWield = true`).
- `2` (`ALLOW_SUB_NON_DW`): Active Soul explicitly authorizes `(mainItem, subItem)` as a non-DW offhand (`m_dualWield = false`, e.g., shield/buckler/grip).
- `-1` (`DENY`): Active Soul's `weaponConfig` rejects `(mainItem, subItem)` (e.g., BRD Adventurer without native DW trying to offhand a Club).

### Reconciliation & Persistence Guarantees

- **Soul swap / clear (`!spec`, Crystal Socket `0x11F`)**: `spec.refreshPlayer`, `spec.clear`, and `spec.onTraitsRebuild` invoke `weaponConfig.reconcileEquipment(player)` after trait rebuild -> invalid `SLOT_SUB` items are cleanly unequipped via `UnequipItem` (sending `0x050` removal, updating look, persisting `char_equip`, preserving inventory).
- **Level sync / delevel**: `charutils::CheckValidEquipment` evaluates `player:getMainLvl() >= minLevel` dynamically, automatically unequipping offhand gear if the player syncs below the Soul's unlock level.
- **Zoning / relogging**: `evaluatePair` reads the player's active `char_var` Soul spec directly rather than a deferred `onGameIn` local var, so `charutils::LoadEquip` persists valid Soul pairings across logins and cross-process zones while rejecting stale/invalid pairings.

---

## 3. Phase 3 — Combat Rules Specification

### 3.1 Dual One-Handed (`dual_1h`) — Active in Phase 4 (BRD Adventurer)
- **Attack rounds**: Standard LandSandBoat `CAttackRound` (`RIGHTATTACK` from `SLOT_MAIN`, `LEFTATTACK` from `SLOT_SUB` when `IsDualWielding()`).
- **Delay**: Standard `(mainDelay + subDelay) * (1 - DUAL_WIELD / 100) * unifiedHasteMultiplier`.
- **TP generation**: Standard LandSandBoat `GetWeaponDelay(true)` (combined DW delay reduced by `DUAL_WIELD`, unaffected by Haste) per hit.
- **Accuracy & Damage**: Standard main-hand (`slot=0`) and offhand (`slot=1`) skill, DEX accuracy, STR attack multiplier, and weapon damage.
- **Weapon Skills**: Preserves existing `SLOT_MAIN` WS selection, `soulspire_ws_talents.lua`, and `soulspire_ws_overrides.lua` untouched.

### 3.2 Dual Two-Handed (`dual_2h`) — Phase 5 Design Contract (NOT Enabled in Phase 4)
Do **not** execute two full-strength independent two-handed attack rounds or simply sum raw 2H damage. Every balance parameter must be opt-in per Soul under `weaponConfig.combat`:

- **Attack sequencing**: Single unified `CAttackRound` with 1 primary swing (`RIGHTATTACK`, `SLOT_MAIN`) + 1 offhand swing (`LEFTATTACK`, `SLOT_SUB`), capped to FFXI's 8-swing round limit.
- **Main-hand & offhand damage budgets**:
  - Configurable `mainDamageScale` (default proposal: `0.78`) and `subDamageScale` (default proposal: `0.55`) applied to weapon base damage / physical swing damage so total auto-attack output targets a controlled ~1.15–1.25x trade-off relative to single 2H + Grip (rather than 2.0x).
  - Suppress double-dipping of `TWO_HANDED_STR_ATTACK_MULTIPLIER` and `SMITE` on `SLOT_SUB` (offhand uses `ONE_HAND_OFF_HAND_STR_ATTACK_MULTIPLIER` by default unless configured).
- **Delay contribution**:
  - Configurable `delayMode = 'sum_scaled'` with `delayScale = 0.65` (e.g., two 480-delay Great Swords -> effective base delay `(480 + 480) * 0.65 = 624` before DW/haste, rather than an unusable 960 delay or a broken 480 single-weapon delay).
- **TP gain**:
  - Configurable `tpScale` (default proposal: `0.65`–`0.75` per swing) computed from effective delay so dual swings do not generate 2x WS frequency.
- **Accuracy**:
  - Main-hand retains `SLOT_MAIN` skill; offhand uses `SLOT_SUB` weapon skill with configurable `subAccuracyPenalty` (default proposal: `-15` ACC) and `ONE_HAND_OFF_HAND` DEX multiplier instead of 2H `0.75` DEX scaling.
- **Haste & Multi-Attack interaction**:
  - Unified attack-rate haste (`0044`) applies once to the combined round delay; `TWOHAND_HASTE_ABILITY` (Hasso) is disabled or scaled by `combat.allowHasso = false` while dual-wielding 2H.
  - Configurable `multiAttackPolicy = 'main_only'` (default) so Double/Triple/Quad Attack procs only roll on `SLOT_MAIN` (preventing 4–6 massive 2H hits per round).
- **Weapon Skills**:
  - `wsUsesMainOnly = true`: WS eligibility, animation, skill tree, and 4-tier talent scaling strictly use `SLOT_MAIN` (preserving `soulspire_ws_talents.lua` and `soulspire_ws_overrides.lua`).

### 3.3 Two-Handed + Shield (`twohand_shield`) — Phase 5 Design Contract (NOT Enabled in Phase 4)
- **Main-hand attack behavior**: Standard single-weapon `SLOT_MAIN` attack round (`m_dualWield = false`, zero offhand melee swings).
- **Shield block eligibility**:
  - Real equipped shield in `SLOT_SUB` uses `xi.combat.physical.canBlock` / `calculateBlockRate` / `getDamageReductionForBlock`.
  - Requires either native `getSkillRank(xi.skill.SHIELD) > 0` OR an explicit Soul-granted Shield skill floor (e.g., DRK/SAM/etc. without native Shield rank would otherwise fail `canBlock` at `physical_utilities.lua:1387`!).
  - Configurable `subShieldSize` (`{ exact = 1 }` for bucklers, `{ max = 2 }`, or unrestricted) and `combat.shieldBlockScale` / `combat.shieldMitigationScale`.
- **Defensive stats & Shield traits/abilities**:
  - Equipped shield naturally grants its item `DEF` and equip mods via `addEquipModifiers`.
  - Shield Bash, Shield Mastery, Sentinel, Reprisal, Palisade remain gated by job/Soul abilities and `getShieldSize() > 0` unless explicitly adjusted via `combat.allowShieldTraits`.
- **Two-handed weapon bonus adjustment**:
  - Configurable `combat.twoHandedStatScale` (default `1.0`; e.g., `0.80`–`0.90` for tank Souls wielding full Size-3/4 tower shields with a Great Sword/Scythe so 2H offensive scaling doesn't dominate 1H+Shield tanks). Never applied globally.

---

## 4. Phase 5 Engineering Requirements & Client Engine Limitations

### 4.1 Server Engineering Requirements for Phase 5
1. **Two-Handed + Shield (`twohand_shield`)**:
   - Promote WAR Spartan's `0030-polearm-buckler-equip.patch` into `soulspire_weapon_config.lua` (retaining identical Size-1 Buckler rules and virtual block fallback).
   - Add per-Soul Shield skill rank override hook (for jobs whose vanilla `SHIELD` rank is 0, e.g. DRK Scythe+Shield) and optional `twoHandedStatScale` / `shieldBlockScale` modifiers.
   - Add independent `xi_test` suites verifying equip, block rate, mitigation, stat adjustments, Soul swap unequip, and lockstyle persistence.
2. **Dual Two-Handed (`dual_2h`)**:
   - In `charutils::EquipArmor` and `charutils::CheckValidEquipment`, relax `PItem->getEquipSlotId() & (1 << SLOT_SUB)` **only** when `EvaluateSoulWeaponPair` returns `1` (`ALLOW_DUAL_WIELD`) and the item has `SLOT_MAIN` (`0x0001`) — avoiding any global `item_equipment` SQL or client DAT edits.
   - Implement configurable `combat` hooks in `CAttackRound`, `CAttack::ProcessDamage`, `CBattleEntity::GetWeaponDelay`, `CBattleEntity::ATT`, `CBattleEntity::ACC`, and `battleutils::GetTP`.
   - Gate behind an explicit `ENABLE_DUAL_2H` flag per Soul until client rendering is verified.

### 4.2 Explicitly Identified Client Rendering, Animation & Engine Limitations

1. **Client Offhand Filtering (`FFXiMain.dll` & Native `crystaljobs.dll` Hook #24)**:
   - Disassembly of supported `FFXiMain.dll` (`TS=0x6ae818b4`, `SizeOfImage=0xC17000`) confirmed that the native Sub-slot item menu (`0x1336CE` -> `0x21DDF0`) already lists `Slots & 0x0002` weapons and shields, and Shields (`Type == 5`) already bypass the Dual Wield check at `0x133CFF` (allowing WAR Spartan/Gladiator Polearm + Size-1 Buckler natively).
   - Both the native Equipment menu (controller & keyboard) and `/equip sub` route through `EquipMenu::TryEquipItem` (`0x133BD0`), which gates non-vanilla Dual Wield jobs at `RVA 0x133D56` (`push 0x8b`).
   - **Native Solution**: `crystaljobs.dll` Hook #24 (`PrologueDetour` at `0x133D56`, plus verified signatures for `0xEB5D0` `GetInventoryItem` and `0x15D210` `GetItemResource`) evaluates data-driven Soul rules synced via `CrystalJobsReplaceWeaponRules` (`CRYSTALJOBS_CAP_SOUL_SUB_WEAPON`). CrystalSocket's custom Sub-slot picker (`buckler.lua`, `##crystal_buckler`, `/equip sub` interception) has been removed; CrystalSocket handles Soul Crystal selection/management and one-shot native rule synchronization only.
   - Server patch `0073-soul-weapon-config.patch` + `soulspire_weapon_config.lua` remain 100% authoritative.
2. **Dual One-Handed (`dual_1h`) Animations**:
   - FFXI natively supports 1H models in `look.main` + `look.sub` and `0x028` `LEFTATTACK` swings. Visual confirmation on live BRD10/WAR5 is required in the manual checklist below to confirm clean stance/swing playback and lockstyle behavior.
3. **Two-Handed + Shield (`twohand_shield`) Animations**:
   - `look.main` (2H) + `look.sub` (Shield) renders on the client, as proven with WAR Spartan Polearm + Size-1 Buckler.
   - **Limitation**: 2H weapon animations grip with both hands; Size-2/3/4 shields clip visibly through the weapon shaft/left hand during idle and swing frames, and shield block animations can snap/blend awkwardly. Must be visually verified per weapon+shield size before enabling on additional Souls.
4. **Dual Two-Handed (`dual_2h`) Models & Animations (HARD CLIENT LIMITATION)**:
   - FFXI's client skeleton and ROM weapon model tables bind 2H weapon models to `look.main` with two-handed grip animations.
   - Sending a 2H weapon's `modelId` in `look.sub` has **unverified / likely broken client rendering**: the client may render an invisible offhand, resolve the wrong ROM sub-table model, or clip severely with a two-handed right-hand grip and no dedicated left-hand 2H swing animation for `AttackAnimation::LEFTATTACK`.
   - **Rule**: Do **not** claim `dual_2h` is playable or visually working based on server-side acceptance alone. Live Windows client verification (and if needed, dedicated model/animation mitigation or lockstyle/visual fallback) is mandatory before enabling `dual_2h` on any Soul.

---

## 5. Manual In-Game Verification Checklist (Phase 4 — BRD Adventurer)

Run on live Windows Ashita v4 client with character `Rin` (`BRD10/WAR5`, Soul: `Adventurer`) carrying `Wind Knife +1` (Dagger), `Onion Sword` (Sword), `Ash Club +1` (Club), and `Metal Slime Shield` (Shield):

- [ ] **Equip Dagger + Sword via Native Equipment Menu (Controller)**: Equip `Wind Knife +1` in `Main`. Highlight `Sub` in the native FFXI Equipment menu and press controller Confirm (`Enter`). Confirm the original FFXI Sub list opens directly (no custom CrystalSocket popup) showing `Onion Sword` and `Metal Slime Shield`. Select `Onion Sword`; confirm it equips into `Sub`.
- [ ] **Equip via Native `/equip sub` Command**: Unequip `Sub`, then run `/equip sub "Onion Sword"` -> confirms native client equips into `Sub` without CrystalSocket command interception. Run `/equip sub none` -> confirms unequips `Sub`.
- [ ] **Swap Orientation (Sword + Dagger)**: Equip `Onion Sword` in `Main`, then equip `Wind Knife +1` in `Sub` via the native Equipment menu -> confirms both equip cleanly.
- [ ] **Unauthorized Weapon Rejection**: Attempt to equip `Ash Club +1` in `Sub` via the native Equipment menu, `/equip sub`, or raw `0x050` -> confirms native hook and server reject it.
- [ ] **Main-Hand Swap Reconciliation**: While wearing `Wind Knife +1` + `Onion Sword`, equip `Ash Club +1` in `Main` -> confirms `Onion Sword` in `Sub` is automatically unequipped.
- [ ] **Combat Verification**: Engage a mob with `Wind Knife +1` + `Onion Sword`. Confirm:
  - Both main-hand and offhand weapon models render visibly on `Rin`.
  - Both main-hand and offhand swing animations play cleanly without T-pose/freezing.
  - Combat log shows 2-hit melee rounds, damage from both swings, expected TP gain, and Adventurer `Cadence` stacks building.
  - Dagger and Sword Weapon Skills execute normally and honor existing WS talents.
- [ ] **Soul Switch Reconciliation**: Switch from `Adventurer` to `Musician` (and also test clearing Soul) via CrystalSocket / `!spec` while dual-wielding -> confirms `Sub` weapon is automatically unequipped, remains safely in inventory/wardrobe, and native Sub menu rejects offhand weapons again.
- [ ] **Zone & Relog Persistence**: Equip `Wind Knife +1` + `Onion Sword` as `Adventurer`, zone to another area, and relog -> confirms both weapons remain equipped and dual-wielding works immediately after zoning/relogging.
- [ ] **Level Sync Reconciliation**: Sync below Lv.10 -> confirms `Sub` weapon is automatically unequipped and native Sub menu rejects offhand weapons.
- [ ] **Regression Check**: Verify `WAR` Spartan Polearm + Size-1 Buckler and vanilla `NIN` Dual Wield work through the native Equipment menu with controller (and WAR Spartan rejects Size-2/3 shields).
