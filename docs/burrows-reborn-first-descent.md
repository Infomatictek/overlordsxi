# SoulspireXI — Burrows Reborn: The First Descent

Status: **Implemented on `feat/burrows-reborn-lv10` (Level 10 Playable Gameplay Prototype — No Rewards)**

## Overview

**Burrows Reborn: The First Descent** is a free, repeatable, reward-free Level 10 tactical Meeble Burrows expedition for **SoulspireXI**, hosted inside LandSandBoat's native instanced Meeble Burrows zone, **Ghoyu's Reverie** (zone `129`, instance `12901`).

- **Zero entry friction**: No pheromone sacks, entry fees, grimoires, prerequisite runs, or replay cooldowns.
- **Effective Level 10**: All participants are synced to Level 10 using SoulspireXI's native non-destructive `xi.effect.LEVEL_RESTRICTION` pipeline (with automatic Soul, combat pace HP, pet, and Shinobi clone rescaling) and restored cleanly on victory, failure, exit, disconnect, or relog.
- **True concurrent party isolation**: Each party receives its own LandSandBoat `CInstance` and isolated dynamic entities (`instance:insertDynamicEntity`), preventing cross-instance interference.
- **Zero rewards**: All expedition mobs suppress EXP, gil, drops, currencies, titles, achievements, and combat/magic skill-ups.

## Burrows Expedition Guide NPC Locations

Fresh Level 10 players can enter immediately from any starting nation or Ru'Lude Gardens by speaking with the **Burrows Expedition Guide** (existing FFXI NPC model `2433`, visible on widescan):

| Hub Zone | Zone ID | Exact Coordinates `(x, y, z, rot)` | Landmark |
| --- | --- | --- | --- |
| **Port San d'Oria** | `232` | `(-2.500, 0.000, -2.000, 64)` | Mog House plaza (4.5 yalms west of Starter Weapons) |
| **Bastok Mines** | `234` | `(80.000, 0.000, -64.102, 109)` | Concourse (3.5 yalms west of Starter Weapons) |
| **Port Windurst** | `240` | `(181.500, -11.999, 217.730, 223)` | Orastery plaza (3.7 yalms west of Starter Weapons) |
| **Ru'Lude Gardens** | `243` | `(3.700, 8.999, -41.341, 128)` | Palace terrace (7.4 yalms east of Starter Weapons) |

Inside **Ghoyu's Reverie**, an in-instance **Burrows Expedition Guide** stands at `(430.9652, 0.5000, 400.6440, rot 238)` to check expedition status or exit safely at any time.

## How to Enter

1. Form a party (or go solo for Low Man). Every member must be **at least Level 10**, alive, and in the same hub zone.
2. Have the party leader speak to the **Burrows Expedition Guide**.
3. Choose a difficulty mode from the native menu:
   - **Low Man (1–3 Players, Lv. 10 Sync)** — balanced primarily around 2 players.
   - **Full Party (4–6 Players, Lv. 10 Sync)** — balanced primarily around 6 players.
4. You are synced to Level 10 and transported directly into an isolated Ghoyu's Reverie chamber at `(458.0, 0.0, 416.0)`.
5. Buff and position at the staging area, then pull **The Burrow Shaman** when ready.

## The Three Connected Encounters

### 1. The Burrow Shaman (Ritual Caster)
- **Enemy**: `The Burrow Shaman` (Lv. 10 Low Man / Lv. 11 Full Party; Full Party adds a Lv. 10 `Burrow Acolyte` for enmity & target priority).
- **Mechanic**: 6 seconds after engagement, the Shaman begins chanting the **Burrow Ward Ritual** (28s Low Man / 26s Full Party).
- **Counterplay**: Interrupt the ritual before it finishes by inflicting **Stun** or **Silence**, landing a **Weapon Skill**, bursting its HP during the channel (`>= 25%` Low Man / `>= 22%` Full Party), or defeating it in time.
- **Boss Impact**:
  - **Interrupted / Defeated**: Grudgeburrow's dark empowerment is **denied**.
  - **Completed**: Grudgeburrow enters **Ritual Empowered** (`+18%` ATK, faster heavy slam & AoE cadences, and `Burrow Tremor` inflicts a 10s Defense Down).

