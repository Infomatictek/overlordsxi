"""Telemetry schema normalization, 1-second series, rolling averages, and markers.

Strictly integrates with OverlordsXI Soul Proving Grounds server-side JSONL logs
(telemetry schema v1.0.0 and v2.0.0). Unsupported or unavailable metrics remain
explicitly marked "unavailable" and are NEVER fabricated.
"""
from __future__ import annotations

import json
import re
from typing import Any

UNAVAILABLE = "unavailable"
SAFE_RUN_ID_RE = re.compile(r"^[a-zA-Z0-9_-]{1,128}$")

FEEDBACK_OPTIONS: list[dict[str, str]] = [
    {"key": "felt_great", "label": "Felt Great"},
    {"key": "damage_felt_weak", "label": "Damage Felt Weak"},
    {"key": "survival_felt_bad", "label": "Survival Felt Bad"},
    {"key": "resource_problems", "label": "Resource Problems"},
    {"key": "mechanics_felt_unfair", "label": "Mechanics Felt Unfair"},
    {"key": "skip", "label": "Skip / Neutral"},
]
FEEDBACK_LABEL_BY_KEY: dict[str, str] = {opt["key"]: opt["label"] for opt in FEEDBACK_OPTIONS}


def is_safe_run_id(run_id: str) -> bool:
    return isinstance(run_id, str) and bool(SAFE_RUN_ID_RE.match(run_id))


def is_num(val: Any) -> bool:
    return isinstance(val, (int, float)) and not isinstance(val, bool)


def num_or_none(val: Any) -> float | None:
    if is_num(val):
        return float(val)
    return None


def int_or_none(val: Any) -> int | None:
    if is_num(val):
        return int(round(float(val)))
    return None


def normalize_lua_list(val: Any) -> list[Any]:
    """Lua's custom JSON encoder serializes empty tables as `{}` instead of `[]`."""
    if isinstance(val, list):
        return val
    if isinstance(val, dict) and len(val) == 0:
        return []
    return []


def parse_jsonl_text(text: str) -> tuple[list[dict[str, Any]], int]:
    """Parse JSONL lines safely; returns (parsed_objects, skipped_malformed_lines)."""
    items: list[dict[str, Any]] = []
    skipped = 0
    if not text:
        return items, skipped
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            skipped += 1
            continue
        if isinstance(obj, dict):
            items.append(obj)
        else:
            skipped += 1
    return items, skipped


def normalize_summary_record(raw: dict[str, Any]) -> dict[str, Any]:
    """Normalize a summary JSONL object (v1.0.0 or v2.0.0) without inventing data."""
    rec = dict(raw)
    schema_version = str(rec.get("telemetry_schema_version") or rec.get("encounter_version") or "1.0.0")
    rec["telemetry_schema_version"] = schema_version

    rec["warnings"] = normalize_lua_list(rec.get("warnings"))

    lvl_sync = rec.get("level_sync")
    if isinstance(lvl_sync, dict):
        lvl_sync = dict(lvl_sync)
        lvl_sync["warnings"] = normalize_lua_list(lvl_sync.get("warnings"))
        rec["level_sync"] = lvl_sync

    log_status = rec.get("logging_status")
    if isinstance(log_status, dict):
        log_status = dict(log_status)
        log_status["errors"] = normalize_lua_list(log_status.get("errors"))
        rec["logging_status"] = log_status

    # Backfill effective/original level only from existing character_level field
    char_lvl = int_or_none(rec.get("character_level"))
    eff_lvl = int_or_none(rec.get("effective_combat_level"))
    orig_lvl = int_or_none(rec.get("original_character_level"))
    if eff_lvl is None and char_lvl is not None:
        rec["effective_combat_level"] = char_lvl
    if orig_lvl is None and char_lvl is not None:
        rec["original_character_level"] = char_lvl
    if rec.get("actual_boss_level") is None and rec.get("boss_level") is not None:
        rec["actual_boss_level"] = rec.get("boss_level")

    # Preserve combat_started when present; infer conservatively for v1.0.0 only when damage/duration proves combat
    if "combat_started" not in rec:
        metrics = rec.get("metrics") or {}
        offense = metrics.get("offense") or {}
        defense = metrics.get("defense") or {}
        dur = num_or_none(rec.get("encounter_duration_sec")) or 0.0
        has_action = (
            (num_or_none(offense.get("total_damage")) or 0) > 0
            or (num_or_none(defense.get("actual_incoming_damage")) or 0) > 0
            or (num_or_none(offense.get("melee_hits")) or 0) > 0
            or (num_or_none(offense.get("spell_casts")) or 0) > 0
        )
        rec["combat_started"] = bool(has_action or dur >= 1.0)

    if "extreme_challenge" not in rec:
        rec["extreme_challenge"] = rec.get("difficulty") in ("extreme", "boss_plus_8")
    if "standard_baseline" not in rec:
        rec["standard_baseline"] = not bool(rec["extreme_challenge"])

    return rec


