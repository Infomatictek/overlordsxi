# SoulspireXI — Complete Weapon Skill Talent Addon Rebuild (v3.0)

**Status:** Complete & Verified (Ready for User Review — NOT merged into `main`)  
**Launcher Branch:** `feat/ws-talent-addon-rebuild` (`soulspirexi-launcher`)  
**Server Branch:** `feat/ws-talent-foundation-v2` (`soulspirexi-src`, protocol enrichment @ `a88634a`)  

---

## 1. Audit Summary (Legacy Addon Root Defects)

Auditing the prior Ashita v4 `soulspire_talents` addon (`premium_ui.lua` + `soulspire_talents.lua`) identified five structural defects:

1. **No anti-double-click / pending lock**: Rapid clicks sent duplicate `OP_INVEST`/`OP_REFUND` packets before the server replied.
2. **Stale Soul state on Soul switching**: Switching Souls did not clear `selectedWsId` / `wsDetail` or trigger a fresh `OP_SYNC`, leaving previous-Soul weapon skills displayed.
3. **Ineligible weapons exposed**: The legacy 16-weapon dropdown displayed incidental and restricted weapon families as empty talent trees.
4. **No classic RPG connected tree or branch identity**: `premium_ui.lua` was a 1,945-line dashboard monolith relying on ~5.2 MB of oversized layout PNGs with no connected progression paths, no Damage/Soul/Utility visual distinction, and no hover tooltips.
5. **Server metadata gaps**: `NODE` packets truncated descriptions at 60 characters and omitted `branch`, `exclusiveGroup`, and `nextDesc`; `META` omitted `soulKey` and `role`.

---

## 2. Official Website Palette & Visual Direction

All colors were verified directly from `/mnt/user/appdata/soulspirexi-src/site/styles.css` (zero unverified color claims) and official emblem copied from `site/assets/logo.png` -> `assets/soulspire_emblem.png`:

- **Surfaces:** `--bg-deep: #070B14`, `--bg-surface: #0F1629`, `--bg-card: #131C33`, `--bg-elevated: #1C2847`
- **Typography:** `--text-primary: #F1F5F9`, `--text-secondary: #CBD5E1`, `--text-muted: #94A3B8`
- **Branch Visual Identity (3-Branch Classic RPG Layout):**
  - **Damage (Left):** Soul Gold (`#FBBF24` / warm metallic `#E8BD70`)
  - **Soul (Centerpiece, ~39% width with violet crystal aura & filigree):** Crystal Violet (`#A855F7` / `#8063BC`)
  - **Utility (Right):** Aether Cyan (`#38BDF8` / `#39CFE5`)
- **State Accents:** Emerald (`#10B981`) for available/affordable ranks, Rose (`#F43F5E`) for mutually exclusive locks and errors.

---

## 3. Architecture & Delivered Files

### Server-Side Backwards-Compatible Protocol Enrichment (`soulspirexi-src` @ `a88634a`)
- `modules/custom/lua/soulspire_ws_talents.lua`:
  - Appended trailing `|soulKey|role` to `META`.
  - Appended trailing `|branch|exclusiveGroup|nextDesc` to `NODE` and expanded description cap from 60 to 110 characters.
  - Server remains 100% authoritative for eligibility, point budgets, 4-WS mastery cap, allocation, refund, and persistence.

