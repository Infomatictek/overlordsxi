# Skyborn implementation report

DRG Soul `skyborn` (SKY), Tier 6 tank. Equip its Soul Crystal or use `!spec set skyborn` from Lv. 10. An ordinary polearm supports both core actions without WS talents, a support subjob or a companion. Polearm is the sole eligible WS family.

- Jump (66, launcher 578) becomes **Grounding Cry**, a 15-yalm challenge on one enemy for 200 CE and 700 VE with a 16-second recast. It works without first dealing damage.
- Ancient Circle (65, launcher 577) becomes **Skyward Guard**, a self-only 1.5-second window on a 20-second recast. The first direct enemy hit is reduced by 35/40/45/50% at Lv. 10/30/50/70+. It preserves targetability and existing enmity.
- The end of Guard adds 100 CE and 300 VE to the original living enemy. A successful interception from Lv. 30 adds a 5/8/10% max-HP ward for five seconds. Guard and ward bypass periodic damage and scripted HP changes. This uses the staged companion-independent design.
- The HUD shows Guard and ward state, remaining ward HP, Guard recast and Cry recast. Both actions and their base recasts appear in the wiki. See the [player guide](../../guides/skyborn.md).

Four focused tests, 104 accessible regression tests, strict Lua wiki and roster checks, 16 native syntax checks, and 1,109 launcher manifest checks passed. Launcher commit `05c8d1be5f9d1db5a2972c4baf1245c608f06f78`.

**Manual Verification Required** — Real cold-start threat and healer-second threat, hit and animation timing within 1.5 seconds, party and multi-hit damage, ward interaction with mitigation, scripted phases, level sync, and Lv. 10/30/50/75 tank tuning. Four existing Combat Analytics API tests require loopback.