def normalize_snapshot(raw: dict[str, Any]) -> dict[str, Any]:
    snap = dict(raw)
    snap["players"] = normalize_lua_list(snap.get("players"))
    snap["pets_and_clones"] = normalize_lua_list(snap.get("pets_and_clones"))
    return snap


def extract_character_name(
    summary: dict[str, Any],
    events: list[dict[str, Any]] | None = None,
    snapshots: list[dict[str, Any]] | None = None,
) -> str | None:
    """Extract character name strictly from logged telemetry fields, or return None."""
    direct = summary.get("character_name")
    if isinstance(direct, str) and direct.strip():
        return direct.strip()

    if snapshots:
        for snap in snapshots:
            players = normalize_lua_list(snap.get("players"))
            if players and isinstance(players[0], dict):
                name = players[0].get("name")
                if isinstance(name, str) and name.strip() and name.strip().lower() != "unknown":
                    return name.strip()

    if events:
        for ev in events:
            if ev.get("event_type") in ("session_start", "combat_start"):
                src = ev.get("source_name")
                if isinstance(src, str) and src.strip() and src.strip().lower() != "unknown":
                    return src.strip()
        for ev in events:
            if ev.get("category") in ("offense", "resource") and ev.get("event_type") not in ("pet_damage",):
                src = ev.get("source_name")
                if isinstance(src, str) and src.strip() and src.strip().lower() != "unknown":
                    return src.strip()

    return None


def compute_rolling_average(values: list[float], window: int) -> list[float]:
    """Compute trailing rolling average over `window` 1-second buckets."""
    if not values:
        return []
    win = max(1, int(window))
    out: list[float] = []
    running = 0.0
    for idx, val in enumerate(values):
        running += val
        if idx >= win:
            running -= values[idx - win]
        denom = min(idx + 1, win)
        out.append(round(running / denom, 2))
    return out


