# Astromancer (BLM) — Soul Implementation Report

**AST · Tier 1 Damage · Crystal slot BLM 1 · Lv.10–75**  
Unlock with `!spec set astromancer` or Crystal Socket. Staff is the only approved WS family. Native TP and baseline talent rules remain in effect.

## Loop and progression

Probe for a favorable element, commit to one uninterrupted Ancient cast, then use probes or reposition while Ancient Magic recovers. Probe damage aligns **Ancient Invocation** to that element, starting from Earth. **Gather Aether** returns 10% max MP on a 90s recast. The role has no defensive or pet abilities and depends on openings and allies for safety.

| Effective level | New decision | INT / M. Attack / M. Accuracy / Max MP |
|---|---|---|
| 10 | Six probes, Ancient Invocation, Gather Aether | +8 / +10 / +8 / +6% |
| 30 | Elemental Survey compares resistance ranks. Starway returns home. | +15 / +18 / +15 / +10% |
| 50 | Six fixed-element advanced Ancient spells | +22 / +28 / +24 / +14% |
| 70–75 | Advanced Ancient bonus rises from 2x to 2.5x before Saturation and caps | +30 / +38 / +34 / +18% |

A completed Ancient cast starts an 18s shared personal recovery. The first damaging Ancient impact starts 20s Astral Saturation on that mob. Follow-ups retain base damage plus 10% of their usual added Soul damage. No damage means no target claim, and follow-ups do not extend the window. At Lv.70+, additional Soul damage on NMs is capped at 3% of encounter-start max HP. Damage follows native resist, mitigation and damage-cap rules. Spells are single-target. Attack speed and TP do not drive the loop.

## Mappings and HUD

- **Probes:** Cinder (144), Rime (149), Gale (154), Bedrock (159), Static Spark (164), Tsunami (169). Lv.10, 1.5s base cast, 3s recast, 4–9 MP.
- **Ancient Invocation:** 160. Lv.10, 4.5s cast, 16% max MP, 18s shared recovery.
- **Utility:** Elemental Survey (235) and Starway (261), Lv.30. Gather Aether server/client ability 75/587, Lv.10.
- **Advanced:** Solar Collapse (204), Rimefall (206), Skybreak (208), Worldsplitter (210), Thunderstar (212), Tidal Cataclysm (214). Lv.50, 7s cast, 22% max MP, 18s shared recovery.
- HUD shows current element, personal recovery, target Saturation and the Gather Aether recast. The [player guide](../../guides/astromancer.md) and all 16 native actions generate in the wiki.
- Native virtual grants and restrictions scope changes to Astromancer. Trust summons remain available.

**Launcher commit:** `2966b5c5b0f2982ef3e25e80733e7d5500620454` on `feat/final-25-souls`.

## Verification

- Four focused Astromancer tests and 58 local non-loopback tests passed. Cases cover probe alignment, recovery, duplicate and unrelated targets, zero damage, cap snapshots, level gates and other-Soul fallback.
- Strict roster audit found 44 registered and 22 planned. Exact Lua wiki generation and all 16 actions validated. Launcher TSVs and 1,109 manifest entries verified.
- Applied the patch following the Zealot and Valkyrie overlays on LandSandBoat `091e7409d1`. Eleven touched or regression-sensitive C++ units passed MSVC syntax checks.
- **Manual Verification Required:** Test Lv.10/30/50/70/75 with ordinary Staff and zero talents, interrupted and absorbed spells, two-client simultaneous impacts, NM and normal-target tuning, native menus, chat and peer identity, plus actual MP costs and cast timers. Compare sustained and burst output with Sage and Zealot.