### Rebuilt Ashita v4 Addon (`soulspirexi-launcher`, `addons/ashita4/soulspire_talents/`)
- `ws_client_meta.lua`: Lean read-only lookup for all 66 canonical Souls, Primary/Signature weapon skill IDs, and player-facing Soul mechanic labels (generated from Foundation 2.1 `ws_eligibility_manifest.json`).
- `talent_theme.lua`: Verified `site/styles.css` palette tokens, engraved panel/corner-filigree primitives, and crisp procedural vector glyphs for Damage/Soul/Utility/Weapon families.
- `talent_state.lua`: Pure-Lua headless-testable state machine handling `META`, `SPENT_BEGIN/SPENT/SPENT_END`, `CAT_BEGIN/CAT/CAT_END`, `WS`, `NODES/NODE`, `WS_END`, `ERR`; strict Primary/Signature weapon grouping; Soul-switch invalidation & full resync trigger; anti-double-click `pendingOp` lock with timeout recovery; genuine prerequisite connection graph (`buildConnections`); exclusive peer detection; and player-facing tooltip model with zero `OX_*` leakage.
- `talent_tree_ui.lua`: Complete classic RPG 3-branch ImGui interface (Header with official emblem & 4-WS mastery counter, Eligible Weapon Selector, Damage | Violet Soul Centerpiece | Utility 4-tier connected tree, 5-Stage Evolution path for `#1 Combo` & `#47 Sanguine Blade`, compact Skillchain Augment Strip, WoW-style hover tooltips, and 2-step Reset WS / Reset All Footer).
- `soulspire_talents.lua`: Lean v3.0.0 Ashita v4 entry point (`/talents`, `/tal`, `/talents sync`, `/talents close`, binary `0x11F`/`0x1FD` + legacy `0x017` `[OXTAL]|`, zone-in `0x00A` resync, 1 Hz job/level check, clean unload).
- Removed obsolete `premium_ui.lua` and 17 unused legacy layout PNGs (~5.2 MB download reduction).

---

## 4. Verification Results

### Automated LuaJIT Functional & Headless Render Tests
- Test suite: `tests/soulspire_talents/test_soulspire_talents.lua`
- Result: **351 passed, 0 failed** (all 6 addon Lua files syntax-checked cleanly in LuaJIT 2.1).
- Verified: 66/66 canonical Souls, Primary/Signature grouping & incidental weapon exclusion, Soul switching invalidation, anti-double-click pending lock & timeout recovery, Evolution exclusive peer detection, genuine prerequisite edges, zero `OX_*` tooltip leaks, and headless `UI.render()` across Standard, Evolution, and Compact (`860×580`) layouts.

### Phase 9 Visual Verification (Synthetic Draw-List Renderer Previews)
> **Transparency Note:** All preview images are **synthetic draw-list renderer previews** rasterized directly from the live Lua `talent_tree_ui.render()` draw commands (`tests/soulspire_talents/capture_ui_previews.lua` + `render_ui_previews.py`). They are **not** live FFXI gameplay captures.

All 10 required states were captured, audited for pairwise hitbox overlaps, out-of-bounds coordinates, and `OX_*` text leaks (**10/10 PASS**), and visually inspected:
1. `01_unallocated.png` — Unallocated tree (0 pts spent)
2. `02_partially_invested.png` — Partially invested tree (4 pts across Damage + Soul)
3. `03_fully_developed.png` — Fully developed tree + Skillchain augment
4. `04_locked_prerequisites.png` — Locked prerequisites (Lv 25 character)
5. `05_mutually_exclusive.png` — Evolution `#1 Combo` mutually exclusive choices & crimson lock bars
6. `06_tooltip_damage.png` — Damage branch hover tooltip (Gold)
7. `07_tooltip_utility.png` — Utility branch hover tooltip (Cyan)
8. `08_tooltip_soul.png` — Soul centerpiece hover tooltip (Violet)
9. `09_weapon_selector.png` — Multi-family weapon selector (`Bladewheel`: Throwing Primary + Dagger Signature; Katana excluded)
10. `10_compact_860x580.png` — Compact resolution layout (`860×580`)

**Visual defects found and fixed during inspection:**
- Shifted vertical progression line start below each node's title label (`y + half + 19`) so lines never cross behind node text.
- Widened Skillchain Augment Strip buttons (`chipW` up to `220px`) so `T1: Fragmentation (0/1)` displays without ellipsis truncation.
- Added compact-height tile scaling (`44px`/`48px` when `tierStep < 94`) for clean vertical breathing room at `860×580`.

### Phase 10 Launcher Packaging & Manifest Verification
- `scripts/update-launcher-manifest.py`: Updated `manifest.json` (1,100 core files + 278 overlay files).
- `scripts/verify-launcher-manifest.py`: **PASSED (1,100 files verified, read-only)**.
- `python3 -m unittest tests/test_manifest_verification.py -v`: **9/9 tests PASSED**.
