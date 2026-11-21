# Soul Implementation Report — Primalist

**Queue 22 of 25 · SMN `primalist` / PRM · Tier 1 damage · Lv. 10–75**

- Assault becomes **Challenge Aspect** and binds one summon and quarry. Seven native single-target avatar pacts become elemental finishers. Carbuncle’s **Astral Comet** and Ifrit’s **Inferno Brand** are available at Lv. 10.
- Native summoning magic loans two starter avatars, two selectable primes from Lv. 30 and the full seven at Lv. 50. Elemental Siphon and Mana Cede select the loan slots at Lv. 30–49. Native learned-spell flags are preserved.
- An eligible elemental pact gains 20/25/30/35% in a 12/15-second window when its damage element matches a lowest resistance rank. Other targets keep ordinary pact damage. Dismissing or swapping avatars closes the window.
- Staff and Club are the weapon-skill and talent families. Staff gear is available through the standard test profile. The HUD shows the avatar, pact cost, loan choices and Challenge status. The [guide](../../guides/primalist.md) and wiki describe all 20 native action identities. Launcher commit `c2c79cdc0d293dac8becf9174fc1025c793e0335`.

**Automated verification.** Four focused tests, 123 accessible regression tests, strict wiki and roster audits, seven native C++ syntax checks, LuaJIT syntax, a Lua HUD fixture and all 1,109 launcher entries passed. Four Combat Analytics tests require unavailable loopback access.

**Manual Verification Required.** At Lv. 10 with no learned primes or weapon-skill talents, cast each starter, open the actual pet Rage list and test matches, resistance changes, wrong targets, interruptions and low MP. Check attunement and sync at Lv. 30/49/50, zoning and pet replacement, native action text across menu and combat log, and spell/pact restoration when switching to Celestial.
