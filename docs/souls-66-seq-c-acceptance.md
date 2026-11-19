# Issue #20 · Sequence C Acceptance Records (Isolated Casters)

Branch: `feat/souls-66-seq-c-casters` (branched from `origin/main` `c34cd4f`).
Automated verification suite: `tests/test_seq_c_isolated_casters.py` + `tools/audit_soul_coverage.py --strict`.

## 1. WHM 2 · Zealot (`zealot`)
- **Files**: `modules/custom/lua/whm_zealot.lua`, `modules/init.append.txt`, `tests/test_seq_c_isolated_casters.py`
- **Implemented contracts**:
  - Additive registration via `spec.registerCrystal(xi.job.WHM, ...)` after `whm_specs.lua` (preserves Bishop).
  - Staff Communion: restores `max(2, floor(maxMP * rate))` (3.5/4.0/4.0/4.5% across Lv10/30/50/70+) on first landed regular main-hand staff hit per attack round (2.5s lock). Zero refund on immunity/zero damage, WS, counters, additional effects, offhand hits, or non-Zealot Souls.
  - Divine Magic pricing & scaling: Banish I–III and Holy / Divine Benediction of Light (Lv70, 2.0× base, 22% max MP, 3.5s cast, 14s recast).
  - Divine Seal (+20%, 90s CD, 20s pending window): survives cast cancellation, consumed on completed damaging divine cast.
- **Automated results**: Positive, negative (Bishop, multiattack, WS/counter/offhand/zero-dmg), Divine Seal cancellation/consumption, and bracket scaling tests passed via `lupa`.
- **Remaining live/field tests**: 20s in-melee vs out-of-melee sustained divine DPS comparison against Bishop at Lv10 and Lv75.

## 2. BLM 1 · Astromancer (`astromancer`)
- **Files**: `modules/custom/lua/blm_astromancer.lua`, `modules/init.append.txt`, `tests/test_seq_c_isolated_casters.py`
- **Implemented contracts**:
  - Additive registration via `spec.registerCrystal(xi.job.BLM, ...)` after `blm_specs.lua` (preserves Necromancer).
  - Verified spell manifest mapping: Water Ancient aspect displays **Tsunami** on verified `Flood` (ID 214), never demo ID 1.
  - Atomic per-enemy 20s Astral Saturation scoped to `(zoneId, targetId, spawnGen)`: second Astromancer receives 10% of clamped bonus without extending/refreshing the window; full resist to zero starts 18s personal recovery without claiming saturation; interruption starts neither.
  - Lv70–75 boss cap caps only added Soul bonus at 3% of encounter-start max HP; Elemental Survey (Lv30+) reports all tied least-resistant elements; probe sets Invocation element with earth fallback.
- **Automated results**: Same-tick dual-Astromancer saturation, separate bosses, despawn/respawn generation reset, full resist, boss 3% cap, and cross-Soul negative tests (Sage, Spellblade) passed via `lupa`.
- **Remaining live/field tests**: Live two-Astromancer same-tick boss parse and Helix/burst non-interference check at Lv10 and Lv75.

## 3. RDM 3 · Scarlet Weaver (`scarletweaver`)
- **Files**: `modules/custom/lua/rdm_scarlet_weaver.lua`, `modules/init.append.txt`, `tests/test_seq_c_isolated_casters.py`
- **Implemented contracts**:
  - Additive registration via `spec.registerCrystal(xi.job.RDM, ...)` after `rdm_specs.lua` (preserves Crimson Duelist).
  - Strictly Scarlet Weaver-scoped mutually exclusive Yin/Yang (never globalized): defaults to Yang on activation, free switch out of combat, 12s shared recast + 2s recovery in combat, same-aspect no-op, disallowed during cast/JA lock.
  - Yin grants +15/18/22/25% to eligible Tier I–III elemental spells; Yang grants +15/18/22/25% to landed regular main-hand Sword hits; Enspell, WS, skillchain, additional attacks, offhand, and non-Scarlet-Weaver Souls receive neither.
- **Automated results**: Default Yang, free/combat switch, action-lock rejection, Yin/Yang mutual exclusion, Enspell/WS/SC exclusions, cleanup, and cross-Soul negative tests (Crimson Duelist, Spellblade) passed via `lupa`.
- **Remaining live/field tests**: Equal-time single-aspect vs rapid-switching parse on an unchanged boss and mid-cast aspect switch resolution at Lv10 and Lv75.
