# Huntsman (RNG) — Playstyle Guide

## At a Glance
Huntsman transforms Ranger into **The Beast Warden** — a **melee pet-tank Soul** (unlocked at **Lv.10**, capped at **Lv.75**) built around a **one-handed Axe**, an **optional offhand Dagger**, tactical **Warhorn commands**, and two distinct beast companion families.

Your **companion is the actual main tank**. The Ranger remains personally fragile and survives through **Master → Pet threat funneling**, positioning within **8 yalms** for **Beastguard**, timed defensive responses (**Predator's Feint** and **Guardian's Call**), and emergency pet-death recovery (**Last Whistle**).

## Setup & Equipment
- **Main Hand:** One-handed **Axe** (primary combat weapon; required for `Warden's Ration`).
- **Optional Offhand:** **Dagger** (Huntsman grants Soul-specific **Dual Wield** at Lv.10+ without needing `/NIN`).
  - **Single-Axe** is fully viable and receives extra Accuracy (`+10/14/18/22`) and Store TP (`+10/14/18/22`).
  - **Axe + Offhand Dagger** trades a bit of single-axe Store TP for Evasion (`+6/10/14/18`) and improves **Predator's Feint** (`+15` extra EVA and `-5s` cooldown).
- **No Auto-Provisioned Ranged Gear:** Huntsman is a melee Soul and no longer auto-equips crossbows/bolts or grants ranged DPS bonuses. Use `!gear` for a level-appropriate 1H Axe (+ optional Dagger) melee loadout.
- **Warhorn Commands:** All tactical commands (`Guardian's Call`, `Rimetusk Gore`, `Saurian Rend`, `Primeval Takedown`) work natively through your Soul Job Abilities. Future custom Warhorn equipment will plug directly into the Huntsman warhorn registry to enhance these commands (they are tactical command gear, not Bard instruments).

## Companion Roles (Shared 60s Summon Cooldown, Max 1 Active Pet)
All Huntsman companions and commands are **100% single-target** so you never pull unintended adds.

### Glacial Tusker — Guardian (`Wild Raaz` Lv.10+ → `Cehuetzi` Lv.75)
- **Identity:** Sustained single-target boss-anchor tank with predictable mitigation and defensive responses.
- **Passives:** `+40/50/60/70%` Pet Max HP, `-28%` DT, `-12%` extra Magic/Breath DT, `+25%` DEF, `+15/25/35/45` MEVA, and `+70/90/110/130` Pet Enmity.
- **`Rimetusk Gore` (30s CD):** Tank-scaled single-target strike with heavy pet threat, `+15%` Pet HP heal, and `-15%` Pet DT for 10s. Apex **Cehuetzi** also applies `Cripple` (`-15%` ATK/MATT, `-20` ACC for 15s).
- **`Primeval Takedown` (45s CD):** Tank-scaled slam with high pet threat, `2s` Stun, and `20%` Pet Max HP Stoneskin (`Permafrost Hide`, 12s).

### Volcanic Saurian — Predator (`Stalker Raptor` Lv.10+ → `Gabbrath` Lv.75)
- **Identity:** Active, agile main-tank companion with faster threat snap, evasion/haste tempo, and enemy interruption.
- **Passives:** `+25/32/40/48%` Pet Max HP, `-18%` DT, `-8%` extra Magic DT, `+15/25/35/45` EVA, `+10/18/26/35` MEVA, `+12/20/28/38` ACC, and `+80/100/125/150` Pet Enmity.
- **`Saurian Rend` (30s CD):** Tank-scaled rend with strong snap threat, `+12%` Pet HP heal, `+25` Pet EVA & `+15%` Pet Haste for 10s, and `Expose` (`-20` EVA/MEVA for 15s). Apex **Gabbrath** also applies `Breach` (`-15%` DEF/MDEF for 15s).
- **`Primeval Takedown` (45s CD):** Tank-scaled interrupt with snap threat, `2s` Stun, `+10%` Pet HP heal, `+200` Pet TP, and `+150` Ranger TP.

## Core Combat Loop & Defensive Tools
1. **Melee Engagement & Threat Funneling:**
   - Fight alongside your companion with your **1H Axe** (or **Axe + Dagger**).
   - Huntsman carries `-20` Master Enmity and funnels **100%** of your single-target melee and WS threat directly to your active companion (both Tusker and Saurian).
   - Cures cast on the Ranger forward real healed + overheal amounts to your active companion (`70%` for Tusker, `55%` for Saurian).
2. **Sustain & Command Readiness (`Warden's Ration`):**
   - Using any **1H Axe Weaponskill** heals your active companion for **`10/12/14/16%` Pet Max HP**, grants **`+200` Pet TP**, and shaves **3 seconds** off active Huntsman command recasts (`6s` internal cooldown).
3. **Positioning for `Beastguard` (Passive AoE Survival):**
   - Stay within **8 yalms** of your living companion while it holds the enemy's attention to reduce incoming eligible **physical and magical AoE/conal damage** by **`25%` (Lv.10) / `28%` (Lv.30) / `32%` (Lv.50) / `35%` (Lv.70–75)**.
   - Does **not** reduce single-target hits or redirect damage to your pet, and turns off immediately if you move out of range or lose pet aggro.
4. **Emergency Evasion (`Predator's Feint` — 45s CD, 40s with Offhand Dagger):**
   - Grants a **3-second** high-evasion window (`+120–150` EVA; `+15` with Dagger), transfers your accumulated single-target threat to your companion, and orders it to re-engage immediately.
5. **Tactical Interception (`Guardian's Call` — 60s CD):**
   - Arms a 10-second window where your companion (within **12 yalms**) intercepts the **next single-target direct attack** aimed at you, taking the hit with its own normal mitigation instead of you. Does not intercept AoE/conal attacks or multi-hit follow-ups.
6. **Pet Death Recovery (`Last Whistle` — Passive, 180s CD):**
   - When your active companion **dies in combat** (never on despawn, swap, or zoning), you gain a **4-second escape window** (`+25%` movement speed, `+80` EVA — you remain vulnerable to damage) and a **15-second** opportunity for an **emergency resummon** (resets summon cooldown; the resummoned companion arrives at **50% Max HP** and **0 TP**).

## Level 10 Starter Experience → Level 75 Apex Progression
- **At Lv.10:** Equip a 1H Axe (plus an optional Dagger if desired), summon **Wild Raaz** (sustained boss anchor) or **Stalker Raptor** (agile snap-threat tank), stay within 8y for **Beastguard**, weave **1H Axe WSs** for **Warden's Ration**, and hold **Predator's Feint** / **Guardian's Call** for spikes.
- **At Lv.75:** Unlock **Cehuetzi** (Glacial Tusker Apex with `Cripple`) and **Gabbrath** (Volcanic Saurian Apex with `Breach`), deepening boss debuff control without invalidating Wild Raaz or Stalker Raptor.
