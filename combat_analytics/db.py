"""SQLite storage layer for SoulspireXI Combat Analytics.

Uses WAL mode, strict foreign keys, gzip-compressed raw JSONL archive blobs
(for faithful original JSONL downloads), indexed filtering, and configurable
per-character retention (default 50 unpinned reports per character + pinned).
"""
from __future__ import annotations

import gzip
import hashlib
import json
import secrets
import sqlite3
import threading
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from .telemetry import (
    FEEDBACK_LABEL_BY_KEY,
    UNAVAILABLE,
    int_or_none,
    is_num,
    normalize_summary_record,
    num_or_none,
    parse_jsonl_text,
)

UNATTRIBUTED_CHAR_KEY = "__unattributed__"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_hex(raw: str) -> str:
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _compress_text(text: str | None) -> bytes | None:
    if text is None or text == "":
        return None
    return gzip.compress(text.encode("utf-8"), compresslevel=6)


def _decompress_text(blob: bytes | None) -> str | None:
    if not blob:
        return None
    return gzip.decompress(blob).decode("utf-8")


SCHEMA_SQL = """
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE COLLATE NOCASE,
    display_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'player')),
    auth_provider TEXT NOT NULL DEFAULT 'local',
    provider_subject TEXT,
    password_hash TEXT,
    character_names_json TEXT NOT NULL DEFAULT '[]',
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    last_login_at TEXT,
    UNIQUE(auth_provider, provider_subject)
);

CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    csrf_token TEXT NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    last_seen_at TEXT NOT NULL,
    ip_hint TEXT,
    user_agent TEXT
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);

CREATE TABLE IF NOT EXISTS runs (
    run_id TEXT PRIMARY KEY,
    schema_version TEXT NOT NULL,
    timestamp_utc TEXT NOT NULL,
    character_name TEXT,
    retention_char_key TEXT NOT NULL,
    soul_key TEXT NOT NULL,
    soul_name TEXT NOT NULL,
    job TEXT NOT NULL,
    role TEXT NOT NULL,
    tier TEXT NOT NULL,
    original_character_level INTEGER,
    effective_combat_level INTEGER,
    boss_type TEXT NOT NULL,
    boss_level INTEGER,
    actual_boss_level INTEGER,
    level_gap INTEGER,
    difficulty TEXT NOT NULL,
    boss_preset TEXT NOT NULL,
    gear_profile TEXT,
    party_composition TEXT,
    outcome TEXT NOT NULL,
    test_mode TEXT,
    combat_started INTEGER NOT NULL DEFAULT 1,
    valid_for_balance INTEGER,
    extreme_challenge INTEGER NOT NULL DEFAULT 0,
    encounter_duration_sec REAL,
    prep_duration_sec REAL,
    total_damage REAL,
    sustained_dps REAL,
    burst_dps_10s REAL,
    actual_incoming_damage REAL,
    effective_healing REAL,
    deaths INTEGER DEFAULT 0,
    pet_deaths INTEGER DEFAULT 0,
    events_count INTEGER NOT NULL DEFAULT 0,
    snapshots_count INTEGER NOT NULL DEFAULT 0,
    pinned INTEGER NOT NULL DEFAULT 0,
    pinned_at TEXT,
    pinned_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    summary_json TEXT NOT NULL,
    imported_at TEXT NOT NULL,
    source_signature TEXT
);
CREATE INDEX IF NOT EXISTS idx_runs_timestamp ON runs(timestamp_utc DESC);
CREATE INDEX IF NOT EXISTS idx_runs_retention ON runs(retention_char_key, pinned, timestamp_utc DESC);
CREATE INDEX IF NOT EXISTS idx_runs_soul ON runs(soul_key);
CREATE INDEX IF NOT EXISTS idx_runs_level ON runs(effective_combat_level);
CREATE INDEX IF NOT EXISTS idx_runs_boss ON runs(boss_type);
CREATE INDEX IF NOT EXISTS idx_runs_difficulty ON runs(difficulty);
CREATE INDEX IF NOT EXISTS idx_runs_outcome ON runs(outcome);
CREATE INDEX IF NOT EXISTS idx_runs_character ON runs(character_name COLLATE NOCASE);

CREATE TABLE IF NOT EXISTS run_raw_files (
    run_id TEXT PRIMARY KEY REFERENCES runs(run_id) ON DELETE CASCADE,
    summary_jsonl_gz BLOB NOT NULL,
    events_jsonl_gz BLOB,
    snapshots_jsonl_gz BLOB,
    feedback_json_gz BLOB
);

CREATE TABLE IF NOT EXISTS run_feedback (
    run_id TEXT PRIMARY KEY REFERENCES runs(run_id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    tag TEXT NOT NULL DEFAULT 'skip',
    label TEXT NOT NULL DEFAULT 'Skip / Neutral',
    summary_text TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT 'web_ui',
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS run_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL REFERENCES runs(run_id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    author_name TEXT NOT NULL,
    combat_sec REAL,
    phase TEXT NOT NULL DEFAULT 'combat',
    body TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_run_notes_run ON run_notes(run_id, combat_sec, created_at);

CREATE TABLE IF NOT EXISTS share_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id TEXT NOT NULL REFERENCES runs(run_id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    token_prefix TEXT NOT NULL,
    label TEXT NOT NULL DEFAULT '',
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT,
    revoked_at TEXT,
    access_count INTEGER NOT NULL DEFAULT 0,
    last_accessed_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_share_links_run ON share_links(run_id);

CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    target_id TEXT,
    detail_json TEXT
);
"""


