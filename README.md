# OverlordsXI Eos Companion

Custom LandSandBoat module package for a SCH job ability, **Call Eos**, which summons a faerie pet named **Eos**.

Eos is a real pet, not a trust. She maintains a stackable Regen on the master, party members, and trusts, and prioritizes removing major debuffs with -na spells and Erase. Orphic Egg is repurposed as a SCH-only ammo item that gives Eos level-scaling Refresh.

## What is in modules

Most of the customization is packaged as LandSandBoat modules:

- `modules/custom/lua/eos_companion.lua` defines the new ability behavior and the Eos-only Regen spell override.
- `modules/custom/lua/overlords_job_specs.lua` defines the reusable Job Crystal / Spec registry, session-safe passive mod engine, item ID resolver, `[OXSPEC]` sync helpers, and Crystal Socket `0x11F`/`0x1FF` Lua bridge helpers (`getCrystalSnapshot`, `getCrystalCatalog`, `handleCrystalSelect`).
- `modules/custom/lua/overlords_job_spec_runtime.lua` refreshes active job crystal passive mods across login, zoning, job changes, level changes, and level syncs (coordinated with `patches/0010-spec-trait-sync-and-unlocks.patch`).
- `modules/custom/lua/overlords_ws_catalog.lua` stores the original LandSandBoat profiles (including skillchains, drains, debuffs, AoE, enmity, and RMEA flags) for all 207 implemented player weaponskills.
- `modules/custom/lua/overlords_ws_talents.lua` defines the per-weaponskill 4-tier (56-point) talent tree engine, bespoke tree registration API, bit-packed `char_vars` persistence, and Ashita v4 sync protocol.
- `modules/custom/lua/overlords_ws_tree_helpers.lua` & `modules/custom/lua/overlords_ws_trees_*.lua` define all 192 bespoke post-H2H (`#16`–`#235`) 4-tier job-themed weaponskill trees across Dagger, Sword, Great Sword, Axe, Great Axe, Scythe, Polearm, Katana, Great Katana, Club, Staff, and Archery/Marksmanship (plus `Maru Kala`).
- `modules/custom/lua/overlords_ws_overrides.lua` normalizes base PC weaponskills to `fTP = 1.0` and `WSC = 0` and applies invested talent ranks, bespoke pre/post-WS node effects, unique WS traits, and dynamic skillchain bonuses dynamically.
- `modules/custom/lua/sch_specs.lua` defines the SCH Medic and Sage crystal behavior.
- `modules/custom/lua/war_specs.lua` defines the WAR Commander, Berserker, and Gladiator crystal passives and ability transformations.
- `modules/custom/lua/mnk_specs.lua` defines the MNK Sensei crystal passives, Staff Evasion/Parry/Counter engine, and ability transformations.
- `modules/custom/lua/dot_damage_log.lua` preserves DoT caster/pet `origin` attribution on `takeDamage` for Lua-ticked DoTs (`Helix` and Nightmare `Bio`) on mobs.
- `modules/custom/lua/overlords_test_gear.lua` defines the level-appropriate 16-slot test gear resolver across all 22 jobs, OverlordsXI crystal specs, weapon types, and level brackets (`1`–`99`).
- `modules/custom/commands/spec.lua` adds `!spec` (`customMenu` crystal selector, CLI subcommands, and `[OXSPEC]` Ashita v4 sync protocol).
- `modules/custom/commands/eos.lua` adds `!eos heal` and `!eos dismiss` (for both Eos and Titania).
- `modules/custom/commands/talent.lua` adds `!talent` (`customMenu` UI, CLI subcommands, and Ashita v4 `[OXTAL]` protocol).
- `modules/custom/commands/gear.lua` adds `!gear` (auto-grants and equips a full 16-slot level-appropriate loadout tailored to main job, active crystal spec, role, and weapon type, with an interactive `customMenu` UI).
- `modules/custom/cpp/eos_companion.cpp` defines Eos (Medic support AI), Titania (Sage enfeebling & elemental nuking AI), and Orphic Egg's fairy Refresh scaling.
- `modules/custom/cpp/kazenoeye_sync.cpp` pushes live, authoritative mob/pet status effect icons and exact remaining times to nearby players (`0x1FE` `OXKE` packet) for the `kazenoeye` client HUD.
- `modules/custom/sql/eos_companion.sql` defines `Call Eos` (`231`), `Call Titania` (`289`), pet rows (`128`/`129`), mob pools (`6020`/`6021`), spell lists (`566`/`600`), and Orphic Egg DB changes.
- `modules/custom/sql/sch_specs.sql` sets both Addendum abilities to level 10 for this ruleset.
- `modules/custom/sql/war_commander_abilities.sql` defines the 4 WAR Commander custom Job Abilities (`396`–`399`: `tactical_breach`, `formation_bulwark`, `battle_cadence`, `rallying_horn`) with independent recast timers (`186`–`189`) and dynamic Lv.10+ crystal unlocking.
- Client launcher, XIPivot DAT overlay (`dat-overlay/ROM`), and Ashita v4 UI addon (`overlords_talents.lua`, `/talents` or `/tal`) live in **[Infomatictek/overlordsxi-launcher](https://github.com/Infomatictek/overlordsxi-launcher)**.

Twelve small engine patches are required:

- `patches/0001-allow-eos-custom-pet-and-effect-ids.patch` raises `MAX_PETID` from `128` to `129` and `MAX_EFFECTID` from `814` to `815`.
- `patches/0002-eos-deterministic-level-and-subjob.patch` makes Eos spawn at the master's level and correctly initializes her SCH main job / SMN subjob levels.
- `patches/0003-unlock-all-player-weaponskills.patch` unlocks all implemented player weaponskills at level 1 for any job wielding that weapon type (excluding NPC/event/unimplemented WSes).
- `patches/0004-dynamic-ws-skillchain-traits.patch` reads per-cast `OX_WS_SC1..3` localVars inside `CCharEntity::OnWeaponSkillFinished` so talent-upgraded skillchain properties apply dynamically on each weaponskill.
- `patches/0005-clear-ws-skillchains-dynamically.patch` clears/overrides WS skillchain slots cleanly when `OX_WS_SC_SET` is present.
- `patches/0006-eos-status-effect-params.patch` configures status effect IDs `789` (stackable Eos Regen) and `814` (hidden faerie Refresh/buff carrier) in C++.
- `patches/0007-spec-ability-unlocks.patch` hooks `xi.overlords.spec.getExtraAbilities` into `charutils::BuildingCharAbilityTable` (so crystal-gated JAs like **Call Eos**, **Call Titania**, Commander WAR's **Warcry** / custom JAs, and Sensei MNK's **Counterstance** remain hidden until unlocked at Lv.10+) and syncs ability recasts in `recalculateAbilitiesTable()`.
- `patches/0008-titania-sage-pet.patch` raises `MAX_PETID` to `130` (`PETID_FAERIE_TITANIA = 129`) and deterministically spawns Titania at the master's level with `BLM` main job and `RDM` subjob.
- `patches/0009-crystal-socket-packets.patch` adds custom packets `0x11F` (`GP_CLI_COMMAND_CRYSTAL_SOCKET`, C2S) and `0x1FF` (`GP_SERV_COMMAND_CRYSTAL_COLLECTION` `CRYS` / `GP_SERV_COMMAND_CRYSTAL_CATALOG` `CRYC`, S2C) backed by `xi.overlords.spec` for the Ashita v4 `crystalsocket` Equipment UI.
- `patches/0010-spec-trait-sync-and-unlocks.patch` expands `MAX_TRAIT_ID` / `CCharEntity::m_TraitList` to `256` (`32` bytes matching `GP_SERV_COMMAND_COMMAND_DATA`), overrides `CCharEntity::hasTrait`, refreshes spec crystal mods/listeners/UI on every `charutils::BuildingCharTraitsTable` rebuild (job change, subjob change, level change, level sync), and injects crystal-gated custom Job Traits (`xi.overlords.spec.getExtraTraits`) directly into the Traits menu.
- `patches/0011-commander-status-effects.patch` raises `MAX_EFFECTID` to `832` and configures custom status effect IDs `815`–`818` (`commander_breach`, `commander_bulwark`, `commander_cadence`, `commander_regroup`).
- `patches/0012-dot-damage-log.patch` attributes player/pet/trust DoT ticks on mobs (`Dia`, `Bio`, `Poison`, `Burn`/`Frost`/`Choke`/`Rasp`/`Shock`/`Drown`, `Requiem`, `Kaustra`, `Geo-Poison`, `Helix`) and emits parser-friendly `0x017` `MESSAGE_SYSTEM_3` combat log lines (`"<Caster>'s <Effect> deals <Amount> point(s) of damage to <Mob>."`).

The pet and status patches keep Eos and Titania deterministic without editing LSB's jug-pet randomization globally. Patches `0003`–`0005` power the per-character weaponskill unlock and talent skillchain system. Patches `0007`, `0010`, and `0011` allow job crystals to dynamically grant and hide ability and trait menu entries per character, run custom Commander tactical status effects cleanly, and keep crystal passives synchronized across all job/level/sync transitions.

## Client Launcher & Client Files

The distributable Windows client launcher (`OverlordsLauncher.exe`), XIPivot DAT overlay, and `overlords_talents` Ashita v4 addon are maintained in **[Infomatictek/overlordsxi-launcher](https://github.com/Infomatictek/overlordsxi-launcher)**:

- **For Players**: Download `OverlordsLauncher.exe` from **[overlordsxi-launcher Releases](https://github.com/Infomatictek/overlordsxi-launcher/releases)** and click **PLAY OVERLORDSXI** (auto-installs Ashita v4, `xiloader.exe`, XIPivot, the OverlordsXI DAT overlay, and `overlords_talents`).
- **For Server Hosts**: Place an `overlords-server.json` next to `OverlordsLauncher.exe` (generated via **Graphics & Settings -> Export Shareable overlords-server.json**) to point players to your server host/IP.

## Install

### Automated Local Server Setup (Windows)

Run [`scripts/setup-local-server.ps1`](scripts/setup-local-server.ps1) from PowerShell to clone or update `landsandboat/server`, apply `patches/*.patch`, sync `modules/custom/*` without clobbering unchanged C++ timestamps, merge `modules/init.append.txt` into `modules/init.txt`, and rebuild only the server executables (`xi_connect`, `xi_world`, `xi_search`, `xi_map`) whose C++/CMake inputs actually changed:

```powershell
.\scripts\setup-local-server.ps1 -ServerDir C:\dev\server
```

Supported flags:

- `-ServerDir` (default `C:\dev\server`): target LandSandBoat checkout path.
- `-BuildJobs` (default `0`, auto-detects CPU thread count): parallel CMake build jobs.
- `-SkipClone` / `-SkipBuild`: update files/patches on an existing checkout without cloning or recompiling.
- `-ForceBuild`: force rebuilding even if no C++/CMake changes are detected.
- `-MapOnly`: only check/build `xi_map` (skips checking `xi_connect`, `xi_world`, `xi_search`).
- `-RunDbTool`: also executes `python tools\dbtool.py` inside `-ServerDir`.

### Manual Install

From your LandSandBoat checkout:

```powershell
Set-Location C:\dev\server
git apply C:\path\to\overlordsxi\patches\0001-allow-eos-custom-pet-and-effect-ids.patch
git apply C:\path\to\overlordsxi\patches\0002-eos-deterministic-level-and-subjob.patch
git apply C:\path\to\overlordsxi\patches\0003-unlock-all-player-weaponskills.patch
git apply C:\path\to\overlordsxi\patches\0004-dynamic-ws-skillchain-traits.patch
git apply C:\path\to\overlordsxi\patches\0005-clear-ws-skillchains-dynamically.patch
git apply C:\path\to\overlordsxi\patches\0006-eos-status-effect-params.patch
git apply C:\path\to\overlordsxi\patches\0007-spec-ability-unlocks.patch
git apply C:\path\to\overlordsxi\patches\0008-titania-sage-pet.patch
git apply C:\path\to\overlordsxi\patches\0009-crystal-socket-packets.patch
git apply C:\path\to\overlordsxi\patches\0010-spec-trait-sync-and-unlocks.patch
git apply C:\path\to\overlordsxi\patches\0011-commander-status-effects.patch
git apply C:\path\to\overlordsxi\patches\0012-dot-damage-log.patch
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_job_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_ws_catalog.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_ws_talents.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_ws_tree_helpers.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_ws_trees_*.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_ws_overrides.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\eos_companion.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\sch_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\war_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\mnk_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\dot_damage_log.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\overlords_job_spec_runtime.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\commands\spec.lua .\modules\custom\commands\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\commands\eos.lua .\modules\custom\commands\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\commands\talent.lua .\modules\custom\commands\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\cpp\eos_companion.cpp .\modules\custom\cpp\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\cpp\kazenoeye_sync.cpp .\modules\custom\cpp\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\sql\eos_companion.sql .\modules\custom\sql\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\sql\sch_specs.sql .\modules\custom\sql\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\sql\war_commander_abilities.sql .\modules\custom\sql\
```

Add these lines to `modules/init.txt`:

```text
custom/lua/overlords_job_specs.lua
custom/lua/overlords_ws_catalog.lua
custom/lua/overlords_ws_talents.lua
custom/lua/overlords_ws_overrides.lua
custom/lua/eos_companion.lua
custom/lua/sch_specs.lua
custom/lua/war_specs.lua
custom/lua/mnk_specs.lua
custom/lua/dot_damage_log.lua
custom/lua/overlords_job_spec_runtime.lua
custom/cpp/eos_companion.cpp
custom/cpp/kazenoeye_sync.cpp
custom/sql/eos_companion.sql
custom/sql/sch_specs.sql
custom/sql/war_commander_abilities.sql
custom/commands/spec.lua
custom/commands/eos.lua
custom/commands/talent.lua
```

Apply the SQL modules with dbtool, or manually import `modules/custom/sql/*.sql` into `xidb`.

Reconfigure/rebuild after adding the C++ module and patches:

```powershell
cmd /c '"C:\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 && cmake --build build --target xi_map -j 4'
```

## Client DAT overlay

The DAT overlay lives in **[Infomatictek/overlordsxi-launcher](https://github.com/Infomatictek/overlordsxi-launcher)** under `dat-overlay\ROM` and is synced automatically by `OverlordsLauncher.exe` (or can be copied manually into your custom DAT loader path such as `C:\DATs\Overlords`).

The overlay updates:

- ability display ID `743` (`231 + 512`) to show `Call Eos`
- ability display ID `801` (`289 + 512`) to show `Call Titania`
- ability display IDs `908`–`911` (`396`–`399 + 512`) to show WAR Commander's custom JAs (`Tactical Breach`, `Formation: Bulwark`, `Battle Cadence`, `Rallying Horn`) with recast IDs `186`–`189`
- Call Eos / Call Titania target metadata to self (`validTarget = Self`)
- Call Eos / Call Titania client recast metadata to the DAT-safe cap
- custom Job Trait IDs `140`–`145` (display IDs `1676`–`1681`, `1536 + traitId`) to show crystal traits in the in-game Job Traits menu (`Commander's Tactics`, `Berserker's Fury`, `Gladiator's Bastion`, `Sensei's Flow`, `Medic's Grace`, `Sage's Wisdom`; up to Trait ID `255` supported)
- Orphic Egg item text to show Eos & Titania Refresh scaling

The server enforces the real 5 minute recast.

## Job Specs / Crystals

The package includes a reusable **Job Crystal / Spec** system (`overlords_job_specs.lua`) with session-safe scaling passive modifiers (`overlords_job_spec_runtime.lua`), an interactive `customMenu` crystal selector (`!spec`), and a silent `[OXSPEC]` sync protocol for custom Ashita v4 UIs. Spec choices are persisted as character variables, one per job (`OX_SPEC_<JOB>`, e.g. `OX_SPEC_WAR`, `OX_SPEC_SCH`).

- **Level 10 Baseline Unlock:** All job crystals / souls require **Lv10** (`DEFAULT_REQ_LEVEL = 10`) in that job to unlock, socket, and activate. If a player level-syncs below Lv10, their socketed crystal remains saved in `OX_SPEC_<JOB>` while its passives and spec hooks are safely suspended until Lv10+ is restored.

Players can use:

```text
!spec
!spec list
!spec info [crystal]
!spec set <crystal>
!spec remove
!eos heal
!eos dismiss
!gear
!gear menu
!gear <level> [weapon]
!gear <weapon> [level]
!gear role <melee|tank|ranged|caster>
!gear level <1-99>
!gear info
```

### Warrior Crystals (`OX_SPEC_WAR`, Lv10+)

- `commander` / **Commander** (*Active Tactical Buffer*): Passives (Lv10/30/50+) `+5/8/12% Max HP`, `+8/16/28 Attack`, `+6/12/20 Acc`, `+4/8/12 Store TP`; unlocks **Warcry** at **Lv10** on a **60s cooldown** (`45s` duration, single-stance party share for Berserk/Defender/Aggressor/Retaliation/Restraint); also unlocks **4 active Lv.10+ tactical JAs** with 2s animation lock & Lv10/30/50/70+ scaling — **Tactical Breach** (`396`, 20s CD, 10s mark, Enemy 15y: `+12/18/24/30%` Skillchain DMG, `+8/12/16/20%` Magic Burst & Crit DMG, `+100/150/200/250` SC closer TP), **Formation: Bulwark** (`397`, 25s CD, 15s, Party 10y: stacking Phalanx `8 + 0.45*Lv`, `+5/10/15/20` MDEF, `+12/18/25/35` Status Resist, `+30/50/75/100%` Knockback Resist), **Battle Cadence** (`398`, 20s CD, 12s, Party 10y: `+12/18/24/30` Subtle Blow & `+0/0/5/10` SB II, `+10/15/22/30` Conserve TP, `+8/12/16/20%` Cure Rcvd), and **Rallying Horn** (`399`, 45s CD, 12s, Party 12y: progressive Slow/Bind -> Weight/Para -> DEF/MDEF Down -> Atk/Acc Down cleanse, `+5/7/9/12%` HP heal, `+75/125/175/250` TP, `+8/10/12/15%` Move Speed).
- `berserker` / **Berserker** (*Fury / Heavy Burst DPS*): Passives (Lv10/30/50+) `+8/12/16% Attack`, `+6/10/14% Double Attack`, `+5/8/12% WS Damage`, `+5/10/15 Store TP`; **Berserk** gains `+10% extra Attack%`, `+60s` duration, and `+300 TP` on activation; **Aggressor** loses its `-25 Evasion` penalty and gains `+5% Crit Rate`; **Blood Rage** gains `+10% Crit Rate` and `+15s` duration; **Warcry** gains `+8% Attack%`.
- `gladiator` / **Gladiator** (*Bloodthirsty Club & Shield Tank*): Passives (Lv10/30/50+) `+10/15/22% Max HP`, `+6/12/20 VIT`, `+12/20/30% DEF`, `-6/10/15% Damage Taken`, `+15/25/40 Enmity`, `+10/15/20% Cure Rcvd`, `+10/20/35 Club & Shield skill`, `+12/24/40 Shield DEF`, `+8/14/22% Block Rate` (`+10%` extra w/ Club+Shield), `+15/25/40 Shield TP`, with `-25% Attack% / Ranged Attack%` & `-20% WSD` lower-damage tradeoff; **Bloodthirsty Leech** (with Club+Shield) heals on Club hits (`1% Max HP + 0.2*Lv`), Club WSs (`3–5% Max HP`), and Shield Blocks (`1.5% Max HP`), all **doubled** during **Blood Rage** (`-10% DT`, `+25 Enmity`, Regen) or **Mighty Strikes** (`60s`, `-25% DT`, `+50 Enmity`); **Defender** (`+35% DEF`, `-10% PDT`, `+15% Block`), **Aggressor** (`0 EVA` penalty, `+20 Enmity`, `+10% Block`), **Retaliation** (`0` move penalty, `+12% Counter`, `+15 Enmity`), and **Warcry** (party `-8% DT`; self `+12 Enmity` & `15% Max HP` heal).

### Monk Crystals (`OX_SPEC_MNK`, Lv10+)

- `sensei` / **Sensei** (*Staff Evasion & Counter Tank*): Passives (Lv10/30/50+) `+12/22/35 Staff Skill`, `+8/15/25 Acc`, `+12/24/40 Evasion Skill`, `+10/22/38 EVA`, `+5/10/15% EVA`, `+6/12/20 AGI`, `+15/30/50 Parry Skill`, `+5/10/15% Parry Rate`, `+12/22/30% Counter`, `+8/16/28 Counter DMG`, `+15/25/40 Enmity`, `-25/40/60% Enmity Loss`, `+6/10/15% Max HP`, `-5/8/12% DT`; **Staff Deflection & Riposte** (`+12%` Parry Rate w/ Staff, Parrying heals `2% Max HP`, grants `+75 TP`, `+Enmity`, & ripostes the attacker; Evading grants `1.5% Max HP`, `+50 TP`, `+Enmity`, & deals an **Evasive Counter**); unlocks **Iron Counterstance** at **Lv10** on a **120s** cooldown (`+30% Counter`, `+20 Counter DMG`, `-10% DT`, `+20 Enmity`, **no DEF halving penalty**); enhances **Dodge** (`60s`, `+25 EVA`, `+15% EVA%`, `+12% Parry Rate`, `+15 Enmity`, `+35% Evasive Counter DMG`), **Focus** (`+15% Counter`, `+15 Parry Skill`, `+10 Counter DMG`), **Boost** (w/ Staff: `+15 Enmity`, `+50 TP`), **Chi Blast** (heavy Enmity + `Accuracy Down`), **Chakra** (`+50%` potency, Regen, cleanses Slow & Silence, +Enmity), **Perfect Counter** (`45s` CD, `+25 Counter DMG`, `+25 Enmity`, `5% HP` heal), **Mantra** (party `-5% DT`), and **Inner Strength** (`60s`, `-25% DT`, `+20% EVA%`, `+30 Counter DMG`, `+50 Enmity`).

### Scholar Crystals (`OX_SPEC_SCH`, Lv10+)

- `medic` / **Medic** (*Light Arts / Eos Support*): Addendum: White remains a 2 hour stance, Sublimation charging stores MP twice as fast without HP drain, Cure/Regen spells use Accession-style 10y AoE without consuming Stratagem charges, and **Call Eos** (`231`) is dynamically unlocked at Lv.10+ (hidden otherwise; Eos despawns if removing or suspending the Medic crystal).
- `sage` / **Sage** (*Dark Arts / Helix Master & Titania*): Addendum: Black remains a 2 hour stance, Ebullience is permanent for black magic, Helix damage is increased by 50%, Helix duration is extended to 2 hours, magic attack bonus is increased by 30, elemental magic gets a 10% target Magic Evasion bypass as bonus accuracy, and **Call Titania** (`289`) is dynamically unlocked at Lv.10+ (summons a Dark Pixie companion that enfeebles, drains/aspirs, and elemental nukes; Titania despawns if removing or suspending the Sage crystal).

Spell and ability modules can branch with:

```lua
xi.overlords.spec.is(player, xi.job.WAR, 'commander')
xi.overlords.spec.is(player, xi.job.MNK, 'sensei')
xi.overlords.spec.is(player, xi.job.SCH, 'medic')
xi.overlords.spec.is(player, xi.job.SCH, 'sage')
```

### Ashita v4 Custom Crystal Addon Protocol (`[OXSPEC]`)

Client addons can communicate silently with `!spec` over `0x017` `SYSTEM_3` lines prefixed with `[OXSPEC]|` (suppressing lines matching `[OXSPEC]|` from the chat log):

- Request full crystal list & active state: `/say !spec sync` (or `/say !spec sync <jobId>`)
- Request current active state only: `/say !spec state`
- Socket crystal silently: `/say !spec uset <key|id|item:itemId>`
- Remove crystal silently: `/say !spec uremove` (or `/say !spec uclear`)

Server responses:

- `[OXSPEC]|STATE|<jobId>|<jobKey>|<jobName>|<lvl>|<activeId>|<activeKey>|<activeName>|<activeIcon>|<activeUnlocked 0|1>`
- `[OXSPEC]|BEGIN|<jobId>|<jobName>|<lvl>|<count>`
- `[OXSPEC]|CRYSTAL|<jobId>|<id>|<key>|<name>|<role>|<icon>|<itemId>|<socketed 0|1>|<desc>|<reqLevel>|<unlocked 0|1>`
- `[OXSPEC]|HIGHLIGHT|<jobId>|<id>|<idx>|<text>`
- `[OXSPEC]|END|<jobId>`
- `[OXSPEC]|ERR|<message>`

## IDs

- **Call Eos**: Ability ID `231` (display `743`), Pet ID `128`, Pool ID `6020` (Light Pixie `0x07EE`), Spell List ID `566`
- **Call Titania**: Ability ID `289` (display `801`), Pet ID `129`, Pool ID `6021` (Dark Pixie `0x07F0`), Spell List ID `600`
- **WAR Commander Commands**: Ability IDs `396`–`399` (display `908`–`911`, recast IDs `186`–`189`): `Tactical Breach` (`396`), `Formation: Bulwark` (`397`), `Battle Cadence` (`398`), `Rallying Horn` (`399`)
- Commander custom status IDs: `815` (`commander_breach`), `816` (`commander_bulwark`), `817` (`commander_cadence`), `818` (`commander_regroup`)
- Eos Regen status ID: `789`
- Faerie hidden Refresh/buff carrier status ID: `814`
- Orphic Egg item ID: `18256`
- Orphic Egg Faerie Refresh mod ID: `1198`
