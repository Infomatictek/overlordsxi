# Zealot (WHM) — Soul Implementation Report

**ZEL · Tier 1 Damage · Crystal slot WHM 2 · Lv.10–75**  
Select via `!spec set zealot` or Crystal Socket. Confirmed against the canonical catalog.

## Combat identity and progression

Zealot fights with a two-handed Staff and converts successful main-hand auto-attacks into MP through **Staff Communion**. A damage-dealing attack round can grant MP once per three seconds. Time casts around boss mechanics and use **Consecration** before an opening to increase the next spell that deals damage by 20%. The window lasts 20 seconds and does not consume on interruption, absorption or zero damage. The kit provides no healing, defensive cooldowns or AoE and depends on melee uptime for MP.

| Effective level | Actions and milestones | MP per Communion | Staff / Accuracy / MND / M. Attack / M. Accuracy |
|---|---|---|---|
| 10 | Dawnfire, Consecration | 3.5% | 12 / 10 / 6 / 8 / 8 |
| 30 | Sunbrand | 4% | 22 / 18 / 12 / 14 / 14 |
| 50 | Pillar of Day, Last Light | 4% | 34 / 28 / 18 / 22 / 22 |
| 70–75 | Last Light gains potency and costs 22% MP | 4.5% | 46 / 40 / 25 / 30 / 30 |

The Staff-only WS whitelist uses existing TP, unlock and talent rules. Ordinary melee still uses the equipped weapon and kit spells require Staff. There are no new haste or TP multipliers. The Communion lock bounds the effect of attack speed. No pet or new action, item, trait, or effect ID is required. Trust summons retain native access.

## Native actions and presentation

| Action | Internal spell or server/client ability ID | Base cast / recast | Cost and target |
|---|---|---|---|
| Dawnfire | 28 | 2s / 6s | 8% max MP, one enemy |
| Sunbrand | 29 | 2.5s / 8s | 12% max MP, one enemy |
| Pillar of Day | 30 | 3s / 12s | 16% max MP, one enemy |
| Last Light | 21 | 3.5s / 14s | 20–22% max MP, one enemy |
| Consecration | 74 / 586 | Instant / 90s | Self |

Kit spells are virtual grants, with explicit effective-level and Soul checks and server-supplied menus. Original learned spell records remain intact. The launcher uses scoped action and visibility TSVs. HUD displays weapon readiness, Communion lock, and Consecration window/recast. The [player guide](../../guides/zealot.md) is included in generated wiki data.

**Launcher commit:** `eac622c6f18d3443e8a04b37cde6f8c914eafe23` on `feat/final-25-souls`.

## Verification

- Focused Lua and integration tests passed (4), including Lv.10 loop, level gates, expiration, weapon checks and Bishop fallback.
- Applied the patch stack to pinned LandSandBoat `091e7409d1`. All eight changed C++ translation units passed MSVC syntax checks. A linked server build and game run remain unverified.
- Strict roster audit found 42 registered and 24 planned. Strict wiki generation passed with zero action errors. Nine wiki tests passed, including existing Shinobi identity and the 66-Soul roster. Generated Zealot guide and all five action entries were checked.
- Launcher TSV validation and all 1,109 manifest entries passed. Combat Analytics HTTP integration uses loopback sockets restricted in this environment, including on the baseline.
- **Manual Verification Required:** Confirm Lv.10 with ordinary staff gear, zero talents and no support subjob. Check effective Lv.30/50/70/75, level sync, relog, job/Soul changes during action windup, actual MP/recasts, native menus/macros and nearby-player names with two clients. Run hard-boss Lv.10 and Lv.75 balance checks.
