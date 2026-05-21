#!/usr/bin/env python3
"""
Web Push sender for teslausb-ng (v1.3.2).

Reads every JSON subscription file under WEBPUSH_SUBSCRIPTIONS_DIR (default
/mutable/webpush_subscriptions) and POSTs an encrypted notification to each
endpoint using VAPID authentication.

Wired into run/send-push-message via the WEBPUSH_ENABLED=true env var.

Usage:
    send_webpush.py "<title>" "<message>"

Requires the `pywebpush` Python package (installed via setup/pi/requirements.txt).
The VAPID keypair is generated once by setup/pi/configure-webpush.sh and stored
at /root/.config/teslausb-webpush/{vapid_private.pem,vapid_public.pem}; the
contact email comes from VAPID_CONTACT (defaults to mailto:teslausb@local).

Subscriptions that return HTTP 404 or 410 are removed from disk (the user
unsubscribed or rotated their browser keys); transient errors are logged and
the subscription is kept.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

try:
    from pywebpush import WebPushException, webpush
except ImportError:
    print("send_webpush: pywebpush not installed; run setup/pi/configure-webpush.sh", file=sys.stderr)
    sys.exit(0)  # exit 0 so send-push-message doesn't fail other backends


SUBS_DIR = Path(os.environ.get("WEBPUSH_SUBSCRIPTIONS_DIR", "/mutable/webpush_subscriptions"))
VAPID_PRIVATE = Path(os.environ.get("VAPID_PRIVATE_KEY", "/root/.config/teslausb-webpush/vapid_private.pem"))
VAPID_CLAIMS = {"sub": os.environ.get("VAPID_CONTACT", "mailto:teslausb@local")}


def load_subscriptions() -> list[tuple[Path, dict]]:
    out: list[tuple[Path, dict]] = []
    if not SUBS_DIR.is_dir():
        return out
    for path in sorted(SUBS_DIR.glob("*.json")):
        try:
            with open(path) as f:
                out.append((path, json.load(f)))
        except (OSError, json.JSONDecodeError) as e:
            print(f"send_webpush: skipping malformed {path}: {e}", file=sys.stderr)
    return out


def send_one(path: Path, sub: dict, payload: str) -> None:
    try:
        webpush(
            subscription_info=sub,
            data=payload,
            vapid_private_key=str(VAPID_PRIVATE),
            vapid_claims=dict(VAPID_CLAIMS),
            ttl=60,
        )
    except WebPushException as e:
        status = getattr(getattr(e, "response", None), "status_code", None)
        if status in (404, 410):
            # Subscription gone — clean it up so we stop trying.
            try:
                path.unlink()
                print(f"send_webpush: removed stale subscription {path.name} (HTTP {status})")
            except OSError:
                pass
        else:
            print(f"send_webpush: {path.name} failed: {e}", file=sys.stderr)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(f"Usage: {argv[0]} <title> <message>", file=sys.stderr)
        return 1
    title, message = argv[1], argv[2]

    if not VAPID_PRIVATE.is_file():
        print(
            f"send_webpush: VAPID private key not found at {VAPID_PRIVATE} — "
            "run setup/pi/configure-webpush.sh first",
            file=sys.stderr,
        )
        return 0

    subs = load_subscriptions()
    if not subs:
        # No browsers subscribed — silent no-op so the rest of send-push-message
        # doesn't get cluttered with "no recipients" noise.
        return 0

    payload = json.dumps({"title": title, "body": message})
    for path, sub in subs:
        send_one(path, sub, payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