def build_time_series(
    summary: dict[str, Any],
    snapshots: list[dict[str, Any]],
    events: list[dict[str, Any]],
) -> dict[str, Any]:
    """Build 1-second time series and rolling averages from snapshots or binned events.

    Never fabricates a timeline for summary-only v1.0.0 runs with no snapshots or events.
    """
    norm_snaps = [normalize_snapshot(s) for s in snapshots]
    points: list[dict[str, Any]] = []
    source = "unavailable"

    if norm_snaps:
        source = "snapshots"
        by_sec: dict[int, dict[str, Any]] = {}
        for snap in norm_snaps:
            sec = int_or_none(snap.get("combat_sec"))
            if sec is None:
                ms = num_or_none(snap.get("combat_ms"))
                sec = int(ms // 1000) if ms is not None else len(by_sec)
            by_sec[sec] = snap

        max_sec = max(by_sec.keys())
        last_known: dict[str, Any] | None = None
        for sec in range(0, max_sec + 1):
            snap = by_sec.get(sec)
            if snap is not None:
                last_known = snap
                interval = snap.get("interval") or {}
                cumulative = snap.get("cumulative") or {}
                dmg_dealt = float(num_or_none(interval.get("damage_dealt")) or 0.0)
                player_dmg = float(num_or_none(interval.get("player_damage")) or 0.0)
                pet_dmg = float(num_or_none(interval.get("pet_clone_damage")) or 0.0)
                dmg_recv = float(num_or_none(interval.get("damage_received")) or 0.0)
                heal_done = float(num_or_none(interval.get("healing_done")) or 0.0)
            else:
                interval = {}
                cumulative = (last_known or {}).get("cumulative") or {}
                dmg_dealt = 0.0
                player_dmg = 0.0
                pet_dmg = 0.0
                dmg_recv = 0.0
                heal_done = 0.0

            ref = snap or last_known or {}
            players = normalize_lua_list(ref.get("players"))
            p0 = players[0] if players and isinstance(players[0], dict) else {}
            boss = ref.get("boss") if isinstance(ref.get("boss"), dict) else {}
            comps = normalize_lua_list(ref.get("pets_and_clones"))

            alive_comps = [c for c in comps if isinstance(c, dict) and c.get("alive", True)]
            avg_comp_hp_pct: float | None = None
            if comps:
                hp_vals = [float(c["hp_pct"]) for c in comps if isinstance(c, dict) and is_num(c.get("hp_pct"))]
                if hp_vals:
                    avg_comp_hp_pct = round(sum(hp_vals) / len(hp_vals), 2)

            max_mp = num_or_none(p0.get("max_mp"))
            mp = num_or_none(p0.get("mp"))
            mp_pct = round((mp / max_mp) * 100.0, 2) if (mp is not None and max_mp and max_mp > 0) else None

            points.append(
                {
                    "sec": sec,
                    "damage_dealt": round(dmg_dealt, 2),
                    "player_damage": round(player_dmg, 2),
                    "pet_clone_damage": round(pet_dmg, 2),
                    "damage_received": round(dmg_recv, 2),
                    "healing_done": round(heal_done, 2),
                    "cum_damage": num_or_none(cumulative.get("total_damage")),
                    "cum_incoming": num_or_none(cumulative.get("incoming_damage")),
                    "cum_healing": num_or_none(cumulative.get("effective_healing")),
                    "player_hp": int_or_none(p0.get("hp")),
                    "player_max_hp": int_or_none(p0.get("max_hp")),
                    "player_hp_pct": num_or_none(p0.get("hp_pct")),
                    "player_mp": int_or_none(p0.get("mp")),
                    "player_max_mp": int_or_none(p0.get("max_mp")),
                    "player_mp_pct": mp_pct,
                    "player_tp": int_or_none(p0.get("tp")),
                    "player_alive": p0.get("alive") if "alive" in p0 else None,
                    "player_buffs": int_or_none(p0.get("buff_count")),
                    "boss_hp": int_or_none(boss.get("hp")),
                    "boss_max_hp": int_or_none(boss.get("max_hp")),
                    "boss_hp_pct": num_or_none(boss.get("hp_pct")),
                    "boss_ce": int_or_none(boss.get("ce_primary")),
                    "boss_ve": int_or_none(boss.get("ve_primary")),
                    "boss_target": boss.get("target_name"),
                    "boss_debuffs": int_or_none(boss.get("debuff_count")),
                    "pet_count": len(comps),
                    "pet_alive_count": len(alive_comps),
                    "pet_avg_hp_pct": avg_comp_hp_pct,
                    "interpolated": snap is None,
                }
            )
    elif events:
        combat_events = [e for e in events if e.get("phase") == "combat" and is_num(e.get("combat_ms"))]
        if combat_events:
            source = "events_binned"
            max_sec = max(int(float(e["combat_ms"]) // 1000) for e in combat_events)
            dur = num_or_none(summary.get("encounter_duration_sec"))
            if dur is not None and int(dur) > max_sec:
                max_sec = int(dur)

            buckets = [
                {"dmg": 0.0, "p_dmg": 0.0, "pet_dmg": 0.0, "inc": 0.0, "heal": 0.0}
                for _ in range(max_sec + 1)
            ]
            for ev in combat_events:
                sec = max(0, min(max_sec, int(float(ev["combat_ms"]) // 1000)))
                etype = ev.get("event_type")
                val = num_or_none(ev.get("value")) or 0.0
                if etype == "damage_dealt":
                    buckets[sec]["dmg"] += val
                    buckets[sec]["p_dmg"] += val
                elif etype == "pet_damage":
                    buckets[sec]["dmg"] += val
                    buckets[sec]["pet_dmg"] += val
                elif etype == "damage_taken":
                    buckets[sec]["inc"] += val
                elif etype == "heal_applied":
                    buckets[sec]["heal"] += val

            cum_dmg = 0.0
            cum_inc = 0.0
            cum_heal = 0.0
            for sec, b in enumerate(buckets):
                cum_dmg += b["dmg"]
                cum_inc += b["inc"]
                cum_heal += b["heal"]
                points.append(
                    {
                        "sec": sec,
                        "damage_dealt": round(b["dmg"], 2),
                        "player_damage": round(b["p_dmg"], 2),
                        "pet_clone_damage": round(b["pet_dmg"], 2),
                        "damage_received": round(b["inc"], 2),
                        "healing_done": round(b["heal"], 2),
                        "cum_damage": round(cum_dmg, 2),
                        "cum_incoming": round(cum_inc, 2),
                        "cum_healing": round(cum_heal, 2),
                        "player_hp": None,
                        "player_max_hp": None,
                        "player_hp_pct": None,
                        "player_mp": None,
                        "player_max_mp": None,
                        "player_mp_pct": None,
                        "player_tp": None,
                        "player_alive": None,
                        "player_buffs": None,
                        "boss_hp": None,
                        "boss_max_hp": None,
                        "boss_hp_pct": None,
                        "boss_ce": None,
                        "boss_ve": None,
                        "boss_target": None,
                        "boss_debuffs": None,
                        "pet_count": None,
                        "pet_alive_count": None,
                        "pet_avg_hp_pct": None,
                        "interpolated": False,
                    }
                )

    dmg_arr = [p["damage_dealt"] for p in points]
    inc_arr = [p["damage_received"] for p in points]
    heal_arr = [p["healing_done"] for p in points]

    roll_dps_3 = compute_rolling_average(dmg_arr, 3)
    roll_dps_5 = compute_rolling_average(dmg_arr, 5)
    roll_dps_10 = compute_rolling_average(dmg_arr, 10)
    roll_inc_5 = compute_rolling_average(inc_arr, 5)
    roll_hps_5 = compute_rolling_average(heal_arr, 5)

    for idx, pt in enumerate(points):
        pt["rolling_dps_3s"] = roll_dps_3[idx]
        pt["rolling_dps_5s"] = roll_dps_5[idx]
        pt["rolling_dps_10s"] = roll_dps_10[idx]
        pt["rolling_inc_5s"] = roll_inc_5[idx]
        pt["rolling_hps_5s"] = roll_hps_5[idx]

    return {
        "source": source,
        "points": points,
        "has_vitals": source == "snapshots",
        "has_mp": any((p.get("player_max_mp") or 0) > 0 for p in points),
        "has_pets": any((p.get("pet_count") or 0) > 0 for p in points)
        or any(e.get("category") == "pet" for e in events),
    }


def extract_event_markers(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Extract notable chart markers from chronological combat events."""
    markers: list[dict[str, Any]] = []
    for ev in events:
        combat_ms = num_or_none(ev.get("combat_ms"))
        if combat_ms is None:
            continue
        sec = round(combat_ms / 1000.0, 2)
        etype = str(ev.get("event_type") or "")
        meta = ev.get("meta") if isinstance(ev.get("meta"), dict) else {}
        seq = ev.get("seq")

        if etype == "weaponskill_use" or (etype == "damage_dealt" and meta.get("source_kind") == "ws"):
            skill_name = meta.get("skill_name") or f"WS #{meta.get('skill_id', '?')}"
            dmg = ev.get("value")
            markers.append(
                {
                    "sec": sec,
                    "seq": seq,
                    "kind": "weaponskill",
                    "label": f"{skill_name} ({dmg})" if is_num(dmg) and dmg > 0 else str(skill_name),
                    "value": dmg,
                }
            )
        elif etype == "defensive_ability_use":
            ab = meta.get("ability_name") or f"Defensive #{ev.get('value', '?')}"
            markers.append({"sec": sec, "seq": seq, "kind": "defensive_cd", "label": str(ab), "value": ev.get("value")})
        elif etype == "damage_spike":
            pct = meta.get("hp_share_pct")
            lbl = f"Spike {ev.get('value')} ({pct}% HP)" if is_num(pct) else f"Spike {ev.get('value')}"
            markers.append({"sec": sec, "seq": seq, "kind": "damage_spike", "label": lbl, "value": ev.get("value")})
        elif etype == "death":
            who = ev.get("target_name") or "Player"
            markers.append({"sec": sec, "seq": seq, "kind": "death", "label": f"Death: {who}", "value": 0})
        elif etype in ("pet_death", "clone_death"):
            who = ev.get("target_name") or meta.get("kind", "Companion")
            markers.append({"sec": sec, "seq": seq, "kind": "clone_loss", "label": f"{etype}: {who}", "value": 0})
        elif etype in ("pet_spawn", "clone_spawn"):
            who = ev.get("source_name") or meta.get("kind", "Companion")
            markers.append({"sec": sec, "seq": seq, "kind": "pet_spawn", "label": f"Spawn: {who}", "value": 0})
        elif etype == "boss_ability_start":
            markers.append(
                {
                    "sec": sec,
                    "seq": seq,
                    "kind": "boss_ability",
                    "label": f"Boss Skill #{meta.get('skill_id', ev.get('value', '?'))}",
                    "value": ev.get("value"),
                }
            )
        elif etype == "boss_spell_start":
            markers.append(
                {
                    "sec": sec,
                    "seq": seq,
                    "kind": "boss_ability",
                    "label": f"Boss Spell #{meta.get('spell_id', ev.get('value', '?'))}",
                    "value": ev.get("value"),
                }
            )
        elif etype == "boss_hp_threshold":
            markers.append(
                {
                    "sec": sec,
                    "seq": seq,
                    "kind": "boss_threshold",
                    "label": f"Boss {ev.get('value')}% HP",
                    "value": ev.get("value"),
                }
            )
        elif etype == "boss_target_change":
            markers.append(
                {
                    "sec": sec,
                    "seq": seq,
                    "kind": "threat_loss",
                    "label": f"Target -> {ev.get('target_name') or ev.get('value')}",
                    "value": ev.get("value"),
                }
            )
        elif etype == "spell_interrupt":
            markers.append(
                {
                    "sec": sec,
                    "seq": seq,
                    "kind": "interrupt",
                    "label": f"Interrupted Spell #{meta.get('spell_id', ev.get('value', '?'))}",
                    "value": ev.get("value"),
                }
            )

    return markers


def build_pet_summary(
    summary: dict[str, Any],
    snapshots: list[dict[str, Any]],
    events: list[dict[str, Any]],
) -> dict[str, Any]:
    """Summarize pet & Shinobi clone activity strictly from telemetry data."""
    metrics = summary.get("metrics") or {}
    offense = metrics.get("offense") or {}
    res = metrics.get("resources_and_pets") or {}

    total_dmg = num_or_none(offense.get("total_damage")) or 0.0
    pet_dmg = num_or_none(offense.get("pet_and_clone_damage")) or 0.0

    by_comp: dict[str, dict[str, Any]] = {}

    def _ensure(key: str, name: str, kind: str) -> dict[str, Any]:
        if key not in by_comp:
            by_comp[key] = {
                "key": key,
                "name": name,
                "kind": kind,
                "spawns": 0,
                "deaths": 0,
                "despawns": 0,
                "damage_dealt": 0,
                "damage_taken": 0,
                "max_hp": None,
                "samples": 0,
                "alive_samples": 0,
            }
        return by_comp[key]

    for ev in events:
        if ev.get("category") != "pet":
            continue
        etype = ev.get("event_type")
        meta = ev.get("meta") if isinstance(ev.get("meta"), dict) else {}
        kind = str(meta.get("kind") or meta.get("source_kind") or ("clone" if "clone" in str(etype) else "pet"))
        if etype in ("pet_damage", "pet_spawn", "clone_spawn", "pet_despawn", "clone_despawn"):
            cid = ev.get("source_id")
            cname = ev.get("source_name") or kind.title()
        else:
            cid = ev.get("target_id")
            cname = ev.get("target_name") or kind.title()
        key = f"{kind}:{cid or cname}"
        rec = _ensure(key, str(cname), kind)
        if etype in ("pet_spawn", "clone_spawn"):
            rec["spawns"] += 1
            if is_num(meta.get("max_hp")):
                rec["max_hp"] = int(meta["max_hp"])
        elif etype in ("pet_death", "clone_death"):
            rec["deaths"] += 1
        elif etype in ("pet_despawn", "clone_despawn"):
            rec["despawns"] += 1
        elif etype == "pet_damage":
            rec["damage_dealt"] += int_or_none(ev.get("value")) or 0
        elif etype == "pet_damage_taken":
            rec["damage_taken"] += int_or_none(ev.get("value")) or 0

    for snap in snapshots:
        for comp in normalize_lua_list(snap.get("pets_and_clones")):
            if not isinstance(comp, dict):
                continue
            kind = str(comp.get("kind") or "pet")
            cid = comp.get("id")
            cname = comp.get("name") or kind.title()
            key = f"{kind}:{cid or cname}"
            rec = _ensure(key, str(cname), kind)
            rec["samples"] += 1
            if comp.get("alive", True):
                rec["alive_samples"] += 1
            if is_num(comp.get("max_hp")):
                rec["max_hp"] = int(comp["max_hp"])

    companions = list(by_comp.values())
    has_activity = bool(
        companions
        or pet_dmg > 0
        or (is_num(res.get("pet_deaths")) and res["pet_deaths"] > 0)
        or (res.get("pet_uptime_pct") not in (None, UNAVAILABLE))
    )

    return {
        "has_activity": has_activity,
        "pet_and_clone_damage": offense.get("pet_and_clone_damage", 0),
        "damage_share_pct": round((pet_dmg / total_dmg) * 100.0, 2) if total_dmg > 0 else UNAVAILABLE,
        "pet_dps": res.get("pet_dps", UNAVAILABLE),
        "pet_uptime_pct": res.get("pet_uptime_pct", UNAVAILABLE),
        "pet_survival": res.get("pet_survival", UNAVAILABLE),
        "pet_deaths": res.get("pet_deaths", 0),
        "companions": companions,
    }
