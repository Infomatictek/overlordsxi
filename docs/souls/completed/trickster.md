# Trickster (THF) — Soul Implementation Report

**TRK · Tier 3 Support · Crystal slot THF 1 · Lv.10–75**  
Select with `!spec set trickster` or Crystal Socket. Verified against the canonical roster.

## Combat loop and progression

Use **Pass the Blame** while lined up behind the party member who should receive threat. The next qualifying attack applies the native positional enmity rule. Land a damaging Dagger or Sword WS to apply 16 seconds of **Suppression**, a single-target Attack Down. Existing or rejected Attack Down and missed WS preserve the 20-second internal cooldown. Suppression works alone at Lv.10 with a basic WS, ordinary gear and zero talents.

| Lv. | Attack Down | Dagger / Accuracy / DEX / Subtle Blow / Enmity |
|---|---|---|
| 10 | 5% | +12 / +10 / +6 / +5 / −8 |
| 30 | 7% | +20 / +16 / +10 / +8 / −12 |
| 50 | 9% | +30 / +24 / +15 / +12 / −16 |
| 70–75 | 12% | +42 / +32 / +20 / +16 / −20 |

Dagger and Sword are the approved WS families. Native TP generation and talent rules apply. The kit has no companion, personal damage loop or tank mitigation. Trusts remain accessible.

## Native action and HUD

**Pass the Blame** uses server/client ability 76/588 at Lv.10. It is self-targeted with a 20-second position window and 35-second recast. The HUD shows the positional window, Suppression recast, and whether the enemy already has Attack Down. The [player guide](../../guides/trickster.md) and native action generate in the wiki.

**Launcher commit:** `860f5cacf6c17ec5c264b34a2d9cad85e3449648` on `feat/final-25-souls`.

## Verification

- Three focused tests and 73 non-loopback regression tests passed. Covered solo Lv.10 suppression, miss and immunity, preservation of existing effects, Lv.75 potency, weapon restrictions, timing and Soul cleanup.
- Strict coverage audit: 49 registered and 17 planned. Exact Lua wiki validation and all 1,109 manifest entries passed.
- Applied the overlay after preceding Soul patches and syntax-checked twelve affected or regression-sensitive C++ units.
- **Manual Verification Required:** Use ordinary Dagger and Sword at Lv.10/30/50/70/75. Verify native enmity destination behind/without an ally, attack-down strength and immune bosses, status/ability name presentation, HUD timing, and Bandit/Trickster switching.
