# Issue #20 · Sequence B Acceptance Records (Staged THF & BST)

Branch: `feat/souls-66-seq-b-staged` (branched from `origin/main` `c34cd4f`).
Automated verification suite: `tests/test_seq_b_thf_bst_souls.py` + `tools/audit_soul_coverage.py --strict`.

## 1. THF 1 · Trickster (`trickster`)
- **Files**: `modules/custom/lua/thf_specs.lua`, `modules/init.append.txt`, `tests/test_seq_b_thf_bst_souls.py`
- **Implemented contracts**:
  - Additive registration via `spec.registerCrystal(xi.job.THF, ...)` at branch 1.
  - Lv10 starter entitlement: loans native `Trick Attack` (ID 76) via `extraAbilities`.
  - Landed Dagger/Sword `WEAPONSKILL_USE` (`damage > 0`) applies `ATTACK_DOWN` for 16s at 5/7/9/12% across Lv10/30/50/70+ with a 20s personal ICD.
  - Missed WS (`damage == 0`) does not apply Attack Down and does not consume ICD.
  - Existing Attack Down on target is preserved and does not consume ICD.
  - Level sync below Lv10 disables trigger; `onRemove` detaches listener cleanly.
- **Automated results**: Positive, negative (miss/existing debuff/off-weapon/Lv9), bracket scaling (Lv10/30/50/70), and cleanup tests passed via `lupa`.
- **Remaining live/field tests**: In-game positional Trick Attack transfer behind an aligned ally vs solo suppression at Lv10 and Lv75, plus boss resist/immunity check.

## 2. THF 2 · Bandit (`bandit`)
- **Files**: `modules/custom/lua/thf_specs.lua`, `modules/init.append.txt`, `tests/test_seq_b_thf_bst_souls.py`
- **Implemented contracts**:
  - Additive registration at branch 2.
  - Lv10 starter entitlement: loans native `Sneak Attack` (ID 44) via `extraAbilities`.
  - Landed Dagger/Sword `WEAPONSKILL_USE` (`damage > 0`) against a target already afflicted with `DEFENSE_DOWN` refunds +75/100/125/150 TP (Lv10/30/50/70+) with a 12s personal ICD.
  - Missed WS, missing Defense Down, or Marksmanship/crossbow WS refunds 0 TP and leaves the 12s ICD ready.
- **Automated results**: Positive, negative (miss/no debuff/Marksmanship/ICD), bracket scaling, and cleanup tests passed via `lupa`.
- **Remaining live/field tests**: Solo acid-bolt / starter proc Defense Down opener and party Defense Down chain at Lv10 and Lv75.

## 3. THF 3 · Phantom (`phantom`)
- **Files**: `modules/custom/lua/thf_specs.lua`, `modules/init.append.txt`, `tests/test_seq_b_thf_bst_souls.py`
- **Implemented contracts**:
  - Additive registration at branch 3.
  - Cold-start opener **Phantom's Dare** mapped locally onto native `Steal` (ID 41, available from Lv5, loaned via `extraAbilities`): 15y range, 18s CD, 0 TP, no `/WAR` required, applies +180 CE / +650 VE and a 6s one-hit unavoidable (MAGICAL or BREATH) damage guard of 8/10/12/15% via `xi.overlords.onPreTakeDamage`.
  - Normal PHYSICAL melee hits never consume the unavoidable guard; guard clears on expiry or `onRemove`.
  - Evaded regular enemy melee (`HIT_MISS`) with Dagger/Katana grants +30/40/55/70 CE and +85/115/150/190 VE on a 2s ICD; non-miss/shadow/parry outcomes never trigger.
- **Automated results**: Range gate, cold-start CE/VE, physical-vs-magical/breath guard consumption, evade ICD, non-miss rejection, and cleanup tests passed via `lupa`.
- **Remaining live/field tests**: Cold-start aggro recovery against an immediate healer Cure at Lv10 and Lv75, plus magic-only boss validation.

## 4. BST 1 · Untamed (`untamed`)
- **Files**: `modules/custom/lua/bst_untamed.lua`, `modules/init.append.txt`, `tests/test_seq_b_thf_bst_souls.py`
- **Implemented contracts**:
  - Additive registration via `spec.registerCrystal(xi.job.BST, ...)` loaded strictly AFTER `custom/lua/bst_specs.lua` so Alpha Warden (branch 2) is never overwritten.
  - Lv10 starter entitlements: loans `Fight` (69), `Reward` (78), `Call Beast` (85), `Ready` (251), and `Bestial Loyalty` (387) via `extraAbilities`.
  - Bilateral Feral Synchronization with independent 8s ICDs:
    - Master landed Axe/Great Axe WS (`damage > 0`) on shared living target in same zone grants +125/175/225/275 pet TP.
    - Pet completed offensive Ready (`WEAPONSKILL_USE` `damage > 0` + `WEAPONSKILL_STATE_EXIT` `completed == true`) on same living target in same zone grants +75/100/125/150 master TP.
  - Reversible pet offense mods (`ACC 10/18/28/40`, `ATT 15/28/42/60`, `DA 3/5/7/10`) cleaned up cleanly on detach/dismiss/resummon without entity-ID reuse leaks.
- **Automated results**: Non-destructive Alpha Warden coexistence, reverse-order bilateral sync, zero-damage/canceled/wrong-target negative checks, entity-ID reuse on resummon, bracket scaling, and cleanup tests passed via `lupa`.
- **Remaining live/field tests**: Live Lv10/75 jug Ready potency & pet TP scaling check (to verify whether engine Ready potency scales with pet TP or needs the `event-contracts.md` +10/12/14/16% timed Ready potency fallback), plus 40–60% partner DPS split parse.
