"""Deterministic combat diagnostics engine (zero AI tokens).

Applies explicit, transparent, deterministic rules to Proving Grounds telemetry
to highlight:
  1. Damage spikes (single hits >= 25% Max HP or 3s burst >= 40% Max HP)
  2. Player deaths (with 5-second preceding death recap)
  3. Clone & pet losses (deaths, rapid despawns, low uptime)
  4. Offensive & healing downtime (contiguous zero-damage gaps, healing gaps)
  5. Resource problems (TP capping near 3000, low MP/OOM, spell interrupts, threat loss)
  6. Data integrity & telemetry health warnings (level sync, partial logging, balance validity)
"""
from __future__ import annotations

from typing import Any

from .telemetry import UNAVAILABLE, is_num, normalize_lua_list, num_or_none

# Deterministic rule thresholds
SPIKE_HP_FRACTION = 0.25
CRITICAL_SPIKE_HP_FRACTION = 0.50
BURST_3S_HP_FRACTION = 0.40
OFFENSE_DOWNTIME_MIN_SEC = 5
HEALING_GAP_MIN_SEC = 10.0
LOW_HP_UNHEALED_PCT = 60.0
LOW_HP_UNHEALED_MIN_SEC = 6
TP_OVERCAP_THRESHOLD = 2900
TP_OVERCAP_MIN_SEC = 5
MP_LOW_PCT = 15.0
MP_LOW_MIN_SEC = 5
PET_LOW_UPTIME_PCT = 70.0
CLONE_RAPID_DESPAWN_SEC = 15.0


def _finding(
    fid: str,
    rule: str,
    severity: str,
    category: str,
    title: str,
    detail: str,
    *,
    combat_sec: float | None = None,
    duration_sec: float | None = None,
    evidence: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "id": fid,
        "rule": rule,
        "severity": severity,  # "critical" | "warning" | "info"
        "category": category,  # "spike" | "death" | "clone_pet" | "downtime" | "resource" | "integrity"
        "title": title,
        "detail": detail,
        "combat_sec": round(combat_sec, 2) if combat_sec is not None else None,
        "duration_sec": round(duration_sec, 2) if duration_sec is not None else None,
        "evidence": evidence or {},
    }


def _find_contiguous_runs(points: list[dict[str, Any]], predicate) -> list[tuple[int, int, int]]:
    """Return list of (start_sec, end_sec, length_sec) for contiguous matching seconds."""
    runs: list[tuple[int, int, int]] = []
    start: int | None = None
    prev: int | None = None
    count = 0
    for pt in points:
        sec = int(pt["sec"])
        if predicate(pt):
            if start is None:
                start = sec
                count = 1
            else:
                count += 1
            prev = sec
        else:
            if start is not None and prev is not None:
                runs.append((start, prev, count))
            start = None
            prev = None
            count = 0
    if start is not None and prev is not None:
        runs.append((start, prev, count))
    return runs