class AnalyticsDB:
    def __init__(self, db_path: Path):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()
        self._init_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(str(self.db_path), timeout=15.0)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON;")
        return conn

    def _init_schema(self) -> None:
        with self._lock:
            conn = self._connect()
            try:
                conn.executescript(SCHEMA_SQL)
                conn.commit()
            finally:
                conn.close()

    def record_audit(
        self,
        action: str,
        *,
        user_id: int | None = None,
        target_id: str | None = None,
        detail: dict[str, Any] | None = None,
    ) -> None:
        with self._lock:
            conn = self._connect()
            try:
                conn.execute(
                    "INSERT INTO audit_log (created_at, user_id, action, target_id, detail_json) VALUES (?, ?, ?, ?, ?)",
                    (utc_now_iso(), user_id, action, target_id, json.dumps(detail or {})),
                )
                conn.commit()
            finally:
                conn.close()

    # -------------------------------------------------------------------------
    # Users & Sessions
    # -------------------------------------------------------------------------
    def _row_to_user(self, row: sqlite3.Row | None) -> dict[str, Any] | None:
        if row is None:
            return None
        try:
            chars = json.loads(row["character_names_json"] or "[]")
        except json.JSONDecodeError:
            chars = []
        return {
            "id": row["id"],
            "username": row["username"],
            "display_name": row["display_name"],
            "role": row["role"],
            "auth_provider": row["auth_provider"],
            "provider_subject": row["provider_subject"],
            "character_names": [str(c) for c in chars if str(c).strip()],
            "is_active": bool(row["is_active"]),
            "created_at": row["created_at"],
            "last_login_at": row["last_login_at"],
        }

    def create_user(
        self,
        *,
        username: str,
        display_name: str,
        role: str,
        auth_provider: str = "local",
        provider_subject: str | None = None,
        password_hash: str | None = None,
        character_names: list[str] | None = None,
    ) -> dict[str, Any]:
        if role not in ("admin", "player"):
            raise ValueError("role must be 'admin' or 'player'")
        now = utc_now_iso()
        chars = [c.strip() for c in (character_names or []) if c.strip()]
        with self._lock:
            conn = self._connect()
            try:
                cur = conn.execute(
                    """
                    INSERT INTO users (
                        username, display_name, role, auth_provider, provider_subject,
                        password_hash, character_names_json, is_active, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?)
                    """,
                    (
                        username.strip(),
                        display_name.strip() or username.strip(),
                        role,
                        auth_provider,
                        provider_subject,
                        password_hash,
                        json.dumps(chars),
                        now,
                    ),
                )
                conn.commit()
                row = conn.execute("SELECT * FROM users WHERE id = ?", (cur.lastrowid,)).fetchone()
                return self._row_to_user(row)  # type: ignore[return-value]
            finally:
                conn.close()

    def get_user_with_secret_by_username(self, username: str) -> sqlite3.Row | None:
        with self._lock:
            conn = self._connect()
            try:
                return conn.execute(
                    "SELECT * FROM users WHERE username = ? COLLATE NOCASE",
                    (username.strip(),),
                ).fetchone()
            finally:
                conn.close()

    def get_user_by_id(self, user_id: int) -> dict[str, Any] | None:
        with self._lock:
            conn = self._connect()
            try:
                row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
                return self._row_to_user(row)
            finally:
                conn.close()

    def get_user_by_provider(self, provider: str, subject: str) -> dict[str, Any] | None:
        with self._lock:
            conn = self._connect()
            try:
                row = conn.execute(
                    "SELECT * FROM users WHERE auth_provider = ? AND provider_subject = ?",
                    (provider, subject),
                ).fetchone()
                return self._row_to_user(row)
            finally:
                conn.close()

    def upsert_oauth_user(
        self,
        *,
        provider: str,
        subject: str,
        username: str,
        display_name: str,
        role: str,
    ) -> dict[str, Any]:
        now = utc_now_iso()
        with self._lock:
            conn = self._connect()
            try:
                row = conn.execute(
                    "SELECT * FROM users WHERE auth_provider = ? AND provider_subject = ?",
                    (provider, subject),
                ).fetchone()
                if row is not None:
                    conn.execute(
                        "UPDATE users SET display_name = ?, role = ?, last_login_at = ? WHERE id = ?",
                        (display_name, role, now, row["id"]),
                    )
                    conn.commit()
                    updated = conn.execute("SELECT * FROM users WHERE id = ?", (row["id"],)).fetchone()
                    return self._row_to_user(updated)  # type: ignore[return-value]

                base_username = f"{provider}:{username}"
                candidate = base_username
                suffix = 1
                while conn.execute("SELECT 1 FROM users WHERE username = ? COLLATE NOCASE", (candidate,)).fetchone():
                    suffix += 1
                    candidate = f"{base_username}_{suffix}"

                cur = conn.execute(
                    """
                    INSERT INTO users (
                        username, display_name, role, auth_provider, provider_subject,
                        password_hash, character_names_json, is_active, created_at, last_login_at
                    ) VALUES (?, ?, ?, ?, ?, NULL, '[]', 1, ?, ?)
                    """,
                    (candidate, display_name, role, provider, subject, now, now),
                )
                conn.commit()
                created = conn.execute("SELECT * FROM users WHERE id = ?", (cur.lastrowid,)).fetchone()
                return self._row_to_user(created)  # type: ignore[return-value]
            finally:
                conn.close()

    def update_user_characters(self, user_id: int, character_names: list[str]) -> dict[str, Any] | None:
        cleaned = [c.strip() for c in character_names if c.strip()]
        with self._lock:
            conn = self._connect()
            try:
                conn.execute(
                    "UPDATE users SET character_names_json = ? WHERE id = ?",
                    (json.dumps(cleaned), user_id),
                )
                conn.commit()
                row = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
                return self._row_to_user(row)
            finally:
                conn.close()

    def list_users(self) -> list[dict[str, Any]]:
        with self._lock:
            conn = self._connect()
            try:
                rows = conn.execute("SELECT * FROM users ORDER BY id ASC").fetchall()
                return [self._row_to_user(r) for r in rows if r is not None]  # type: ignore[misc]
            finally:
                conn.close()

    def count_users(self) -> int:
        with self._lock:
            conn = self._connect()
            try:
                row = conn.execute("SELECT COUNT(*) AS n FROM users").fetchone()
                return int(row["n"]) if row else 0
            finally:
                conn.close()

    def create_session(
        self,
        user_id: int,
        *,
        ttl_hours: int,
        ip_hint: str = "",
        user_agent: str = "",
    ) -> tuple[str, str]:
        raw_token = secrets.token_urlsafe(32)
        csrf_token = secrets.token_urlsafe(24)
        token_hash = sha256_hex(raw_token)
        now = datetime.now(timezone.utc)
        now_iso = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        exp_iso = (now + timedelta(hours=max(1, ttl_hours))).strftime("%Y-%m-%dT%H:%M:%SZ")
        with self._lock:
            conn = self._connect()
            try:
                conn.execute("DELETE FROM sessions WHERE expires_at < ?", (now_iso,))
                conn.execute(
                    """
                    INSERT INTO sessions (token_hash, user_id, csrf_token, created_at, expires_at, last_seen_at, ip_hint, user_agent)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (token_hash, user_id, csrf_token, now_iso, exp_iso, now_iso, ip_hint[:64], user_agent[:200]),
                )
                conn.execute("UPDATE users SET last_login_at = ? WHERE id = ?", (now_iso, user_id))
                conn.commit()
            finally:
                conn.close()
        return raw_token, csrf_token

    def get_session(self, raw_token: str) -> dict[str, Any] | None:
        if not raw_token:
            return None
        token_hash = sha256_hex(raw_token)
        now_iso = utc_now_iso()
        with self._lock:
            conn = self._connect()
            try:
                row = conn.execute(
                    """
                    SELECT s.token_hash, s.csrf_token, s.expires_at, u.*
                    FROM sessions s
                    JOIN users u ON u.id = s.user_id
                    WHERE s.token_hash = ? AND s.expires_at > ? AND u.is_active = 1
                    """,
                    (token_hash, now_iso),
                ).fetchone()
                if row is None:
                    return None
                conn.execute("UPDATE sessions SET last_seen_at = ? WHERE token_hash = ?", (now_iso, token_hash))
                conn.commit()
                user = self._row_to_user(row)
                return {
                    "csrf_token": row["csrf_token"],
                    "expires_at": row["expires_at"],
                    "user": user,
                }
            finally:
                conn.close()

    def delete_session(self, raw_token: str) -> None:
        if not raw_token:
            return
        with self._lock:
            conn = self._connect()
            try:
                conn.execute("DELETE FROM sessions WHERE token_hash = ?", (sha256_hex(raw_token),))
                conn.commit()
            finally:
                conn.close()

    # -------------------------------------------------------------------------
    # Runs Import, Querying, Filtering & Retention
    # -------------------------------------------------------------------------
    def upsert_run(
        self,
        *,
        run_id: str,
        summary_raw_line: str,
        summary_obj: dict[str, Any],
        character_name: str | None,
        events_raw_jsonl: str | None,
        events_count: int,
        snapshots_raw_jsonl: str | None,
        snapshots_count: int,
        feedback_raw_json: str | None,
        feedback_obj: dict[str, Any] | None,
        source_signature: str,
    ) -> bool:
        """Insert or update a run; returns True if inserted or changed, False if skipped."""
        norm = normalize_summary_record(summary_obj)
        metrics = norm.get("metrics") or {}
        offense = metrics.get("offense") or {}
        defense = metrics.get("defense") or {}
        healing = metrics.get("healing") or {}
        res = metrics.get("resources_and_pets") or {}

        retention_key = character_name.lower() if character_name else UNATTRIBUTED_CHAR_KEY
        now = utc_now_iso()

        with self._lock:
            conn = self._connect()
            try:
                existing = conn.execute(
                    "SELECT source_signature, pinned, pinned_at, pinned_by FROM runs WHERE run_id = ?",
                    (run_id,),
                ).fetchone()
                if existing is not None and existing["source_signature"] == source_signature:
                    return False

                pinned = int(existing["pinned"]) if existing else 0
                pinned_at = existing["pinned_at"] if existing else None
                pinned_by = existing["pinned_by"] if existing else None

                conn.execute(
                    """
                    INSERT OR REPLACE INTO runs (
                        run_id, schema_version, timestamp_utc, character_name, retention_char_key,
                        soul_key, soul_name, job, role, tier,
                        original_character_level, effective_combat_level,
                        boss_type, boss_level, actual_boss_level, level_gap,
                        difficulty, boss_preset, gear_profile, party_composition,
                        outcome, test_mode, combat_started, valid_for_balance, extreme_challenge,
                        encounter_duration_sec, prep_duration_sec,
                        total_damage, sustained_dps, burst_dps_10s,
                        actual_incoming_damage, effective_healing, deaths, pet_deaths,
                        events_count, snapshots_count,
                        pinned, pinned_at, pinned_by,
                        summary_json, imported_at, source_signature
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        run_id,
                        str(norm.get("telemetry_schema_version") or "1.0.0"),
                        str(norm.get("timestamp_utc") or now),
                        character_name,
                        retention_key,
                        str(norm.get("soul_key") or "none"),
                        str(norm.get("soul_name") or "None"),
                        str(norm.get("job") or "UNKNOWN"),
                        str(norm.get("role") or "Unassigned"),
                        str(norm.get("tier") or "Unassigned"),
                        int_or_none(norm.get("original_character_level")),
                        int_or_none(norm.get("effective_combat_level")),
                        str(norm.get("boss_type") or "unknown"),
                        int_or_none(norm.get("boss_level")),
                        int_or_none(norm.get("actual_boss_level")),
                        int_or_none(norm.get("level_gap")),
                        str(norm.get("difficulty") or "even_match"),
                        str(norm.get("boss_preset") or "normal"),
                        str(norm.get("gear_profile") or "unknown"),
                        str(norm.get("party_composition") or "solo"),
                        str(norm.get("outcome") or "completed"),
                        str(norm.get("test_mode") or "manual"),
                        1 if norm.get("combat_started") else 0,
                        None if norm.get("valid_for_balance") is None else (1 if norm.get("valid_for_balance") else 0),
                        1 if norm.get("extreme_challenge") else 0,
                        num_or_none(norm.get("encounter_duration_sec")),
                        num_or_none(norm.get("prep_duration_sec")),
                        num_or_none(offense.get("total_damage")),
                        num_or_none(offense.get("sustained_dps")),
                        num_or_none(offense.get("burst_dps_10s")),
                        num_or_none(defense.get("actual_incoming_damage")),
                        num_or_none(healing.get("effective_healing")),
                        int_or_none(defense.get("deaths")) or 0,
                        int_or_none(res.get("pet_deaths")) or 0,
                        int(events_count),
                        int(snapshots_count),
                        pinned,
                        pinned_at,
                        pinned_by,
                        json.dumps(norm, separators=(",", ":")),
                        now,
                        source_signature,
                    ),
                )

                conn.execute(
                    """
                    INSERT OR REPLACE INTO run_raw_files (
                        run_id, summary_jsonl_gz, events_jsonl_gz, snapshots_jsonl_gz, feedback_json_gz
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    (
                        run_id,
                        _compress_text(summary_raw_line.rstrip("\r\n") + "\n"),
                        _compress_text(events_raw_jsonl),
                        _compress_text(snapshots_raw_jsonl),
                        _compress_text(feedback_raw_json),
                    ),
                )

                # Import NPC-menu feedback only if no web UI feedback already exists
                if isinstance(feedback_obj, dict):
                    existing_fb = conn.execute(
                        "SELECT source FROM run_feedback WHERE run_id = ?", (run_id,)
                    ).fetchone()
                    if existing_fb is None or existing_fb["source"] == "npc_menu":
                        tag = str(feedback_obj.get("tag") or "skip")
                        label = str(feedback_obj.get("label") or FEEDBACK_LABEL_BY_KEY.get(tag, tag))
                        note = str(feedback_obj.get("note") or "")
                        conn.execute(
                            """
                            INSERT OR REPLACE INTO run_feedback (
                                run_id, user_id, tag, label, summary_text, source, updated_at
                            ) VALUES (?, NULL, ?, ?, ?, ?, ?)
                            """,
                            (
                                run_id,
                                tag,
                                label,
                                note,
                                str(feedback_obj.get("source") or "npc_menu"),
                                str(feedback_obj.get("recorded_utc") or now),
                            ),
                        )

                conn.commit()
                return True
            finally:
                conn.close()

    def enforce_retention(self, max_unpinned_per_character: int) -> dict[str, Any]:
        """Keep the newest `max_unpinned_per_character` unpinned runs per character.

        Pinned runs are NEVER deleted and do not count against the unpinned quota.
        """
        keep = max(1, int(max_unpinned_per_character))
        deleted_ids: list[str] = []
        with self._lock:
            conn = self._connect()
            try:
                char_rows = conn.execute(
                    "SELECT DISTINCT retention_char_key FROM runs WHERE pinned = 0"
                ).fetchall()
                for crow in char_rows:
                    ckey = crow["retention_char_key"]
                    excess = conn.execute(
                        """
                        SELECT run_id FROM runs
                        WHERE retention_char_key = ? AND pinned = 0
                        ORDER BY timestamp_utc DESC, imported_at DESC, run_id DESC
                        LIMIT -1 OFFSET ?
                        """,
                        (ckey, keep),
                    ).fetchall()
                    for erow in excess:
                        deleted_ids.append(erow["run_id"])
                if deleted_ids:
                    conn.executemany("DELETE FROM runs WHERE run_id = ?", [(rid,) for rid in deleted_ids])
                    conn.commit()
            finally:
                conn.close()
        return {"max_unpinned_per_character": keep, "deleted_count": len(deleted_ids), "deleted_run_ids": deleted_ids}

    def _visibility_clause(self, user: dict[str, Any]) -> tuple[str, list[Any]]:
        if user.get("role") == "admin":
            return "1=1", []
        chars = [c.strip().lower() for c in (user.get("character_names") or []) if str(c).strip()]
        if not chars:
            return "1=0", []
        placeholders = ",".join("?" for _ in chars)
        return f"LOWER(COALESCE(r.character_name, '')) IN ({placeholders})", chars

    def user_can_access_run(self, user: dict[str, Any], run_row: dict[str, Any]) -> bool:
        if user.get("role") == "admin":
            return True
        cname = (run_row.get("character_name") or "").strip().lower()
        if not cname:
            return False
        allowed = {c.strip().lower() for c in (user.get("character_names") or []) if str(c).strip()}
        return cname in allowed

    def list_runs(
        self,
        user: dict[str, Any],
        *,
        soul: str | None = None,
        job: str | None = None,
        level: int | None = None,
        boss_type: str | None = None,
        difficulty: str | None = None,
        outcome: str | None = None,
        date_from: str | None = None,
        date_to: str | None = None,
        character: str | None = None,
        pinned: bool | None = None,
        valid_only: bool = False,
        query: str | None = None,
        limit: int = 50,
        offset: int = 0,
    ) -> dict[str, Any]:
        vis_sql, vis_params = self._visibility_clause(user)
        clauses = [vis_sql]
        params: list[Any] = list(vis_params)

        if soul:
            clauses.append("(LOWER(r.soul_key) = LOWER(?) OR LOWER(r.soul_name) = LOWER(?))")
            params.extend([soul.strip(), soul.strip()])
        if job:
            clauses.append("LOWER(r.job) = LOWER(?)")
            params.append(job.strip())
        if level is not None:
            clauses.append("r.effective_combat_level = ?")
            params.append(int(level))
        if boss_type:
            clauses.append("LOWER(r.boss_type) = LOWER(?)")
            params.append(boss_type.strip())
        if difficulty:
            clauses.append("LOWER(r.difficulty) = LOWER(?)")
            params.append(difficulty.strip())
        if outcome:
            clauses.append("LOWER(r.outcome) = LOWER(?)")
            params.append(outcome.strip())
        if date_from:
            clauses.append("r.timestamp_utc >= ?")
            params.append(date_from.strip())
        if date_to:
            d_to = date_to.strip()
            if len(d_to) == 10:
                d_to = d_to + "T23:59:59Z"
            clauses.append("r.timestamp_utc <= ?")
            params.append(d_to)
        if character:
            clauses.append("LOWER(COALESCE(r.character_name, '')) = LOWER(?)")
            params.append(character.strip())
        if pinned is not None:
            clauses.append("r.pinned = ?")
            params.append(1 if pinned else 0)
        if valid_only:
            clauses.append("r.valid_for_balance = 1")
        if query:
            like = f"%{query.strip()}%"
            clauses.append(
                "(r.run_id LIKE ? OR r.soul_name LIKE ? OR r.boss_type LIKE ? OR COALESCE(r.character_name, '') LIKE ? OR EXISTS (SELECT 1 FROM run_notes n WHERE n.run_id = r.run_id AND n.body LIKE ?))"
            )
            params.extend([like, like, like, like, like])

        where_sql = " AND ".join(clauses)
        lim = max(1, min(200, int(limit)))
        off = max(0, int(offset))

        with self._lock:
            conn = self._connect()
            try:
                total_row = conn.execute(
                    f"SELECT COUNT(*) AS n FROM runs r WHERE {where_sql}", params
                ).fetchone()
                total = int(total_row["n"]) if total_row else 0

                rows = conn.execute(
                    f"""
                    SELECT r.*, fb.tag AS feedback_tag, fb.label AS feedback_label,
                           (SELECT COUNT(*) FROM run_notes n WHERE n.run_id = r.run_id) AS notes_count,
                           (SELECT COUNT(*) FROM share_links s WHERE s.run_id = r.run_id AND s.revoked_at IS NULL) AS active_shares
                    FROM runs r
                    LEFT JOIN run_feedback fb ON fb.run_id = r.run_id
                    WHERE {where_sql}
                    ORDER BY r.pinned DESC, r.timestamp_utc DESC, r.run_id DESC
                    LIMIT ? OFFSET ?
                    """,
                    params + [lim, off],
                ).fetchall()

                # Facets scoped to user visibility
                f_souls = conn.execute(
                    f"SELECT DISTINCT r.soul_key, r.soul_name FROM runs r WHERE {vis_sql} ORDER BY r.soul_name",
                    vis_params,
                ).fetchall()
                f_levels = conn.execute(
                    f"SELECT DISTINCT r.effective_combat_level FROM runs r WHERE {vis_sql} AND r.effective_combat_level IS NOT NULL ORDER BY r.effective_combat_level",
                    vis_params,
                ).fetchall()
                f_bosses = conn.execute(
                    f"SELECT DISTINCT r.boss_type FROM runs r WHERE {vis_sql} ORDER BY r.boss_type",
                    vis_params,
                ).fetchall()
                f_diffs = conn.execute(
                    f"SELECT DISTINCT r.difficulty FROM runs r WHERE {vis_sql} ORDER BY r.difficulty",
                    vis_params,
                ).fetchall()
                f_outcomes = conn.execute(
                    f"SELECT DISTINCT r.outcome FROM runs r WHERE {vis_sql} ORDER BY r.outcome",
                    vis_params,
                ).fetchall()
                f_chars = conn.execute(
                    f"SELECT DISTINCT r.character_name FROM runs r WHERE {vis_sql} AND r.character_name IS NOT NULL ORDER BY r.character_name",
                    vis_params,
                ).fetchall()
                pinned_total = conn.execute(
                    f"SELECT COUNT(*) AS n FROM runs r WHERE {vis_sql} AND r.pinned = 1",
                    vis_params,
                ).fetchone()["n"]

                items = [
                    {
                        "run_id": r["run_id"],
                        "schema_version": r["schema_version"],
                        "timestamp_utc": r["timestamp_utc"],
                        "character_name": r["character_name"],
                        "soul_key": r["soul_key"],
                        "soul_name": r["soul_name"],
                        "job": r["job"],
                        "role": r["role"],
                        "tier": r["tier"],
                        "original_character_level": r["original_character_level"],
                        "effective_combat_level": r["effective_combat_level"],
                        "boss_type": r["boss_type"],
                        "boss_level": r["boss_level"],
                        "actual_boss_level": r["actual_boss_level"],
                        "level_gap": r["level_gap"],
                        "difficulty": r["difficulty"],
                        "boss_preset": r["boss_preset"],
                        "outcome": r["outcome"],
                        "test_mode": r["test_mode"],
                        "combat_started": bool(r["combat_started"]),
                        "valid_for_balance": None if r["valid_for_balance"] is None else bool(r["valid_for_balance"]),
                        "extreme_challenge": bool(r["extreme_challenge"]),
                        "encounter_duration_sec": r["encounter_duration_sec"],
                        "prep_duration_sec": r["prep_duration_sec"],
                        "total_damage": r["total_damage"],
                        "sustained_dps": r["sustained_dps"] if r["sustained_dps"] is not None else UNAVAILABLE,
                        "burst_dps_10s": r["burst_dps_10s"] if r["burst_dps_10s"] is not None else UNAVAILABLE,
                        "actual_incoming_damage": r["actual_incoming_damage"],
                        "effective_healing": r["effective_healing"],
                        "deaths": r["deaths"],
                        "pet_deaths": r["pet_deaths"],
                        "events_count": r["events_count"],
                        "snapshots_count": r["snapshots_count"],
                        "pinned": bool(r["pinned"]),
                        "pinned_at": r["pinned_at"],
                        "feedback_tag": r["feedback_tag"],
                        "feedback_label": r["feedback_label"],
                        "notes_count": r["notes_count"],
                        "active_shares": r["active_shares"],
                    }
                    for r in rows
                ]

                return {
                    "total": total,
                    "pinned_total": int(pinned_total),
                    "limit": lim,
                    "offset": off,
                    "items": items,
                    "facets": {
                        "souls": [{"key": s["soul_key"], "name": s["soul_name"]} for s in f_souls],
                        "levels": [int(lv["effective_combat_level"]) for lv in f_levels],
                        "boss_types": [b["boss_type"] for b in f_bosses],
                        "difficulties": [d["difficulty"] for d in f_diffs],
                        "outcomes": [o["outcome"] for o in f_outcomes],
                        "characters": [c["character_name"] for c in f_chars],
                    },
                }
            finally:
                conn.close()

    def get_run_meta(self, run_id: str) -> dict[str, Any] | None:
        with self._lock:
            conn = self._connect()
            try:
                row = conn.execute("SELECT * FROM runs WHERE run_id = ?", (run_id,)).fetchone()
                if row is None:
                    return None
                return dict(row)
            finally:
                conn.close()

    def get_run_payload(self, run_id: str) -> dict[str, Any] | None:
        """Load full stored run metadata, summary, events, snapshots, feedback, and notes."""
        with self._lock:
            conn = self._connect()
            try:
                run_row = conn.execute("SELECT * FROM runs WHERE run_id = ?", (run_id,)).fetchone()
                if run_row is None:
                    return None
                raw_row = conn.execute("SELECT * FROM run_raw_files WHERE run_id = ?", (run_id,)).fetchone()
                fb_row = conn.execute("SELECT * FROM run_feedback WHERE run_id = ?", (run_id,)).fetchone()
                note_rows = conn.execute(
                    "SELECT * FROM run_notes WHERE run_id = ? ORDER BY COALESCE(combat_sec, -1) ASC, created_at ASC",
                    (run_id,),
                ).fetchall()

                summary = json.loads(run_row["summary_json"])
                events_text = _decompress_text(raw_row["events_jsonl_gz"]) if raw_row else None
                snaps_text = _decompress_text(raw_row["snapshots_jsonl_gz"]) if raw_row else None
                events, _ = parse_jsonl_text(events_text or "")
                snapshots, _ = parse_jsonl_text(snaps_text or "")

                feedback = None
                if fb_row is not None:
                    feedback = {
                        "tag": fb_row["tag"],
                        "label": fb_row["label"],
                        "summary_text": fb_row["summary_text"],
                        "source": fb_row["source"],
                        "updated_at": fb_row["updated_at"],
                    }

                notes = [
                    {
                        "id": n["id"],
                        "run_id": n["run_id"],
                        "user_id": n["user_id"],
                        "author_name": n["author_name"],
                        "combat_sec": n["combat_sec"],
                        "phase": n["phase"],
                        "body": n["body"],
                        "created_at": n["created_at"],
                        "updated_at": n["updated_at"],
                    }
                    for n in note_rows
                ]

                return {
                    "meta": {
                        "run_id": run_row["run_id"],
                        "schema_version": run_row["schema_version"],
                        "timestamp_utc": run_row["timestamp_utc"],
                        "character_name": run_row["character_name"],
                        "pinned": bool(run_row["pinned"]),
                        "pinned_at": run_row["pinned_at"],
                        "imported_at": run_row["imported_at"],
                        "events_count": run_row["events_count"],
                        "snapshots_count": run_row["snapshots_count"],
                        "has_events_file": bool(raw_row and raw_row["events_jsonl_gz"]),
                        "has_snapshots_file": bool(raw_row and raw_row["snapshots_jsonl_gz"]),
                        "has_feedback_file": bool(raw_row and raw_row["feedback_json_gz"]),
                    },
                    "summary": summary,
                    "events": events,
                    "snapshots": snapshots,
                    "feedback": feedback,
                    "notes": notes,
                }
            finally:
                conn.close()

    def get_run_raw_files(self, run_id: str) -> dict[str, str | None] | None:
        with self._lock:
            conn = self._connect()
            try:
                raw_row = conn.execute("SELECT * FROM run_raw_files WHERE run_id = ?", (run_id,)).fetchone()
                if raw_row is None:
                    return None
                return {
                    "summary": _decompress_text(raw_row["summary_jsonl_gz"]),
                    "events": _decompress_text(raw_row["events_jsonl_gz"]),
                    "snapshots": _decompress_text(raw_row["snapshots_jsonl_gz"]),
                    "feedback": _decompress_text(raw_row["feedback_json_gz"]),
                }
            finally:
                conn.close()

    def set_run_pinned(self, run_id: str, pinned: bool, user_id: int | None) -> bool:
        now = utc_now_iso() if pinned else None
        with self._lock:
            conn = self._connect()
            try:
                cur = conn.execute(
                    "UPDATE runs SET pinned = ?, pinned_at = ?, pinned_by = ? WHERE run_id = ?",
                    (1 if pinned else 0, now, user_id if pinned else None, run_id),
                )
                conn.commit()
                return cur.rowcount > 0
            finally:
                conn.close()

    # -------------------------------------------------------------------------
    # Feedback & Timestamped Notes
    # -------------------------------------------------------------------------
    def save_feedback(
        self,
        run_id: str,
        *,
        user_id: int | None,
        tag: str,
        summary_text: str,
    ) -> dict[str, Any]:
        clean_tag = tag.strip() if tag and tag.strip() in FEEDBACK_LABEL_BY_KEY else "skip"
        label = FEEDBACK_LABEL_BY_KEY[clean_tag]
        now = utc_now_iso()
        with self._lock:
            conn = self._connect()
            try:
                conn.execute(
                    """
                    INSERT OR REPLACE INTO run_feedback (
                        run_id, user_id, tag, label, summary_text, source, updated_at
                    ) VALUES (?, ?, ?, ?, ?, 'web_ui', ?)
                    """,
                    (run_id, user_id, clean_tag, label, summary_text.strip()[:2000], now),
                )
                conn.commit()
                return {
                    "tag": clean_tag,
                    "label": label,
                    "summary_text": summary_text.strip()[:2000],
                    "source": "web_ui",
                    "updated_at": now,
                }
            finally:
                conn.close()

    def add_note(
        self,
        run_id: str,
        *,
        user_id: int | None,
        author_name: str,
        body: str,
        combat_sec: float | None = None,
        phase: str = "combat",
    ) -> dict[str, Any]:
        clean_body = body.strip()[:2000]
        if not clean_body:
            raise ValueError("Note body cannot be empty")
        clean_phase = phase if phase in ("preparation", "combat", "post", "general") else "combat"
        sec_val = round(float(combat_sec), 2) if is_num(combat_sec) else None
        now = utc_now_iso()
        with self._lock:
            conn = self._connect()
            try:
                cur = conn.execute(
                    """
                    INSERT INTO run_notes (run_id, user_id, author_name, combat_sec, phase, body, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (run_id, user_id, author_name[:80], sec_val, clean_phase, clean_body, now, now),
                )
                conn.commit()
                row = conn.execute("SELECT * FROM run_notes WHERE id = ?", (cur.lastrowid,)).fetchone()
                return dict(row)  # type: ignore[arg-type]
            finally:
                conn.close()

    def delete_note(self, run_id: str, note_id: int, user: dict[str, Any]) -> bool:
        with self._lock:
            conn = self._connect()
            try:
                row = conn.execute(
                    "SELECT * FROM run_notes WHERE id = ? AND run_id = ?", (note_id, run_id)
                ).fetchone()
                if row is None:
                    return False
                if user.get("role") != "admin" and row["user_id"] != user.get("id"):
                    raise PermissionError("Cannot delete another user's note")
                conn.execute("DELETE FROM run_notes WHERE id = ?", (note_id,))
                conn.commit()
                return True
            finally:
                conn.close()

    # -------------------------------------------------------------------------
    # Share Links (Private by Default, Explicitly Generated, Expiring & Revocable)
    # -------------------------------------------------------------------------
    def create_share_link(
        self,
        run_id: str,
        *,
        created_by: int | None,
        label: str = "",
        expires_in_hours: float | None = None,
    ) -> dict[str, Any]:
        raw_token = secrets.token_urlsafe(32)
        token_hash = sha256_hex(raw_token)
        token_prefix = raw_token[:8]
        now = datetime.now(timezone.utc)
        now_iso = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        exp_iso: str | None = None
        if expires_in_hours is not None and expires_in_hours > 0:
            exp_iso = (now + timedelta(hours=float(expires_in_hours))).strftime("%Y-%m-%dT%H:%M:%SZ")

        with self._lock:
            conn = self._connect()
            try:
                cur = conn.execute(
                    """
                    INSERT INTO share_links (
                        run_id, token_hash, token_prefix, label, created_by, created_at, expires_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (run_id, token_hash, token_prefix, label.strip()[:120], created_by, now_iso, exp_iso),
                )
                conn.commit()
                return {
                    "id": cur.lastrowid,
                    "run_id": run_id,
                    "token": raw_token,  # Shown once upon creation
                    "token_prefix": token_prefix,
                    "label": label.strip()[:120],
                    "created_at": now_iso,
                    "expires_at": exp_iso,
                    "revoked_at": None,
                    "access_count": 0,
                }
            finally:
                conn.close()

    def list_share_links(self, run_id: str) -> list[dict[str, Any]]:
        now_iso = utc_now_iso()
        with self._lock:
            conn = self._connect()
            try:
                rows = conn.execute(
                    "SELECT * FROM share_links WHERE run_id = ? ORDER BY created_at DESC",
                    (run_id,),
                ).fetchall()
                out = []
                for r in rows:
                    expired = bool(r["expires_at"] and r["expires_at"] <= now_iso)
                    revoked = bool(r["revoked_at"])
                    out.append(
                        {
                            "id": r["id"],
                            "run_id": r["run_id"],
                            "token_prefix": r["token_prefix"],
                            "label": r["label"],
                            "created_at": r["created_at"],
                            "expires_at": r["expires_at"],
                            "revoked_at": r["revoked_at"],
                            "expired": expired,
                            "active": not revoked and not expired,
                            "access_count": r["access_count"],
                            "last_accessed_at": r["last_accessed_at"],
                        }
                    )
                return out
            finally:
                conn.close()

    def revoke_share_link(self, share_id: int) -> dict[str, Any] | None:
        now_iso = utc_now_iso()
        with self._lock:
            conn = self._connect()
            try:
                row = conn.execute("SELECT * FROM share_links WHERE id = ?", (share_id,)).fetchone()
                if row is None:
                    return None
                conn.execute(
                    "UPDATE share_links SET revoked_at = COALESCE(revoked_at, ?) WHERE id = ?",
                    (now_iso, share_id),
                )
                conn.commit()
                return {"id": share_id, "run_id": row["run_id"], "revoked_at": row["revoked_at"] or now_iso}
            finally:
                conn.close()

    def resolve_share_token(self, raw_token: str) -> dict[str, Any] | None:
        """Validate a share token; returns share metadata or None if invalid/revoked/expired."""
        if not raw_token or len(raw_token) < 16:
            return None
        token_hash = sha256_hex(raw_token)
        now_iso = utc_now_iso()
        with self._lock:
            conn = self._connect()
            try:
                row = conn.execute("SELECT * FROM share_links WHERE token_hash = ?", (token_hash,)).fetchone()
                if row is None:
                    return None
                if row["revoked_at"] is not None:
                    return None
                if row["expires_at"] is not None and row["expires_at"] <= now_iso:
                    return None
                conn.execute(
                    "UPDATE share_links SET access_count = access_count + 1, last_accessed_at = ? WHERE id = ?",
                    (now_iso, row["id"]),
                )
                conn.commit()
                return {
                    "id": row["id"],
                    "run_id": row["run_id"],
                    "label": row["label"],
                    "created_at": row["created_at"],
                    "expires_at": row["expires_at"],
                    "access_count": int(row["access_count"]) + 1,
                }
            finally:
                conn.close()

    def get_retention_stats(self, max_unpinned_per_character: int) -> dict[str, Any]:
        with self._lock:
            conn = self._connect()
            try:
                total = conn.execute("SELECT COUNT(*) AS n FROM runs").fetchone()["n"]
                pinned = conn.execute("SELECT COUNT(*) AS n FROM runs WHERE pinned = 1").fetchone()["n"]
                per_char = conn.execute(
                    """
                    SELECT COALESCE(character_name, '(Unattributed)') AS character_name,
                           SUM(CASE WHEN pinned = 0 THEN 1 ELSE 0 END) AS unpinned_count,
                           SUM(CASE WHEN pinned = 1 THEN 1 ELSE 0 END) AS pinned_count
                    FROM runs
                    GROUP BY retention_char_key
                    ORDER BY unpinned_count DESC
                    """
                ).fetchall()
                return {
                    "max_unpinned_per_character": max_unpinned_per_character,
                    "total_runs": int(total),
                    "pinned_runs": int(pinned),
                    "unpinned_runs": int(total - pinned),
                    "by_character": [dict(r) for r in per_char],
                }
            finally:
                conn.close()
