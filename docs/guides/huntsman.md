# Huntsman (RNG) — Playstyle Guide

## At a Glance
Huntsman makes Ranger a **Modal Beastmaster Ranger** whose role flips dynamically based on whichever beast you summon:
- **Glacial Tusker Mode** (`Wild Raaz` Lv.10 / `Cehuetzi` Lv.75): **`Tank` Mode** (-60% damage dealt, 0.25x pet mobskill; 100% of your single-target threat goes straight to your AoE/Magic/Breath-immune Tusker).
- **Volcanic Saurian Mode** (`Stalker Raptor` Lv.10 / `Gabbrath` Lv.75 — or no pet): **`HybridSupport` Mode** (-25% damage dealt; your Saurian radiates a 15y party ACC/Attack aura while buffing party TP & damage).

## Setup & Gear
- **Auto-Provisioned Gear:** At Lv.10+, socketing Huntsman **automatically equips a Light Crossbow & 99x Crossbow Bolts** if empty, grants **100% Ammo Recycle**, and eliminates **all ranged distance penalties** (`0` sweet-spot penalty).
- **Pets (60s shared summon CD, max 1 pet):** Choose Tusker when tanking or soloing bosses; choose Saurian when supporting a group.

## How to Play (Step-by-Step)
1. **Choose Your Mode & Summon (60s shared CD):**
   - Summon **Wild Raaz / Cehuetzi** for **Tank Mode** (`+40–70%` Pet HP, `-30%` Pet DT, `+60–120` Pet Enmity, 100% AoE/Breath/Magic immunity, and 80% Cure forwarding from Master).
   - Summon **Stalker Raptor / Gabbrath** for **Pack Support Mode** (`15y` party aura giving +8–20 ACC/RACC & +8–15% ATK/RATK).
2. **Engage at Any Range (0–20y):** Auto-shoot with `OX_AUTO_RANGED`. All your single-target ranged/melee attacks transfer 100% enmity to your Tusker in Tank Mode.
3. **Press Mode-Specific Pet Command (30s CD):**
   - *Tusker:* Use `Rimetusk Gore` (huge pet threat, heals Pet 20% HP, -20% Pet DT for 10s; Cehuetzi also applies `Cripple` -15% ATK/-20 ACC).
   - *Saurian:* Use `Saurian Rend` (heals Pet 15% HP, grants 15y party `+150 TP` & `+15%` ATK/RATK/MATT for 15s; Gabbrath also applies `Breach` -15% DEF/-15 MDEF).
4. **Heal & Fuel Pet with Ranged WSs (`Warden's Ration`):** Every **Archery or Marksmanship WS** heals your pet for `15–22%` Pet Max HP and grants **+250 Pet TP**. Finish/panic with `Primeval Takedown` (45s CD: Tusker gets extra threat + 2s Stun + 25% Stoneskin; Saurian gives Master `+300 TP`).

## Key Mechanics & Stacks
- **Dynamic Role Switching (`MODAL_TIER_RESOLVERS`):** Summoning a Tusker puts you into Tank tier automatically; summoning a Saurian (or dismissing your pet) puts you into Hybrid Support tier automatically.
- **100% Single-Target Design:** All Huntsman pet attacks and JAs are strictly single-target (won't accidentally pull extra adds).

## Common Mistakes (Don't Do This)
- **Don't fire melee WSs expecting `Warden's Ration`:** Only **Archery or Marksmanship Weaponskills** heal your beast and grant +250 Pet TP.
- **Remember the shared 60s summon cooldown:** Swapping between Tusker and Saurian shares one 60s timer (`recastId 256`).
- **Cure forwarding only works with Tuskers:** Healing the Ranger heals the active Tusker (80% + 100% overheal), not Saurians.
