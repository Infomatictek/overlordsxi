"""Authentication and security helpers for SoulspireXI Combat Analytics.

Supports:
  1. Securely managed local accounts (scrypt password hashing + HttpOnly sessions + CSRF).
  2. Optional OAuth2 providers (Discord and GitHub) configured via environment variables.

NEVER accesses FFXI/LandSandBoat game account tables or accepts FFXI passwords.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import threading
import time
import urllib.parse
import urllib.request
from typing import Any

from .config import AnalyticsConfig

SCRYPT_N = 16384
SCRYPT_R = 8
SCRYPT_P = 1
SCRYPT_DKLEN = 32
MIN_PASSWORD_LEN = 10


def hash_password(password: str) -> str:
    if not isinstance(password, str) or len(password) < MIN_PASSWORD_LEN:
        raise ValueError(f"Password must be at least {MIN_PASSWORD_LEN} characters long")
    salt = secrets.token_bytes(16)
    dk = hashlib.scrypt(
        password.encode("utf-8"),
        salt=salt,
        n=SCRYPT_N,
        r=SCRYPT_R,
        p=SCRYPT_P,
        dklen=SCRYPT_DKLEN,
    )
    salt_b64 = base64.b64encode(salt).decode("ascii")
    dk_b64 = base64.b64encode(dk).decode("ascii")
    return f"scrypt${SCRYPT_N}${SCRYPT_R}${SCRYPT_P}${salt_b64}${dk_b64}"


def verify_password(password: str, stored_hash: str | None) -> bool:
    if not password or not stored_hash:
        return False
    parts = stored_hash.split("$")
    if len(parts) != 6 or parts[0] != "scrypt":
        return False
    try:
        n = int(parts[1])
        r = int(parts[2])
        p = int(parts[3])
        salt = base64.b64decode(parts[4].encode("ascii"))
        expected = base64.b64decode(parts[5].encode("ascii"))
    except (ValueError, TypeError):
        return False
    derived = hashlib.scrypt(
        password.encode("utf-8"),
        salt=salt,
        n=n,
        r=r,
        p=p,
        dklen=len(expected),
    )
    return hmac.compare_digest(derived, expected)


class LoginRateLimiter:
    """Thread-safe sliding-window login throttle."""

    def __init__(self, max_attempts: int = 10, window_sec: int = 900):
        self.max_attempts = max(3, int(max_attempts))
        self.window_sec = max(60, int(window_sec))
        self._lock = threading.Lock()
        self._attempts: dict[str, list[float]] = {}

    def _prune(self, key: str, now: float) -> list[float]:
        cutoff = now - self.window_sec
        arr = [ts for ts in self._attempts.get(key, []) if ts > cutoff]
        if arr:
            self._attempts[key] = arr
        elif key in self._attempts:
            del self._attempts[key]
        return arr

    def is_blocked(self, key: str) -> bool:
        now = time.monotonic()
        with self._lock:
            return len(self._prune(key, now)) >= self.max_attempts

    def record_failure(self, key: str) -> None:
        now = time.monotonic()
        with self._lock:
            arr = self._prune(key, now)
            arr.append(now)
            self._attempts[key] = arr

    def reset(self, key: str) -> None:
        with self._lock:
            self._attempts.pop(key, None)


class OAuthStateStore:
    """Short-lived CSRF state nonces for Discord/GitHub OAuth2 callbacks."""

    def __init__(self, ttl_sec: int = 600):
        self.ttl_sec = ttl_sec
        self._lock = threading.Lock()
        self._states: dict[str, tuple[str, float, str]] = {}

    def issue(self, provider: str, return_to: str = "/#reports") -> str:
        nonce = secrets.token_urlsafe(24)
        now = time.monotonic()
        with self._lock:
            expired = [k for k, v in self._states.items() if v[1] < now]
            for k in expired:
                del self._states[k]
            self._states[nonce] = (provider, now + self.ttl_sec, return_to)
        return nonce

    def consume(self, nonce: str, provider: str) -> str | None:
        now = time.monotonic()
        with self._lock:
            rec = self._states.pop(nonce, None)
        if rec is None:
            return None
        prov, exp, return_to = rec
        if prov != provider or exp < now:
            return None
        return return_to


def build_oauth_authorize_url(cfg: AnalyticsConfig, provider: str, state: str) -> str:
    if provider == "discord":
        if not cfg.discord_enabled:
            raise ValueError("Discord OAuth is not configured")
        params = urllib.parse.urlencode(
            {
                "client_id": cfg.discord_client_id,
                "redirect_uri": cfg.discord_redirect_uri,
                "response_type": "code",
                "scope": "identify",
                "state": state,
            }
        )
        return f"https://discord.com/api/oauth2/authorize?{params}"

    if provider == "github":
        if not cfg.github_enabled:
            raise ValueError("GitHub OAuth is not configured")
        params = urllib.parse.urlencode(
            {
                "client_id": cfg.github_client_id,
                "redirect_uri": cfg.github_redirect_uri,
                "scope": "read:user",
                "state": state,
            }
        )
        return f"https://github.com/login/oauth/authorize?{params}"

    raise ValueError(f"Unsupported OAuth provider: {provider}")


def _http_json(url: str, *, data: bytes | None = None, headers: dict[str, str] | None = None) -> dict[str, Any]:
    req = urllib.request.Request(url, data=data, headers=headers or {})
    with urllib.request.urlopen(req, timeout=12) as resp:
        body = resp.read().decode("utf-8")
    parsed = json.loads(body)
    if not isinstance(parsed, dict):
        raise ValueError("Unexpected OAuth JSON response")
    return parsed


def exchange_oauth_code(cfg: AnalyticsConfig, provider: str, code: str) -> dict[str, Any]:
    """Exchange OAuth2 authorization code for verified user identity (Discord or GitHub)."""
    if provider == "discord":
        if not cfg.discord_enabled:
            raise ValueError("Discord OAuth is not configured")
        form = urllib.parse.urlencode(
            {
                "client_id": cfg.discord_client_id,
                "client_secret": cfg.discord_client_secret,
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": cfg.discord_redirect_uri,
            }
        ).encode("utf-8")
        token_resp = _http_json(
            "https://discord.com/api/oauth2/token",
            data=form,
            headers={"Content-Type": "application/x-www-form-urlencoded", "User-Agent": "SoulspireXI-Analytics/1.0"},
        )
        access_token = token_resp.get("access_token")
        if not access_token:
            raise ValueError("Discord OAuth token exchange failed")
        me = _http_json(
            "https://discord.com/api/users/@me",
            headers={"Authorization": f"Bearer {access_token}", "User-Agent": "SoulspireXI-Analytics/1.0"},
        )
        sub = str(me.get("id") or "")
        if not sub:
            raise ValueError("Discord user ID missing")
        username = str(me.get("username") or sub)
        display_name = str(me.get("global_name") or username)
        role = "admin" if sub in cfg.discord_admin_ids else "player"
        return {"provider": "discord", "subject": sub, "username": username, "display_name": display_name, "role": role}

    if provider == "github":
        if not cfg.github_enabled:
            raise ValueError("GitHub OAuth is not configured")
        form = urllib.parse.urlencode(
            {
                "client_id": cfg.github_client_id,
                "client_secret": cfg.github_client_secret,
                "code": code,
                "redirect_uri": cfg.github_redirect_uri,
            }
        ).encode("utf-8")
        token_resp = _http_json(
            "https://github.com/login/oauth/access_token",
            data=form,
            headers={"Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "SoulspireXI-Analytics/1.0"},
        )
        access_token = token_resp.get("access_token")
        if not access_token:
            raise ValueError("GitHub OAuth token exchange failed")
        me = _http_json(
            "https://api.github.com/user",
            headers={"Authorization": f"Bearer {access_token}", "Accept": "application/vnd.github+json", "User-Agent": "SoulspireXI-Analytics/1.0"},
        )
        sub = str(me.get("id") or "")
        login = str(me.get("login") or "")
        if not sub or not login:
            raise ValueError("GitHub user profile incomplete")
        display_name = str(me.get("name") or login)
        role = "admin" if login.lower() in cfg.github_admin_users else "player"
        return {"provider": "github", "subject": sub, "username": login, "display_name": display_name, "role": role}

    raise ValueError(f"Unsupported OAuth provider: {provider}")
