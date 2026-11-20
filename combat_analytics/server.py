"""Lightweight ThreadingHTTPServer API for SoulspireXI Combat Analytics.

Deployable directly behind SWAG/Nginx (`location /api/combat/` -> `http://127.0.0.1:8765`)
or standalone for local prototyping (`--serve-site`). Uses Python 3.11 stdlib only.
"""
from __future__ import annotations

import hmac
import json
import mimetypes
import re
import urllib.parse
from http import cookies
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

from . import __version__
from .auth import (
    LoginRateLimiter,
    OAuthStateStore,
    build_oauth_authorize_url,
    exchange_oauth_code,
    hash_password,
    verify_password,
)
from .config import AnalyticsConfig
from .db import AnalyticsDB
from .diagnostics import analyze_encounter
from .exports import (
    build_markdown_summary,
    build_raw_bundle_zip,
    build_runs_list_csv,
    build_timeline_csv,
)
from .importer import LogPollingWorker, import_proving_grounds_logs
from .telemetry import (
    FEEDBACK_OPTIONS,
    build_pet_summary,
    build_time_series,
    extract_event_markers,
    is_safe_run_id,
)

MAX_JSON_BODY_BYTES = 256 * 1024  # 256 KB ceiling for API JSON bodies


def build_full_report(
    payload: dict[str, Any],
    *,
    shares: list[dict[str, Any]] | None = None,
    read_only: bool = False,
    share_info: dict[str, Any] | None = None,
) -> dict[str, Any]:
    summary = payload["summary"]
    events = payload["events"]
    snapshots = payload["snapshots"]
    time_series = build_time_series(summary, snapshots, events)
    markers = extract_event_markers(events)
    pet_summary = build_pet_summary(summary, snapshots, events)
    diagnostics = analyze_encounter(summary, events, time_series)

    res: dict[str, Any] = {
        "read_only": read_only,
        "meta": payload["meta"],
        "summary": summary,
        "time_series": time_series,
        "markers": markers,
        "pet_summary": pet_summary,
        "diagnostics": diagnostics,
        "feedback": payload["feedback"],
        "notes": payload["notes"],
        "events": events,
    }
    if shares is not None:
        res["shares"] = shares
    if share_info is not None:
        res["share"] = share_info
    return res


class AnalyticsApp:
    """Shared application state attached to the HTTP server instance."""

    def __init__(self, cfg: AnalyticsConfig, db: AnalyticsDB | None = None):
        self.cfg = cfg
        self.db = db or AnalyticsDB(cfg.db_path)
        self.rate_limiter = LoginRateLimiter(
            max_attempts=cfg.max_login_attempts,
            window_sec=cfg.login_window_sec,
        )
        self.oauth_states = OAuthStateStore()
        self.poller: LogPollingWorker | None = None

    def start_background_tasks(self) -> None:
        if self.cfg.log_dir or self.cfg.legacy_log_path:
            import_proving_grounds_logs(
                self.db,
                log_dir=self.cfg.log_dir,
                legacy_log_path=self.cfg.legacy_log_path,
                retention_per_character=self.cfg.retention_per_character,
            )
        if self.cfg.poll_interval_sec > 0 and (self.cfg.log_dir or self.cfg.legacy_log_path):
            self.poller = LogPollingWorker(
                self.db,
                log_dir=self.cfg.log_dir,
                legacy_log_path=self.cfg.legacy_log_path,
                retention_per_character=self.cfg.retention_per_character,
                interval_sec=self.cfg.poll_interval_sec,
            )
            self.poller.start()

    def stop_background_tasks(self) -> None:
        if self.poller is not None:
            self.poller.stop()
            self.poller = None


class AnalyticsHTTPServer(ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, server_address: tuple[str, int], app: AnalyticsApp):
        self.app = app
        super().__init__(server_address, AnalyticsRequestHandler)


class AnalyticsRequestHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        # Quiet logging in tests; override or wrap if verbose logging is desired.
        pass

    @property
    def app(self) -> AnalyticsApp:
        return self.server.app  # type: ignore[attr-defined]

    def _client_ip(self) -> str:
        if self.app.cfg.trust_proxy_headers:
            xff = self.headers.get("X-Forwarded-For")
            if xff:
                return xff.split(",")[0].strip()
            xri = self.headers.get("X-Real-IP")
            if xri:
                return xri.strip()
        return self.client_address[0] if self.client_address else "unknown"

    def _is_https(self) -> bool:
        if self.app.cfg.cookie_secure:
            return True
        if self.app.cfg.trust_proxy_headers:
            proto = (self.headers.get("X-Forwarded-Proto") or "").lower()
            if proto == "https":
                return True
        return False

    def _base_url(self) -> str:
        if self.app.cfg.public_base_url:
            return self.app.cfg.public_base_url
        scheme = "https" if self._is_https() else "http"
        host = self.headers.get("X-Forwarded-Host") or self.headers.get("Host") or f"{self.app.cfg.host}:{self.app.cfg.port}"
        return f"{scheme}://{host}"

    def _common_headers(self, *, is_api: bool) -> list[tuple[str, str]]:
        hdrs = [
            ("X-Content-Type-Options", "nosniff"),
            ("X-Frame-Options", "SAMEORIGIN"),
            ("Referrer-Policy", "no-referrer"),
        ]
        if is_api:
            hdrs.append(("Cache-Control", "private, no-store"))
            hdrs.append(("X-Robots-Tag", "noindex, nofollow"))
        origin = self.headers.get("Origin")
        if origin and origin in self.app.cfg.allowed_origins:
            hdrs.append(("Access-Control-Allow-Origin", origin))
            hdrs.append(("Access-Control-Allow-Credentials", "true"))
            hdrs.append(("Vary", "Origin"))
        return hdrs

    def _send_bytes(
        self,
        status: int,
        data: bytes,
        content_type: str,
        *,
        is_api: bool = True,
        extra_headers: list[tuple[str, str]] | None = None,
    ) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        for k, v in self._common_headers(is_api=is_api):
            self.send_header(k, v)
        for k, v in extra_headers or []:
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def _send_json(
        self,
        status: int,
        payload: Any,
        *,
        extra_headers: list[tuple[str, str]] | None = None,
    ) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self._send_bytes(status, body, "application/json; charset=utf-8", is_api=True, extra_headers=extra_headers)

    def _send_redirect(self, location: str, *, extra_headers: list[tuple[str, str]] | None = None) -> None:
        self.send_response(302)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        for k, v in self._common_headers(is_api=True):
            self.send_header(k, v)
        for k, v in extra_headers or []:
            self.send_header(k, v)
        self.end_headers()

    def _read_json_body(self) -> dict[str, Any]:
        raw_len = self.headers.get("Content-Length")
        if not raw_len:
            return {}
        try:
            length = int(raw_len)
        except ValueError:
            raise ValueError("Invalid Content-Length")
        if length < 0 or length > MAX_JSON_BODY_BYTES:
            raise ValueError("Request body too large")
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        try:
            obj = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            raise ValueError("Invalid JSON payload")
        if not isinstance(obj, dict):
            raise ValueError("JSON body must be an object")
        return obj

    def _session_cookie_token(self) -> str:
        raw_cookie = self.headers.get("Cookie")
        if not raw_cookie:
            return ""
        jar = cookies.SimpleCookie()
        try:
            jar.load(raw_cookie)
        except cookies.CookieError:
            return ""
        morsel = jar.get(self.app.cfg.cookie_name)
        return morsel.value if morsel else ""

    def _make_cookie_header(self, raw_token: str, *, max_age: int) -> tuple[str, str]:
        parts = [
            f"{self.app.cfg.cookie_name}={raw_token}",
            "Path=/",
            "HttpOnly",
            "SameSite=Lax",
            f"Max-Age={max_age}",
        ]
        if self._is_https():
            parts.append("Secure")
        return ("Set-Cookie", "; ".join(parts))

    def _current_session(self) -> dict[str, Any] | None:
        tok = self._session_cookie_token()
        if not tok:
            return None
        return self.app.db.get_session(tok)

    def _require_auth(self, *, require_csrf: bool = False, require_admin: bool = False) -> dict[str, Any] | None:
        sess = self._current_session()
        if sess is None or not sess.get("user"):
            self._send_json(401, {"error": "authentication_required", "message": "Sign in to view Combat Reports."})
            return None
        if require_csrf:
            sent = (self.headers.get("X-CSRF-Token") or "").strip()
            expected = str(sess.get("csrf_token") or "")
            if not sent or not expected or not hmac.compare_digest(sent, expected):
                self._send_json(403, {"error": "csrf_invalid", "message": "Missing or invalid CSRF token."})
                return None
        if require_admin and sess["user"].get("role") != "admin":
            self._send_json(403, {"error": "admin_required", "message": "Administrator privileges required."})
            return None
        return sess

    # -------------------------------------------------------------------------
    # HTTP Methods Dispatch
    # -------------------------------------------------------------------------
    def do_OPTIONS(self) -> None:
        hdrs = [
            ("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS"),
            ("Access-Control-Allow-Headers", "Content-Type, X-CSRF-Token"),
            ("Access-Control-Max-Age", "600"),
        ]
        self._send_bytes(204, b"", "text/plain", is_api=True, extra_headers=hdrs)

    def do_HEAD(self) -> None:
        self.do_GET()

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)

        if path.startswith("/api/combat"):
            self._dispatch_api("GET", path, qs)
            return

        if self.app.cfg.serve_static_site and self.app.cfg.site_dir:
            self._serve_static(path)
            return

        self._send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        self._dispatch_api("POST", parsed.path, urllib.parse.parse_qs(parsed.query))

    def do_PUT(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        self._dispatch_api("PUT", parsed.path, urllib.parse.parse_qs(parsed.query))

    def do_PATCH(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        self._dispatch_api("PATCH", parsed.path, urllib.parse.parse_qs(parsed.query))

    def do_DELETE(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        self._dispatch_api("DELETE", parsed.path, urllib.parse.parse_qs(parsed.query))

    # -------------------------------------------------------------------------
    # Static File Serving (Local Prototype Mode Only)
    # -------------------------------------------------------------------------
    def _serve_static(self, req_path: str) -> None:
        site_root = self.app.cfg.site_dir.resolve()  # type: ignore[union-attr]
        rel = "index.html" if req_path in ("", "/") else req_path.lstrip("/")
        target = (site_root / rel).resolve()
        if site_root not in target.parents and target != site_root:
            self._send_json(403, {"error": "forbidden"})
            return
        if not target.is_file():
            self._send_json(404, {"error": "not_found"})
            return
        ctype, _ = mimetypes.guess_type(str(target))
        if target.suffix == ".js":
            ctype = "application/javascript; charset=utf-8"
        elif target.suffix == ".css":
            ctype = "text/css; charset=utf-8"
        elif target.suffix == ".html":
            ctype = "text/html; charset=utf-8"
        elif target.suffix == ".json":
            ctype = "application/json; charset=utf-8"
        self._send_bytes(200, target.read_bytes(), ctype or "application/octet-stream", is_api=False)

    # -------------------------------------------------------------------------
    # API Router
    # -------------------------------------------------------------------------
    def _q(self, qs: dict[str, list[str]], key: str) -> str | None:
        vals = qs.get(key)
        if not vals:
            return None
        v = vals[0].strip()
        return v if v != "" else None

    def _dispatch_api(self, method: str, path: str, qs: dict[str, list[str]]) -> None:
        try:
            # 1. Health & Auth
            if method == "GET" and path == "/api/combat/health":
                self._send_json(200, {"ok": True, "version": __version__})
                return

            if method == "GET" and path == "/api/combat/auth/me":
                self._handle_auth_me()
                return

            if method == "POST" and path == "/api/combat/auth/login":
                self._handle_login()
                return

            if method == "POST" and path == "/api/combat/auth/logout":
                self._handle_logout()
                return

            m = re.match(r"^/api/combat/auth/oauth/(discord|github)/(start|callback)$", path)
            if m and method == "GET":
                if m.group(2) == "start":
                    self._handle_oauth_start(m.group(1), qs)
                else:
                    self._handle_oauth_callback(m.group(1), qs)
                return

            # 2. Public Share Link Resolution (Read-Only)
            m = re.match(r"^/api/combat/shared/([A-Za-z0-9_-]{16,128})$", path)
            if m and method == "GET":
                self._handle_shared_report(m.group(1))
                return

            m = re.match(r"^/api/combat/shared/([A-Za-z0-9_-]{16,128})/download$", path)
            if m and method == "GET":
                self._handle_shared_download(m.group(1), qs)
                return

            # 3. Authenticated Reports Collection
            if method == "GET" and path == "/api/combat/reports":
                self._handle_list_reports(qs)
                return

            # 4. Authenticated Single Report & Sub-Resources
            m = re.match(r"^/api/combat/reports/([A-Za-z0-9_-]+)$", path)
            if m and method == "GET":
                self._handle_get_report(m.group(1))
                return

            m = re.match(r"^/api/combat/reports/([A-Za-z0-9_-]+)/events$", path)
            if m and method == "GET":
                self._handle_get_report_events(m.group(1), qs)
                return

            m = re.match(r"^/api/combat/reports/([A-Za-z0-9_-]+)/pin$", path)
            if m and method == "POST":
                self._handle_pin_report(m.group(1))
                return

            m = re.match(r"^/api/combat/reports/([A-Za-z0-9_-]+)/feedback$", path)
            if m and method in ("PUT", "POST"):
                self._handle_save_feedback(m.group(1))
                return

            m = re.match(r"^/api/combat/reports/([A-Za-z0-9_-]+)/notes$", path)
            if m and method == "POST":
                self._handle_add_note(m.group(1))
                return

            m = re.match(r"^/api/combat/reports/([A-Za-z0-9_-]+)/notes/(\d+)$", path)
            if m and method == "DELETE":
                self._handle_delete_note(m.group(1), int(m.group(2)))
                return

            m = re.match(r"^/api/combat/reports/([A-Za-z0-9_-]+)/shares$", path)
            if m and method == "POST":
                self._handle_create_share(m.group(1))
                return

            m = re.match(r"^/api/combat/shares/(\d+)$", path)
            if m and method == "DELETE":
                self._handle_revoke_share(int(m.group(1)))
                return

            m = re.match(r"^/api/combat/reports/([A-Za-z0-9_-]+)/download$", path)
            if m and method == "GET":
                self._handle_download_report(m.group(1), qs)
                return

            # 5. Admin Endpoints
            if method == "POST" and path == "/api/combat/admin/import":
                self._handle_admin_import()
                return

            if method == "GET" and path == "/api/combat/admin/retention":
                self._handle_admin_retention()
                return

            if method == "POST" and path == "/api/combat/admin/retention/prune":
                self._handle_admin_prune()
                return

            if method == "GET" and path == "/api/combat/admin/users":
                self._handle_admin_list_users()
                return

            if method == "POST" and path == "/api/combat/admin/users":
                self._handle_admin_create_user()
                return

            m = re.match(r"^/api/combat/admin/users/(\d+)$", path)
            if m and method == "PATCH":
                self._handle_admin_update_user(int(m.group(1)))
                return

            self._send_json(404, {"error": "not_found"})
        except ValueError as exc:
            self._send_json(400, {"error": "bad_request", "message": str(exc)})
        except PermissionError as exc:
            self._send_json(403, {"error": "forbidden", "message": str(exc)})
        except Exception:
            self._send_json(500, {"error": "internal_error", "message": "An unexpected server error occurred."})

    # -------------------------------------------------------------------------
    # Auth Handlers
    # -------------------------------------------------------------------------
    def _handle_auth_me(self) -> None:
        sess = self._current_session()
        self._send_json(
            200,
            {
                "authenticated": bool(sess),
                "user": sess["user"] if sess else None,
                "csrf_token": sess["csrf_token"] if sess else None,
                "providers": self.app.cfg.enabled_providers(),
                "feedback_options": FEEDBACK_OPTIONS,
                "retention_per_character": self.app.cfg.retention_per_character,
            },
        )

    def _handle_login(self) -> None:
        if not self.app.cfg.enable_local_auth:
            self._send_json(403, {"error": "local_auth_disabled", "message": "Local password login is disabled."})
            return
        body = self._read_json_body()
        username = str(body.get("username") or "").strip()
        password = str(body.get("password") or "")
        ip = self._client_ip()
        throttle_key = f"{ip}:{username.lower()}"

        if self.app.rate_limiter.is_blocked(throttle_key):
            self._send_json(
                429,
                {"error": "too_many_attempts", "message": "Too many failed login attempts. Please wait and try again."},
            )
            return

        row = self.app.db.get_user_with_secret_by_username(username) if username else None
        if (
            row is None
            or not row["is_active"]
            or row["auth_provider"] != "local"
            or not verify_password(password, row["password_hash"])
        ):
            self.app.rate_limiter.record_failure(throttle_key)
            self._send_json(401, {"error": "invalid_credentials", "message": "Invalid username or password."})
            return

        self.app.rate_limiter.reset(throttle_key)
        raw_tok, csrf = self.app.db.create_session(
            int(row["id"]),
            ttl_hours=self.app.cfg.session_ttl_hours,
            ip_hint=ip,
            user_agent=self.headers.get("User-Agent") or "",
        )
        user = self.app.db.get_user_by_id(int(row["id"]))
        self.app.db.record_audit("login_local", user_id=int(row["id"]), detail={"ip": ip})
        cookie_hdr = self._make_cookie_header(raw_tok, max_age=self.app.cfg.session_ttl_hours * 3600)
        self._send_json(
            200,
            {"authenticated": True, "user": user, "csrf_token": csrf},
            extra_headers=[cookie_hdr],
        )

    def _handle_logout(self) -> None:
        sess = self._current_session()
        if sess is not None:
            sent = (self.headers.get("X-CSRF-Token") or "").strip()
            expected = str(sess.get("csrf_token") or "")
            if not sent or not hmac.compare_digest(sent, expected):
                self._send_json(403, {"error": "csrf_invalid", "message": "Missing or invalid CSRF token."})
                return
            self.app.db.record_audit("logout", user_id=sess["user"]["id"])
        raw_tok = self._session_cookie_token()
        if raw_tok:
            self.app.db.delete_session(raw_tok)
        self._send_json(200, {"ok": True}, extra_headers=[self._make_cookie_header("", max_age=0)])

    def _default_return_to(self) -> str:
        if self.app.cfg.public_base_url:
            parsed = urllib.parse.urlparse(self.app.cfg.public_base_url)
            prefix = (parsed.path or "").rstrip("/")
            if prefix and prefix.startswith("/") and not prefix.startswith("//"):
                return f"{prefix}/#reports"
        return "/#reports"

    def _handle_oauth_start(self, provider: str, qs: dict[str, list[str]]) -> None:
        default_return = self._default_return_to()
        return_to = self._q(qs, "return_to") or default_return
        if not return_to.startswith("/") or return_to.startswith("//"):
            return_to = default_return
        state = self.app.oauth_states.issue(provider, return_to=return_to)
        url = build_oauth_authorize_url(self.app.cfg, provider, state)
        self._send_redirect(url)

    def _handle_oauth_callback(self, provider: str, qs: dict[str, list[str]]) -> None:
        code = self._q(qs, "code")
        state = self._q(qs, "state")
        if not code or not state:
            self._send_json(400, {"error": "oauth_invalid", "message": "Missing OAuth code or state."})
            return
        return_to = self.app.oauth_states.consume(state, provider)
        if return_to is None:
            self._send_json(400, {"error": "oauth_state_invalid", "message": "OAuth state expired or invalid."})
            return
        ident = exchange_oauth_code(self.app.cfg, provider, code)
        if ident["role"] != "admin" and not self.app.cfg.oauth_allow_players:
            self._send_json(403, {"error": "oauth_not_authorized", "message": "Account is not authorized for this instance."})
            return
        user = self.app.db.upsert_oauth_user(
            provider=ident["provider"],
            subject=ident["subject"],
            username=ident["username"],
            display_name=ident["display_name"],
            role=ident["role"],
        )
        raw_tok, _ = self.app.db.create_session(
            int(user["id"]),
            ttl_hours=self.app.cfg.session_ttl_hours,
            ip_hint=self._client_ip(),
            user_agent=self.headers.get("User-Agent") or "",
        )
        self.app.db.record_audit(f"login_oauth_{provider}", user_id=int(user["id"]))
        cookie_hdr = self._make_cookie_header(raw_tok, max_age=self.app.cfg.session_ttl_hours * 3600)
        self._send_redirect(return_to, extra_headers=[cookie_hdr])

    # -------------------------------------------------------------------------
    # Reports Handlers
    # -------------------------------------------------------------------------
    def _load_authorized_run(self, sess: dict[str, Any], run_id: str) -> dict[str, Any] | None:
        if not is_safe_run_id(run_id):
            self._send_json(400, {"error": "invalid_run_id"})
            return None
        meta = self.app.db.get_run_meta(run_id)
        if meta is None:
            self._send_json(404, {"error": "run_not_found"})
            return None
        if not self.app.db.user_can_access_run(sess["user"], meta):
            self._send_json(403, {"error": "forbidden", "message": "You do not have access to this encounter report."})
            return None
        return meta

    def _handle_list_reports(self, qs: dict[str, list[str]]) -> None:
        sess = self._require_auth()
        if not sess:
            return
        level_raw = self._q(qs, "level")
        level = int(level_raw) if (level_raw and level_raw.isdigit()) else None
        pinned_raw = self._q(qs, "pinned")
        pinned = True if pinned_raw == "true" else (False if pinned_raw == "false" else None)
        valid_only = self._q(qs, "valid_only") == "true"
        limit = int(self._q(qs, "limit") or "50")
        offset = int(self._q(qs, "offset") or "0")

        res = self.app.db.list_runs(
            sess["user"],
            soul=self._q(qs, "soul"),
            job=self._q(qs, "job"),
            level=level,
            boss_type=self._q(qs, "boss_type"),
            difficulty=self._q(qs, "difficulty"),
            outcome=self._q(qs, "outcome"),
            date_from=self._q(qs, "date_from"),
            date_to=self._q(qs, "date_to"),
            character=self._q(qs, "character"),
            pinned=pinned,
            valid_only=valid_only,
            query=self._q(qs, "q"),
            limit=limit,
            offset=offset,
        )
        if self._q(qs, "format") == "csv":
            csv_text = build_runs_list_csv(res["items"])
            self._send_bytes(
                200,
                csv_text.encode("utf-8"),
                "text/csv; charset=utf-8",
                extra_headers=[("Content-Disposition", 'attachment; filename="soulspirexi_combat_reports.csv"')],
            )
            return
        res["retention_per_character"] = self.app.cfg.retention_per_character
        self._send_json(200, res)

    def _handle_get_report(self, run_id: str) -> None:
        sess = self._require_auth()
        if not sess:
            return
        if not self._load_authorized_run(sess, run_id):
            return
        payload = self.app.db.get_run_payload(run_id)
        if payload is None:
            self._send_json(404, {"error": "run_not_found"})
            return
        shares = self.app.db.list_share_links(run_id)
        self._send_json(200, build_full_report(payload, shares=shares, read_only=False))

    def _handle_get_report_events(self, run_id: str, qs: dict[str, list[str]]) -> None:
        sess = self._require_auth()
        if not sess:
            return
        if not self._load_authorized_run(sess, run_id):
            return
        payload = self.app.db.get_run_payload(run_id)
        if payload is None:
            self._send_json(404, {"error": "run_not_found"})
            return
        events = payload["events"]
        phase = self._q(qs, "phase")
        category = self._q(qs, "category")
        etype = self._q(qs, "event_type")
        q = (self._q(qs, "q") or "").lower()
        sec_from_raw = self._q(qs, "sec_from")
        sec_to_raw = self._q(qs, "sec_to")
        sec_from = float(sec_from_raw) if sec_from_raw is not None else None
        sec_to = float(sec_to_raw) if sec_to_raw is not None else None

        filtered = []
        for ev in events:
            if phase and ev.get("phase") != phase:
                continue
            if category and ev.get("category") != category:
                continue
            if etype and ev.get("event_type") != etype:
                continue
            if sec_from is not None or sec_to is not None:
                cms = ev.get("combat_ms")
                if not isinstance(cms, (int, float)):
                    continue
                sec = cms / 1000.0
                if sec_from is not None and sec < sec_from:
                    continue
                if sec_to is not None and sec > sec_to:
                    continue
            if q and q not in json.dumps(ev).lower():
                continue
            filtered.append(ev)

        limit = max(1, min(1000, int(self._q(qs, "limit") or "200")))
        offset = max(0, int(self._q(qs, "offset") or "0"))
        self._send_json(
            200,
            {
                "total": len(filtered),
                "limit": limit,
                "offset": offset,
                "items": filtered[offset : offset + limit],
            },
        )

    def _handle_pin_report(self, run_id: str) -> None:
        sess = self._require_auth(require_csrf=True)
        if not sess:
            return
        if not self._load_authorized_run(sess, run_id):
            return
        body = self._read_json_body()
        pinned = bool(body.get("pinned"))
        self.app.db.set_run_pinned(run_id, pinned, sess["user"]["id"])
        self.app.db.record_audit("pin_report", user_id=sess["user"]["id"], target_id=run_id, detail={"pinned": pinned})
        self._send_json(200, {"run_id": run_id, "pinned": pinned})

    def _handle_save_feedback(self, run_id: str) -> None:
        sess = self._require_auth(require_csrf=True)
        if not sess:
            return
        if not self._load_authorized_run(sess, run_id):
            return
        body = self._read_json_body()
        fb = self.app.db.save_feedback(
            run_id,
            user_id=sess["user"]["id"],
            tag=str(body.get("tag") or "skip"),
            summary_text=str(body.get("summary_text") or ""),
        )
        self._send_json(200, {"feedback": fb})

    def _handle_add_note(self, run_id: str) -> None:
        sess = self._require_auth(require_csrf=True)
        if not sess:
            return
        if not self._load_authorized_run(sess, run_id):
            return
        body = self._read_json_body()
        sec_raw = body.get("combat_sec")
        combat_sec: float | None = None
        if sec_raw is not None and sec_raw != "":
            combat_sec = float(sec_raw)
        note = self.app.db.add_note(
            run_id,
            user_id=sess["user"]["id"],
            author_name=sess["user"]["display_name"],
            body=str(body.get("body") or ""),
            combat_sec=combat_sec,
            phase=str(body.get("phase") or ("combat" if combat_sec is not None else "general")),
        )
        self._send_json(201, {"note": note})

    def _handle_delete_note(self, run_id: str, note_id: int) -> None:
        sess = self._require_auth(require_csrf=True)
        if not sess:
            return
        if not self._load_authorized_run(sess, run_id):
            return
        ok = self.app.db.delete_note(run_id, note_id, sess["user"])
        if not ok:
            self._send_json(404, {"error": "note_not_found"})
            return
        self._send_json(200, {"ok": True})

    def _handle_create_share(self, run_id: str) -> None:
        sess = self._require_auth(require_csrf=True)
        if not sess:
            return
        if not self._load_authorized_run(sess, run_id):
            return
        body = self._read_json_body()
        exp_raw = body.get("expires_in_hours")
        expires_in_hours: float | None = None
        if exp_raw is not None and exp_raw != "":
            expires_in_hours = float(exp_raw)
            if expires_in_hours <= 0:
                raise ValueError("expires_in_hours must be positive")
        share = self.app.db.create_share_link(
            run_id,
            created_by=sess["user"]["id"],
            label=str(body.get("label") or ""),
            expires_in_hours=expires_in_hours,
        )
        share["share_url"] = f"{self._base_url()}/#share/{share['token']}"
        self.app.db.record_audit(
            "create_share",
            user_id=sess["user"]["id"],
            target_id=run_id,
            detail={"share_id": share["id"], "expires_at": share["expires_at"]},
        )
        self._send_json(201, {"share": share})

    def _handle_revoke_share(self, share_id: int) -> None:
        sess = self._require_auth(require_csrf=True)
        if not sess:
            return
        revoked = self.app.db.revoke_share_link(share_id)
        if revoked is None:
            self._send_json(404, {"error": "share_not_found"})
            return
        self.app.db.record_audit("revoke_share", user_id=sess["user"]["id"], target_id=str(share_id))
        self._send_json(200, {"ok": True, "revoked": revoked})

    def _serve_download_for_run(self, run_id: str, file_kind: str) -> None:
        raw_files = self.app.db.get_run_raw_files(run_id)
        if raw_files is None:
            self._send_json(404, {"error": "run_not_found"})
            return

        if file_kind in ("summary", "events", "snapshots", "feedback"):
            content = raw_files.get(file_kind)
            if not content:
                self._send_json(404, {"error": "file_unavailable", "message": f"Original {file_kind} file not present for this run."})
                return
            ext = "json" if file_kind == "feedback" else "jsonl"
            ctype = "application/json; charset=utf-8" if ext == "json" else "application/x-ndjson; charset=utf-8"
            self._send_bytes(
                200,
                content.encode("utf-8"),
                ctype,
                extra_headers=[("Content-Disposition", f'attachment; filename="{run_id}_{file_kind}.{ext}"')],
            )
            return

        if file_kind == "bundle":
            data = build_raw_bundle_zip(run_id, raw_files)
            self._send_bytes(
                200,
                data,
                "application/zip",
                extra_headers=[("Content-Disposition", f'attachment; filename="{run_id}_telemetry.zip"')],
            )
            return

        payload = self.app.db.get_run_payload(run_id)
        if payload is None:
            self._send_json(404, {"error": "run_not_found"})
            return
        report = build_full_report(payload, read_only=True)

        if file_kind == "markdown":
            md = build_markdown_summary(report)
            self._send_bytes(
                200,
                md.encode("utf-8"),
                "text/markdown; charset=utf-8",
                extra_headers=[("Content-Disposition", f'attachment; filename="{run_id}_report.md"')],
            )
            return

        if file_kind == "csv":
            csv_text = build_timeline_csv(report["time_series"])
            self._send_bytes(
                200,
                csv_text.encode("utf-8"),
                "text/csv; charset=utf-8",
                extra_headers=[("Content-Disposition", f'attachment; filename="{run_id}_timeline.csv"')],
            )
            return

        raise ValueError("Unsupported download file type")

    def _handle_download_report(self, run_id: str, qs: dict[str, list[str]]) -> None:
        sess = self._require_auth()
        if not sess:
            return
        if not self._load_authorized_run(sess, run_id):
            return
        file_kind = self._q(qs, "file") or "bundle"
        self._serve_download_for_run(run_id, file_kind)

    def _handle_shared_report(self, raw_token: str) -> None:
        share = self.app.db.resolve_share_token(raw_token)
        if share is None:
            self._send_json(404, {"error": "share_invalid", "message": "Share link is invalid, expired, or revoked."})
            return
        payload = self.app.db.get_run_payload(share["run_id"])
        if payload is None:
            self._send_json(404, {"error": "run_not_found"})
            return
        self._send_json(200, build_full_report(payload, read_only=True, share_info=share))

    def _handle_shared_download(self, raw_token: str, qs: dict[str, list[str]]) -> None:
        share = self.app.db.resolve_share_token(raw_token)
        if share is None:
            self._send_json(404, {"error": "share_invalid", "message": "Share link is invalid, expired, or revoked."})
            return
        file_kind = self._q(qs, "file") or "bundle"
        self._serve_download_for_run(share["run_id"], file_kind)

    # -------------------------------------------------------------------------
    # Admin Handlers
    # -------------------------------------------------------------------------
    def _handle_admin_import(self) -> None:
        sess = self._require_auth(require_csrf=True, require_admin=True)
        if not sess:
            return
        result = import_proving_grounds_logs(
            self.app.db,
            log_dir=self.app.cfg.log_dir,
            legacy_log_path=self.app.cfg.legacy_log_path,
            retention_per_character=self.app.cfg.retention_per_character,
        )
        self.app.db.record_audit("admin_import", user_id=sess["user"]["id"], detail={"imported": result["imported"]})
        self._send_json(200, result)

    def _handle_admin_retention(self) -> None:
        sess = self._require_auth(require_admin=True)
        if not sess:
            return
        self._send_json(200, self.app.db.get_retention_stats(self.app.cfg.retention_per_character))

    def _handle_admin_prune(self) -> None:
        sess = self._require_auth(require_csrf=True, require_admin=True)
        if not sess:
            return
        res = self.app.db.enforce_retention(self.app.cfg.retention_per_character)
        self.app.db.record_audit("admin_prune", user_id=sess["user"]["id"], detail=res)
        self._send_json(200, res)

    def _handle_admin_list_users(self) -> None:
        sess = self._require_auth(require_admin=True)
        if not sess:
            return
        self._send_json(200, {"users": self.app.db.list_users()})

    def _handle_admin_create_user(self) -> None:
        sess = self._require_auth(require_csrf=True, require_admin=True)
        if not sess:
            return
        body = self._read_json_body()
        username = str(body.get("username") or "").strip()
        password = str(body.get("password") or "")
        role = str(body.get("role") or "player").strip()
        display_name = str(body.get("display_name") or username).strip()
        chars = body.get("character_names") or []
        if not username:
            raise ValueError("username is required")
        if not isinstance(chars, list):
            raise ValueError("character_names must be a list")
        pw_hash = hash_password(password)
        user = self.app.db.create_user(
            username=username,
            display_name=display_name,
            role=role,
            auth_provider="local",
            password_hash=pw_hash,
            character_names=[str(c) for c in chars],
        )
        self.app.db.record_audit("admin_create_user", user_id=sess["user"]["id"], target_id=str(user["id"]))
        self._send_json(201, {"user": user})

    def _handle_admin_update_user(self, user_id: int) -> None:
        sess = self._require_auth(require_csrf=True, require_admin=True)
        if not sess:
            return
        body = self._read_json_body()
        chars = body.get("character_names")
        if not isinstance(chars, list):
            raise ValueError("character_names must be a list")
        updated = self.app.db.update_user_characters(user_id, [str(c) for c in chars])
        if updated is None:
            self._send_json(404, {"error": "user_not_found"})
            return
        self._send_json(200, {"user": updated})


def create_server(cfg: AnalyticsConfig, db: AnalyticsDB | None = None) -> AnalyticsHTTPServer:
    app = AnalyticsApp(cfg, db=db)
    return AnalyticsHTTPServer((cfg.host, cfg.port), app)
