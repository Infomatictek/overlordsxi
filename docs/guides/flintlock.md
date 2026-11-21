# Flintlock (COR) — Playstyle Guide

## At a Glance
Flintlock is a Tier 1 **single-target Gun damage** Corsair. Its currently implemented combat loop centers on **Deadeye Chamber** self-buffs, **Quick Draw** applying **Powder Mark**, and a Marksmanship weapon skill detonating that mark for extra fire damage and TP. **Hair Trigger** creates a short offense-first burst window, while **Broadside Salvo** provides an additional shot and resources. Unlike support Corsairs, Flintlock does not maintain party rolls or provide a healing rotation.

## Setup & Gear
- **Unlock:** Equip Flintlock's Soul Crystal or use `!spec set flintlock` at Lv. 10.
- **Required weapon:** Equip a **Gun** in the ranged slot and compatible **bullets** in ammo. The server can provision an early Firefly gun and Bronze Bullets when the appropriate starter slots are empty.
- **Stats:** Prioritize Ranged Accuracy, Ranged Attack, AGI, Snapshot, Rapid Shot, Marksmanship skill and ranged critical bonuses.
- **Ammo and cards:** The Soul grants full bullet/card **Recycle** in its current server definition; still verify your active gun and ammunition before using ranged attacks.
- **Role:** Rely on your tank to hold hate. Hair Trigger reduces personal Defense, and Flintlock has no special healing mechanic in this implemented kit.

## How to Play (Step-by-Step)
1. **Apply Deadeye Chamber:** Use the self-only **Deadeye Chamber** action for the 30-second weapon-skill and critical damage buff. It has a 15-second recast; it is not a party roll or a Double-Up minigame.
2. **Prepare the target:** Use an available **Quick Draw** charge to mark the intended single enemy with **Powder Mark**, which lasts 10 seconds.
3. **Detonate with Marksmanship:** Before the mark expires, land a **Marksmanship weapon skill** against that same enemy with a Gun equipped. Your own valid mark is consumed for extra fire damage and **150 TP**.
4. **Use Hair Trigger for concentrated offense:** Activate **Hair Trigger** ahead of a ranged burst or weapon skill. Its 10-second effect increases Triple Shot, Snapshot and weapon-skill damage at the cost of Defense; its ability recast is 30 seconds.
5. **Add Broadside Salvo:** Fire **Broadside Salvo** at a living enemy within 20 yalms for a strong single-target ranged strike, **250 TP** and an additional Quick Draw charge. It has a 22-second recast.
6. **Continue normal ranged attacks:** Use ordinary gun shots and eligible weapon skills to maintain damage between Powder Mark opportunities. Save the next Quick Draw for a weapon skill you can execute promptly.
7. **Use Wild Card when valuable:** The current Flintlock kit allows a self-directed **Wild Card** resource reset, granting TP and restoring available charges or ability recasts according to its server behavior.
8. **Respect encounter timing:** Do not enter Hair Trigger before a major incoming hit or waste Powder Mark when your weapon skill is unavailable.

## Key Mechanics & Stacks
- **Deadeye Chamber:** Self-only buff lasting **30 seconds** with a **15-second recast**. Ranged and magical weapon-skill damage rises by **15/20/25/30%** at Lv. 10/30/50/70, plus 15% ranged critical damage.
- **Powder Mark:** Quick Draw uses a charge system, with a **10-second charge recast** and two charges. A marked enemy retains the effect for **10 seconds**. Your own Gun-equipped Marksmanship weapon skill detonates it.
- **Powder Mark payoff:** On a valid detonation the server adds one fire-damage hit scaled from your gun damage and AGI, and grants **150 TP**.
- **Hair Trigger:** 30-second recast, 10-second window; **+30 Triple Shot**, **+30 Snapshot**, **+25 weapon-skill damage**, **-15% Defense**.
- **Broadside Salvo:** 22-second recast, up to 20 yalms; a level-scaling ranged hit grants **250 TP** and restores one Quick Draw charge.
- **Recycle and progression:** Current server definition grants full Recycle. At Lv. 10/30/50/70, Gun-equipped bonuses include Ranged Attack and Magic Attack +15/22/30/40%, Snapshot/Rapid Shot +20/30/40/50, and Marksmanship +15/25/35/50.
- **Threat tradeoff:** Reduced personal enmity scales with level, but the damage kit does not replace party threat control.
- **Current implementation note:** This guide describes the current server's single-Gun Powder Mark gameplay. Any future separate twin-pistol redesign should receive a new guide after it is implemented and validated.

## Common Mistakes (Don't Do This)
- **Trying to trigger Powder Mark with a melee weapon skill:** The detonation requires a Gun and an eligible Marksmanship weapon skill.
- **Letting the ten-second mark expire:** Prepare sufficient TP and a ready weapon skill before spending Quick Draw.
- **Using Deadeye Chamber as a party roll:** This is a self-buff; its value is personal damage.
- **Entering Hair Trigger before unavoidable damage:** The Defense reduction makes the window risky without a tank and healer.
- **Confusing Recycle with having valid equipment:** A Gun and compatible bullets are still required to shoot.
- **Assuming this guide documents a completed twin-pistol system:** The checked server Soul module still exposes the Powder Mark and single-Gun action loop.
