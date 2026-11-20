"""Export utilities: original JSONL/ZIP downloads, Markdown summaries, and CSV."""
from __future__ import annotations

import csv
import io
import zipfile
from typing import Any

from .telemetry import UNAVAILABLE


def _fmt(val: Any) -> str:
    if val is None or val == "":
        return "N/A"
    if val == UNAVAILABLE:
        return "Unavailable"
    if isinstance(val, bool):
        return "Yes" if val else "No"
    if isinstance(val, float):
        return f"{val:.2f}".rstrip("0").rstrip(".")
    return str(val)


def build_raw_bundle_zip(run_id: str, raw_files: dict[str, str | None]) -> bytes:
    """Package all available original JSONL/JSON files for `run_id` into a ZIP archive."""
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        if raw_files.get("summary"):
            zf.writestr(f"{run_id}_summary.jsonl", raw_files["summary"])  # type: ignore[arg-type]
        if raw_files.get("events"):
            zf.writestr(f"events/{run_id}.jsonl", raw_files["events"])  # type: ignore[arg-type]
        if raw_files.get("snapshots"):
            zf.writestr(f"snapshots/{run_id}.jsonl", raw_files["snapshots"])  # type: ignore[arg-type]
        if raw_files.get("feedback"):
            zf.writestr(f"feedback/{run_id}.json", raw_files["feedback"])  # type: ignore[arg-type]
    return buf.getvalue()


def build_timeline_csv(time_series: dict[str, Any]) -> str:
    """Export 1-second timeline points + rolling averages as CSV."""
    out = io.StringIO()
    cols = [
        "sec",
        "damage_dealt",
        "player_damage",
        "pet_clone_damage",
        "rolling_dps_5s",
        "rolling_dps_10s",
        "damage_received",
        "rolling_inc_5s",
        "healing_done",
        "rolling_hps_5s",
        "player_hp",
        "player_max_hp",
        "player_hp_pct",
        "player_mp",
        "player_max_mp",
        "player_tp",
        "boss_hp",
        "boss_hp_pct",
        "boss_ce",
        "boss_ve",
        "pet_count",
        "pet_alive_count",
    ]
    writer = csv.DictWriter(out, fieldnames=cols, extrasaction="ignore")
    writer.writeheader()
    for pt in time_series.get("points") or []:
        writer.writerow(pt)
    return out.getvalue()


def build_runs_list_csv(items: list[dict[str, Any]]) -> str:
    out = io.StringIO()
    cols = [
        "run_id",
        "timestamp_utc",
        "character_name",
        "soul_name",
        "job",
        "effective_combat_level",
        "boss_type",
        "actual_boss_level",
        "difficulty",
        "outcome",
        "encounter_duration_sec",
        "total_damage",
        "sustained_dps",
        "burst_dps_10s",
        "actual_incoming_damage",
        "effective_healing",
        "deaths",
        "pet_deaths",
        "pinned",
        "feedback_label",
    ]
    writer = csv.DictWriter(out, fieldnames=cols, extrasaction="ignore")
    writer.writeheader()
    for item in items:
        writer.writerow(item)
    return out.getvalue()


