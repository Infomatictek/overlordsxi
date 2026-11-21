# SoulspireXI — Universal Soul Weapon Configuration Modes Progress

> **Branch (Server):** `feat/soul-weapon-templates` (base: `30d1fad`)  
> **Branch (Launcher):** `feat/soul-weapon-templates` (base: `e15fbd2`)  
> **Scope:** Complete the four reusable weapon configuration templates (`dual_1h`, `dual_2h`, `twohand_shield`, `vanilla`) in the shared Soul Weapon Configuration System without per-Soul C++ patches or global FFXI item SQL/DAT edits.

---

## Architecture Overview

| Mode | Identifier | Purpose | Reference / Prototype Soul | Engine Decision (`EvaluateSoulWeaponPair`) |
| --- | --- | --- | --- | --- |
| Template 1 | `dual_1h` | Dual-wield two permitted 1H weapons on Souls without vanilla Dual Wield | BRD Adventurer (Dagger + Sword, Lv10+) | `1` (`ALLOW_DUAL_WIELD`) |
| Template 2 | `dual_2h` | Dual-wield two permitted 2H weapons (two distinct items) with balanced combat scaling & compact visual model profile | WAR Berserker (Great Axe + Great Axe, Lv10+, `compact_dual_axe`) | `1` (`ALLOW_DUAL_WIELD`) |
| Template 3 | `twohand_shield` | Equip a permitted 2H weapon with a permitted shield (e.g. Size-1 Buckler) | WAR Spartan (Polearm + Size-1 Buckler, Lv10+) | `2` (`ALLOW_SUB_NON_DW`) |
| Template 4 | `vanilla` | Default LandSandBoat equipment behavior when `weaponConfig` is absent | Vanilla NIN DW, single 2H, 1H + Shield | `0` (`VANILLA`) |

---

## Step 1 — Template 1 (`dual_1h`) Audit Baseline

Audited against server `main` (`30d1fad`) and launcher `main` (`e15fbd2`):

- **Server Lua (`modules/custom/lua/soulspire_weapon_config.lua`)**:
  - Data-driven registry (`register`, `resolveSpec`, `getConfig`, `classifyItem`, `evaluatePair`, `reconcileEquipment`).
  - BRD Adventurer (`job = 10`, `spec = 'adventurer'`) registered with `mode = 'dual_1h'`, `minLevel = 10`, `mainWhitelist = { 'dagger', 'sword' }`, `subWhitelist = { 'dagger', 'sword' }`, `pairings = { { main = 'dagger', sub = 'sword' }, { main = 'sword', sub = 'dagger' } }`, `restrictSoulDualWieldToPairings = true`, `allowVanillaShield = true`.
- **Server C++ (`patches/0073-soul-weapon-config.patch`)**:
  - Hooks `charutils::EquipArmor`, `charutils::EquipItem`, and `charutils::CheckValidEquipment`.
  - Exposes `player:checkValidEquipment()` for Lua-driven Soul switch/delevel reconciliation.
  - Preserves vanilla LandSandBoat `CAttackRound` Dual Wield, weapon delay, TP, accuracy, damage, and WS authorization.
- **Client Native (`crystaljobs.dll` + CrystalSocket `0.3.9`)**:
  - `CrystalJobsReplaceWeaponRules` syncs active Soul rules on Soul change/zone.
  - Native Equipment menu remains the sole equipment interface; CrystalSocket is restricted to Soul Crystal management only.
  - Hook #24 (`soul_sub_weapon_detour` at `0x133D56`) authorizes permitted `DUAL_1H` offhand weapons inside `FFXiMain.dll`.
- **Status:** Preserved as regression baseline; no rewrite needed.

---

## Persistent Verification Matrix (Levels 10, 30, 50, 75)

Legend: `PASS` = verified via real-engine `xi_test` / unit test / Windows CI; `PENDING` = implementation in progress; `NOT TESTED (Windows client required)` = requires live Windows FFXI client + physical controller.

| Mode | Prototype / Fixture | Server Equip & Validation (Lv10/30/50/75) | Combat / Delay / TP / WS | Inventory & Soul Switch Reconciliation | Native Client DLL / CI | Live Windows Rendering, Animations & Controller |
| --- | --- | --- | --- | --- | --- | --- |
| `dual_1h` | BRD Adventurer (Dagger + Sword) | PASS (Lv10/30/50/75 to be re-verified in full matrix) | PASS (vanilla DW) | PASS | PASS (24-hook DLL) | Previously verified for BRD Adventurer; re-verify after DLL update |
| `dual_2h` | WAR Berserker (Twin Great Axes) | PASS (Lv10/30/50/75 verified via `xi_test`, duplicate guard, non-GA rejection, Lv9 gating) | PASS (scaled delay, main/sub damage & TP hooks, main-only multi-attack, real dual-swing combat) | PASS (Soul switch, delevel, inventory preserved) | PASS (26-hook DLL CI run `44892970292`, MSVC `/W4 /WX` + `selftest.exe`) | NOT TESTED (Windows client required) |
| `twohand_shield` | WAR Spartan (Polearm + Size-1 Buckler) | PENDING | PENDING | PENDING | PENDING | NOT TESTED (Windows client required) |
| `vanilla` | NIN DW, Single 2H, 1H + Shield | PENDING | PENDING | PENDING | PENDING | NOT TESTED (Windows client required) |

---

## Checkpoint Log

- **Checkpoint 1 (`dual_1h` audit & progress tracking):** Initialized `docs/soul-weapon-modes-progress.md` on `feat/soul-weapon-templates`.
- **Checkpoint 2 (`dual_2h` WAR Berserker prototype):** Added `patches/0074-soul-weapon-templates.patch` (`SLOT_SUB` 2H authorization when `soulPair == 1`, `compact_dual_axe` look override, configurable `mainDamageScale`/`subDamageScale`/`delayScale`/`tpScale`/`multiAttackPolicy`), registered WAR Berserker (`mode = 'dual_2h'`) in `soulspire_weapon_config.lua`, added native `crystaljobs.dll` Hooks #25 (`0x21DF85`) & #26 (`0x133DD3`) on launcher `feat/soul-weapon-templates` (`37fcfb3`, CI run `44892970292` green), and passed 6/6 real-engine `xi_test` across Lv10/30/50/75.
