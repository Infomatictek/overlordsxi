# Nightblade implementation report

NIN Soul `nightblade` (NGB), Tier 3 support. Equip its crystal or use `!spec set nightblade` from Lv. 10. Katana is the eligible WS family. The reactive support loop uses ordinary gear, zero WS talents and any subjob.

- Jubaku: Ichi (341) becomes **Severing Seal**. It targets one active hostile spell within 15 yalms. A full landing can interrupt a susceptible cast. If it resolves, sealed direct damage is reduced by 8/10/10/12% at Lv. 10/30/50/70+.
- Hojo: Ichi (344) becomes **Blunting Seal**. Physical damage from the selected enemy technique falls by 10/13/13/16%. The native engine identifies the actual damage type at resolution. A nonphysical technique restores an available Quick Read window and uses the three-second mismatch retry.
- Both seals have a 0.5-second base cast, use no tools, and share a 20-second recast, reduced to 18 seconds from Lv. 50. The seal belongs to one enemy action sequence. It resolves with that action or expires after eight seconds. Protected and instant mechanics outside the native telegraph path are excluded.
- Katon: Ichi (320) becomes **Signal Flare**, a tool-free single-target fire cast. Innin (249, launcher 761) becomes **Quick Read** at Lv. 30. It reduces the next valid seal's base cast to 0.25 seconds within an eight-second window, on a 45-second recast.
- HUD shows the current enemy tell, seal status, both recasts and Quick Read. See the [player guide](../../guides/nightblade.md).

Four focused tests, 97 accessible regression tests, strict Lua wiki and roster checks, 16 native syntax checks and 1,109 launcher manifest checks passed. Launcher commit `773f9cf1e683e26324f1e9e4d12422f2cf788d98`.

**Manual Verification Required** — Live cast recognition, skill type confirmation and retry packet timings, resistance and immunity, interruption-proof and scripted encounters, two Nightblades on an overlapping cast, level sync and Lv. 10/30/50/75 party performance. Four existing Combat Analytics API tests require loopback.
