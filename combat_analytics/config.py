"""Environment-driven configuration for the OverlordsXI Combat Analytics backend.

All secrets and deployment-specific settings are supplied via environment
variables (or a local, gitignored .env file). Never hardcode secrets or
FFXI database credentials here.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path


def _env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def _env_int(name: str, default: int, *, minimum: int | None = None) -> int:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        val = default
    else:
        try:
            val = int(raw.strip())
        except ValueError:
            val = default
    if minimum is not None and val < minimum:
        return minimum
    return val


def _env_list(name: str) -> list[str]:
    raw = os.environ.get(name, "")
    return [item.strip() for item in raw.split(",") if item.strip()]


def load_dotenv_file(path: Path) -> None:
    """Minimal stdlib .env loader (does not overwrite existing environment vars)."""
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        s = line.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        key, val = s.split("=", 1)
        key = key.strip()
        val = val.strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
            val = val[1:-1]
        if key and key not in os.environ:
            os.environ[key] = val


@dataclass
class AnalyticsConfig:
    host: str = "127.0.0.1"
    port: int = 8765
    db_path: Path = field(default_factory=lambda: Path(".combat_analytics_data") / "analytics.db")
    log_dir: Path | None = None
    legacy_log_path: Path | None = None
    site_dir: Path | None = None
    serve_static_site: bool = False
    public_base_url: str = ""
    allowed_origins: list[str] = field(default_factory=list)

    # Retention: default 50 recent unpinned reports per character, plus all pinned reports.
    retention_per_character: int = 50
    poll_interval_sec: int = 0  # 0 disables background polling; set e.g. 15 in production

    # Session & Cookie Security
    session_ttl_hours: int = 168  # 7 days
    cookie_name: str = "ox_combat_session"
    cookie_secure: bool = False  # Auto-enabled when behind HTTPS / X-Forwarded-Proto: https
    trust_proxy_headers: bool = True
    max_login_attempts: int = 10
    login_window_sec: int = 900

    # Local Auth toggle (securely managed scrypt accounts; NEVER FFXI passwords)
    enable_local_auth: bool = True

    # Optional Discord OAuth2 provider
    discord_client_id: str = ""
    discord_client_secret: str = ""
    discord_redirect_uri: str = ""
    discord_admin_ids: list[str] = field(default_factory=list)

    # Optional GitHub OAuth2 provider
    github_client_id: str = ""
    github_client_secret: str = ""
    github_redirect_uri: str = ""
    github_admin_users: list[str] = field(default_factory=list)

    # Whether non-admin OAuth logins are permitted as 'player' accounts
    oauth_allow_players: bool = True

    @property
    def discord_enabled(self) -> bool:
        return bool(self.discord_client_id and self.discord_client_secret and self.discord_redirect_uri)

    @property
    def github_enabled(self) -> bool:
        return bool(self.github_client_id and self.github_client_secret and self.github_redirect_uri)

    def enabled_providers(self) -> list[str]:
        providers: list[str] = []
        if self.enable_local_auth:
            providers.append("local")
        if self.discord_enabled:
            providers.append("discord")
        if self.github_enabled:
            providers.append("github")
        return providers

    @classmethod
    def from_env(cls, env_file: Path | None = None) -> "AnalyticsConfig":
        if env_file is not None:
            load_dotenv_file(env_file)
        else:
            default_env = Path(__file__).resolve().parent / ".env"
            if default_env.is_file():
                load_dotenv_file(default_env)

        log_dir_raw = os.environ.get("OVERLORDS_PG_LOG_DIR", "").strip()
        legacy_raw = os.environ.get("OVERLORDS_PG_LEGACY_LOG", "").strip()
        site_dir_raw = os.environ.get("OVERLORDS_SITE_DIR", "").strip()
        default_site = Path(__file__).resolve().parent.parent / "site"

        return cls(
            host=os.environ.get("OVERLORDS_ANALYTICS_HOST", "127.0.0.1").strip() or "127.0.0.1",
            port=_env_int("OVERLORDS_ANALYTICS_PORT", 8765, minimum=1),
            db_path=Path(
                os.environ.get(
                    "OVERLORDS_ANALYTICS_DB",
                    str(Path(".combat_analytics_data") / "analytics.db"),
                )
            ),
            log_dir=Path(log_dir_raw) if log_dir_raw else None,
            legacy_log_path=Path(legacy_raw) if legacy_raw else None,
            site_dir=Path(site_dir_raw) if site_dir_raw else (default_site if default_site.is_dir() else None),
            serve_static_site=_env_bool("OVERLORDS_SERVE_STATIC_SITE", False),
            public_base_url=os.environ.get("OVERLORDS_PUBLIC_BASE_URL", "").strip().rstrip("/"),
            allowed_origins=_env_list("OVERLORDS_ALLOWED_ORIGINS"),
            retention_per_character=_env_int("OVERLORDS_RETENTION_PER_CHARACTER", 50, minimum=1),
            poll_interval_sec=_env_int("OVERLORDS_POLL_INTERVAL_SEC", 0, minimum=0),
            session_ttl_hours=_env_int("OVERLORDS_SESSION_TTL_HOURS", 168, minimum=1),
            cookie_name=os.environ.get("OVERLORDS_COOKIE_NAME", "ox_combat_session").strip() or "ox_combat_session",
            cookie_secure=_env_bool("OVERLORDS_COOKIE_SECURE", False),
            trust_proxy_headers=_env_bool("OVERLORDS_TRUST_PROXY_HEADERS", True),
            max_login_attempts=_env_int("OVERLORDS_MAX_LOGIN_ATTEMPTS", 10, minimum=3),
            login_window_sec=_env_int("OVERLORDS_LOGIN_WINDOW_SEC", 900, minimum=60),
            enable_local_auth=_env_bool("OVERLORDS_ENABLE_LOCAL_AUTH", True),
            discord_client_id=os.environ.get("OVERLORDS_DISCORD_CLIENT_ID", "").strip(),
            discord_client_secret=os.environ.get("OVERLORDS_DISCORD_CLIENT_SECRET", "").strip(),
            discord_redirect_uri=os.environ.get("OVERLORDS_DISCORD_REDIRECT_URI", "").strip(),
            discord_admin_ids=_env_list("OVERLORDS_DISCORD_ADMIN_IDS"),
            github_client_id=os.environ.get("OVERLORDS_GITHUB_CLIENT_ID", "").strip(),
            github_client_secret=os.environ.get("OVERLORDS_GITHUB_CLIENT_SECRET", "").strip(),
            github_redirect_uri=os.environ.get("OVERLORDS_GITHUB_REDIRECT_URI", "").strip(),
            github_admin_users=[u.lower() for u in _env_list("OVERLORDS_GITHUB_ADMIN_USERS")],
            oauth_allow_players=_env_bool("OVERLORDS_OAUTH_ALLOW_PLAYERS", True),
        )
