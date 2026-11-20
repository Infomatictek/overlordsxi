# Scarlet Weaver (RDM) — Soul Implementation Report

**SCW · Tier 1 Damage · Crystal slot RDM 3 · Lv.10–75**  
Select with `!spec set scarletweaver` or Crystal Socket. The canonical RDM design is an offensive Yin/Yang choice with two mutually exclusive forms.

## Combat loop and progression

Start in **Yang** and use a Sword. **Spellweave** enters **Yin** for eligible single-target elemental spells. **Bladeweave** returns to Yang for regular main-hand Sword hits. Use the form that fits the encounter's next opening. In combat, a change starts a shared 12-second timer and a two-second window before any form bonus applies. Outside combat, form changes are free. Enspells, extra attacks, offhand hits, weapon skills and skillchains do not gain either bonus.

| Effective level | Form bonus | Unlocks | Sword / Accuracy / DEX / INT / M. Attack |
|---|---|---|---|
| 10 | 15% | Both forms and six elemental stitches | +10 / +10 / +6 / +6 / +8 |
| 30 | 18% | Scarlet Spindle | +18 / +18 / +10 / +12 / +14 |
| 50 | 22% | Violet Shuttle | +28 / +28 / +15 / +18 / +22 |
| 70–75 | 25% | Tempest Loom | +40 / +38 / +20 / +25 / +30 |

Sword is the only permitted WS family. The base loop functions with zero talents and with normal TP and haste rules. Scarlet Weaver depends on allies for healing and defensive windows, and uses no companion or defensive spell rotation. Trust access is retained.

## Native actions and HUD

- **Spellweave** 247/759 and **Bladeweave** 274/786 are self-targeted abilities with the shared Soul recast.
- **Lv.10 stitches:** Searing Needle (144), Rime Stitch (149), Gale Needle (154), Copper Stitch (159), Storm Needle (164), Tide Stitch (169). 1.5s cast and 3s base recast.
- **Progression:** Scarlet Spindle (145) at Lv.30, 2s/6s. Violet Shuttle (165) at Lv.50, 2.4s/7s. Tempest Loom (156) at Lv.70, 3s/12s.
- Contributing casts use native MP cost and resist rules. The HUD shows form, current bonus, recovery and shared recast. The [player guide](../../guides/scarletweaver.md) and all eleven native actions generate in the wiki.

**Launcher commit:** `571a4da93dcd285c4c46b7d8fd2bb1442b3d9b74` on `feat/final-25-souls`.

## Verification

- Three focused tests and 64 local non-loopback regression tests passed, including form exclusivity, free out-of-combat switching, shared recovery, level progression, damage scope and Crimson Duelist fallback.
- Strict roster audit found 46 registered and 20 planned. Exact wiki generation verified all eleven native actions. Launcher TSVs and all 1,109 manifest entries checked.
- Native overlay applies to the pinned LandSandBoat base after prior Soul patches. Eleven touched or regression-sensitive C++ units passed MSVC syntax checks.
- **Manual Verification Required:** With ordinary gear and zero talents, play both forms at Lv.10/30/50/70/75. Confirm swapped timing under enmity, interrupted and mid-action changes, normal versus extra Sword hits, no bonus on WS or skillchain, element resist tuning, packet menus and names, and no leakage to Crimson Duelist.
