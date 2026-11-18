# Verdant (GEO) — Playstyle Guide

## At a Glance
Verdant turns Geomancer into a **Luopan-anchored sanctuary healer** (`Healer` tier: -60% personal damage dealt, 0.12x WS scaling). While a **Luopan** is deployed, every combat tick pulses **Verdant Bloom** (party heal + MP + Barkskin Stoneskin from overheal), and every **Cure, Indi, Geo spell, or Club/Staff WS** heals your Luopan back to 100% HP while firing **Nature's Surge** (16% party heal + cleanse)!

## Setup & Gear
- **Weapon / Gear:** **Club + Shield (or Staff) + Handbell.** Club or Staff WSs are required to trigger Nature's Surge / Canopy bonus heals from Weaponskills.
- **Priority Stats:** Max HP (almost every heal scales off **GEO Max HP**!), MND, Cure Potency, Fast Cast, Geomancy/Handbell/Healing skill.

## How to Play (Step-by-Step)
1. **Plant Your Luopan Immediately (`Geo-*`):** Summon a `Geo-*` Luopan right on the pull (`Bolster` doubles Verdant Bloom!). As long as your Luopan is alive in combat, every 3s `Verdant Bloom` automatically heals the 15y party for **6–12% GEO Max HP** (`12–24%` in Bolster), restores **+15 MP**, and turns overhealing into **Barkskin Stoneskin** (up to 25% target Max HP).
2. **Keep `Nature's Surge` Rolling (`Spells & Club/Staff WSs`):** Every `Cure`, `Indi-*`, `Geo-*`, or **Club/Staff WS** heals your Luopan straight back to **100% HP** and triggers **Nature's Surge** (**16% GEO Max HP party heal + 1-debuff cleanse**, 15y).
3. **Protect & Overheal Window (`Canopy of the Ancients`):** Press `Canopy of the Ancients` (25s CD, 12s) to grant 15y allies `-15% DMG` ward + **Knockback Immunity** — AND for those 12s, **every Magic cast or Club/Staff WS adds an extra +10% party AoE heal**!
4. **Emergency HoT & Luopan Reset:**
   - `Verdant Renewal` (20s CD): **30% party HP heal + 3-debuff cleanse** + 15s Hybrid Regen (`25 + 3.5% Max HP/t`) + `+8/t` Refresh.
   - `Life Cycle` (15s CD, **0 self-HP loss**): full-heals your Luopan to 100% HP AND heals the party for **25% GEO Max HP**.

## Key Mechanics & Stacks
- **Self-Sustaining Luopan:** Because every Cure, Indi, Geo spell, and Club/Staff WS tops your Luopan back to 100% HP, simply casting normally keeps your Luopan healthy.
- **GEO Max HP Scaling:** Just like Wyvernheart, stacking Max HP + Cure Potency directly scales your party heals and Barkskin shields.

## Common Mistakes (Don't Do This)
- **Never let your Luopan stay unsummoned:** Without a Luopan on the field, `Verdant Bloom` pauses completely (`COMBAT_TICK` checks `hasPet()`).
- **Note `Verdant Bloom` ticks only while engaged/in combat:** Out of combat, rely on `Verdant Renewal` or casting spells for heals.
