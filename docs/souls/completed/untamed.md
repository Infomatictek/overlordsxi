# Soul Implementation Report — Untamed

**Queue 20 of 25 · BST `untamed` / UNT · Tier 1 pure damage · Lv. 10–75**

- Feral Synchronization exchanges TP between the master and the hare. Landed Pack Rend or Axe and Great Axe weapon skills feed the companion. Landed Raking Kick feeds the master. Both links have independent eight-second recovery and require a shared living target.
- Call Beast becomes **Call Packmate**, a jug-free starter summon. Charm is **Pack Rend**, Fight is **Set Quarry**, and Foot Kick is **Raking Kick**. Heel, Leave, Reward and Ready receive Soul-specific identities. **Rally Packmate** repurposes Bestial Loyalty at Lv. 30.
- The base loop works at Lv. 10. The companion and exchange scale at Lv. 30, 50 and 70. Only Axe and Great Axe enter the weapon-skill talent and execution routes. The damage kit uses native pet threat. The HUD shows target alignment, master and pet TP, and both recovery timers.
- The [player guide](../../guides/untamed.md) and generated wiki describe the same nine native actions. The launcher implementation is `fa55b23ba7d903e1e498486e6e3764880c572d74`. The [tracker](../FINAL_25_PROGRESS.md) records the server checkpoint.

**Automated verification.** Four focused tests, 115 accessible regression tests, strict wiki and canonical roster audits, 21 native C++ syntax checks, an embedded Lua HUD fixture, and all 1,109 launcher manifest entries passed. The four Combat Analytics loopback tests require network permissions this environment does not have.

**Manual Verification Required.** At Lv. 10 with no weapon-skill talents, summon, engage, use both TP links and verify both names and descriptions in the native pet menu and battle log. Test Ready charge spending, resummons, pet death, zoning and level sync, and compare damage at Lv. 10, 30, 50 and 75. Switch to Alpha Warden and verify pet skills, weapon permissions and Soul HUD reset.