def analyze_encounter(
    summary: dict[str, Any],
    events: list[dict[str, Any]],
    time_series: dict[str, Any],
) -> dict[str, Any]:
    """Run all deterministic rules and return structured findings + summary counts."""
    findings: list[dict[str, Any]] = []
    points = time_series.get("points") or []
    metrics = summary.get("metrics") or {}
    offense = metrics.get("offense") or {}
    defense = metrics.get("defense") or {}
    healing = metrics.get("healing") or {}
    threat = metrics.get("threat") or {}
    res = metrics.get("resources_and_pets") or {}
    safety = metrics.get("safety") or {}

    # Estimate player max HP from snapshots if available
    max_hp_vals = [p["player_max_hp"] for p in points if is_num(p.get("player_max_hp")) and p["player_max_hp"] > 0]
    player_max_hp = max(max_hp_vals) if max_hp_vals else None

    # -------------------------------------------------------------------------
    # 1. Damage Spikes
    # -------------------------------------------------------------------------
    spike_events = [e for e in events if e.get("event_type") == "damage_spike"]
    if spike_events:
        for idx, ev in enumerate(spike_events, start=1):
            ms = num_or_none(ev.get("combat_ms"))
            sec = (ms / 1000.0) if ms is not None else None
            dmg = num_or_none(ev.get("value")) or 0
            meta = ev.get("meta") if isinstance(ev.get("meta"), dict) else {}
            share = num_or_none(meta.get("hp_share_pct"))
            sev = "critical" if (share is not None and share >= CRITICAL_SPIKE_HP_FRACTION * 100) else "warning"
            src = ev.get("source_name") or "Boss"
            extra = f" ({share:.1f}% Max HP)" if share is not None else ""
            findings.append(
                _finding(
                    f"spike_{idx}",
                    "damage_spike",
                    sev,
                    "spike",
                    f"Damage Spike: {int(dmg)} dmg{extra}",
                    f"{src} dealt {int(dmg)} damage in a single hit{extra}.",
                    combat_sec=sec,
                    evidence={
                        "damage": dmg,
                        "hp_share_pct": share,
                        "boss_action_seq": meta.get("boss_action_seq"),
                    },
                )
            )
    else:
        # Check damage_taken events against snapshot player_max_hp if damage_spike events weren't emitted
        detected_from_events = 0
        if player_max_hp:
            for ev in events:
                if ev.get("event_type") != "damage_taken":
                    continue
                dmg = num_or_none(ev.get("value")) or 0
                frac = dmg / player_max_hp
                if frac >= SPIKE_HP_FRACTION:
                    detected_from_events += 1
                    ms = num_or_none(ev.get("combat_ms"))
                    sec = (ms / 1000.0) if ms is not None else None
                    pct = round(frac * 100.0, 1)
                    sev = "critical" if frac >= CRITICAL_SPIKE_HP_FRACTION else "warning"
                    findings.append(
                        _finding(
                            f"spike_ev_{detected_from_events}",
                            "damage_spike",
                            sev,
                            "spike",
                            f"Damage Spike: {int(dmg)} dmg ({pct}% Max HP)",
                            f"Single incoming hit of {int(dmg)} exceeded {int(SPIKE_HP_FRACTION * 100)}% of Max HP ({player_max_hp}).",
                            combat_sec=sec,
                            evidence={"damage": dmg, "player_max_hp": player_max_hp, "hp_share_pct": pct},
                        )
                    )
        # Summary-only fallback
        spike_count = num_or_none(defense.get("spike_hit_count")) or 0
        max_spike = num_or_none(defense.get("max_damage_spike")) or 0
        if detected_from_events == 0 and spike_count > 0:
            findings.append(
                _finding(
                    "spike_summary",
                    "damage_spike",
                    "warning",
                    "spike",
                    f"{int(spike_count)} Damage Spike(s) Recorded (Max {int(max_spike)})",
                    f"Telemetry summary recorded {int(spike_count)} hits >= 25% Max HP; peak single hit was {int(max_spike)}.",
                    evidence={"spike_hit_count": int(spike_count), "max_damage_spike": max_spike},
                )
            )

    # 3-second incoming burst check from snapshots
    if player_max_hp and len(points) >= 3:
        best_burst = 0.0
        best_sec = 0
        for i in range(len(points)):
            win_sum = sum(float(points[j].get("damage_received") or 0) for j in range(max(0, i - 2), i + 1))
            if win_sum > best_burst:
                best_burst = win_sum
                best_sec = int(points[i]["sec"])
        burst_frac = best_burst / player_max_hp
        if burst_frac >= BURST_3S_HP_FRACTION:
            pct = round(burst_frac * 100.0, 1)
            findings.append(
                _finding(
                    "incoming_burst_3s",
                    "incoming_burst_3s",
                    "critical" if burst_frac >= 0.70 else "warning",
                    "spike",
                    f"3-Second Incoming Burst: {int(best_burst)} dmg ({pct}% Max HP)",
                    f"Peak 3-second incoming damage window ended at +{best_sec}s ({int(best_burst)} / {player_max_hp} HP).",
                    combat_sec=float(best_sec),
                    duration_sec=3.0,
                    evidence={"burst_3s_damage": best_burst, "hp_share_pct": pct},
                )
            )

    # -------------------------------------------------------------------------
    # 2. Player Deaths (with 5-second Death Recap)
    # -------------------------------------------------------------------------
    death_events = [e for e in events if e.get("event_type") == "death"]
    if death_events:
        for idx, ev in enumerate(death_events, start=1):
            ms = num_or_none(ev.get("combat_ms"))
            sec = (ms / 1000.0) if ms is not None else None
            killer = ev.get("source_name") or "Unknown"
            victim = ev.get("target_name") or "Player"
            recap: list[dict[str, Any]] = []
            if ms is not None:
                for prev in events:
                    pms = num_or_none(prev.get("combat_ms"))
                    if pms is not None and (ms - 5000) <= pms <= ms and prev.get("event_type") in (
                        "damage_taken",
                        "damage_spike",
                        "heal_applied",
                        "boss_ability_start",
                        "boss_spell_start",
                        "defensive_ability_use",
                    ):
                        recap.append(
                            {
                                "combat_sec": round(pms / 1000.0, 2),
                                "event_type": prev.get("event_type"),
                                "source": prev.get("source_name"),
                                "value": prev.get("value"),
                            }
                        )
            findings.append(
                _finding(
                    f"death_{idx}",
                    "player_death",
                    "critical",
                    "death",
                    f"Player Death: {victim} defeated by {killer}",
                    f"{victim} fell at +{sec:.1f}s ({len(recap)} defensive/incoming events in the preceding 5s)."
                    if sec is not None
                    else f"{victim} was defeated by {killer}.",
                    combat_sec=sec,
                    evidence={"victim": victim, "killer": killer, "recap_5s": recap[-8:]},
                )
            )
    else:
        deaths_count = num_or_none(defense.get("deaths")) or 0
        if deaths_count > 0 or summary.get("outcome") == "defeat":
            findings.append(
                _finding(
                    "death_summary",
                    "player_death",
                    "critical",
                    "death",
                    f"Encounter Defeat ({int(max(1, deaths_count))} Death)",
                    "Player death recorded in encounter summary.",
                    evidence={"deaths": int(deaths_count), "outcome": summary.get("outcome")},
                )
            )

    # -------------------------------------------------------------------------
    # 3. Clone & Pet Losses
    # -------------------------------------------------------------------------
    comp_death_events = [e for e in events if e.get("event_type") in ("clone_death", "pet_death")]
    for idx, ev in enumerate(comp_death_events, start=1):
        ms = num_or_none(ev.get("combat_ms"))
        sec = (ms / 1000.0) if ms is not None else None
        is_clone = ev.get("event_type") == "clone_death"
        who = ev.get("target_name") or ("Clone" if is_clone else "Pet")
        killer = ev.get("source_name") or "Boss"
        findings.append(
            _finding(
                f"comp_loss_{idx}",
                "clone_loss" if is_clone else "pet_loss",
                "warning",
                "clone_pet",
                f"{'Clone' if is_clone else 'Pet'} Lost: {who}",
                f"{who} was defeated by {killer}" + (f" at +{sec:.1f}s." if sec is not None else "."),
                combat_sec=sec,
                evidence={"companion": who, "killer": killer, "kind": "clone" if is_clone else "pet"},
            )
        )

    # Rapid clone despawns (< 15s after spawn)
    last_spawn_by_id: dict[Any, float] = {}
    rapid_despawns = 0
    for ev in events:
        etype = ev.get("event_type")
        ms = num_or_none(ev.get("combat_ms"))
        if ms is None:
            continue
        if etype == "clone_spawn":
            last_spawn_by_id[ev.get("source_id") or ev.get("source_name")] = ms / 1000.0
        elif etype == "clone_despawn":
            cid = ev.get("source_id") or ev.get("source_name")
            if cid in last_spawn_by_id:
                life = (ms / 1000.0) - last_spawn_by_id[cid]
                if 0 < life < CLONE_RAPID_DESPAWN_SEC:
                    rapid_despawns += 1
                    findings.append(
                        _finding(
                            f"clone_rapid_despawn_{rapid_despawns}",
                            "clone_rapid_despawn",
                            "warning",
                            "clone_pet",
                            f"Rapid Clone Loss ({life:.1f}s lifetime)",
                            f"Clone {ev.get('source_name') or cid} despawned only {life:.1f}s after summoning.",
                            combat_sec=ms / 1000.0,
                            duration_sec=life,
                            evidence={"lifetime_sec": round(life, 2)},
                        )
                    )

    if not comp_death_events and is_num(res.get("pet_deaths")) and res["pet_deaths"] > 0:
        findings.append(
            _finding(
                "pet_deaths_summary",
                "pet_loss",
                "warning",
                "clone_pet",
                f"{int(res['pet_deaths'])} Pet/Clone Death(s)",
                f"Telemetry recorded {int(res['pet_deaths'])} pet or clone deaths during this encounter.",
                evidence={"pet_deaths": int(res["pet_deaths"])},
            )
        )

    pet_uptime = num_or_none(res.get("pet_uptime_pct"))
    if pet_uptime is not None and pet_uptime < PET_LOW_UPTIME_PCT:
        findings.append(
            _finding(
                "pet_low_uptime",
                "pet_low_uptime",
                "warning",
                "clone_pet",
                f"Low Pet/Clone Uptime ({pet_uptime:.1f}%)",
                f"Pet/clone uptime fell below the {PET_LOW_UPTIME_PCT:.0f}% threshold ({pet_uptime:.1f}%).",
                evidence={"pet_uptime_pct": pet_uptime},
            )
        )

    # -------------------------------------------------------------------------
    # 4. Offensive & Healing Downtime
    # -------------------------------------------------------------------------
    alive_points = [p for p in points if p.get("player_alive") is not False]
    if len(alive_points) >= OFFENSE_DOWNTIME_MIN_SEC:
        zero_dmg_runs = [
            r
            for r in _find_contiguous_runs(alive_points, lambda p: (p.get("damage_dealt") or 0) <= 0)
            if r[2] >= OFFENSE_DOWNTIME_MIN_SEC
        ]
        if zero_dmg_runs:
            total_dt = sum(r[2] for r in zero_dmg_runs)
            longest = max(zero_dmg_runs, key=lambda r: r[2])
            pct = round((total_dt / len(alive_points)) * 100.0, 1)
            findings.append(
                _finding(
                    "combat_downtime",
                    "combat_downtime",
                    "warning" if pct >= 20.0 else "info",
                    "downtime",
                    f"Offensive Downtime: {total_dt}s across {len(zero_dmg_runs)} gap(s) ({pct}%)",
                    f"Longest zero-damage stretch was {longest[2]}s (+{longest[0]}s to +{longest[1]}s) while alive in combat.",
                    combat_sec=float(longest[0]),
                    duration_sec=float(longest[2]),
                    evidence={
                        "total_downtime_sec": total_dt,
                        "downtime_pct": pct,
                        "gaps": [{"start_sec": a, "end_sec": b, "duration_sec": c} for a, b, c in zero_dmg_runs],
                    },
                )
            )

    heal_dt = num_or_none(healing.get("healing_downtime_sec"))
    if heal_dt is not None and heal_dt >= HEALING_GAP_MIN_SEC:
        findings.append(
            _finding(
                "healing_downtime",
                "healing_downtime",
                "warning",
                "downtime",
                f"Max Healing Gap: {heal_dt:.1f}s",
                f"Maximum interval between heals reached {heal_dt:.1f}s (threshold >= {HEALING_GAP_MIN_SEC:.0f}s).",
                duration_sec=heal_dt,
                evidence={"healing_downtime_sec": heal_dt},
            )
        )

    if alive_points and time_series.get("has_vitals"):
        unhealed_runs = [
            r
            for r in _find_contiguous_runs(
                alive_points,
                lambda p: is_num(p.get("player_hp_pct"))
                and p["player_hp_pct"] < LOW_HP_UNHEALED_PCT
                and (p.get("healing_done") or 0) <= 0,
            )
            if r[2] >= LOW_HP_UNHEALED_MIN_SEC
        ]
        if unhealed_runs:
            longest = max(unhealed_runs, key=lambda r: r[2])
            findings.append(
                _finding(
                    "low_hp_unhealed",
                    "low_hp_unhealed",
                    "warning",
                    "downtime",
                    f"Unhealed Below {int(LOW_HP_UNHEALED_PCT)}% HP for {longest[2]}s",
                    f"Player remained below {int(LOW_HP_UNHEALED_PCT)}% HP with zero healing from +{longest[0]}s to +{longest[1]}s.",
                    combat_sec=float(longest[0]),
                    duration_sec=float(longest[2]),
                    evidence={"start_sec": longest[0], "end_sec": longest[1], "duration_sec": longest[2]},
                )
            )

    # -------------------------------------------------------------------------
    # 5. Resource Problems (TP overcap, Low MP/OOM, Spell Interrupts, Threat Loss)
    # -------------------------------------------------------------------------
    if alive_points and time_series.get("has_vitals"):
        tp_cap_runs = [
            r
            for r in _find_contiguous_runs(
                alive_points, lambda p: is_num(p.get("player_tp")) and p["player_tp"] >= TP_OVERCAP_THRESHOLD
            )
            if r[2] >= TP_OVERCAP_MIN_SEC
        ]
        if tp_cap_runs:
            total_cap = sum(r[2] for r in tp_cap_runs)
            longest = max(tp_cap_runs, key=lambda r: r[2])
            findings.append(
                _finding(
                    "tp_overcap",
                    "tp_cap_waste",
                    "warning",
                    "resource",
                    f"TP Capped (>= {TP_OVERCAP_THRESHOLD}) for {total_cap}s",
                    f"TP sat near the 3000 cap without being spent (longest stretch {longest[2]}s at +{longest[0]}s).",
                    combat_sec=float(longest[0]),
                    duration_sec=float(longest[2]),
                    evidence={"total_capped_sec": total_cap, "threshold": TP_OVERCAP_THRESHOLD},
                )
            )

        if time_series.get("has_mp"):
            mp_low_runs = [
                r
                for r in _find_contiguous_runs(
                    alive_points, lambda p: is_num(p.get("player_mp_pct")) and p["player_mp_pct"] <= MP_LOW_PCT
                )
                if r[2] >= MP_LOW_MIN_SEC
            ]
            if mp_low_runs:
                total_low = sum(r[2] for r in mp_low_runs)
                longest = max(mp_low_runs, key=lambda r: r[2])
                hit_zero = any((p.get("player_mp") or 0) == 0 for p in alive_points if (p.get("player_max_mp") or 0) > 0)
                findings.append(
                    _finding(
                        "mp_depletion",
                        "mp_depletion",
                        "critical" if hit_zero else "warning",
                        "resource",
                        f"{'Out of MP (OOM)' if hit_zero else 'Low MP'} for {total_low}s",
                        f"MP stayed at or below {int(MP_LOW_PCT)}% for {total_low}s (longest stretch {longest[2]}s starting at +{longest[0]}s).",
                        combat_sec=float(longest[0]),
                        duration_sec=float(longest[2]),
                        evidence={"total_low_mp_sec": total_low, "hit_zero_mp": hit_zero},
                    )
                )

    tp_gen = num_or_none(res.get("tp_generated")) or 0
    tp_spent = num_or_none(res.get("tp_spent")) or 0
    if tp_gen >= 2000 and tp_spent == 0:
        findings.append(
            _finding(
                "tp_unspent",
                "tp_unspent",
                "warning",
                "resource",
                f"Unused TP ({int(tp_gen)} generated, 0 spent)",
                f"Generated {int(tp_gen)} TP during the encounter without executing a Weapon Skill.",
                evidence={"tp_generated": int(tp_gen), "tp_spent": int(tp_spent)},
            )
        )

    interrupts = num_or_none(offense.get("spell_interrupts")) or 0
    casts = num_or_none(offense.get("spell_casts")) or 0
    if interrupts > 0:
        total_attempts = casts + interrupts
        rate = round((interrupts / total_attempts) * 100.0, 1) if total_attempts > 0 else 100.0
        findings.append(
            _finding(
                "spell_interrupts",
                "spell_interrupts",
                "critical" if rate >= 25.0 else "warning",
                "resource",
                f"{int(interrupts)} Spell Interrupt(s) ({rate:.1f}%)",
                f"{int(interrupts)} cast(s) interrupted out of {int(total_attempts)} total attempts.",
                evidence={"spell_interrupts": int(interrupts), "spell_casts": int(casts), "interrupt_rate_pct": rate},
            )
        )

    threat_losses = num_or_none(threat.get("threat_losses")) or 0
    if threat_losses > 0:
        findings.append(
            _finding(
                "threat_losses",
                "threat_loss",
                "warning",
                "resource",
                f"{int(threat_losses)} Threat / Aggro Loss(es)",
                f"Boss switched primary target away from the primary player {int(threat_losses)} time(s).",
                evidence={
                    "threat_losses": int(threat_losses),
                    "tank_aggro_uptime_pct": threat.get("tank_aggro_uptime_pct", UNAVAILABLE),
                },
            )
        )

    # -------------------------------------------------------------------------
    # 6. Telemetry & Balance Integrity Warnings
    # -------------------------------------------------------------------------
    if summary.get("combat_started") is False:
        findings.append(
            _finding(
                "combat_never_started",
                "combat_never_started",
                "info",
                "integrity",
                "Combat Never Started",
                "Session ended during preparation phase before any hostile action occurred.",
            )
        )

    lvl_sync = summary.get("level_sync")
    if isinstance(lvl_sync, dict) and lvl_sync.get("valid") is False:
        findings.append(
            _finding(
                "invalid_level_sync",
                "invalid_level_sync",
                "warning",
                "integrity",
                "Invalid Level Sync",
                "Level sync validation failed; encounter excluded from balance baselines.",
                evidence={"warnings": normalize_lua_list(lvl_sync.get("warnings"))},
            )
        )

    log_status = summary.get("logging_status")
    if isinstance(log_status, dict) and log_status.get("partial_recording") is True:
        findings.append(
            _finding(
                "partial_recording",
                "partial_recording",
                "warning",
                "integrity",
                "Partial Telemetry Recording",
                "Some events or snapshots were dropped or failed to write during this run.",
                evidence={
                    "events_dropped": log_status.get("events_dropped", 0),
                    "snapshots_dropped": log_status.get("snapshots_dropped", 0),
                    "errors": normalize_lua_list(log_status.get("errors")),
                },
            )
        )

    if safety.get("progression_clean") is False:
        findings.append(
            _finding(
                "progression_dirty",
                "progression_dirty",
                "critical",
                "integrity",
                "Progression Safety Alert (EXP Observed)",
                f"Observed {safety.get('exp_points_observed', 0)} EXP across {safety.get('exp_events_observed', 0)} event(s) in a Proving Grounds trial.",
                evidence=safety,
            )
        )

    counts = {"critical": 0, "warning": 0, "info": 0}
    for f in findings:
        sev = f["severity"]
        if sev in counts:
            counts[sev] += 1

    return {
        "rule_engine_version": "1.0.0",
        "counts": counts,
        "total": len(findings),
        "findings": findings,
    }