### 2. The Stoneguard (Defensive Stance & Timing)
- **Enemy**: `The Stoneguard` (Lv. 11 Low Man / Lv. 12 Full Party).
- **Mechanic**: Cycles into **Iron Shell Stance** for 12s (`-65%` physical damage taken, `+20` MDEF, melee counter-spikes), followed by an **8s Guard Broken / Exposed** window (`+35%` physical / `+25%` magic damage taken, `-35%` DEF).
- **Counterplay**: Hold heavy melee TP skills during Iron Shell and burst during the Exposed window — or shatter Iron Shell early with elemental magic damage or Defense Down (which also grants a bonus `+5%` Exposed damage window on Grudgeburrow).
- **Boss Impact**: Defeating The Stoneguard shatters Grudgeburrow's stone plating (**-25% DEF, +15% physical damage taken**).

### 3. Grudgeburrow (Final Boss)
- **Enemy**: `Grudgeburrow` (Lv. 12 Low Man / Lv. 13 Full Party, NM scaling).
- **Mechanics**:
  - **Crushing Burrow Slam**: Telegraphed 5 seconds in advance against the primary enmity target. Mitigated by active tank cooldowns (Defender, Sentinel, Rampart, Palisade, Phalanx, Utsusemi) and capped safely to reward tanking & healing rather than one-shotting.
  - **Exposed Core (8s)**: Immediately follows every Crushing Burrow Slam (`+30%` / `+35%` physical damage taken, `+25%` magic damage taken, `-25%` DEF) for coordinated Weapon Skill and Soul bursts.
  - **Burrow Tremor**: Warned 3 seconds in advance; deals manageable earth AoE damage across the chamber (plus 10s Defense Down if the Shaman's ritual completed).

## Technical Architecture

- `modules/custom/sql/soulspire_burrows_first_descent.sql` — Idempotent `instance_list` registration for instance `12901` (`the_first_descent`, zone `129`, 30-minute limit).
- `patches/0046-burrows-reborn-first-descent-instance.patch` — Thin LandSandBoat instance bridge at `scripts/zones/Ghoyus_Reverie/instances/the_first_descent.lua` delegating callbacks to `xi.soulspire.burrows.instance`.
- `modules/custom/lua/soulspire_burrows_config.lua` — Shared configuration, eligibility validation, boss adaptation rules, and JSONL telemetry formatter.
- `modules/custom/lua/soulspire_burrows_first_descent.lua` — Hub & in-instance NPCs, native `customMenu`, multi-instance session manager, Lv. 10 sync/restoration, encounter state machine, zero-reward safeguards, and disconnect/relog recovery.
- `log/burrows_reborn/runs.jsonl` — Structured run telemetry (mode, party size, Souls, encounter outcomes, boss adaptations, duration, `rewards_suppressed: true`).

## Docker Deployment (SoulspireXI Stack)

All server patches, custom Lua modules, and SQL registrations are built and deployed directly through the SoulspireXI Docker stack (`deploy/unraid/`):

```bash
git fetch origin
git checkout feat/burrows-reborn-lv10
cd deploy/unraid
./scripts/soulspire-ctl.sh build burrows-lv10-proto
./scripts/soulspire-ctl.sh deploy burrows-lv10-proto
```

- `build` automatically applies `patches/0046-burrows-reborn-first-descent-instance.patch`, copies `modules/custom/**`, and updates `modules/init.txt`.
- `deploy` automatically backs up MariaDB, applies idempotent `modules/custom/sql/soulspire_burrows_first_descent.sql` (`instance_list` `12901`), rolls out the containers, and runs `verify-deployment.sh`.
- Telemetry logs persist to `${APPDATA_DIR}/logs/burrows_reborn/runs.jsonl`.

## Known Limitations

1. **Native Meeble model placeholder in upstream LandSandBoat**: Stock LandSandBoat `Meeble_Augur` / `Snarling_Meeble` pools in Ghoyu's Reverie currently have `modelid = 0` (invisible placeholder). To avoid DAT edits or invisible enemies, The First Descent uses verified visible Zone 129 models (`Orcish_Hexspinner`, `Old_Quadav`, and `Gigas_Flanker`) with `HP = 0` for authentic Level 10 scaling.
2. **Client-side visual verification pending**: Automated tests validate the full Lua state machine, menus, level sync, multi-instance isolation, encounter adaptations, disconnect/failure recovery, and reward suppression; a live in-game client playtest on the Docker server should still confirm sightlines and combat feel in Ghoyu's Reverie at `(458, 0, 416..446)`.

