#!/bin/bash
#
# Receives Web Push subscription JSON from the browser and stores it under
# WEBPUSH_SUBSCRIPTIONS_DIR (default /mutable/webpush_subscriptions). Each
# subscription is keyed by a short hash of its endpoint URL so re-subscribing
# from the same browser just overwrites the existing file.
#
# Returns 200 on success, 4xx on validation errors. Reads the JSON body from
# stdin (CONTENT_LENGTH limited to 8 KiB to prevent abuse).

set -eu

SUBS_DIR="${WEBPUSH_SUBSCRIPTIONS_DIR:-/mutable/webpush_subscriptions}"

emit_status() {
  printf 'HTTP/1.0 %s\r\n' "$1"
  printf 'Content-type: application/json\r\n'
  printf '\r\n'
}

if [[ "${REQUEST_METHOD:-GET}" != "POST" ]]; then
  emit_status "405 Method Not Allowed"
  echo "{\"ok\":false,\"error\":\"POST required\"}"
  exit 0
fi

if [[ -z "${CONTENT_LENGTH:-}" ]] || (( CONTENT_LENGTH <= 0 )) || (( CONTENT_LENGTH > 8192 )); then
  emit_status "411 Length Required"
  echo "{\"ok\":false,\"error\":\"missing or oversized Content-Length\"}"
  exit 0
fi

body=$(head -c "$CONTENT_LENGTH" -)

# Validate it's parseable JSON with an endpoint field. Use python (always
# present on the Pi for tesla_api.py) instead of jq, which isn't guaranteed.
endpoint=$(python3 - <<EOF
import json, sys
try:
    sub = json.loads("""$body""")
    ep = sub.get("endpoint")
    keys = sub.get("keys", {})
    if not ep or not keys.get("p256dh") or not keys.get("auth"):
        raise ValueError("missing endpoint or keys")
    print(ep)
except Exception:
    sys.exit(1)
EOF
) || {
  emit_status "400 Bad Request"
  echo "{\"ok\":false,\"error\":\"malformed subscription JSON\"}"
  exit 0
}

# Hash the endpoint to get a stable filename (so re-subscribes from the same
# browser overwrite rather than accumulate).
mkdir -p "$SUBS_DIR"
fname="$SUBS_DIR/$(printf '%s' "$endpoint" | sha256sum | cut -c1-16).json"
printf '%s' "$body" > "$fname"
chmod 600 "$fname"

emit_status "200 OK"
echo "{\"ok\":true}"
