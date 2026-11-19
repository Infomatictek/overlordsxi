# Issue #20 · Sequence D Acceptance Records (Offensive Openings)

Branch: `feat/souls-66-seq-d-openings` (branched from `origin/main` `c34cd4f`).
Automated verification suite: `tests/test_seq_d_offensive_openings.py` + `tools/audit_soul_coverage.py --strict`.

| Soul | Module | Automated Verification (`lupa`) | Remaining Live/Field Tests |
|---|---|---|---|
| **PLD 3 · Oathbreaker** | `modules/custom/lua/pld_oathbreaker.lua` | Out-of-combat Condemn/Absolve commitment, hate-list swap rejection, Flash lockout under Condemn, >=8% max HP Absolve retaliation, Reckoning 1.5–2.0× (doubled under retaliation), cleanup. | In-game ally-hit vs self-hit retaliation test and Lv10/75 parse. |
| **DRK 1 · Reaper** | `modules/custom/lua/drk_reaper.lua` | 5s recovery from damaging spell/TP move & 6th regular round, periodic tick exclusion, Finality 1.3× base vs 2.3–3.0× recovery + Lv50/70 <25% HP execute, miss starts CD without consuming recovery. | Multi-hit TP move single-window test and Lv10/75 parse. |
| **RNG 1 · Sniper** | `modules/custom/lua/rng_sniper.lua` | Sightline Shot 20y, 3s/4s aim, movement >1y / LOS / target swap / incapacitation cancel (0 ammo, 3s retry), miss spends 1 ammo & 12s recast, Lv10–75 2.0–3.2× & +10–30 RACC. | Stationary vs forced-movement boss parse, Eagle Eye Shot non-inheritance. |
| **DRG 1 · Lancer** | `modules/custom/lua/drg_lancer.lua` | Spineshatter Vault 4–12y range gate, blocked-terrain cancel (3s retry, no displacement), 4–7y 1.6× vs >7–12y 2.2–2.8×, Lv50/70 +15/20% native Jump follow-up within 5s. | Wall/elevation geometry and moving target test at Lv10/75. |
| **BLU 1 · Warmage** | `modules/custom/lua/blu_warmage.lua` | Assess Prey 12s CD / 8s window with explicit tie handling, Sprout Smack (blunt) & Power Attack (piercing) starter pair, +12/15/18/20% post-resist matching bonus, single-target conversion policy, melee/WS exclusion. | Live Blue Magic set-point loan & Bomb Toss single-target test at Lv10/75. |
| **SMN 1 · Primalist** | `modules/custom/lua/smn_primalist.lua` | Lv10/30/50 avatar loan roster (no permanent flags), Challenge Aspect 20s CD / 12–15s window, avatar swap clears promise, lowest-resistance elemental Rage +20/25/30/35%, physical-only exclusion. | Live avatar swap mid-commit and resistant vs weak boss test at Lv10/75. |
| **GEO 3 · Terramancer** | `modules/custom/lua/geo_terramancer.lua` | Shallow (+2s, 1.8–2.2×) & Deep (+4s, 2.8–3.6×) faults, 8s shared recast, single-fault rejection without cost, fixed snapshot (ID/spawnGen/zone/2D ≤3y/|Δy| ≤3y), spectator isolation. | Stationary vs moving claimed boss with spectator mob on marker at Lv10/75. |
