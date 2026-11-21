# SoulspireXI — Mass Combat Gauntlet, Investigation Queue & ChatGPT Analysis Export Guide

This guide explains how to use the upgraded **SoulspireXI Admin Combat Testing Suite** (`https://wiki.soulspirexi.com/admin`) to run automated multi-Soul benchmarks, read human-readable combat parses, triage the Automated Investigation Queue, and export compact archives for ChatGPT analysis — **without spending AI API tokens on routine parsing or reporting**.

---

## 1. Running the Mass Combat Gauntlet

Open **Automated Gauntlet** in the Admin sidebar.

### Saved Presets
Use the preset bar at the top to configure common matrices in one click:
- **Quick Smoke Test**: 4 representative Souls (Tank, Healer, DPS, Caster) @ Lv.10 Even Match, 1 iteration, `Auto by Role`.
- **Full Soul Coverage**: All 66 canonical Souls @ Lv.10 Even Match, 1 iteration, `Auto by Role`.
- **Role Balance**: All validated Souls @ Lv.10 & Lv.75, Even Match & Very Tough, 3 iterations.
- **Level Progression**: Validated Souls across Lv.10, Lv.30, Lv.50, and Lv.75.
- **Boss Difficulty Scaling**: Representative Souls across +0 EM, +3 VT, +5 IT, and +8 Extreme (Normal & NM) against Physical Bruiser, Magic Caster, and AoE Boss.
- **Complete Regression Gauntlet**: All 66 Souls across all 4 levels, Even Match & Very Tough, 3 iterations.

### Party Selection (`Auto by Role`)
Select **Auto by Role (Recommended)** in the party dropdown so every Soul is evaluated in a role-appropriate benchmark party (`trio_tank_bench` for Tanks, `trio_healer_bench` for Healers, `trio_dps_bench` for Damage & Support) instead of forcing healers or tanks to solo a boss.

### Resilient Batch Queue
- The **Calculated Tests** readout shows the exact matrix size before enqueueing.
- Queue state is checkpointed to disk after every encounter (`queue_checkpoint.json`). If the parser container restarts mid-batch, any interrupted `running` job is automatically restored to `queued` so you can click **Start / Resume** without losing completed results.
- Controls: **Start / Resume**, **Pause**, **Retry Failed**, **Cancel**, **Clear Finished**.

---

## 2. Human-Readable Encounter Reports & Event Log

Open **Encounters & Timeline** and select any recorded fight.

- **Human-Readable Encounter Report** (rendered directly above the timeline graphs):
  - **Validity Badge**: Explicitly marks `VALID FOR BALANCE` vs `INVALID FOR BALANCE` with exact invalidation reasons.
  - **What Happened**: Deterministic plain-English fight narrative (opener, key casts/abilities, deaths, AI verification summary).
  - **Role & Combat Cards**: Damage, Survival, Healing & Resources, and AI Execution (verified vs unverified vs failed decisions).
  - **Diagnostic Findings**: Click any finding to jump directly to the **Event Log** filtered to its timestamp and warning category.
- **Human-Readable Event Log**:
  - Switch between **Simple View** (plain English), **Detailed View** (mechanics, IDs, deltas), and **Raw JSON**.
  - Filter by category: `Damage`, `Healing`, `Boss Mechanics`, `Spells`, `Weapon Skills`, `Job Abilities`, `TP / MP Resources`, `AI Decisions & Failures`, and `Warnings / Deaths / Spikes`.

---

## 3. Automated Investigation Queue

Open **Investigation Queue** in the Admin sidebar.

- Automatically scans completed encounters, deduplicates repeated failures by `(code, soul_key)`, and flags **Shared-System** defects whenever **3 or more distinct Souls** exhibit the same failure code.
- **Top 10 Problems to Investigate** ranks open issues by severity (`Critical` → `High` → `Medium` → `Low`), breadth across Souls, run frequency, and shared-system impact.
- **Workflow Triage**:
  - Update status (`New`, `Investigating`, `Confirmed`, `Needs More Data`, `Resolved`, `Won't Fix`), add developer notes, link a commit/issue ref, pin priority items, or mark false positives.
  - **Automatic Regression Reopening**: If an issue marked `Resolved` reappears in a newer run (and is not marked as a false positive), it automatically reopens to `New` and increments `reopened_count`.
  - Click any **Affected Run** button to jump straight to that encounter's report, or click **Export Investigation for ChatGPT** for a focused single-issue bundle.

---

## 4. Exporting & Uploading Bundles to ChatGPT

### Two Archive Modes
1. **Export for ChatGPT (Compact ZIP)** *(Recommended default)*:
   - Compact (~100–500 KB even across hundreds of runs), bounded to stay comfortably within ChatGPT's upload and context limits.
   - Contains `README.md`, `executive_summary.md`, `coverage.csv`, `all_results.csv`, `validation_failures.csv`, `anomalies.json`, `regression_summary.csv`, per-Soul summaries under `souls/<soul_key>/`, the full `investigations/` folder, deterministic representative evidence logs, `metadata/schema.json`, and `manifest.json` (which explicitly lists any omitted raw logs — nothing is silently dropped).
2. **Complete Research Archive (ZIP)**:
   - Includes everything in the Compact package plus complete decision traces and readable event logs for all runs. Best for offline archival or deep-dive debugging.

### Privacy & Security Guarantees
- All secret/credential keys (`password`, `token`, `cookie`, `secret`, `auth`, `hash`, `api_key`, `private_key`) and server host paths (`/mnt/user/...`, `/root/...`, `C:\...`) are stripped recursively before ZIP creation.
- **Anonymize Player Names** is enabled by default (`anonymize=true`), replacing non-`Test_` character names with `REDACTED_PLAYER` across JSON, Markdown, and event logs.

### Recommended Prompts for ChatGPT
Upload `soulspirexi-gauntlet-compact-YYYY-MM-DD.zip` to ChatGPT and ask:
- **Triage & Bug Hunting**: *"Read `README.md`, `investigations/top_10_priorities.md`, and `investigations/shared_system_warnings.md`. Group the Critical and High issues into engine bugs vs AI profile issues and give me a prioritized fix order."*
- **Role-Aware Balance Review**: *"Inspect `executive_summary.md`, `all_results.csv`, and `coverage.csv`. Ignoring all rows where `valid_for_balance=False` or `extreme_challenge=True`, compare Souls strictly within their own role (Tank vs Tank, Healer vs Healer, Damage vs Damage, Support vs Support) and identify statistical outliers."*
- **Single-Encounter Deep Dive**: Upload an individual `encounter-<run_id>.zip` and ask: *"Read `summary.md` and `readable_events.txt` and explain why the AI failed or underperformed during this encounter."*
