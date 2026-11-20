"""Safe local JSONL log importer for Soul Proving Grounds telemetry.

Reads:
  - `<log_dir>/runs.jsonl` (v2.0.0) + companion `events/<run_id>.jsonl`,
    `snapshots/<run_id>.jsonl`, `feedback/<run_id>.json`
  - Optional legacy `<legacy_log_path>` (e.g. `log/proving_grounds_runs.jsonl`, v1.0.0 & v2.0.0)

Validates `run_id` strictly before resolving companion paths to prevent path traversal,
imports idempotently, and enforces configured per-character retention.
"""
from __future__ import annotations

import hashlib
import json
import threading
from pathlib import Path
from typing import Any

from .db import AnalyticsDB
from .telemetry import extract_character_name, is_safe_run_id, parse_jsonl_text


def _read_optional_text(path: Path | None) -> tuple[str | None, float]:
    if path is None or not path.is_file():
        return None, 0.0
    try:
        st = path.stat()
        return path.read_text(encoding="utf-8", errors="replace"), float(st.st_mtime)
    except OSError:
        return None, 0.0


def _signature(*parts: Any) -> str:
    h = hashlib.sha256()
    for p in parts:
        h.update(str(p).encode("utf-8"))
        h.update(b"|")
    return h.hexdigest()


def import_proving_grounds_logs(
    db: AnalyticsDB,
    *,
    log_dir: Path | None = None,
    legacy_log_path: Path | None = None,
    retention_per_character: int = 50,
) -> dict[str, Any]:
    """Scan local JSONL files, import new/updated runs, and enforce retention."""
    sources: list[tuple[Path, Path | None]] = []

    if log_dir is not None:
        base = Path(log_dir)
        runs_idx = base / "runs.jsonl"
        if runs_idx.is_file():
            sources.append((runs_idx, base))
        # Also detect legacy file right next to `proving_grounds/` if caller passed `log/proving_grounds`
        sibling_legacy = base.parent / "proving_grounds_runs.jsonl"
        if legacy_log_path is None and sibling_legacy.is_file():
            sources.append((sibling_legacy, base))

    if legacy_log_path is not None:
        leg = Path(legacy_log_path)
        if leg.is_file():
            base_guess = Path(log_dir) if log_dir is not None else (leg.parent / "proving_grounds")
            if not any(s[0].resolve() == leg.resolve() for s in sources):
                sources.append((leg, base_guess if base_guess.is_dir() else None))

    imported = 0
    skipped_unchanged = 0
    malformed_lines = 0
    invalid_run_ids = 0
    seen_runs_in_pass: set[str] = set()

    for runs_file, companion_base in sources:
        text, _ = _read_optional_text(runs_file)
        if not text:
            continue
        for raw_line in text.splitlines():
            line = raw_line.strip()
            if not line:
                continue
            try:
                summary_obj = json.loads(line)
            except json.JSONDecodeError:
                malformed_lines += 1
                continue
            if not isinstance(summary_obj, dict):
                malformed_lines += 1
                continue

            run_id = summary_obj.get("run_id")
            if not isinstance(run_id, str) or not is_safe_run_id(run_id):
                invalid_run_ids += 1
                continue

            # If we already imported this exact run_id from v2 runs.jsonl in this pass, skip duplicate in legacy log
            if run_id in seen_runs_in_pass:
                continue
            seen_runs_in_pass.add(run_id)

            events_text = None
            snaps_text = None
            fb_text = None
            ev_mtime = 0.0
            sn_mtime = 0.0
            fb_mtime = 0.0

            if companion_base is not None:
                ev_path = companion_base / "events" / f"{run_id}.jsonl"
                sn_path = companion_base / "snapshots" / f"{run_id}.jsonl"
                fb_path = companion_base / "feedback" / f"{run_id}.json"
                events_text, ev_mtime = _read_optional_text(ev_path)
                snaps_text, sn_mtime = _read_optional_text(sn_path)
                fb_text, fb_mtime = _read_optional_text(fb_path)

            events_list, _ = parse_jsonl_text(events_text or "")
            snaps_list, _ = parse_jsonl_text(snaps_text or "")
            fb_obj: dict[str, Any] | None = None
            if fb_text:
                try:
                    parsed_fb = json.loads(fb_text)
                    if isinstance(parsed_fb, dict):
                        fb_obj = parsed_fb
                except json.JSONDecodeError:
                    fb_obj = None

            char_name = extract_character_name(summary_obj, events_list, snaps_list)
            sig = _signature(
                hashlib.sha256(line.encode("utf-8")).hexdigest(),
                len(events_text or ""),
                ev_mtime,
                len(snaps_text or ""),
                sn_mtime,
                len(fb_text or ""),
                fb_mtime,
            )

            changed = db.upsert_run(
                run_id=run_id,
                summary_raw_line=line,
                summary_obj=summary_obj,
                character_name=char_name,
                events_raw_jsonl=events_text,
                events_count=len(events_list),
                snapshots_raw_jsonl=snaps_text,
                snapshots_count=len(snaps_list),
                feedback_raw_json=fb_text,
                feedback_obj=fb_obj,
                source_signature=sig,
            )
            if changed:
                imported += 1
            else:
                skipped_unchanged += 1

    retention = db.enforce_retention(retention_per_character)
    return {
        "sources_scanned": [str(s[0]) for s in sources],
        "imported": imported,
        "skipped_unchanged": skipped_unchanged,
        "malformed_lines": malformed_lines,
        "invalid_run_ids": invalid_run_ids,
        "retention": retention,
    }


class LogPollingWorker:
    """Optional lightweight background thread that imports new JSONL logs periodically."""

    def __init__(
        self,
        db: AnalyticsDB,
        *,
        log_dir: Path | None,
        legacy_log_path: Path | None,
        retention_per_character: int,
        interval_sec: int,
    ):
        self.db = db
        self.log_dir = log_dir
        self.legacy_log_path = legacy_log_path
        self.retention_per_character = retention_per_character
        self.interval_sec = max(5, int(interval_sec))
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._thread is not None:
            return
        self._thread = threading.Thread(target=self._run, name="pg-log-importer", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=3.0)

    def _run(self) -> None:
        while not self._stop.wait(self.interval_sec):
            try:
                import_proving_grounds_logs(
                    self.db,
                    log_dir=self.log_dir,
                    legacy_log_path=self.legacy_log_path,
                    retention_per_character=self.retention_per_character,
                )
            except Exception:
                pass
