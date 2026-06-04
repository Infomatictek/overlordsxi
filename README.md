# OverlordsXI Eos Companion

Custom LandSandBoat module package for a SCH job ability, **Call Eos**, which summons a faerie pet named **Eos**.

Eos is a real pet, not a trust. She maintains a stackable Regen on the master, party members, and trusts, and prioritizes removing major debuffs with -na spells and Erase. Orphic Egg is repurposed as a SCH-only ammo item that gives Eos level-scaling Refresh.

## What is in modules

Most of the customization is packaged as LandSandBoat modules:

- `modules/custom/lua/eos_companion.lua` defines the new ability behavior and the Eos-only Regen spell override.
- `modules/custom/cpp/eos_companion.cpp` defines Eos support AI and Orphic Egg's Eos-only Refresh behavior.
- `modules/custom/sql/eos_companion.sql` defines the ability row, pet row, mob pool, Eos spell list, custom status rows, and Orphic Egg DB changes.

One tiny engine patch is still required:

- `patches/0001-allow-eos-custom-pet-and-effect-ids.patch` raises `MAX_PETID` from `128` to `129` and `MAX_EFFECTID` from `814` to `815`.

That patch is needed because LSB bounds pet IDs and status effect IDs in C++. The packaged version does not need direct edits to `pet_controller.cpp`, `status_effect_container.cpp`, `modifier.h`, base Lua enums, or base SQL files.

## Install

From your LandSandBoat checkout:

```powershell
Set-Location C:\dev\server
git apply C:\path\to\overlordsxi\patches\0001-allow-eos-custom-pet-and-effect-ids.patch
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\eos_companion.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\cpp\eos_companion.cpp .\modules\custom\cpp\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\sql\eos_companion.sql .\modules\custom\sql\
```

Add these lines to `modules/init.txt`:

```text
custom/lua/eos_companion.lua
custom/cpp/eos_companion.cpp
custom/sql/eos_companion.sql
```

Apply the SQL module with dbtool, or manually import `modules/custom/sql/eos_companion.sql` into `xidb`.

Reconfigure/rebuild after adding the C++ module:

```powershell
cmd /c '"C:\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 && cmake --build build --target xi_map -j 4'
```

## Client DAT overlay

Copy `dat-overlay\ROM` into your custom DAT loader path:

```text
C:\DATs\Overlords
```

The overlay updates:

- ability display ID `743` to show `Call Eos`
- Call Eos target metadata to self
- Call Eos client recast metadata to the DAT-safe cap
- Orphic Egg item text to show Eos Refresh scaling

The server enforces the real 5 minute recast.

## IDs

- Ability ID: `231`
- Client ability display ID: `743`
- Pet ID: `128`
- Pet pool ID: `6020`
- Eos spell list ID: `566`
- Eos Regen status ID: `789`
- Eos hidden Refresh carrier status ID: `814`
- Orphic Egg item ID: `18256`
- Orphic Egg Eos Refresh mod ID: `1198`
