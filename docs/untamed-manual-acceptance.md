# Untamed staging & manual acceptance

**Branch:** `feature/bst-untamed-feral-sync`; **not merged to live `main`**.

This module extends the existing BST implementation. Load it **after** `custom/lua/bst_specs.lua`, because the existing `spec.registerJob(BST, ...)` rebuilds the registration table for Alpha Warden. A load before that module can silently replace Untamed's registration.

## Windows LandSandBoat acceptance procedure
1. After validating Lua syntax, sync the branch's `modules/custom/lua/bst_untamed.lua` into the server's equivalent directory.
2. Ensure `modules/init.txt` contains `custom/lua/bst_untamed.lua` **after** `custom/lua/bst_specs.lua`. Keep existing BST, RNG, and pet engine patches untouched.
3. Restart `xi_map` when needed for module loading; a FileWatcher copy alone may not register a brand-new module in `init.txt`.
4. On a normal Lv10 BST, run `!spec list` and confirm Untamed appears, then `!spec set untamed`. Confirm using a normal Axe or Great Axe (no special item).
5. Engage one enemy together with an ordinary jug pet and use a master Axe/Great Axe weapon skill. Confirm the pet gets TP only when it is engaged on the same enemy and only once per 8s.
6. Use a pet Ready skill: confirm the master receives TP only on completed Ready, not on a canceled skill, and no more often than once per 8s.
7. Swap away from Untamed / dismiss pet / re-summon; verify offensive pet mods do not double-stack or survive onto Alpha Warden and do not become stuck after a recycled pet ID.
8. At Lv10, 30, 50, 70, and 75 measure master+pet DPS, pet deaths, TP loops and hate ownership versus Alpha Warden and Huntsman in comparable fights. For difficult bosses, pay special attention to AoE pet loss.
9. Confirm no player-facing DAT or ability/menu update is needed (first pass uses existing skill and Ready actions).

## Acceptance limits
- The current passive offensive pet bonuses are deliberately modest until actual combat parses justify them.
- No custom offensive hit is injected: the pet must execute a **real** Ready action.
- Untamed is not yet complete until game logs verify damage, pet survival, and level 10 viability.
- **Do not rework Huntsman** under the Untamed branch. Its current ranged/modal design diverges from the newly proposed melee-warhorn commander and deserves a separately reviewed migration.