def build_markdown_summary(report: dict[str, Any]) -> str:
    """Render a clean, shareable Markdown encounter report (zero AI tokens)."""
    meta = report.get("meta") or {}
    s = report.get("summary") or {}
    m = s.get("metrics") or {}
    off = m.get("offense") or {}
    dfn = m.get("defense") or {}
    heal = m.get("healing") or {}
    thr = m.get("threat") or {}
    res = m.get("resources_and_pets") or {}
    diag = report.get("diagnostics") or {}
    fb = report.get("feedback")
    notes = report.get("notes") or []

    lines: list[str] = [
        f"# OverlordsXI Proving Grounds Report — `{meta.get('run_id')}`",
        "",
        f"- **Date (UTC):** `{s.get('timestamp_utc')}`",
        f"- **Character:** `{meta.get('character_name') or 'Not logged'}`",
        f"- **Soul / Job:** **{s.get('soul_name', 'None')}** (`{s.get('job', 'UNKNOWN')}`, {s.get('role', 'Unassigned')} / {s.get('tier', 'Unassigned')})",
        f"- **Levels:** Effective Lv.{_fmt(s.get('effective_combat_level'))} (Original Lv.{_fmt(s.get('original_character_level'))}) vs **{s.get('boss_type', 'unknown')}** Lv.{_fmt(s.get('actual_boss_level'))} (`{s.get('difficulty', 'even_match')}`)",
        f"- **Outcome:** `{s.get('outcome', 'unknown')}` | **Combat Duration:** `{_fmt(s.get('encounter_duration_sec'))}s` (Prep: `{_fmt(s.get('prep_duration_sec'))}s`)",
        f"- **Schema:** `v{meta.get('schema_version', '1.0.0')}` | **Balance Valid:** `{_fmt(s.get('valid_for_balance'))}`",
        "",
        "## Key Metrics",
        "",
        "| Category | Metric | Value |",
        "|---|---|---|",
        f"| Offense | Total Damage | {_fmt(off.get('total_damage'))} |",
        f"| Offense | Sustained DPS | {_fmt(off.get('sustained_dps'))} |",
        f"| Offense | 10s Peak Burst DPS | {_fmt(off.get('burst_dps_10s'))} |",
        f"| Offense | Auto / WS / Spell / Pet DMG | {_fmt(off.get('autoattack_damage'))} / {_fmt(off.get('weaponskill_damage'))} / {_fmt(off.get('spell_damage'))} / {_fmt(off.get('pet_and_clone_damage'))} |",
        f"| Offense | Hit Rate / Crit Rate | {_fmt(off.get('hit_rate'))} / {_fmt(off.get('crit_rate'))} |",
        f"| Defense | Actual Incoming Damage | {_fmt(dfn.get('actual_incoming_damage'))} |",
        f"| Defense | Max Single Spike / Spike Hits | {_fmt(dfn.get('max_damage_spike'))} / {_fmt(dfn.get('spike_hit_count'))} |",
        f"| Defense | Deaths / Defensive CDs | {_fmt(dfn.get('deaths'))} / {_fmt(dfn.get('defensive_cd_uses'))} |",
        f"| Healing | Effective Healing / HPS | {_fmt(heal.get('effective_healing'))} / {_fmt(heal.get('healing_per_second'))} |",
        f"| Healing | MP Consumed / Recovered | {_fmt(heal.get('mp_consumed'))} / {_fmt(heal.get('mp_recovered'))} |",
        f"| Threat | Max Enmity (CE / VE) | {_fmt(thr.get('enmity_generation'))} ({_fmt(thr.get('max_ce'))} / {_fmt(thr.get('max_ve'))}) |",
        f"| Threat | Aggro Uptime / Threat Losses | {_fmt(thr.get('tank_aggro_uptime_pct'))}% / {_fmt(thr.get('threat_losses'))} |",
        f"| Resources | TP Generated / Spent | {_fmt(res.get('tp_generated'))} / {_fmt(res.get('tp_spent'))} |",
        f"| Pets/Clones | Pet DPS / Uptime / Deaths | {_fmt(res.get('pet_dps'))} / {_fmt(res.get('pet_uptime_pct'))} / {_fmt(res.get('pet_deaths'))} |",
        "",
        "## Deterministic Rule Findings",
        "",
    ]

    findings = diag.get("findings") or []
    if not findings:
        lines.append("_No anomalies flagged by deterministic rules._")
    else:
        for f in findings:
            ts = f"`+{f['combat_sec']}s` " if f.get("combat_sec") is not None else ""
            lines.append(f"- **[{str(f.get('severity', 'info')).upper()}]** {ts}**{f.get('title')}** — {f.get('detail')}")

    if fb:
        lines.extend(
            [
                "",
                "## Fight Feel Feedback",
                "",
                f"- **Tag:** {fb.get('label')} (`{fb.get('tag')}`)",
                f"- **Summary:** {fb.get('summary_text') or '_None_'}",
            ]
        )

    if notes:
        lines.extend(["", "## Timestamped Notes", ""])
        for n in notes:
            ts = f"`+{n['combat_sec']}s`" if n.get("combat_sec") is not None else "`General`"
            lines.append(f"- {ts} **{n.get('author_name', 'User')}**: {n.get('body')}")

    return "\n".join(lines) + "\n"
