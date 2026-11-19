# Issue #20 · Sequence E Acceptance Records (Targeted Defense & Support — 11 Souls)

Branch: `feat/souls-66-seq-e-support` (branched from `origin/main` `c34cd4f`).
Automated verification suite: `tests/test_seq_e_targeted_support.py` + `tools/audit_soul_coverage.py --strict`.

| Soul | Module | Automated Verification (`lupa`) | Remaining Live/Field Tests |
|---|---|---|---|
| **WHM 3 · Valkyrie** | `modules/custom/lua/whm_valkyrie.lua` | Wingmate selection, hostile-damage-only interruption, manual-cancel exclusion, atomic first-Escort claim across 2 Valkyries, +100% SIRD & 0/15/15/25% MP refund. | Live Cure interruption vs manual cancel at Lv10/75. |
| **BLM 2 · Channeler** | `modules/custom/lua/blm_channeler.lua` | Conduit Link -20–30% cast / -15–25% MP, anti-Channeler recursion, Ancient Magic exclusion, Lv30+ 5% completion relay (0 on cancel). | Live healer & nuker pairing + interrupt before cast start. |
| **RDM 2 · Royal Tactician** | `modules/custom/lua/rdm_royal_tactician.lua` | Slow/Paralyze→Advance, Blind/Silence→Recompose, latest-order overwrite, Dispel repeat, Lv50+ full-resist half-potency fallback (24s ICD), strongest-wins per recipient. | Live enfeeble/dispel order cycle at Lv10/75. |
| **DRK 3 · Scourge** | `modules/custom/lua/drk_scourge.lua` | Global single-slot curse (Withering/Ash/Famine), resist preserves existing curse, auto/scripted-HP exclusion, hard-immunity one-hit fallback blocked when same-category curse active. | Two-Scourge hard-immunity boss test at Lv10/75. |
| **RNG 3 · Arcane Archer** | `modules/custom/lua/rng_arcane_archer.lua` | Exclusive 6-element arrow mark, atomic single claim on simultaneous ally hits, wrong-element/DoT/off-party exclusion, solo own elemental bow WS half bonus. | Live simultaneous ally nuke & solo bow WS test at Lv10/75. |
| **NIN 3 · Nightblade** | `modules/custom/lua/nin_nightblade.lua` | Severing/Blunting Seals on server action sequence, mismatch 3s free retry (no interrupt fishing), single seal per sequence across 2 Nightblades, scripted execution immunity. | Live interruptible vs uninterruptible boss cast test. |
| **DRG 2 · Skyborn** | `modules/custom/lua/drg_skyborn.lua` | Grounding Cry cold-start (+200 CE / +700 VE), Skyward Guard keeps targetability & hate, 35–50% single-hit reduction + landing +100/+300 CE/VE + 5–10% HP ward, scripted HP-set excluded. | Live healer-second hate retention check during Guard. |
| **SCH 3 · Archivist** | `modules/custom/lua/sch_archivist.lua` | Record exact action ID (1/2 slots), File Countermeasure 20–30%, wrong action never consumes page, multiple pages consume only highest, scripted HP-set bypass. | Live two same-element spells exact-ID discrimination test. |
| **BST 3 · Beastspeaker** | `modules/custom/lua/bst_beastspeaker.lua` | Read Quarry family/weakest type + unknown fallback (+4/6%), pet same-target gate, 2 hits/actor cap, 1 claim per multiattack round, WS/SC exclusion. | Non-beast & unknown-family boss parse at Lv10/75. |
| **SMN 3 · Herald** | `modules/custom/lua/smn_herald.lua` | Astral Accord 15y party snapshot, independent per-member single claim (+8–12%), same-element refresh never restores spent claim, avatar swap ends Accord. | Multi-ally multi-mob claim verification at Lv10/75. |
| **GEO 1 · Diviner** | `modules/custom/lua/geo_diviner.lua` | Clamped 2D segment projection (3–15y, 2.0/2.5y width, |Δy| ≤ 3y, zone), Shift without lifetime refresh, 2-Diviner strongest-wins & fallback to weaker on exit. | Live endpoint/edge/multi-floor corridor check at Lv10/75. |
