# OverlordsXI Eos Companion

Custom LandSandBoat module package for a SCH job ability, **Call Eos**, which summons a faerie pet named **Eos**.

Eos is a real pet, not a trust. She maintains a stackable Regen on the master, party members, and trusts, and prioritizes removing major debuffs with -na spells and Erase. Orphic Egg is repurposed as a SCH-only ammo item that gives Eos level-scaling Refresh.

## What is in modules

Most of the customization is packaged as LandSandBoat modules:

- `modules/custom/lua/eos_companion.lua` defines the new ability behavior and the Eos-only Regen spell override.
- `modules/custom/lua/overlords_job_specs.lua` defines the reusable per-job spec helper API.
- `modules/custom/lua/overlords_ws_catalog.lua` stores the original LandSandBoat profiles for all 207 implemented player weaponskills.
- `modules/custom/lua/overlords_ws_talents.lua` defines the per-weaponskill talent tree generator, bit-packed `char_vars` persistence, and Ashita v4 sync protocol.
- `modules/custom/lua/overlords_ws_overrides.lua` normalizes base PC weaponskills to `fTP = 1.0` and `WSC = 0` and applies invested talent ranks dynamically.
- `modules/custom/lua/sch_specs.lua` defines the SCH Medic and Sage spec behavior.
- `modules/custom/commands/spec.lua` adds the player-facing `!spec` command.
- `modules/custom/commands/eos.lua` adds `!eos heal` and `!eos dismiss`.
- `modules/custom/commands/talent.lua` adds `!talent` (`customMenu` UI, CLI subcommands, and Ashita v4 `[OXTAL]` protocol).
- `modules/custom/cpp/eos_companion.cpp` defines Eos support AI and Orphic Egg's Eos-only Refresh behavior.
- `modules/custom/sql/eos_companion.sql` defines the ability row, pet row, mob pool, Eos spell list, custom status rows, and Orphic Egg DB changes.
- `modules/custom/sql/sch_specs.sql` sets both Addendum abilities to level 10 for this ruleset.
- `addons/ashita4/overlords_talents/overlords_talents.lua` provides the Ashita v4 ImGui talent tree UI (`/talents` or `/tal`).

Three small engine patches are still required:

- `patches/0001-allow-eos-custom-pet-and-effect-ids.patch` raises `MAX_PETID` from `128` to `129` and `MAX_EFFECTID` from `814` to `815`.
- `patches/0002-eos-deterministic-level-and-subjob.patch` makes Eos spawn at the master's level and correctly initializes her SCH main job / SMN subjob levels.
- `patches/0003-unlock-all-player-weaponskills.patch` unlocks all implemented player weaponskills at level 1 for any job wielding that weapon type (excluding NPC/event/unimplemented WSes).

The first patch is needed because LSB bounds pet IDs and status effect IDs in C++. The second patch keeps Eos from inheriting randomized jug-pet level behavior. The third patch removes skill, quest, level 75, and job gates from player weaponskill eligibility.

## Install

From your LandSandBoat checkout:

```powershell
Set-Location C:\dev\server
git apply C:\path\to\overlordsxi\patches\0001-allow-eos-custom-pet-and-effect-ids.patch
git apply C:\path\to\overlordsxi\patches\0002-eos-deterministic-level-and-subjob.patch
git apply C:\path\to\overlordsxi\patches\0003-unlock-all-player-weaponskills.patch
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_job_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_ws_catalog.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_ws_talents.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_ws_overrides.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\eos_companion.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\sch_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\commands\spec.lua .\modules\custom\commands\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\commands\eos.lua .\modules\custom\commands\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\commands\talent.lua .\modules\custom\commands\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\cpp\eos_companion.cpp .\modules\custom\cpp\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\sql\eos_companion.sql .\modules\custom\sql\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\sql\sch_specs.sql .\modules\custom\sql\
```

Add these lines to `modules/init.txt`:

```text
custom/lua/overlords_job_specs.lua
custom/lua/overlords_ws_catalog.lua
custom/lua/overlords_ws_talents.lua
custom/lua/overlords_ws_overrides.lua
custom/lua/eos_companion.lua
custom/lua/sch_specs.lua
custom/cpp/eos_companion.cpp
custom/sql/eos_companion.sql
custom/sql/sch_specs.sql
custom/commands/spec.lua
custom/commands/eos.lua
custom/commands/talent.lua
```

Apply the SQL module with dbtool, or manually import `modules/custom/sql/eos_companion.sql` into `xidb`.

Reconfigure/rebuild after adding the C++ module and patches:

```powershell
cmd /c '"C:\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 && cmake --build build --target xi_map -j 4'
```

For the Ashita v4 UI, copy `addons\ashita4\overlords_talents` into your Ashita `addons\` directory and load it with `/addon load overlords_talents`, then open it with `/talents` or `/tal`.

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

## Job Specs

The package includes the first pass of a reusable job spec system. Spec choices are stored as character variables, one per job. SCH currently uses:

```text
OX_SPEC_SCH
```

Players can use:

```text
!spec
!spec list
!spec set medic
!spec set sage
!spec clear
!eos heal
!eos dismiss
```

Current SCH spec slots:

- `medic` / Medic: Addendum: White remains a 2 hour stance, Sublimation charging stores MP twice as fast without HP drain, and Cure/Regen spells use Accession-style 10y AoE without consuming Stratagem charges.
- `sage` / Sage: Addendum: Black remains a 2 hour stance, Ebullience is permanent for black magic, Helix damage is increased by 50%, Helix duration is extended to 2 hours, magic attack bonus is increased by 30, and elemental magic gets a 10% target Magic Evasion bypass as bonus accuracy.

Spell and ability modules can branch with:

```lua
xi.overlords.spec.is(player, xi.job.SCH, 'medic')
```

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
