"""Automated unit, HTTP API integration, security & UI tests for OverlordsXI Combat Analytics."""
from __future__ import annotations

import io
import json
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timedelta, timezone
from http.cookiejar import CookieJar
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from combat_analytics.auth import (  # noqa: E402
    build_oauth_authorize_url,
    hash_password,
    verify_password,
)
from combat_analytics.config import AnalyticsConfig  # noqa: E402
from combat_analytics.db import AnalyticsDB  # noqa: E402
from combat_analytics.diagnostics import analyze_encounter  # noqa: E402
from combat_analytics.importer import import_proving_grounds_logs  # noqa: E402
from combat_analytics.server import create_server  # noqa: E402
from combat_analytics.telemetry import (  # noqa: E402
    UNAVAILABLE,
    build_pet_summary,
    build_time_series,
    extract_event_markers,
)


def _make_sample_v2_run(
    run_id: str,
    *,
    timestamp_utc: str = "2026-11-20T02:12:13Z",
    character_name: str = "HeroOne",
    soul_key: str = "shinobi",
    soul_name: str = "Shinobi",
    job: str = "NIN",
    level: int = 75,
    boss_type: str = "aoe_boss",
    boss_level: int = 78,
    difficulty: str = "very_tough",
    outcome: str = "defeat",
    include_clone_loss: bool = True,
    include_mp_oom: bool = False,
) -> tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]], dict[str, Any]]:
    summary = {
        "run_id": run_id,
        "telemetry_schema_version": "2.0.0",
        "timestamp_utc": timestamp_utc,
        "encounter_id": f"pg_{boss_type}_normal_p{level}_b{boss_level}_{difficulty}_solo",
        "encounter_version": "2.0.0",
        "soul_name": soul_name,
        "soul_key": soul_key,
        "job": job,
        "role": "Shadow Clone Melee DPS",
        "tier": "Damage",
        "original_character_level": level,
        "effective_combat_level": level,
        "character_level": level,
        "boss_type": boss_type,
        "boss_level": boss_level,
        "actual_boss_level": boss_level,
        "level_gap": boss_level - level,
        "difficulty": difficulty,
        "standard_baseline": difficulty != "extreme",
        "extreme_challenge": difficulty == "extreme",
        "boss_preset": "normal",
        "level_sync": {"valid": True, "warnings": {}},
        "gear_profile": f"accessible_lv{level}",
        "party_composition": "solo",
        "combat_started": True,
        "prep_duration_sec": 12.0,
        "encounter_duration_sec": 20.0,
        "total_session_sec": 32.0,
        "test_mode": "manual",
        "outcome": outcome,
        "seed": UNAVAILABLE,
        "valid_for_balance": difficulty != "extreme",
        "warnings": {},
        "logging_status": {
            "ok": True,
            "partial_recording": False,
            "events_written": 10,
            "events_dropped": 0,
            "snapshots_written": 21,
            "snapshots_dropped": 0,
            "errors": {},
        },
        "metrics": {
            "offense": {
                "total_damage": 5200,
                "player_damage": 4000,
                "sustained_dps": 260.0,
                "burst_dps_10s": 390.0,
                "autoattack_damage": 2400,
                "weaponskill_damage": 1600,
                "spell_damage": 0,
                "pet_and_clone_damage": 1200,
                "melee_hits": 25,
                "melee_misses": 3,
                "hit_rate": 0.8929,
                "crit_hits": 5,
                "crit_rate": 0.2,
                "weaponskill_uses": 2,
                "ability_uses": 3,
                "spell_casts": 2,
                "spell_interrupts": 1,
            },
            "defense": {
                "raw_incoming_damage": UNAVAILABLE,
                "actual_incoming_damage": 1950,
                "mitigated_damage": UNAVAILABLE,
                "block_rate": UNAVAILABLE,
                "parry_rate": UNAVAILABLE,
                "evasion_rate": UNAVAILABLE,
                "incoming_swings_hit": 12,
                "incoming_swings_missed": 4,
                "max_damage_spike": 650,
                "spike_hit_count": 1,
                "deaths": 1 if outcome == "defeat" else 0,
                "defensive_cd_uses": 1,
            },
            "healing": {
                "effective_healing": 300,
                "overhealing": UNAVAILABLE,
                "healing_per_second": 15.0,
                "mp_consumed": 180 if include_mp_oom else 0,
                "mp_recovered": 20 if include_mp_oom else 0,
                "healing_downtime_sec": 11.5,
            },
            "threat": {
                "enmity_generation": 4100,
                "max_ce": 1500,
                "max_ve": 2600,
                "threat_samples": 20,
                "tank_aggro_uptime_pct": 95.0,
                "threat_losses": 1,
            },
            "resources_and_pets": {
                "tp_generated": 3600,
                "tp_spent": 2100,
                "mp_efficiency": UNAVAILABLE,
                "avg_active_buffs": 2.5,
                "pet_survival": False if include_clone_loss else True,
                "pet_uptime_pct": 62.0 if include_clone_loss else 100.0,
                "pet_dps": 60.0,
                "pet_deaths": 1 if include_clone_loss else 0,
                "soul_specific_metrics": UNAVAILABLE,
            },
            "boss": {"abilities_used": 2, "spells_cast": 0},
            "safety": {"exp_events_observed": 0, "exp_points_observed": 0, "progression_clean": True},
        },
        "metric_availability": {
            "raw_incoming_damage": "unavailable: TAKE_DAMAGE receives post-mitigation final damage only",
            "overhealing": "unavailable: MAGIC_USE reports applied recovery only",
        },
    }

    events = [
        {
            "run_id": run_id, "seq": 1, "phase": "preparation", "session_ms": 0,
            "category": "lifecycle", "event_type": "session_start",
            "source_id": 1001, "source_name": character_name, "target_id": 9001, "target_name": "DE_Crucible_Boss", "value": boss_level,
        },
        {
            "run_id": run_id, "seq": 2, "phase": "combat", "session_ms": 12000, "combat_ms": 0,
            "category": "lifecycle", "event_type": "combat_start",
            "source_id": 1001, "source_name": character_name, "target_id": 9001, "target_name": "DE_Crucible_Boss", "value": "melee_hit",
        },
        {
            "run_id": run_id, "seq": 3, "phase": "combat", "session_ms": 13000, "combat_ms": 1000,
            "category": "pet", "event_type": "clone_spawn",
            "source_id": 5001, "source_name": "Shadow_Clone_A", "value": level, "meta": {"kind": "clone", "owner_id": 1001, "max_hp": 800},
        },
        {
            "run_id": run_id, "seq": 4, "phase": "combat", "session_ms": 17000, "combat_ms": 5000,
            "category": "offense", "event_type": "damage_dealt",
            "source_id": 1001, "source_name": character_name, "target_id": 9001, "target_name": "DE_Crucible_Boss",
            "value": 850, "meta": {"source_kind": "ws", "skill_name": "Blade: Jin", "tp_spent": 1100},
        },
        {
            "run_id": run_id, "seq": 5, "phase": "combat", "session_ms": 20000, "combat_ms": 8000,
            "category": "boss", "event_type": "boss_ability_start",
            "source_id": 9001, "source_name": "DE_Crucible_Boss", "target_id": 1001, "target_name": character_name,
            "value": 665, "meta": {"skill_id": 665},
        },
        {
            "run_id": run_id, "seq": 6, "phase": "combat", "session_ms": 20500, "combat_ms": 8500,
            "category": "defense", "event_type": "damage_taken",
            "source_id": 9001, "source_name": "DE_Crucible_Boss", "target_id": 1001, "target_name": character_name,
            "value": 650, "meta": {"boss_action_seq": 5, "boss_skill_id": 665},
        },
        {
            "run_id": run_id, "seq": 7, "phase": "combat", "session_ms": 20500, "combat_ms": 8500,
            "category": "defense", "event_type": "damage_spike",
            "source_id": 9001, "source_name": "DE_Crucible_Boss", "target_id": 1001, "target_name": character_name,
            "value": 650, "meta": {"hp_share_pct": 54.2, "boss_action_seq": 5},
        },
    ]
    if include_clone_loss:
        events.append(
            {
                "run_id": run_id, "seq": 8, "phase": "combat", "session_ms": 20700, "combat_ms": 8700,
                "category": "pet", "event_type": "clone_death",
                "source_id": 9001, "source_name": "DE_Crucible_Boss", "target_id": 5001, "target_name": "Shadow_Clone_A",
                "value": 0, "meta": {"kind": "clone", "owner_id": 1001},
            }
        )
    if outcome == "defeat":
        events.append(
            {
                "run_id": run_id, "seq": 9, "phase": "combat", "session_ms": 31000, "combat_ms": 19000,
                "category": "defense", "event_type": "death",
                "source_id": 9001, "source_name": "DE_Crucible_Boss", "target_id": 1001, "target_name": character_name,
                "value": 0,
            }
        )

    snapshots = []
    for sec in range(0, 21):
        in_downtime = 10 <= sec <= 15
        dmg = 0 if in_downtime else 320
        inc = 650 if sec == 8 else 65
        mp_val = (0 if sec >= 12 else 180) if include_mp_oom else 0
        max_mp = 200 if include_mp_oom else 0
        tp_val = 2950 if 11 <= sec <= 16 else 900
        comps: Any = (
            [{"id": 5001, "name": "Shadow_Clone_A", "kind": "clone", "owner_id": 1001, "hp": 500, "max_hp": 800, "hp_pct": 62.5, "alive": True}]
            if sec < 9
            else {}  # Deliberately test Lua empty table `{}` serialization!
        )
        snapshots.append(
            {
                "run_id": run_id,
                "combat_sec": sec,
                "combat_ms": sec * 1000,
                "players": [
                    {
                        "id": 1001, "name": character_name, "hp": max(0, 1200 - sec * 55), "max_hp": 1200,
                        "hp_pct": round(max(0, 1200 - sec * 55) / 12.0, 2),
                        "mp": mp_val, "max_mp": max_mp, "tp": tp_val,
                        "alive": not (outcome == "defeat" and sec >= 19), "buff_count": 2,
                    }
                ],
                "boss": {
                    "id": 9001, "name": "DE_Crucible_Boss", "hp": max(0, 10000 - sec * 300), "max_hp": 10000,
                    "hp_pct": round(max(0, 10000 - sec * 300) / 100.0, 2),
                    "target_id": 1001, "target_name": character_name, "ce_primary": 500 + sec * 50, "ve_primary": 1200,
                },
                "pets_and_clones": comps,
                "interval": {
                    "damage_dealt": dmg, "player_damage": dmg, "pet_clone_damage": 0,
                    "damage_received": inc, "healing_done": 150 if sec == 9 else 0,
                },
                "cumulative": {
                    "total_damage": sec * 250, "player_damage": sec * 200, "pet_clone_damage": sec * 50,
                    "incoming_damage": sec * 90, "effective_healing": 150 if sec >= 9 else 0,
                },
                "soul_resources": UNAVAILABLE,
            }
        )

    feedback = {
        "run_id": run_id,
        "telemetry_schema_version": "2.0.0",
        "recorded_utc": timestamp_utc,
        "source": "npc_menu",
        "tag": "survival_felt_bad",
        "label": "Survival Felt Bad",
    }
    return summary, events, snapshots, feedback


