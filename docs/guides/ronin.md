# Ronin (SAM) — Playstyle Guide

## At a Glance
Ronin transforms Samurai into a **Great Katana anticipation, parry, and Stagger tank** (`Tank` tier: -60% damage dealt, 0.12x WS scaling, +60–120 baseline Enmity). While `Seigan` is active, 25–30% of incoming damage is **deferred into non-lethal Mushin Stagger** over 9 seconds, which you purify away (and turn into healing & AoE enmity) using **Tachi Weaponskills, `Meditate`, or `Blade Bash`**.

## Setup & Gear
- **Required Weapon:** **Great Katana in Main Hand.** Without a Great Katana equipped, **all Ronin passive stats, `Seigan` tanking mods, Mind's Eye charges, Mushin Stagger, and Tachi Purify shut off.**
- **Priority Stats:** VIT, HP, DEF, Parry, Counter, DT-, Enmity.

## How to Play (Step-by-Step)
1. **Stance & Anticipate:** Turn on `Seigan` (Lv.10+, 15s CD: `-8–14%` DT, `+12–20%` DEF/Counter, `+25–40` Enmity) and press `Third Eye` (15s CD under Seigan -> grants **2 Mind's Eye charges** under Lv.50, **3 charges** at Lv.50+). Each anticipated melee hit or single-target TP move triggers a Great Katana counter-slash (`+60 TP` + high threat).
2. **Defer Hits into `Mushin Stagger`:** Incoming hits >=8 damage defer **30%** (in Seigan; 25% out) into a staggered 9-second non-lethal DoT (capped at 50% Max HP).
3. **Purify Stagger with Tachi WSs & JAs:** Never let Stagger tick down needlessly — spend TP on **Tachi Weaponskills** to instantly **purify 50% of active Stagger**, heal 3–5% Max HP, and pulse 10y AoE enmity!
4. **Full Purify & Emergency Cooldowns:** Use `Blade Bash` (30s CD: 4s Stun, -15% Attack Down, heavy enmity + **100% Stagger Purify**), `Meditate` (60s CD: **100% Stagger Purify**, 15–25% self-heal, AoE threat), `Hamanoha` (90s CD: Atk/Acc Down), `Warding Circle` (120s CD: -8% DT / +15 MEVA + AoE threat), or `Meikyo Shisui` (**100% Stagger Purify**, 3x Mind's Eye, -20% DT, +50 Enmity).

## Key Mechanics & Stacks
- **Mushin Stagger:** Incoming burst gets converted into a 3-tick (9s) non-lethal pool. Clearing it with Tachi WSs, `Meditate`, `Blade Bash`, or `Meikyo Shisui` erases that deferred damage entirely before it hurts you.
- **Great Katana Lock:** Your entire tank kit checks `isGreatKatanaEquipped`.

## Common Mistakes (Don't Do This)
- **Don't unequip Great Katana or fight in `Hasso`:** Using `Hasso` drops `Seigan` mitigation/Mind's Eye counters; unequipping Great Katana turns off all passives.
- **Don't sit at 1000+ TP with heavy Stagger active:** Firing a Tachi WS immediately cuts your pending Stagger in half and heals you!
