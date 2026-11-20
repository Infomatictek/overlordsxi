# Soul Implementation Report — Herald

**Queue 23 of 25 · SMN `herald` / HLD · Tier 3 support · Lv. 10–75**

- Avatar’s Favor becomes **Astral Accord**. Native avatar summons become envoy invitations. The first two avatars and their response pacts are available at Lv. 10. Shiva and Garuda join at Lv. 30, and the full seven are available at Lv. 50.
- The Accord snapshots nearby party members within 15 yalms. It grants one matching ordinary elemental damage claim per member, shared with that member’s pet. The effect scales from 8% to 12% and lasts 8–10 seconds. A spent same-element claim stays spent on refresh.
- Damage hooks cover standard elemental spells, eligible Blue Magic, magical weapon skills and elemental pet techniques. Claims settle on delivered HP damage. The bonus excludes skillchains, periodic ticks and extra Soul burst damage.
- Staff and Club are the weapon-skill and talent families. The HUD shows avatar, element, claim count, MP cost and duration. The [player guide](../../guides/herald.md) and generated wiki cover all 19 action identities. Launcher commit `169695cf40b4195743e30649b9169cb250eb4176`.

**Automated verification.** Four focused tests, 127 accessible regression tests, strict wiki and canonical roster audits, nine native C++ syntax checks, LuaJIT syntax, Lua HUD fixture and all 1,109 launcher entries passed. The four Combat Analytics loopback tests require unavailable network access.

**Manual Verification Required.** At Lv. 10, summon each starter without learned primes and use an Accord with two party members attacking separate enemies. Check low MP, mixed elements, AoE ordering, magic and pet claims, avatar death, party departure and competition between different Heralds. Verify native names and timers, plus isolation from Celestial and Primalist through level sync and Soul changes.
