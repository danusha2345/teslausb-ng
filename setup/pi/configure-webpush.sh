#!/bin/bash -eu
#
# Phase 1.3.2 — Web Push notifications setup.
#
# Generates a VAPID keypair (RFC 8292), installs pywebpush via the pinned
# Python requirements, drops the public key where the web UI can fetch it,
# and creates the subscriptions directory.
#
# Idempotent: if a VAPID keypair already exists, the script leaves it alone
# and just refreshes the public-key file the web UI reads.
#
# Enable per-feature by setting in /root/teslausb_setup_variables.conf:
#     WEBPUSH_ENABLED=true
#     # Optional, used in VAPID claims (good practice, otherwise mailto:teslausb@local):
#     # VAPID_CONTACT="mailto:you@example.com"

function log_progress() {
  if declare -F setup_progress > /dev/null; then
    setup_progress "configure-webpush: $1"
  else
    echo "configure-webpush: $1"
  fi
}

if [[ "${WEBPUSH_ENABLED:-false}" != "true" ]]; then
  log_progress "WEBPUSH_ENABLED is not true, skipping."
  exit 0
fi

VAPID_DIR="/root/.config/teslausb-webpush"
VAPID_PRIV="$VAPID_DIR/vapid_private.pem"
VAPID_PUB="$VAPID_DIR/vapid_public.pem"
WEB_PUB="/var/www/html/vapid_public_key.txt"
SUBS_DIR="/mutable/webpush_subscriptions"

mkdir -p "$VAPID_DIR" "$SUBS_DIR"
chmod 700 "$VAPID_DIR"
chmod 755 "$SUBS_DIR"

if [[ -f "$VAPID_PRIV" && -f "$VAPID_PUB" ]]; then
  log_progress "VAPID keypair already exists at $VAPID_DIR (keeping)."
else
  log_progress "Generating VAPID keypair..."
  # openssl ecparam emits a P-256 private key that pywebpush accepts directly.
  openssl ecparam -name prime256v1 -genkey -noout -out "$VAPID_PRIV"
  openssl ec -in "$VAPID_PRIV" -pubout -out "$VAPID_PUB" 2> /dev/null
  chmod 600 "$VAPID_PRIV"
  chmod 644 "$VAPID_PUB"
fi

# Extract the raw 65-byte uncompressed point from the public key and
# url-base64-encode it — that's the form a browser's
# `applicationServerKey: urlBase64ToUint8Array(...)` expects.
log_progress "Writing browser-facing public key to $WEB_PUB ..."
mkdir -p "$(dirname "$WEB_PUB")"
python3 - <<EOF > "$WEB_PUB"
import base64
from cryptography.hazmat.primitives import serialization
with open("$VAPID_PUB", "rb") as f:
    pub = serialization.load_pem_public_key(f.read())
raw = pub.public_bytes(
    encoding=serialization.Encoding.X962,
    format=serialization.PublicFormat.UncompressedPoint,
)
print(base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii"))
EOF
chmod 644 "$WEB_PUB"

log_progress "Web Push setup complete. Browsers can now subscribe via the web UI."
log_progress "  Subscriptions dir: $SUBS_DIR"
log_progress "  Public key file:   $WEB_PUB"
