# OverlordsXI Crystal Spec Guides

Every `.md` file in `docs/guides/` maps cleanly by crystal `key` (for example `bishop.md`, `celestial.md`, `spartan.md`) into the OverlordsXI Wiki's **"How to Play"** panel on each Crystal card.

To add a guide for a new class/crystal, drop `<spec_key>.md` here using these five headings:

```markdown
# Crystal Name (JOB) — Playstyle Guide

## At a Glance
Plain-English summary of what the spec is built to do and any role trade-offs.

## Setup & Gear
- **Required Weapon / Shield:** ...
- **Priority Stats:** ...

## How to Play (Step-by-Step)
1. **Opener:** ...
2. **Core Loop:** ...
3. **Spender / Burst:** ...
4. **Defensive / Reactive:** ...

## Key Mechanics & Stacks
- **Stack / Stance Name:** ...

## Common Mistakes (Don't Do This)
- ...
```

Pushing to `main` (or `feat/**` / `feature/**`) automatically rebuilds `site/data.json` and `site/data.js` via `.github/workflows/update-wiki.yml`.
