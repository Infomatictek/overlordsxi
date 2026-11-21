# Soul Implementation Report — Diviner

**Queue 25 of 25 · GEO `diviner` / DIV · Tier 3 support · Lv. 10–75**

- Indi-Precision becomes **Lay Meridian**, a fixed anchor whose second endpoint follows the Diviner. Full Circle becomes **Recall Meridian**, Stone becomes **Ley Spark**, and Ecliptic Attrition becomes **Meridian Shift** at Lv. 30.
- From Lv. 10, allies within two yalms of the 3–15-yalm segment gain +12 ACC and MACC. The segment uses an interpolated vertical check and requires the same party, zone, battle and instance. Shift reanchors without extending the original lifetime.
- At Lv. 50 the radius grows to 2.5 yalms and +28 ACC/MACC. At Lv. 70 the lifetime reaches 40 seconds and the bonus reaches +35. Each recipient gets only the strongest covering bonus and falls back to a weaker eligible line on exit.
- Club and Staff are the weapon-skill and talent families. The HUD shows active coverage, party count, anchor distance and duration. See the [player guide](../../guides/diviner.md). Launcher commit `f2ef25b79d92cf11ed8ed15699b190e9c51638a9`.

**Automated verification.** Four focused tests and the complete 139-test suite passed, including the four Combat Analytics loopback tests. Strict wiki and roster audits, seven native C++ syntax checks, the Lua HUD fixture and all 1,109 launcher entries passed. The strict roster recognized all 66 canonical Souls.

**Manual Verification Required.** At Lv. 10 with zero weapon-skill talents, place the lane in a real party and verify the native actions, ACC/MACC changes, both endcaps, vertical limits, movement and HUD readouts. Repeat with an overlapping Diviner, a different instance, zoning, party changes, death and Soul changes. At Lv. 30 and 75, verify Shift preserves expiry and the later width and duration are visible in play.
