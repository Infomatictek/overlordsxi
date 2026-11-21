# SoulspireXI — Soul Spell Authorization & Client DAT Compatibility Audit

Date: 2026-11-20

## 1. Confirmed Root Causes

### A. Terramancer Casting Failure (`Stone Chip` 159 / `Shallow Fault` 160)

- **Error observed in client:** `"Incorrect job, job level too low, or required ability not activated."`
- **Where rejection occurs:** **FFXI client (`FFXiMain.dll`) before `0x01A` is sent**, NOT the server. Server spell rejection sends `MsgBasic::CannotCastSpell` (`47`, `"<caster> cannot cast <spell>."`).
- **Server status (verified on real `xi_test` engine):**
  - `patches/0069-terramancer-native-actions.patch` (`terramancer_actions.h`, `char_entity.cpp`, `magic_state.cpp`, `0x0aa_magic_data.cpp`, `battle_entity.cpp`, `lua_base_entity.cpp`) and `modules/custom/lua/geo_terramancer_specs.lua` already authorize `Stone` (`159`, Stone Chip) and `Stone II` (`160`, Shallow Fault) at GEO Lv.10 and `Stone III` (`161`, Deep Fault) at GEO Lv.30.
  - `0x0AA` Magic Data sets bits `159` and `160` (clears `161`) at Lv.10.
  - Both `Stone Chip` (`159`) and `Shallow Fault` (`160`) cast, deduct MP/recast, establish claim, and trigger delayed eruption in `xi_test`.
- **Client root cause (`soulspirexi-launcher`):**
  - `native/crystaljobs/crystaljobs.cpp` only hooked `0x22DAB9` (`magic_list_filter_hook`), which wraps only the **Magic Menu list display** call to `FFXiMain.dll+0x22CDE0` (`CanUseSpell`).
  - When a player attempts to cast `Shallow Fault` (`160`), `FFXiMain.dll` executes its **cast-time** check (`0x22CDE0` via unhooked callers) against `ROM/118/114.DAT`, where `Stone II` still requires `GEO:34` (`Stone III` requires `GEO:58`). Because `10 < 34`, the client rejects the cast locally.
  - **Fix implemented in `native/crystaljobs/crystaljobs.cpp`:** Added a 5-byte prologue detour (`can_use_spell_detour`) on `0x22CDE0` itself (using the verified 5-byte `mov eax, ds:[main_job_slot]` prologue) with a 10-byte executable trampoline so **both** Magic Menu display and cast execution (`/ma` and menu selection) consult the active Soul's visibility/eligibility policy.

### B. Shinobi — `Utsusemi: Ni` (`339`) DAT Availability Leakage

- **Client root cause (`soulspirexi-launcher/dat-overlay/ROM/118/114.DAT`):**
  - Commit `ff964030` globally edited 35 spells in `ROM/118/114.DAT` to Lv.10, including **`339` (`Utsusemi: Ni`: `NIN:37 -> NIN:10`)**. Commit `d6a03de8` also set `338` (`Utsusemi: Ichi`: `NIN:12 -> NIN:10`).
  - Because `114.DAT` is global and non-Soul-aware, any Lv.10 `/NIN` subjob (e.g., `WAR20/NIN10`) saw `Utsusemi: Ni` as available in the client Magic Menu, even though Shinobi only unlocks `339` at Lv.37 (`modules/custom/lua/nin_specs.lua`).
- **Server status (verified on real `xi_test` engine):**
  - MariaDB `spell_list` retains vanilla `338 = NIN:12` and `339 = NIN:37`.
  - `WAR20/NIN10` attempting `339` or `338`, and Shinobi Lv.10 attempting `339`, are **rejected** by the server with `MsgBasic::CannotCastSpell` (`47`).
- **Fix implemented in `soulspirexi-launcher`:**
  - Restored `Spell 339 (Utsusemi: Ni)` in `dat-overlay/ROM/118/114.DAT` from `NIN:10` back to vanilla `NIN:37`.
  - Added `kagemusha	spell	339	10	unlock` to `addons/ashita4/soulspire_soul_actions/data/visibility.tsv` so Kagemusha retains Lv.10 `Utsusemi: Ni` via the Soul-aware `0x22CDE0` hook without leaking to subjobs or Shinobi.

