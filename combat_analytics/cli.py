"""Command-line interface for OverlordsXI Combat Analytics backend.

Examples:
  python -m combat_analytics.cli create-user --username admin --role admin
  python -m combat_analytics.cli import-logs --log-dir C:\\dev\\server\\log\\proving_grounds
  python -m combat_analytics.cli serve --serve-site --log-dir C:\\dev\\server\\log\\proving_grounds
"""
from __future__ import annotations

import argparse
import getpass
import json
import sys
from pathlib import Path

from .auth import hash_password
from .config import AnalyticsConfig
from .db import AnalyticsDB
from .importer import import_proving_grounds_logs
from .server import create_server


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="combat_analytics", description="OverlordsXI Combat Analytics Backend CLI")
    p.add_argument("--env-file", type=Path, default=None, help="Optional path to .env configuration file")
    p.add_argument("--db", type=Path, default=None, help="Override SQLite database path")

    sub = p.add_subparsers(dest="command", required=True)

    p_cu = sub.add_parser("create-user", help="Create a securely hashed local admin or player account (NOT FFXI password)")
    p_cu.add_argument("--username", required=True)
    p_cu.add_argument("--display-name", default="")
    p_cu.add_argument("--role", choices=["admin", "player"], default="admin")
    p_cu.add_argument("--characters", default="", help="Comma-separated character names for player-scoped visibility")
    p_cu.add_argument("--password-stdin", action="store_true", help="Read password from stdin instead of prompt")

    sub.add_parser("list-users", help="List configured analytics accounts (without secrets)")

    p_imp = sub.add_parser("import-logs", help="Import local Soul Proving Grounds JSONL logs")
    p_imp.add_argument("--log-dir", type=Path, default=None, help="Path to log/proving_grounds directory")
    p_imp.add_argument("--legacy-log", type=Path, default=None, help="Path to log/proving_grounds_runs.jsonl")
    p_imp.add_argument("--retention", type=int, default=None, help="Max unpinned reports per character (default 50)")

    p_prune = sub.add_parser("prune", help="Enforce per-character retention (preserving pinned reports)")
    p_prune.add_argument("--retention", type=int, default=None)

    p_srv = sub.add_parser("serve", help="Run the Combat Analytics HTTP API server")
    p_srv.add_argument("--host", default=None)
    p_srv.add_argument("--port", type=int, default=None)
    p_srv.add_argument("--log-dir", type=Path, default=None)
    p_srv.add_argument("--legacy-log", type=Path, default=None)
    p_srv.add_argument("--serve-site", action="store_true", help="Also serve static site/ files for local testing")
    p_srv.add_argument("--poll-interval", type=int, default=None, help="Background log import interval in seconds")

    return p


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    cfg = AnalyticsConfig.from_env(args.env_file)
    if args.db is not None:
        cfg.db_path = args.db

    db = AnalyticsDB(cfg.db_path)

    if args.command == "create-user":
        if args.password_stdin:
            pw = sys.stdin.readline().rstrip("\r\n")
        else:
            pw = getpass.getpass("New analytics password (min 10 chars, do NOT reuse FFXI password): ")
            pw2 = getpass.getpass("Confirm password: ")
            if pw != pw2:
                print("Error: passwords do not match.", file=sys.stderr)
                return 1
        chars = [c.strip() for c in args.characters.split(",") if c.strip()]
        user = db.create_user(
            username=args.username,
            display_name=args.display_name or args.username,
            role=args.role,
            auth_provider="local",
            password_hash=hash_password(pw),
            character_names=chars,
        )
        print(json.dumps({"created": user}, indent=2))
        return 0

    if args.command == "list-users":
        print(json.dumps({"users": db.list_users()}, indent=2))
        return 0

    if args.command == "import-logs":
        res = import_proving_grounds_logs(
            db,
            log_dir=args.log_dir or cfg.log_dir,
            legacy_log_path=args.legacy_log or cfg.legacy_log_path,
            retention_per_character=args.retention or cfg.retention_per_character,
        )
        print(json.dumps(res, indent=2))
        return 0

    if args.command == "prune":
        res = db.enforce_retention(args.retention or cfg.retention_per_character)
        print(json.dumps(res, indent=2))
        return 0

    if args.command == "serve":
        if args.host:
            cfg.host = args.host
        if args.port:
            cfg.port = args.port
        if args.log_dir:
            cfg.log_dir = args.log_dir
        if args.legacy_log:
            cfg.legacy_log_path = args.legacy_log
        if args.serve_site:
            cfg.serve_static_site = True
        if args.poll_interval is not None:
            cfg.poll_interval_sec = args.poll_interval

        srv = create_server(cfg, db=db)
        srv.app.start_background_tasks()
        print(
            f"OverlordsXI Combat Analytics listening on http://{cfg.host}:{cfg.port} "
            f"(db={cfg.db_path}, serve_site={cfg.serve_static_site}, retention={cfg.retention_per_character}/char)"
        )
        if db.count_users() == 0 and not (cfg.discord_enabled or cfg.github_enabled):
            print(
                "Note: No analytics accounts exist yet. Run:\n"
                "  python -m combat_analytics.cli create-user --username admin --role admin"
            )
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            srv.app.stop_background_tasks()
            srv.server_close()
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
