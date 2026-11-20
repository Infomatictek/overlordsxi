# Archivist implementation report

SCH Soul `archivist` (ARC), Tier 3 support. Equip its Soul Crystal or use `!spec set archivist` from Lv. 10. Staff and Club are the permitted WS families. The support loop uses ordinary gear, zero WS talents and any subjob.

- Modus Veritas (214, launcher 726) becomes **Record**. It watches a hostile enemy for 12 seconds and stores the next completed spell or technique for 60 seconds on a six-second recast. Records bind the action category and ID to the specific living enemy spawn.
- Sandstorm (99) becomes **File Countermeasure**, a tool- and MP-free half-second cast to a party member or self. Its 15-second recast starts when a page is filed. Range is 15y at Lv. 10 and 20y from Lv. 30. The page lasts 20 seconds, increasing to 25 at Lv. 70.
- The exact next matching action is reduced by 20/25/25/30% at Lv. 10/30/50/70+. With multiple eligible pages, only the strongest is spent. That reduction covers the matching action's subsequent hits, leaving other pages available. Wrong IDs, new spawns, ordinary hits and scripted HP changes bypass the page.
- Stone (159) becomes **Margin Note**, a Lv. 10 earth spell. Sublimation (233, launcher 745) becomes **Index Pages** once the second record slot opens at Lv. 50. HUD shows the recorded action, recording window, active page and recasts. See the [player guide](../../guides/archivist.md).

Four focused tests, 111 accessible regression tests, strict Lua wiki and roster checks, 19 native syntax checks, LuaJIT HUD syntax and 1,109 launcher manifest checks passed. Launcher commit `8635bc3bad2ecaa39926bfb10230af096b2b5c54`.

**Manual Verification Required** — Live capture of same-element spells with different IDs, player and party targeting, interrupted cast exclusion, multi-hit and concurrent pages, enemy respawn, scripted HP-set and death mechanics, HUD timing, level sync, and Lv. 10/30/50/75 party use. Four existing Combat Analytics API tests require loopback.