### C. Overlapping Magic Description Text

- **Root cause (`soulspirexi-launcher`):**
  - 7 entries in `soul_actions.tsv` (including Terramancer's `Shallow Fault` and `Deep Fault`) contained raw UTF-8 multibyte punctuation (`’` `E2 80 99`, `–` `E2 80 93`), which FFXI's single-byte `helpwind` renderer misinterprets as multibyte/control bytes.
  - `native/crystaljobs/actions.h` (`copy_cstr_bounded`) did not sanitize high bytes (`>= 0x7F`) or bound `helpwind` display lengths (66 entries exceeded 90 characters, up to 167 characters).
- **Fixes implemented:**
  - Sanitized all 7 non-ASCII entries in `soul_actions.tsv` (and `geo_terramancer_specs.lua`) to pure ASCII.
  - Hardened `copy_cstr_bounded` in `native/crystaljobs/actions.h` to normalize UTF-8 punctuation and strip control/high bytes (`< 0x20 || >= 0x7F`), and added `format_action_description(..., 96)` in `resolve_magic_desc` / `resolve_ability_desc`.

## 2. 66-Soul Audit Summary

- **29 spells across 10 Souls** had `unlockLvl < 114.DAT` level (all affected by the unhooked `0x22CDE0` cast-time check):
  - `zealot` (WHM): `30` (50 vs 65)
  - `astromancer` (BLM): `144` (10 vs 13), `149` (10 vs 17), `164` (10 vs 21), `160` (10 vs 26), `204/208/210/212/214` (50 vs 52–60)
  - `channeler` (BLM): `164` (10 vs 21)
  - `scarletweaver` (RDM): `144/149/154/164` (10 vs 14–29), `145` (30 vs 50), `165` (50 vs 60)
  - `royaltactician` (RDM): `56` (10 vs 13), `59` (10 vs 18), `260` (30 vs 32)
  - `scourge` (DRK): `230` (10 vs 15), `271` (30 vs 31)
  - `nightblade` (NIN): `341` (10 vs 30)
  - `warmage` (BLU): `527` (30 vs 34), `591` (70 vs 71), `644` (70 vs 73)
  - `archivist` (SCH): `99` (10 vs 41)
  - `terramancer` (GEO): `160` (10 vs 34), `161` (30 vs 58)
- **34 other spells in `ROM/118/114.DAT`** remain globally lowered to Lv.10 (DRK `242/246/266/268/275/277`, RDM `312-317/473/493/511`, NIN `320/323/326/329/332/335/338/344/347`, BLU `581/593/632/658/662/681/690/692`, RUN `363/364/477`). Server-side `xi_test` verified **0/18 subjob leaks**; restoring these remaining DAT rows to vanilla should be done once the rebuilt Windows `crystaljobs.dll` (`0x22CDE0` detour) is deployed and verified in-game alongside `visibility.tsv` entries for the older Souls (`dreadnought`, `crimsonduelist`, `magus`, `kagemusha`).

## 3. Remaining Client-Side Limitations & Manual Verification

1. **Windows DLL Rebuild Required:** `plugins/ashita4/crystaljobs.dll` is a 32-bit Windows DLL (`__declspec(naked)` / `__asm`) and cannot be compiled on this Linux host. Run `native/crystaljobs/build.cmd` on Windows (or via CI), copy the rebuilt `crystaljobs.dll` to `plugins/ashita4/crystaljobs.dll`, and re-run `scripts/update-launcher-manifest.py`.
2. **In-Game Manual Verification Checklist (after Windows `crystaljobs.dll` rebuild):**
   - Log in as `Rin` (GEO Lv.10 Terramancer): confirm `Stone Chip` (`159`) and `Shallow Fault` (`160`) both cast cleanly from the Magic Menu and `/ma`, with clean single-line `helpwind` descriptions and zero text overlap.
   - Log in as `WAR20/NIN10`: confirm `Utsusemi: Ni` (`339`) is no longer shown or castable.
   - Switch Souls while the Magic Menu is open (e.g. Terramancer -> Verdant -> Diviner) and confirm menu eligibility updates cleanly on refresh.
