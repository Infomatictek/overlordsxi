# Reaper implementation report

DRK Soul `reaper` (RPR), Tier 1 damage. Equip its crystal or use `!spec set reaper` from Lv. 10. Ordinary Scythe gear supports the complete Lv. 10 loop. Only Scythe weapon skills are eligible and the core kit works with zero WS talent investment.

- A damaging enemy spell or TP move opens five seconds of recovery when the action finishes. Every sixth ordinary enemy melee round also opens recovery. Multi-target damage resolves once per action, and the enemy's current round count is visible in the HUD.
- Weapon Bash becomes **Finality** (server 77, launcher 589). This four-yalm Finisher has a 16-second recast and deals 1.3× baseline Scythe damage, scaling to 2.3/2.6/2.6/3.0× during recovery at levels 10/30/50/70+. A successful strike spends the opportunity for the acting Reaper. At Lv. 50/70, openings against enemies below 25% HP gain another 15/20%.
- Drain becomes **Grave Toll** (245). The 12 MP, 1.5-second cast deals ranged dark damage, gains 50% during recovery and leaves Finality's opportunity available.
- The launcher shows the target's attack rounds, recovery timer and Finality recast. The wiki lists both Lv. 10 actions with their server recasts. See the [player guide](../../guides/reaper.md).

Passed 3 focused tests, 82 accessible regression tests, strict Lua wiki and roster checks, 12 native syntax checks and 1,109 launcher manifest checks. Launcher commit `1622283d608cdefad89cb4aea43ec4d241c496dd`.

**Manual Verification Required** — In-game action identity and menu refresh, actual timings for single- and multi-target enemy actions, combat performance at Lv. 10/30/50/75, spell resistance, WS restrictions under level sync and HUD refresh on target swaps. Four existing Combat Analytics API tests require local loopback.
