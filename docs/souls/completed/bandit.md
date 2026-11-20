# Bandit (THF) — Soul Implementation Report

**BND · Tier 1 Damage · Crystal slot THF 2 · Lv.10–75**  
Select with `!spec set bandit` or Crystal Socket. Verified against the canonical roster.

## Combat loop and progression

Choose an existing enemy Defense Down opening or create a private one with **Find the Gap**. At weapon-skill start the server records whether that target already qualifies. A damaging Dagger or Sword WS then triggers **Opportunism** if its 12s lockout is ready. A successful claim spends the personal opening. A miss, canceled WS or ineligible weapon leaves the refund available.

Find the Gap is the Lv.10 solo access path. It grants the Bandit a personal condition and applies no party debuff. **Back Alley Strike** rewards attacking from behind. The kit uses standard weapon swings, position and TP with zero weapon-skill talents or support-subjob requirements. It has no pet. The roles of Phantom and Trickster keep their own defense and threat mechanics.

| Effective Lv. | Opportunism TP | Dagger / Accuracy / Attack / DEX / Crit rate / Store TP bonuses |
|---|---|---|
| 10 | 75 | +12 / +10 / +12 / +6 / +3% / +3 |
| 30 | 100 | +22 / +20 / +24 / +12 / +5% / +5 |
| 50 | 125 | +34 / +30 / +38 / +18 / +7% / +7 |
| 70–75 | 150 | +48 / +42 / +55 / +24 / +9% / +10 |

## Native actions and HUD

- **Back Alley Strike** server/client ID 44/556. Lv.10, self, 20s window, 45s recast.
- **Find the Gap** server/client ID 45/557. Lv.10, one enemy within 5y plus normal target hitbox allowance, 15s window, 24s recast.
- Dagger and Sword are the approved weapon-skill families. Native WS skill gates and baseline talent rules apply. Trust summons retain access.
- HUD shows personal/external exposure and the Opportunism lockout. The [player guide](../../guides/bandit.md) and both native actions generate in the wiki.

**Launcher commit:** `3430706a43f05f9844dd0784c076f9e94026873e` on `feat/final-25-souls`.

## Verification

- Three focused tests and 70 local non-loopback regression tests passed. Covered Lv.10 solo, a miss before a hit, empty/canceled WS, weapon rejection, level scaling, effect present at start, and Soul switch cleanup.
- Strict roster audit: 48 registered and 18 planned. Exact Lua wiki validation generated both actions. Launcher TSVs and 1,109 manifest entries passed.
- Applied the native patch on verified LandSandBoat with the earlier Soul patches. Twelve C++ units passed syntax checks, including the weapon-skill state.
- **Manual Verification Required:** Check Lv.10/30/50/70/75 with ordinary gear and zero talents. Test Dagger and Sword, solo opening and ally Defense Down, interrupted/missed WS, a WS that applies Defense Down itself, repeated dummy respawns, TP charge/output, native ability names and the positional status presentation after Soul switches.