def _write_v2_log_dir(
    base: Path,
    runs: list[tuple[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]], dict[str, Any] | None]],
) -> None:
    (base / "events").mkdir(parents=True, exist_ok=True)
    (base / "snapshots").mkdir(parents=True, exist_ok=True)
    (base / "feedback").mkdir(parents=True, exist_ok=True)
    summary_lines = []
    for summary, events, snaps, fb in runs:
        rid = summary["run_id"]
        summary_lines.append(json.dumps(summary, separators=(",", ":")))
        if events:
            (base / "events" / f"{rid}.jsonl").write_text(
                "\n".join(json.dumps(e, separators=(",", ":")) for e in events) + "\n", encoding="utf-8"
            )
        if snaps:
            (base / "snapshots" / f"{rid}.jsonl").write_text(
                "\n".join(json.dumps(s, separators=(",", ":")) for s in snaps) + "\n", encoding="utf-8"
            )
        if fb:
            (base / "feedback" / f"{rid}.json").write_text(json.dumps(fb) + "\n", encoding="utf-8")
    (base / "runs.jsonl").write_text("\n".join(summary_lines) + "\n", encoding="utf-8")


class TelemetryAndDiagnosticsTests(unittest.TestCase):
    def test_v2_time_series_markers_pets_and_deterministic_rules(self):
        summary, events, snaps, _ = _make_sample_v2_run("pg_diag_test_1", include_clone_loss=True, include_mp_oom=True)
        ts = build_time_series(summary, snaps, events)
        self.assertEqual(ts["source"], "snapshots")
        self.assertTrue(ts["has_vitals"])
        self.assertTrue(ts["has_mp"])
        self.assertTrue(ts["has_pets"])
        self.assertEqual(len(ts["points"]), 21)
        self.assertIn("rolling_dps_5s", ts["points"][10])
        self.assertIn("rolling_dps_10s", ts["points"][10])

        markers = extract_event_markers(events)
        marker_kinds = {m["kind"] for m in markers}
        self.assertIn("weaponskill", marker_kinds)
        self.assertIn("damage_spike", marker_kinds)
        self.assertIn("death", marker_kinds)
        self.assertIn("clone_loss", marker_kinds)

        pet_sum = build_pet_summary(summary, snaps, events)
        self.assertTrue(pet_sum["has_activity"])
        self.assertEqual(pet_sum["pet_deaths"], 1)
        self.assertEqual(len(pet_sum["companions"]), 1)

        diag = analyze_encounter(summary, events, ts)
        rules = {f["rule"] for f in diag["findings"]}
        for expected in (
            "damage_spike",
            "incoming_burst_3s",
            "player_death",
            "clone_loss",
            "pet_low_uptime",
            "combat_downtime",
            "healing_downtime",
            "tp_cap_waste",
            "mp_depletion",
            "spell_interrupts",
            "threat_loss",
        ):
            self.assertIn(expected, rules, f"Missing deterministic rule: {expected}")

        # Verify unsupported metrics stay strictly "unavailable"
        self.assertEqual(summary["metrics"]["defense"]["raw_incoming_damage"], UNAVAILABLE)
        self.assertEqual(summary["metrics"]["healing"]["overhealing"], UNAVAILABLE)

    def test_v1_summary_only_never_fabricates_timeline(self):
        v1_summary = {
            "run_id": "pg_legacy_v1",
            "encounter_version": "1.0.0",
            "timestamp_utc": "2026-11-20T01:25:09Z",
            "soul_key": "none",
            "soul_name": "None",
            "job": "WAR",
            "character_level": 10,
            "boss_type": "physical_bruiser",
            "boss_level": 10,
            "difficulty": "even_match",
            "outcome": "reset",
            "encounter_duration_sec": 0.001,
            "metrics": {
                "offense": {"total_damage": 0, "sustained_dps": 0},
                "defense": {"actual_incoming_damage": 0, "raw_incoming_damage": UNAVAILABLE, "deaths": 0},
                "healing": {"effective_healing": 0, "overhealing": UNAVAILABLE},
                "threat": {"enmity_generation": 0, "threat_losses": 0},
                "resources_and_pets": {"tp_generated": 0, "tp_spent": 0, "pet_uptime_pct": UNAVAILABLE},
                "safety": {"progression_clean": True, "exp_events_observed": 0, "exp_points_observed": 0},
            },
        }
        ts = build_time_series(v1_summary, [], [])
        self.assertEqual(ts["source"], "unavailable")
        self.assertEqual(ts["points"], [])

    def test_retention_keeps_configured_recent_per_character_plus_pinned(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            db = AnalyticsDB(tmp / "test.db")
            log_dir = tmp / "pg"
            runs_to_write = []
            base_dt = datetime(2026, 11, 1, 0, 0, 0, tzinfo=timezone.utc)
            # 60 runs for HeroOne, 5 runs for HeroTwo
            for i in range(60):
                ts_iso = (base_dt + timedelta(minutes=i)).strftime("%Y-%m-%dT%H:%M:%SZ")
                runs_to_write.append(_make_sample_v2_run(f"pg_h1_{i:03d}", timestamp_utc=ts_iso, character_name="HeroOne"))
            for i in range(5):
                ts_iso = (base_dt + timedelta(minutes=i)).strftime("%Y-%m-%dT%H:%M:%SZ")
                runs_to_write.append(_make_sample_v2_run(f"pg_h2_{i:03d}", timestamp_utc=ts_iso, character_name="HeroTwo"))

            _write_v2_log_dir(log_dir, runs_to_write)
            # First import with high limit so we can pin the oldest HeroOne run (`pg_h1_000`)
            import_proving_grounds_logs(db, log_dir=log_dir, retention_per_character=100)
            self.assertTrue(db.set_run_pinned("pg_h1_000", True, None))

            # Enforce default retention = 50 unpinned per character
            prune_res = db.enforce_retention(50)
            self.assertEqual(prune_res["deleted_count"], 9)  # 59 unpinned -> keep 50, delete 9 oldest unpinned

            # Oldest pinned run MUST still exist, plus 50 newest unpinned for HeroOne, plus all 5 for HeroTwo
            self.assertIsNotNone(db.get_run_meta("pg_h1_000"))
            self.assertIsNone(db.get_run_meta("pg_h1_001"))  # Deleted (unpinned & older than 50)
            self.assertIsNotNone(db.get_run_meta("pg_h1_059"))  # Kept (newest)
            stats = db.get_retention_stats(50)
            self.assertEqual(stats["pinned_runs"], 1)
            self.assertEqual(stats["unpinned_runs"], 55)

    def test_importer_rejects_path_traversal_run_ids(self):
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            db = AnalyticsDB(tmp / "test.db")
            log_dir = tmp / "pg"
            log_dir.mkdir()
            bad = {"run_id": "../../etc/passwd", "metrics": {}}
            (log_dir / "runs.jsonl").write_text(json.dumps(bad) + "\n", encoding="utf-8")
            res = import_proving_grounds_logs(db, log_dir=log_dir)
            self.assertEqual(res["imported"], 0)
            self.assertEqual(res["invalid_run_ids"], 1)


class _TestHttpClient:
    """Minimal cookie-aware HTTP client using Python stdlib urllib."""

    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.jar = CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(self.jar))
        self.csrf_token: str | None = None

    def request(
        self,
        method: str,
        path: str,
        *,
        json_body: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
        send_csrf: bool = True,
    ) -> tuple[int, bytes, Any]:
        hdrs = dict(headers or {})
        data = None
        if json_body is not None:
            data = json.dumps(json_body).encode("utf-8")
            hdrs["Content-Type"] = "application/json"
        if send_csrf and self.csrf_token and method.upper() not in ("GET", "HEAD", "OPTIONS"):
            hdrs["X-CSRF-Token"] = self.csrf_token
        req = urllib.request.Request(f"{self.base_url}{path}", data=data, headers=hdrs, method=method.upper())
        try:
            with self.opener.open(req, timeout=10) as resp:
                return resp.status, resp.read(), resp.headers
        except urllib.error.HTTPError as err:
            return err.code, err.read(), err.headers

    def json(self, method: str, path: str, **kwargs) -> tuple[int, Any, Any]:
        status, body, hdrs = self.request(method, path, **kwargs)
        parsed = json.loads(body.decode("utf-8")) if body else None
        return status, parsed, hdrs


