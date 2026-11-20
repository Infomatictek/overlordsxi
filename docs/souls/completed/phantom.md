# Phantom (THF) — Soul Implementation Report

**PHN · Tier 6 Tank · Crystal slot THF 3 · Lv.10–75**  
Select with `!spec set phantom` or Crystal Socket. Verified against the canonical roster.

## Combat loop and progression

**Phantom's Dare** challenges an enemy from neutral at Lv.10. The normal native threat/claim path applies base 180 CE and 650 VE. It also arms **Dare Guard** for six seconds. One magical or breath hit consumes the guard and is reduced. Genuine enemy melee misses build further threat with Dagger or Katana. Physical hits, parries, blocks and shadow absorption do not grant evasion threat or consume the guard.

| Effective Lv. | Guard | Evasion threat (CE / VE) | Dagger / Evasion / AGI / Max HP / additional damage taken reduction / Enmity |
|---|---|---|---|
| 10 | 8% | 30 / 85 | +10 / +20 / +7 / +8% / 5% / +20 |
| 30 | 10% | 40 / 115 | +20 / +35 / +12 / +12% / 7% / +30 |
| 50 | 12% | 55 / 150 | +30 / +55 / +18 / +16% / 10% / +40 |
| 70–75 | 15% | 70 / 190 | +42 / +75 / +25 / +20% / 12% / +50 |

Evasion threat has a two-second lockout. Repeated unavoidable attacks remain the weakness once Dare Guard is spent. No support subjob, pet, special TP economy or WS talent allocation is required.

## Native action, weapons and HUD

- **Phantom's Dare** uses server/client ability 41/553. Lv.10, one target at 15y, 18s recast, zero TP.
- Dagger and Katana are the approved WS families. Phantom receives scoped access to Kunai, Wakizashi, Kodachi, Sai and Rai Kunimitsu, plus an effective-level Katana baseline. `!gear` offers a Dagger tank set and supports the permitted families.
- HUD shows Dare cooldown, guard time and evasion readiness. The [player guide](../../guides/phantom.md) and native action generate in the wiki.

**Launcher commit:** `39e03537d8b4b0d3ceeb58afcce8062efd7bb4a0` on `feat/final-25-souls`.

## Verification

- Three focused tests and 76 non-loopback regression tests passed. Covered cold-start enmity input and range, single eligible hit, physical retention, evasion cooldown, level scaling, weapon types and Soul cleanup.
- Strict roster audit found 50 registered and 16 planned. Exact wiki validation, launcher TSVs and 1,109 manifest entries verified.
- Applied the overlay after preceding Soul patches. Twelve touched or regression-sensitive C++ units passed MSVC syntax checks.
- **Manual Verification Required:** Run Lv.10/30/50/70/75 with ordinary gear and zero talents. Verify neutral pull before a healer Cure, real evasion versus parry/shadows, repeated magic/breath, actual 15y client targeting, Katana equip/WS and switch cleanup, native name and HUD timing, and no loot/quest behavior.
