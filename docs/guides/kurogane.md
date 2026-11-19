# Kurogane (NIN) — Playstyle Guide

## At a Glance
**Tier 1 Pure Damage (KRG)** · Unlock at level 10 with `!spec set kurogane`.

Kurogane is designed as a shadow-clone damage dealer inspired by independent Shadow Clone Jutsu fighters. The intended gameplay is offensive only: briefly summon copies of your Ninja that independently use melee, throwing attacks, Ninjutsu, and occasional weapon skills. One damaging AoE can wipe out every copy. No healing, support, tanking, or damage bonus for clone deaths.

**Development status:** The registry, preliminary passive bonuses, and Katana WS profile exist in the draft Kurogane PR. **Live multi-NPC clone spawning, AI, custom JAs, and Utsusemi replacement are not implemented.** The steps below describe the intended playstyle, not currently executable mechanics.

## Setup & Gear
- **Allowed WS weapon:** Katana (`xi.skill.KATANA`). Equip Katana for weapon skill talent access.
- **Priority stats:** STR, DEX, Katana skill, Attack, Accuracy, WSD; offensive Ninjutsu is a secondary damage option.
- **Soul unlock:** Lv.10, `!spec set kurogane`; the canonical crystal abbreviation is `KRG`.
- **Role scaling:** Tier 1 Damage; 0% physical/ranged/magical damage dealt penalty.
- **Passive bonus tiers (Lv10/30/50/70+):** +10/16/22/28 STR/DEX; +15/25/35/50 Katana; +8/12/16/20% Attack; +5/8/12/16% WSD; +5/8/11/14 Double Attack; +5/10/15/20 Store TP; -20/-25/-30/-40 Enmity. These are initial tuning numbers.

## How to Play (Step-by-Step)
1. **Opener (planned):** Engage one enemy and use Utsusemi: Ichi or Ni to spawn several 1-HP shadow NPCs, rather than defensive Utsusemi images.
2. **Core Loop (planned):** Maintain Katana melee pressure while clones act on separate timers. Their weighted decisions include melee strikes, shuriken, damaging Ninjutsu and occasional independently timed WS.
3. **Burst (planned):** Use offensive WS talent choices to shape clone action preferences; Shadow Legion creates a larger staged wave and Phantom Assault briefly increases action frequency. Both abilities need SQL/client IDs and the server entity backend.
4. **Reactive play (planned):** Cast after enemy AoE rather than immediately before it: clones are disposable and have 1 HP. There is no reward for losing them.

## Key Mechanics & Stacks
- **Clone cap (planned):** Ichi 3, Ni 4, normal active cap 5; excess spawns replace oldest copies.
- **Clone lifetime (planned):** Independent 6–10s expiry and combat decisions; on death or expiry the clone vanishes in smoke.
- **Damage ownership (planned):** Player + all clones share the Tier 1 total damage budget. Clones do not produce personal loot or TP, cannot independently select unintended enemies, cannot recursively create clones, and do not trigger uncontrolled skillchains.
- **No stack-based power gain:** Clones do not grant retaliation, defense, or extra damage when destroyed.
- **Kagemusha separation:** Its tank-only Kage Bunshin JA (443), Smoke Lotus (444), and defensive Utsusemi code remain unchanged.

## Common Mistakes (Don't Do This)
- Don't interpret the currently registered Soul as proof that real shadow-clone NPCs are already live.
- Don't summon 1-HP clones into an imminent boss-wide AoE once this system is implemented.
- Don't treat clones as defensive Utsusemi charges or substitute them for tanks.
- Don't assume clones always execute your last WS or move in synchronized formation.
- Don't deploy the draft PR as a completed clone system; the C++ entity backend and gameplay validation are required.