class CombatAnalyticsApiIntegrationTests(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.tmp = Path(self._td.name)
        self.log_dir = self.tmp / "pg_logs"

        r1 = _make_sample_v2_run("pg_run_hero1_shinobi", timestamp_utc="2026-11-18T10:00:00Z", character_name="HeroOne", soul_key="shinobi", soul_name="Shinobi", job="NIN", level=75, boss_type="aoe_boss", boss_level=78, difficulty="very_tough", outcome="defeat")
        r2 = _make_sample_v2_run("pg_run_hero2_berserker", timestamp_utc="2026-11-19T12:00:00Z", character_name="HeroTwo", soul_key="berserker", soul_name="Berserker", job="WAR", level=10, boss_type="physical_bruiser", boss_level=10, difficulty="even_match", outcome="victory", include_clone_loss=False)
        _write_v2_log_dir(self.log_dir, [r1, r2])

        self.cfg = AnalyticsConfig(
            host="127.0.0.1",
            port=0,
            db_path=self.tmp / "analytics.db",
            log_dir=self.log_dir,
            site_dir=REPO_ROOT / "site",
            serve_static_site=True,
            retention_per_character=50,
            max_login_attempts=4,
            discord_client_id="demo_discord_id",
            discord_client_secret="demo_discord_secret",
            discord_redirect_uri="https://wiki.example.com/api/combat/auth/oauth/discord/callback",
        )
        self.db = AnalyticsDB(self.cfg.db_path)
        self.admin_user = self.db.create_user(
            username="admin",
            display_name="Server Admin",
            role="admin",
            password_hash=hash_password("CorrectHorseBatteryStaple!"),
        )
        self.player_user = self.db.create_user(
            username="player1",
            display_name="HeroOne Player",
            role="player",
            password_hash=hash_password("AnotherStrongPassword123!"),
            character_names=["HeroOne"],
        )

        self.server = create_server(self.cfg, db=self.db)
        self.server.app.start_background_tasks()
        host, port = self.server.server_address
        self.base_url = f"http://{host}:{port}"
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.app.stop_background_tasks()
        self.server.server_close()
        self.thread.join(timeout=3)
        self._td.cleanup()

    def test_private_by_default_and_security_headers(self):
        anon = _TestHttpClient(self.base_url)
        st, body, hdrs = anon.json("GET", "/api/combat/reports")
        self.assertEqual(st, 401)
        self.assertEqual(body["error"], "authentication_required")
        self.assertEqual(hdrs.get("X-Robots-Tag"), "noindex, nofollow")
        self.assertIn("no-store", hdrs.get("Cache-Control", ""))

        st2, _, _ = anon.json("GET", "/api/combat/reports/pg_run_hero1_shinobi")
        self.assertEqual(st2, 401)

        st3, _, _ = anon.json("GET", "/api/combat/reports/pg_run_hero1_shinobi/download?file=summary")
        self.assertEqual(st3, 401)

    def test_scrypt_auth_csrf_rate_limit_and_logout(self):
        self.assertTrue(verify_password("CorrectHorseBatteryStaple!", hash_password("CorrectHorseBatteryStaple!")))
        self.assertFalse(verify_password("wrong", hash_password("CorrectHorseBatteryStaple!")))

        client = _TestHttpClient(self.base_url)
        # Wrong password hits rate limiter after max_login_attempts=4
        for _ in range(4):
            st, _, _ = client.json("POST", "/api/combat/auth/login", json_body={"username": "admin", "password": "wrongpassword"})
            self.assertEqual(st, 401)
        st_lock, body_lock, _ = client.json("POST", "/api/combat/auth/login", json_body={"username": "admin", "password": "CorrectHorseBatteryStaple!"})
        self.assertEqual(st_lock, 429)
        self.assertEqual(body_lock["error"], "too_many_attempts")

        # Reset throttle for a clean login test
        self.server.app.rate_limiter.reset("127.0.0.1:admin")
        st_ok, body_ok, hdrs_ok = client.json("POST", "/api/combat/auth/login", json_body={"username": "admin", "password": "CorrectHorseBatteryStaple!"})
        self.assertEqual(st_ok, 200)
        self.assertTrue(body_ok["authenticated"])
        self.assertIn("HttpOnly", hdrs_ok.get("Set-Cookie", ""))
        client.csrf_token = body_ok["csrf_token"]

        # State-changing request without CSRF MUST fail with 403
        st_nocsrf, _, _ = client.json("POST", "/api/combat/reports/pg_run_hero1_shinobi/pin", json_body={"pinned": True}, send_csrf=False)
        self.assertEqual(st_nocsrf, 403)

        # With CSRF succeeds
        st_pin, pin_body, _ = client.json("POST", "/api/combat/reports/pg_run_hero1_shinobi/pin", json_body={"pinned": True})
        self.assertEqual(st_pin, 200)
        self.assertTrue(pin_body["pinned"])

        # Logout clears session
        st_out, _, _ = client.json("POST", "/api/combat/auth/logout")
        self.assertEqual(st_out, 200)
        st_after, _, _ = client.json("GET", "/api/combat/reports")
        self.assertEqual(st_after, 401)

    def test_oauth_provider_advertised_and_authorize_url(self):
        anon = _TestHttpClient(self.base_url)
        st, me, _ = anon.json("GET", "/api/combat/auth/me")
        self.assertEqual(st, 200)
        self.assertIn("local", me["providers"])
        self.assertIn("discord", me["providers"])
        url = build_oauth_authorize_url(self.cfg, "discord", "state_nonce_123")
        self.assertIn("discord.com/api/oauth2/authorize", url)
        self.assertIn("state=state_nonce_123", url)

    def test_player_scoping_filters_feedback_notes_shares_and_downloads(self):
        # 1. Player login sees ONLY HeroOne runs, NOT HeroTwo
        p_client = _TestHttpClient(self.base_url)
        st, data, _ = p_client.json("POST", "/api/combat/auth/login", json_body={"username": "player1", "password": "AnotherStrongPassword123!"})
        self.assertEqual(st, 200)
        p_client.csrf_token = data["csrf_token"]

        st_list, list_data, _ = p_client.json("GET", "/api/combat/reports")
        self.assertEqual(st_list, 200)
        self.assertEqual(list_data["total"], 1)
        self.assertEqual(list_data["items"][0]["run_id"], "pg_run_hero1_shinobi")

        # Accessing HeroTwo's report is 403 Forbidden
        st_forbid, _, _ = p_client.json("GET", "/api/combat/reports/pg_run_hero2_berserker")
        self.assertEqual(st_forbid, 403)

        # 2. Admin sees both runs and filters cleanly by soul, level, boss, difficulty, outcome, date
        admin = _TestHttpClient(self.base_url)
        _, adm_login, _ = admin.json("POST", "/api/combat/auth/login", json_body={"username": "admin", "password": "CorrectHorseBatteryStaple!"})
        admin.csrf_token = adm_login["csrf_token"]

        _, all_runs, _ = admin.json("GET", "/api/combat/reports")
        self.assertEqual(all_runs["total"], 2)

        _, filt, _ = admin.json(
            "GET",
            "/api/combat/reports?soul=berserker&level=10&boss_type=physical_bruiser&difficulty=even_match&outcome=victory&date_from=2026-11-19&date_to=2026-11-19",
        )
        self.assertEqual(filt["total"], 1)
        self.assertEqual(filt["items"][0]["run_id"], "pg_run_hero2_berserker")

        # 3. Feedback & Timestamped Notes
        st_fb, fb_res, _ = admin.json(
            "PUT",
            "/api/combat/reports/pg_run_hero1_shinobi/feedback",
            json_body={"tag": "mechanics_felt_unfair", "summary_text": "AoE spike wiped clone instantly."},
        )
        self.assertEqual(st_fb, 200)
        self.assertEqual(fb_res["feedback"]["tag"], "mechanics_felt_unfair")

        st_note, note_res, _ = admin.json(
            "POST",
            "/api/combat/reports/pg_run_hero1_shinobi/notes",
            json_body={"combat_sec": 8.5, "body": "Grand Slam hit for 650 and killed Shadow Clone A"},
        )
        self.assertEqual(st_note, 201)
        note_id = note_res["note"]["id"]

        # 4. Share Link lifecycle: create -> anonymous read-only view & download -> revoke -> 404
        st_sh, sh_res, _ = admin.json(
            "POST",
            "/api/combat/reports/pg_run_hero1_shinobi/shares",
            json_body={"label": "Team Review", "expires_in_hours": 24},
        )
        self.assertEqual(st_sh, 201)
        share_token = sh_res["share"]["token"]
        share_id = sh_res["share"]["id"]

        anon = _TestHttpClient(self.base_url)
        st_pub, pub_rep, _ = anon.json("GET", f"/api/combat/shared/{share_token}")
        self.assertEqual(st_pub, 200)
        self.assertTrue(pub_rep["read_only"])
        self.assertEqual(pub_rep["meta"]["run_id"], "pg_run_hero1_shinobi")
        self.assertEqual(pub_rep["feedback"]["tag"], "mechanics_felt_unfair")
        self.assertEqual(len(pub_rep["notes"]), 1)
        self.assertNotIn("shares", pub_rep)

        # Download original JSONL bundle via share link
        st_zip, zip_bytes, _ = anon.request("GET", f"/api/combat/shared/{share_token}/download?file=bundle")
        self.assertEqual(st_zip, 200)
        with zipfile.ZipFile(io.BytesIO(zip_bytes), "r") as zf:
            names = set(zf.namelist())
            self.assertIn("pg_run_hero1_shinobi_summary.jsonl", names)
            self.assertIn("events/pg_run_hero1_shinobi.jsonl", names)
            self.assertIn("snapshots/pg_run_hero1_shinobi.jsonl", names)
            self.assertIn("feedback/pg_run_hero1_shinobi.json", names)

        # Markdown & CSV exports
        st_md, md_bytes, _ = admin.request("GET", "/api/combat/reports/pg_run_hero1_shinobi/download?file=markdown")
        self.assertEqual(st_md, 200)
        self.assertIn(b"Deterministic Rule Findings", md_bytes)

        st_csv, csv_bytes, _ = admin.request("GET", "/api/combat/reports/pg_run_hero1_shinobi/download?file=csv")
        self.assertEqual(st_csv, 200)
        self.assertIn(b"rolling_dps_10s", csv_bytes)

        # Revoke share -> immediately 404 for anonymous client
        st_rev, _, _ = admin.json("DELETE", f"/api/combat/shares/{share_id}")
        self.assertEqual(st_rev, 200)
        st_after_rev, _, _ = anon.json("GET", f"/api/combat/shared/{share_token}")
        self.assertEqual(st_after_rev, 404)

        # Delete note
        st_del, _, _ = admin.json("DELETE", f"/api/combat/reports/pg_run_hero1_shinobi/notes/{note_id}")
        self.assertEqual(st_del, 200)

        # Static site served cleanly in prototype mode
        st_idx, idx_bytes, _ = anon.request("GET", "/")
        self.assertEqual(st_idx, 200)
        self.assertIn(b"Combat Reports", idx_bytes)


class SecurityHygieneAndUiSuiteTests(unittest.TestCase):
    def test_no_private_logs_or_secrets_in_static_site_or_backend(self):
        site_dir = REPO_ROOT / "site"
        for p in site_dir.rglob("*"):
            if p.is_file():
                self.assertNotIn(p.suffix.lower(), {".jsonl", ".db", ".sqlite", ".env"})
        for js_file in (site_dir / "app.js", site_dir / "combat-reports.js"):
            txt = js_file.read_text(encoding="utf-8")
            self.assertNotIn("github_pat_", txt)
            self.assertNotIn("accounts_password", txt)
            self.assertNotIn("mariadb", txt.lower())

        # Backend must never touch FFXI accounts table / MariaDB
        backend_dir = REPO_ROOT / "combat_analytics"
        for py_file in backend_dir.glob("*.py"):
            txt = py_file.read_text(encoding="utf-8")
            self.assertNotIn("import mariadb", txt)
            self.assertNotIn("import pymysql", txt)
            self.assertNotIn("import mysql", txt)

    def test_frontend_js_syntax_and_ui_unit_tests(self):
        node_bin = shutil.which("node")
        if not node_bin:
            self.skipTest("node runtime not found on PATH")

        for rel in ("site/combat-reports.js", "site/app.js"):
            chk = subprocess.run([node_bin, "--check", str(REPO_ROOT / rel)], capture_output=True, text=True)
            self.assertEqual(chk.returncode, 0, msg=f"Syntax check failed for {rel}: {chk.stderr}")

        ui_test = subprocess.run(
            [node_bin, "--test", str(REPO_ROOT / "tests" / "test_combat_reports_ui.mjs")],
            capture_output=True,
            text=True,
        )
        self.assertEqual(ui_test.returncode, 0, msg=f"UI tests failed:\n{ui_test.stdout}\n{ui_test.stderr}")


if __name__ == "__main__":
    unittest.main()
