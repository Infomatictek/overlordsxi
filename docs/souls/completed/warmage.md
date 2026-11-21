# Warmage implementation report

BLU Soul `warmage` (WMG), Tier 1 damage. Equip its Soul Crystal or use `!spec set warmage` at Lv. 10. The gear profile offers a normal sword. Sword and Club are the permitted WS families, and the core loop works with zero WS talents and any subjob.

- Chain Affinity (94, launcher 606) becomes **Assess Prey**. It examines the engaged target within 15 yalms for eight seconds on a 12-second recast. All tied least-resistant categories available at the player's level qualify. Matching Blue Magic gains 12/15/18/20% post-resistance damage at Lv. 10/30/50/70+.
- Lv. 10 starts with Sprout Smack → **Briar Hammer**, Power Attack → **Needle Lunge**, and Foot Kick → **Razor Heel**. Lv. 30 adds Bludgeon → **Skullbreaker Volley** and Smite of Rage → **Iron Cleave**.
- Lv. 50 adds Jet Stream → **Gale Knuckle**, Mandibular Bite → **Serrated Bite**, and Bomb Toss → **Ember Charge**. Lv. 70 adds Death Scissors → **Guillotine Shears**, Heat Breath → **Furnace Breath**, and Mind Blast → **Storm Gaze**. All eleven offensive spells use single-target targeting. Ember Charge, Furnace Breath and Storm Gaze use elemental Blue Magic.
- The read-only Soul set provides unlocked spells without learning prerequisites and suppresses saved-set traits and modifiers while active. The engine preserves the player's saved normal Blue Magic set. The HUD shows ties, assessment duration and recast. See the [player guide](../../guides/warmage.md).

Three focused tests, 107 accessible regression tests, strict Lua wiki and roster checks, 19 native syntax checks, shared Blue Magic Lua syntax and 1,109 launcher manifest checks passed. Launcher commit `d9d6ea9f15983611bff9b7b4d67da2e24bb5ab67`.

**Manual Verification Required** — Live cast and set menus under new character, relog, job change, level sync and other BLU Soul swaps. Verify all eleven animations, names, MP and AoE isolation, real data for defense category choice, party interaction with an Arcane Archer mark, and Lv. 10/30/50/75 combat tuning. Four existing Combat Analytics tests require loopback.
