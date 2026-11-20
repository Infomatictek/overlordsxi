# SoulspireXI Eos Companion

Custom LandSandBoat module package for a SCH job ability, **Call Eos**, which summons a faerie pet named **Eos**.

Eos is a real pet, not a trust. She maintains a stackable Regen on the master, party members, and trusts, and prioritizes removing major debuffs with -na spells and Erase. Orphic Egg is repurposed as a SCH-only ammo item that gives Eos level-scaling Refresh.

## What is in modules

Most of the customization is packaged as LandSandBoat modules:

- `modules/custom/lua/eos_companion.lua` defines the new ability behavior and the Eos-only Regen spell override.
- `modules/custom/lua/soulspire_job_specs.lua` defines the reusable Job Crystal / Spec registry, session-safe passive mod engine, item ID resolver, `[OXSPEC]` sync helpers, and Crystal Socket `0x11F`/`0x1FF` Lua bridge helpers (`getCrystalSnapshot`, `getCrystalCatalog`, `handleCrystalSelect`).
- `modules/custom/lua/soulspire_job_spec_runtime.lua` refreshes active job crystal passive mods across login, zoning, job changes, level changes, and level syncs (coordinated with `patches/0010-spec-trait-sync-and-unlocks.patch`).
- `modules/custom/lua/soulspire_ws_catalog.lua` stores the original LandSandBoat profiles (including skillchains, drains, debuffs, AoE, enmity, and RMEA flags) for all 207 implemented player weaponskills.
- `modules/custom/lua/soulspire_ws_talents.lua` defines the per-weaponskill 4-tier (56-point) talent tree engine, bespoke tree registration API, bit-packed `char_vars` persistence, and Ashita v4 sync protocol.
- `modules/custom/lua/soulspire_ws_tree_helpers.lua` & `modules/custom/lua/soulspire_ws_trees_*.lua` define all 192 bespoke post-H2H (`#16`â€“`#235`) 4-tier job-themed weaponskill trees across Dagger, Sword, Great Sword, Axe, Great Axe, Scythe, Polearm, Katana, Great Katana, Club, Staff, and Archery/Marksmanship (plus `Maru Kala`).
- `modules/custom/lua/soulspire_ws_overrides.lua` normalizes base PC weaponskills to `fTP = 1.0` and `WSC = 0` and applies invested talent ranks, bespoke pre/post-WS node effects, unique WS traits, and dynamic skillchain bonuses dynamically.
- `modules/custom/lua/sch_specs.lua` defines the SCH Medic and Sage crystal behavior.
- `modules/custom/lua/war_specs.lua` defines the WAR Commander, Berserker, and Gladiator crystal passives and ability transformations.
- `modules/custom/lua/mnk_specs.lua` defines the MNK Sensei crystal passives, Staff Evasion/Parry/Counter engine, and ability transformations.
- `modules/custom/lua/run_specs.lua` defines the RUN Inquisitor, Spellblade, and Lifebinder crystal passives, 3-rune Lv.10+ mastery, Runic Riposte/Brand/Lifetap engines, and ability/spell transformations.
- `modules/custom/lua/dot_damage_log.lua` preserves DoT caster/pet `origin` attribution on `takeDamage` for Lua-ticked DoTs (`Helix` and Nightmare `Bio`) on mobs.
- `modules/custom/lua/soulspire_test_gear.lua` defines the level-appropriate 16-slot test gear resolver across all 22 jobs, SoulspireXI crystal specs, weapon types, and level brackets (`1`â€“`99`).
- `modules/custom/commands/spec.lua` adds `!spec` (`customMenu` crystal selector, CLI subcommands, and `[OXSPEC]` Ashita v4 sync protocol).
- `modules/custom/commands/eos.lua` adds `!eos heal` and `!eos dismiss` (for both Eos and Titania).
- `modules/custom/commands/talent.lua` adds `!talent` (`customMenu` UI, CLI subcommands, and Ashita v4 `[OXTAL]` protocol).
- `modules/custom/commands/gear.lua` adds `!gear` (auto-grants and equips a full 16-slot level-appropriate loadout tailored to main job, active crystal spec, role, and weapon type, with an interactive `customMenu` UI).
- `modules/custom/cpp/eos_companion.cpp` defines Eos (Medic support AI), Titania (Sage enfeebling & elemental nuking AI), and Orphic Egg's fairy Refresh scaling.
- `modules/custom/cpp/kazenoeye_sync.cpp` pushes live, authoritative mob/pet status effect icons and exact remaining times to nearby players (`0x1FE` `OXKE` packet) for the `kazenoeye` client HUD.
- `modules/custom/sql/eos_companion.sql` defines `Call Eos` (`231`), `Call Titania` (`289`), pet rows (`128`/`129`), mob pools (`6020`/`6021`), spell lists (`566`/`600`), and Orphic Egg DB changes.
- `modules/custom/sql/sch_specs.sql` sets both Addendum abilities to level 10 for this ruleset.
- `modules/custom/sql/war_commander_abilities.sql` defines the 4 WAR Commander custom Job Abilities (`396`â€“`399`: `tactical_breach`, `formation_bulwark`, `battle_cadence`, `rallying_horn`) with independent recast timers (`186`â€“`189`) and dynamic Lv.10+ crystal unlocking.
- `modules/custom/sql/run_specs.sql` backports RUN `Liement` (`373`), `One for All` (`374`), `Odyllic Subterfuge` (`378`), and `Regen IV` (`477`) to Lv.75, removes merit gating from `Rayke` (`375`) and `Battuta` (`376`), and defines the 7 RUN crystal Job Abilities (`412`â€“`418`: `iron_battuta`, `runic_aegis`, `runic_convergence`, `effusion_slash`, `overcharge_runes`, `font_of_life`, `sanctified_ward`) with recast IDs `198`, `199`, `201`â€“`205`.
- Client launcher, XIPivot DAT overlay (`dat-overlay/ROM`), and Ashita v4 UI addon (`soulspire_talents.lua`, `/talents` or `/tal`) live in **[Infomatictek/overlordsxi-launcher](https://github.com/Infomatictek/overlordsxi-launcher)**.

Twelve small engine patches are required:

- `patches/0001-allow-eos-custom-pet-and-effect-ids.patch` raises `MAX_PETID` from `128` to `129` and `MAX_EFFECTID` from `814` to `815`.
- `patches/0002-eos-deterministic-level-and-subjob.patch` makes Eos spawn at the master's level and correctly initializes her SCH main job / SMN subjob levels.
- `patches/0003-unlock-all-player-weaponskills.patch` unlocks all implemented player weaponskills at level 1 for any job wielding that weapon type (excluding NPC/event/unimplemented WSes).
- `patches/0004-dynamic-ws-skillchain-traits.patch` reads per-cast `OX_WS_SC1..3` localVars inside `CCharEntity::OnWeaponSkillFinished` so talent-upgraded skillchain properties apply dynamically on each weaponskill.
- `patches/0005-clear-ws-skillchains-dynamically.patch` clears/overrides WS skillchain slots cleanly when `OX_WS_SC_SET` is present.
- `patches/0006-eos-status-effect-params.patch` configures status effect IDs `789` (stackable Eos Regen) and `814` (hidden faerie Refresh/buff carrier) in C++.
- `patches/0007-spec-ability-unlocks.patch` hooks `xi.soulspire.spec.getExtraAbilities` into `charutils::BuildingCharAbilityTable` (so crystal-gated JAs like **Call Eos**, **Call Titania**, Commander WAR's **Warcry** / custom JAs, and Sensei MNK's **Counterstance** remain hidden until unlocked at Lv.10+) and syncs ability recasts in `recalculateAbilitiesTable()`.
- `patches/0008-titania-sage-pet.patch` raises `MAX_PETID` to `130` (`PETID_FAERIE_TITANIA = 129`) and deterministically spawns Titania at the master's level with `BLM` main job and `RDM` subjob.
- `patches/0009-crystal-socket-packets.patch` adds custom packets `0x11F` (`GP_CLI_COMMAND_CRYSTAL_SOCKET`, C2S) and `0x1FF` (`GP_SERV_COMMAND_CRYSTAL_COLLECTION` `CRYS` / `GP_SERV_COMMAND_CRYSTAL_CATALOG` `CRYC`, S2C) backed by `xi.soulspire.spec` for the Ashita v4 `crystalsocket` Equipment UI.
- `patches/0010-spec-trait-sync-and-unlocks.patch` expands `MAX_TRAIT_ID` / `CCharEntity::m_TraitList` to `256` (`32` bytes matching `GP_SERV_COMMAND_COMMAND_DATA`), overrides `CCharEntity::hasTrait`, refreshes spec crystal mods/listeners/UI on every `charutils::BuildingCharTraitsTable` rebuild (job change, subjob change, level change, level sync), and injects crystal-gated custom Job Traits (`xi.soulspire.spec.getExtraTraits`) directly into the Traits menu.
- `patches/0011-commander-status-effects.patch` raises `MAX_EFFECTID` to `832` and configures custom status effect IDs `815`â€“`826` (`commander_breach`, `commander_bulwark`, `commander_cadence`, `commander_regroup`, `berserker_bloodlust`, `gladiator_bastion`, `inquisitor_battuta`, `inquisitor_aegis`, `inquisitor_converge`, `spellblade_overcharge`, `lifebinder_font`, `lifebinder_sanctuary`).
- `patches/0012-dot-damage-log.patch` attributes player/pet/trust DoT ticks on mobs (`Dia`, `Bio`, `Poison`, `Burn`/`Frost`/`Choke`/`Rasp`/`Shock`/`Drown`, `Requiem`, `Kaustra`, `Geo-Poison`, `Helix`) and emits parser-friendly `0x017` `MESSAGE_SYSTEM_3` combat log lines (`"<Caster>'s <Effect> deals <Amount> point(s) of damage to <Mob>."`).
- `patches/0037-crystal-swap-busy-state.patch` fixes the Crystal Socket UI falsely rejecting idle players as busy, and leaves combat-swap policy to `xi.soulspire.spec.canSwap()`.

The pet and status patches keep Eos and Titania deterministic without editing LSB's jug-pet randomization globally. Patches `0003`â€“`0005` power the per-character weaponskill unlock and talent skillchain system. Patches `0007`, `0010`, and `0011` allow job crystals to dynamically grant and hide ability and trait menu entries per character, run custom crystal tactical status effects cleanly, and keep crystal passives synchronized across all job/level/sync transitions.

## Client Launcher & Client Files

The distributable Windows client launcher (`SoulspireLauncher.exe`), XIPivot DAT overlay, and `soulspire_talents` Ashita v4 addon are maintained in **[Infomatictek/overlordsxi-launcher](https://github.com/Infomatictek/overlordsxi-launcher)**:

- **For Players**: Download `SoulspireLauncher.exe` from **[overlordsxi-launcher Releases](https://github.com/Infomatictek/overlordsxi-launcher/releases)** and click **PLAY SOULSPIREXI** (auto-installs Ashita v4, `xiloader.exe`, XIPivot, the SoulspireXI DAT overlay, and `soulspire_talents`).
- **For Server Hosts**: Place an `overlords-server.json` next to `SoulspireLauncher.exe` (generated via **Graphics & Settings -> Export Shareable overlords-server.json**) to point players to your server host/IP.

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
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\soulspire_job_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\soulspire_ws_catalog.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\soulspire_ws_talents.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\soulspire_ws_tree_helpers.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\soulspire_ws_trees_*.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\soulspire_ws_overrides.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\eos_companion.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\sch_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\war_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\mnk_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\run_specs.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\dot_damage_log.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\lua\soulspire_job_spec_runtime.lua .\modules\custom\lua\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\commands\spec.lua .\modules\custom\commands\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\commands\eos.lua .\modules\custom\commands\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\commands\talent.lua .\modules\custom\commands\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\cpp\eos_companion.cpp .\modules\custom\cpp\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\cpp\kazenoeye_sync.cpp .\modules\custom\cpp\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\sql\eos_companion.sql .\modules\custom\sql\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\sql\sch_specs.sql .\modules\custom\sql\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\sql\war_commander_abilities.sql .\modules\custom\sql\
Copy-Item -Recurse -Force C:\path\to\overlordsxi\modules\custom\sql\run_specs.sql .\modules\custom\sql\
```

Add these lines to `modules/init.txt`:

```text
custom/lua/soulspire_job_specs.lua
custom/lua/soulspire_ws_catalog.lua
custom/lua/soulspire_ws_talents.lua
custom/lua/soulspire_ws_overrides.lua
custom/lua/eos_companion.lua
custom/lua/sch_specs.lua
custom/lua/war_specs.lua
custom/lua/mnk_specs.lua
custom/lua/run_specs.lua
custom/lua/dot_damage_log.lua
custom/lua/soulspire_job_spec_runtime.lua
custom/cpp/eos_companion.cpp
custom/cpp/kazenoeye_sync.cpp
custom/sql/eos_companion.sql
custom/sql/sch_specs.sql
custom/sql/war_commander_abilities.sql
custom/sql/run_specs.sql
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

The DAT overlay lives in **[Infomatictek/overlordsxi-launcher](https://github.com/Infomatictek/overlordsxi-launcher)** under `dat-overlay\ROM` and is synced automatically by `SoulspireLauncher.exe` (or can be copied manually into your custom DAT loader path such as `C:\DATs\Overlords`).

The overlay updates:

- ability display ID `743` (`231 + 512`) to show `Call Eos`
- ability display ID `801` (`289 + 512`) to show `Call Titania`
- ability display IDs `908`â€“`911` (`396`â€“`399 + 512`) to show WAR Commander's custom JAs (`Tactical Breach`, `Formation: Bulwark`, `Battle Cadence`, `Rallying Horn`) with recast IDs `186`â€“`189`
- ability display IDs `924`â€“`930` (`412`â€“`418 + 512`) to show RUN crystal custom JAs (`Stance: Iron Battuta`, `Stance: Runic Aegis`, `Runic Convergence`, `Effusion Slash`, `Overcharge Runes`, `Font of Life`, `Sanctified Ward`) with recast IDs `198`, `199`, `201`â€“`205`
- Call Eos / Call Titania target metadata to self (`validTarget = Self`)
- Call Eos / Call Titania client recast metadata to the DAT-safe cap
- custom Job Trait IDs `140`â€“`152` (display IDs `1676`â€“`1688`, `1536 + traitId`) to show crystal traits in the in-game Job Traits menu (`Commander's Tactics`, `Berserker's Fury`, `Gladiator's Bastion`, `Sensei's Flow`, `Medic's Grace`, `Sage's Wisdom`, `Bladewheel Mastery`, `Harbinger's Drain`, `Dark Pact`, `Grim Conversion`, `Inquisitor's Ward`, `Runic Brand`, `Sacred Pulse`; up to Trait ID `255` supported)
- Orphic Egg item text to show Eos & Titania Refresh scaling

The server enforces the real 5 minute recast.

## Job Specs / Crystals

The package includes a reusable **Job Crystal / Spec** system (`soulspire_job_specs.lua`) with session-safe scaling passive modifiers (`soulspire_job_spec_runtime.lua`), an interactive `customMenu` crystal selector (`!spec`), and a silent `[OXSPEC]` sync protocol for custom Ashita v4 UIs. Spec choices are persisted as character variables, one per job (`OX_SPEC_<JOB>`, e.g. `OX_SPEC_WAR`, `OX_SPEC_SCH`, `OX_SPEC_RUN`).

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
!gear tp
!gear ws
!gear menu
!gear <level> [weapon]
!gear <weapon> [level]
!gear role <tp|ws|tank|ranged|caster>
!gear level <1-99>
!gear info
```

### Warrior Crystals (`OX_SPEC_WAR`, Lv10+)

- `commander` / **Commander** (*Active Tactical Buffer*): Passives (Lv10/30/50+) `+5/8/12% Max HP`, `+8/16/28 Attack`, `+6/12/20 Acc`, `+4/8/12 Store TP`; unlocks **Warcry** at **Lv10** on a **60s cooldown** (`45s` duration, single-stance party share for Berserk/Defender/Aggressor/Retaliation/Restraint); also unlocks **4 active Lv.10+ tactical JAs** with 2s animation lock & Lv10/30/50/70+ scaling â€” **Tactical Breach** (`396`, 20s CD, 10s mark, Enemy 15y: `+12/18/24/30%` Skillchain DMG, `+8/12/16/20%` Magic Burst & Crit DMG, `+100/150/200/250` SC closer TP), **Formation: Bulwark** (`397`, 25s CD, 15s, Party 10y: stacking Phalanx `8 + 0.45*Lv`, `+5/10/15/20` MDEF, `+12/18/25/35` Status Resist, `+30/50/75/100%` Knockback Resist), **Battle Cadence** (`398`, 20s CD, 12s, Party 10y: `+12/18/24/30` Subtle Blow & `+0/0/5/10` SB II, `+10/15/22/30` Conserve TP, `+8/12/16/20%` Cure Rcvd), and **Rallying Horn** (`399`, 45s CD, 12s, Party 12y: progressive Slow/Bind -> Weight/Para -> DEF/MDEF Down -> Atk/Acc Down cleanse, `+5/7/9/12%` HP heal, `+75/125/175/250` TP, `+8/10/12/15%` Move Speed).
- `berserker` / **Berserker** (*Fury / Heavy Burst DPS*): Passives (Lv10/30/50+) `+8/12/16% Attack`, `+6/10/14% Double Attack`, `+5/8/12% WS Damage`, `+5/10/15 Store TP`; **Berserk** gains `+10% extra Attack%`, `+60s` duration, and `+300 TP` on activation; **Aggressor** loses its `-25 Evasion` penalty and gains `+5% Crit Rate`; **Blood Rage** gains `+10% Crit Rate` and `+15s` duration; **Warcry** gains `+8% Attack%`.
- `spartan` / **Spartan** (*Phalanx Spear-Wall & Grit Barrier Tank*, in-place replacement for Gladiator; `gladiator` stays a silent alias): requires a Polearm + Size-1 Buckler (or empty SUB for a virtual Aspis Buckler). Passives (Lv10/30/50/70+) `+12/16/20/25% Max HP`, `+8/14/20/26 VIT`, `+14/20/26/32% DEF` (`+12/24/36/48` Shield DEF), `-8/11/14/18% Damage Taken`, `+60/80/100/120 Enmity` (+20/30/40/50% retention), `+15/25/35/50` Polearm & Shield skill, `+10/16/22/28% Block`, `+15/25/35/45 Shield TP`; Tier 6 `-60%` dealt. **Spartan's Grit** (+1 per hit taken/block, max 5) is spent by any Polearm WS for an **Iron Resolve** barrier (`4/5/6/7%` Max HP per stack, cap `35%`/`40%` with a real Buckler). **Impaling Thrust** (ID 402, 20s) and **Phalanx Ward** (ID 403, 35s, 2 Grit, effect 820) plus Defender Light Brace / Phalanx Heavy Brace, Tactical Instinct warnings, Warcry/Provoke Adrenaline Surge and Mighty Strikes 5 Grit.

### Monk Crystals (`OX_SPEC_MNK`, Lv10+)

- `sensei` / **Sensei** (*Staff Evasion & Counter Tank*): Passives (Lv10/30/50+) `+12/22/35 Staff Skill`, `+8/15/25 Acc`, `+12/24/40 Evasion Skill`, `+10/22/38 EVA`, `+5/10/15% EVA`, `+6/12/20 AGI`, `+15/30/50 Parry Skill`, `+5/10/15% Parry Rate`, `+12/22/30% Counter`, `+8/16/28 Counter DMG`, `+15/25/40 Enmity`, `-25/40/60% Enmity Loss`, `+6/10/15% Max HP`, `-5/8/12% DT`; **Staff Deflection & Riposte** (`+12%` Parry Rate w/ Staff, Parrying heals `2% Max HP`, grants `+75 TP`, `+Enmity`, & ripostes the attacker; Evading grants `1.5% Max HP`, `+50 TP`, `+Enmity`, & deals an **Evasive Counter**); unlocks **Iron Counterstance** at **Lv10** on a **120s** cooldown (`+30% Counter`, `+20 Counter DMG`, `-10% DT`, `+20 Enmity`, **no DEF halving penalty**); enhances **Dodge** (`60s`, `+25 EVA`, `+15% EVA%`, `+12% Parry Rate`, `+15 Enmity`, `+35% Evasive Counter DMG`), **Focus** (`+15% Counter`, `+15 Parry Skill`, `+10 Counter DMG`), **Boost** (w/ Staff: `+15 Enmity`, `+50 TP`), **Chi Blast** (heavy Enmity + `Accuracy Down`), **Chakra** (`+50%` potency, Regen, cleanses Slow & Silence, +Enmity), **Perfect Counter** (`45s` CD, `+25 Counter DMG`, `+25 Enmity`, `5% HP` heal), **Mantra** (party `-5% DT`), and **Inner Strength** (`60s`, `-25% DT`, `+20% EVA%`, `+30 Counter DMG`, `+50 Enmity`).

### Scholar Crystals (`OX_SPEC_SCH`, Lv10+)

- `medic` / **Medic** (*Light Arts / Eos Support*): Addendum: White remains a 2 hour stance, Sublimation charging stores MP twice as fast without HP drain, Cure/Regen spells use Accession-style 10y AoE without consuming Stratagem charges, and **Call Eos** (`231`) is dynamically unlocked at Lv.10+ (hidden otherwise; Eos despawns if removing or suspending the Medic crystal).
- `sage` / **Sage** (*Dark Arts / Helix Master & Titania*): Addendum: Black remains a 2 hour stance, Ebullience is permanent for black magic, Helix damage is increased by 50%, Helix duration is extended to 2 hours, magic attack bonus is increased by 30, elemental magic gets a 10% target Magic Evasion bypass as bonus accuracy, and **Call Titania** (`289`) is dynamically unlocked at Lv.10+ (summons a Dark Pixie companion that enfeebles, drains/aspirs, and elemental nukes; Titania despawns if removing or suspending the Sage crystal).

### Samurai Crystals (`OX_SPEC_SAM`, Lv10+)

- `ronin` / **Ronin** (*Mushin Seigan & Stagger Tank*): Open weapon choice; requires Great Katana for passives (`+12/16/20/24% Max HP`, `+14/18/22/26% DEF`, `-12/15/18/22% DT`, `+10/18/26/36 MEVA`, `+25/35/45/60 Enmity`, `+15/20/25/30% Enmity Retention`, `+10/16/22/30 Parry`, `-8% Attack%`), unlocks **Seigan** (`15s` CD: `-8/10/12/14% DT`, `+12/15/18/20% DEF`, `+25/30/35/40 Enmity`, `+12/15/18/20% Counter`), **Third Eye** (`15s` CD under Seigan, `2-3` **Mind's Eye** anticipation charges countering melee swings and single-target mob TP moves for `+60 TP` & high Enmity), **Mushin Stagger** (`25-30%` hit deferral into a 9s pool purified by Tachi WSs, **Meditate**, and **Blade Bash**), **Warding Circle** (`120s` CD party `-8% DT` & `+15 MEVA`), and **Meikyo Shisui** (`-20% DT` + instant Mind's Eye).
- `imperialarcher` / **Imperial Archer** (*Oisoya Bow & Blade Skirmisher*): Tenzen-inspired ranged & melee switch-hitter; raises **Archery to A+** (`+66 @ Lv.75`), grants `100% Recycle` (0 arrows consumed), enables `20y` **Bow** auto-attacks outside melee with zero point-blank Bow penalty, and unlocks **Oisoya Shot** (`432`, `25s` CD, `20y` Enemy: `+200-350 TP`, primes `Chainbound`, grants **Drawn Oisoya**). Tachi WSs grant **Drawn Oisoya** (buffing next Archery WS with `+TP Bonus`, `+R.Atk%`, and `+125 TP` refund); Archery WSs grant **Cosmic Brand** (buffing next Tachi WS with `+18-40% SC DMG` and `+125 TP` refund); closes Skillchains via **Cosmic Elucidation** (`+12-30% SC DMG` & `+100 TP`). **Hasso** works with Bow or Great Katana.
- `warlord` / **Warlord** (*Iaijutsu & Onimaru Melee DPS*): Requires Great Katana for passives (`+8/13/18/24% Atk%`, `+8/15/24/34 Acc`, `+4/7/10/14% Crit Rate`, `+6/11/16/22% Crit DMG`, `+4/8/12/16% WSD`, `+10/16/22/30% Zanshin`, `+6/10/15/20 Store TP`); unlocks **Hagakure** at Lv.10+ on a **20s CD** (*Noto* Sheathe-and-Draw turning the next Tachi into an Iaijutsu Draw-Slash with `+35-100% Crit Rate`, `+12-32% Crit DMG`, `+15-30% DEF Ignore`, `+250-600 TP Bonus`, `Save TP`, and `Chainbound`); Tachi WSs stack **Ashura's Edge** (`1-3x`: `+Atk%`, `+Ability Haste`, `+Zanshin` & `25%` melee blood-leech); Skillchains trigger **Onimaru Blood-Quench** (`+10-25% SC DMG`, `5-8% Max HP` heal, & `+125 TP`).

### Rune Fencer Crystals (`OX_SPEC_RUN`, Lv10+)

- `inquisitor` / **Inquisitor** (*Hybrid Stance-Swapping Ward Tank*): Passives (Lv10/30/50/70+) `+8/12/16/22% Max HP`, `+10/18/26/36% DEF`, `-5/8/12/16% DT`, `-6/10/14/18% MDT`, `+15/28/42/60 Parry Skill`, `+6/10/14/18% Parry Rate`, `+18/30/45/65 Enmity`, `-25/40/55/70% Enmity Loss`, `+10/16/22/30 MEVA`; unlocks **3-Rune Mastery** at Lv.10+; **Parry & Runic Riposte** heals `2% Max HP`, restores `1.5% Max MP`, grants `+60 TP` & Enmity, and deals an elemental counter-slash on every Parry; **Swipe / Lunge / Gambit / Rayke** do **not** consume runes and generate heavy bonus Enmity; **Vallation / Valiance** grant party Phalanx & `-10% DT`; **Pflug / Battuta / Liement / One for All** gain extended durations & mitigation; unlocks **Stance: Iron Battuta** (`412`, 10s CD: physical parry/counter stance + transition AoE Enmity flash), **Stance: Runic Aegis** (`413`, 10s CD: magic ward stance + transition 10y party Stoneskin), and **Runic Convergence** (`414`, 45s CD, 15s: runs both stances simultaneously + `15% Max HP` heal & 10y party `-10% DT`).
- `spellblade` / **Spellblade** (*Greatsword & Conduction Elemental Spellweaver DPS*): Main-job RUN with Greatsword only; raises **Greatsword skill to A+**, grants **A-rank Elemental Magic skill**, and sets **Enhancing Magic skill to B-rank**; **Single-Press Rune Enchantment** fills all unlocked rune slots (`1` at Lv.5, `2` at Lv.35, `3` at Lv.65; `5m` duration, `5s` shared recast, `8` opposing-element resistance per rune at Lv.75) with a single element (`Ignis`, `Gelus`, `Flabra`, `Tellus`, `Sulpor`, `Unda`, `Lux`, `Tenebrae`) of equal base offensive potency; **Rune Edge** triggers once per normal Greatsword attack round on the first landed hit for `floor((0.08*GS + 0.04*Enh + 4*runes) * delay / 480)` elemental damage (`0` TP, no crit/MB/wall buildup, not multiplied by DA/TA/OAT/WS/Counters); **Conduction** (`827`, Lv.15+) grants `1` stack (max `3`) per landed normal Greatsword attack round (including `0`-damage physical hits & magic resists, surviving target/armor swaps and clearing on weapon/grip swap or `30s` disengaged) and restores delay-adjusted fractional MP (`1/2/3 MP` at Lv.15/40/65) on positive Rune Edge damage; unlocks **Runic Bolt** (`415`, Lv.15+, `2.0s` cast, `8s` CD, `8â€“24 MP`, `10y`: `floor(1.15*Elem + 0.50*INT)`) and **Runic Sever** (`416`, Lv.55+, `3.0s` cast, `30s` CD, `40 MP`, `10y`: `floor(1.75*Elem + 0.80*INT)`), where each Conduction spent reduces base cast time by `0.5s` and base MP cost by `15%` (`0.5s / 13 MP` for Bolt and `1.5s / 22 MP` for Sever at 3 stacks at Lv.75) with full era magic accuracy/MAB/MB/accumulative wall resolution and preserved Conduction on interrupt; **Edgeflare** (`824`, Lv.30+) increases Rune Edge damage by `+25%` for `12s` after a positively damaging Bolt or Sever (clears on element change); reworks **Swordplay** (`Lv.20+`, `+10 ACC & MACC` for `60s`, `180s` CD), **Vallation** (`Lv.40+`, spends `1â€“3` Conduction for `10/20/30%` opposing-element damage reduction for `15s`, self-only, `120s` CD), **Gambit** (`Lv.70+`, spends `3` Conduction so the target takes `1.10x` positive damage from the active rune's element from all attackers for `20s`, `180s` CD), and **Runic Ascendance** (`828`, 2-hour override: `+50%` Rune Edge potency â€” `+75%` with Edgeflare â€” and `2` Conduction per qualifying round for `30s`).
- `lifebinder` / **Lifebinder** (*Vivacious Pulse & Runic Mending Healer*): Passives (Lv10/30/50/70+) `+10/18/26/35% Max MP`, `+8/15/24/35 MND`, `+15/28/42/60 Healing & Enhancing Skill`, `+12/18/24/30% Cure Potency`, `+10/15/20/25% Fast Cast`, `+2/4/6/9/tick Refresh`, `+10/16/22/30 Cure Spellcasting Time -%`, `-15/22/30/40 Enmity`; unlocks **3-Rune Mastery** at Lv.10+; unlocks **Sacred Pulse** (**Vivacious Pulse** `383` at Lv.10+ on a **15s CD** as a **12y Party AoE heal** with per-rune **Lux** AoE Regen, **Unda** progressive debuff cleanse, **Tenebrae** AoE MP restore + Refresh, and **Elemental** `25%` heal Stoneskin); **Runic Lifetap** splashes `35%` of melee damage and `20%` of WS damage as an instant mend to the most injured party member within 15y while restoring `2% Max MP`; **Regen Iâ€“IV** (`+50%` potency, `+60s` duration) and **Cure Iâ€“IV** project to all party members within **10y**; unlocks **Font of Life** (`417`, 25s CD: single-target `35% Max HP` instant mend, 2-debuff cleanse, `+15% Cure Rcvd`, `-12% DT` for 15s) and **Sanctified Ward** (`418`, 45s CD, 15s, Party 12y: `20% Max HP` Stoneskin, `+25/tick` Regen, `+5/tick` Refresh, `-15% DT`).

Spell and ability modules can branch with:

```lua
xi.soulspire.spec.is(player, xi.job.WAR, 'commander')
xi.soulspire.spec.is(player, xi.job.MNK, 'sensei')
xi.soulspire.spec.is(player, xi.job.SAM, 'ronin')
xi.soulspire.spec.is(player, xi.job.SAM, 'imperialarcher')
xi.soulspire.spec.is(player, xi.job.SAM, 'warlord')
xi.soulspire.spec.is(player, xi.job.SCH, 'medic')
xi.soulspire.spec.is(player, xi.job.SCH, 'sage')
xi.soulspire.spec.is(player, xi.job.RUN, 'inquisitor')
xi.soulspire.spec.is(player, xi.job.RUN, 'spellblade')
xi.soulspire.spec.is(player, xi.job.RUN, 'lifebinder')
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
- **WAR Commander Commands**: Ability IDs `396`â€“`399` (display `908`â€“`911`, recast IDs `186`â€“`189`): `Tactical Breach` (`396`), `Formation: Bulwark` (`397`), `Battle Cadence` (`398`), `Rallying Horn` (`399`)
- **RUN Crystal Abilities**: Ability IDs `412`â€“`418` (display `924`â€“`930`, recast IDs `198`, `199`, `201`â€“`205`): `Stance: Iron Battuta` (`412`), `Stance: Runic Aegis` (`413`), `Runic Convergence` (`414`), `Runic Bolt` (`415`), `Runic Sever` (`416`), `Font of Life` (`417`), `Sanctified Ward` (`418`)
- **SAM Crystal Abilities**: Ability ID `438` (display `950`, recast ID `215`): `Oisoya Shot` (`438`)
- **RUN Crystal Traits**: Trait IDs `150`â€“`152` (display `1686`â€“`1688`): `Inquisitor's Ward` (`150`), `Rune Edge & Conduction` (`151`), `Sacred Pulse` (`152`)
- **SAM Crystal Traits**: Trait IDs `158`â€“`160` (display `1694`â€“`1696`): `Ronin's Mushin` (`158`), `Oisoya Mastery` (`159`), `Onimaru's Iaijutsu` (`160`)
- Commander & WAR custom status IDs: `815` (`commander_breach`), `816` (`commander_bulwark`), `817` (`commander_cadence`), `818` (`commander_regroup`), `819` (`berserker_bloodlust`), `820` (`gladiator_bastion` / Spartan Phalanx Ward)
- RUN custom status IDs: `821` (`inquisitor_battuta`), `822` (`inquisitor_aegis`), `823` (`inquisitor_converge`), `824` (`spellblade_edgeflare`), `825` (`lifebinder_font`), `826` (`lifebinder_sanctuary`), `827` (`spellblade_conduction`), `828` (`spellblade_ascendance`)
- SAM custom status IDs: `837` (`ronin_stagger`), `838` (`imp_drawn_oisoya`), `839` (`imp_cosmic_brand`), `840` (`warlord_noto`), `841` (`warlord_ashura`)
- Eos Regen status ID: `789`
- Faerie hidden Refresh/buff carrier status ID: `814`
- Orphic Egg item ID: `18256`
- Orphic Egg Faerie Refresh mod ID: `1198`
