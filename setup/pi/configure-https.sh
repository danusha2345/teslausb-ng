#!/bin/bash -eu
#
# HTTPS for the teslausb-ng web UI (unblocks v1.3.2 Web Push, which needs a
# secure context for the Service Worker to load).
#
# When HTTPS_ENABLED=true in /root/teslausb_setup_variables.conf this:
#   1. Generates a self-signed cert at /etc/nginx/ssl/teslausb.{crt,key}
#      with SANs for teslausb.local / teslausb / <hostname>(.local).
#   2. Installs the 443 server block (teslausb-ssl.nginx) alongside the
#      existing :80 block — http:// keeps working, https:// is added.
#   3. Mirrors whatever auth_basic setting configure-web.sh applied so web
#      auth (if enabled) covers both ports.
#
# A self-signed cert means browsers show a one-time "not trusted" warning;
# accept it (or import the cert) once per device. See doc/HTTPS.md. ACME /
# Let's Encrypt is out of scope here because teslausb is LAN-only with no
# public hostname.
#
# Idempotent: an existing cert is reused; only the nginx wiring is refreshed.

function log_progress() {
  if declare -F setup_progress > /dev/null; then
    setup_progress "configure-https: $1"
  else
    echo "configure-https: $1"
  fi
}

if [[ "${HTTPS_ENABLED:-false}" != "true" ]]; then
  log_progress "HTTPS_ENABLED is not true, skipping."
  exit 0
fi

SSL_DIR="/etc/nginx/ssl"
CRT="$SSL_DIR/teslausb.crt"
KEY="$SSL_DIR/teslausb.key"

mkdir -p "$SSL_DIR"

if [[ -f "$CRT" && -f "$KEY" ]]; then
  log_progress "Reusing existing cert at $CRT."
else
  hostname=$(cat /etc/hostname 2> /dev/null | tr -d '[:space:]')
  hostname="${hostname:-teslausb}"
  log_progress "Generating self-signed cert (CN=teslausb.local, +SANs for $hostname)..."
  openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$KEY" \
    -out "$CRT" \
    -subj "/CN=teslausb.local" \
    -addext "subjectAltName=DNS:teslausb.local,DNS:teslausb,DNS:${hostname},DNS:${hostname}.local" \
    2> /dev/null
fi
chmod 600 "$KEY"
chmod 644 "$CRT"

# Install the 443 server block next to the existing :80 one.
SSL_CONF="/etc/nginx/sites-available/teslausb-ssl.nginx"
cp -f "$SOURCE_DIR/teslausb-www/teslausb-ssl.nginx" "$SSL_CONF"
ln -sf "$SSL_CONF" /etc/nginx/sites-enabled/teslausb-ssl

# Mirror the auth_basic decision configure-web.sh made on the HTTP block.
if grep -q 'auth_basic "Restricted Content"' /etc/nginx/sites-available/teslausb.nginx 2> /dev/null; then
  sed -i 's/auth_basic off/auth_basic "Restricted Content"/' "$SSL_CONF"
  log_progress "Mirrored web auth onto the HTTPS block."
fi

# Validate before relying on it; nginx -t catches a bad cert path early.
if command -v nginx > /dev/null && ! nginx -t 2> /dev/null; then
  log_progress "WARNING: nginx -t failed after enabling HTTPS — check $SSL_CONF."
fi

log_progress "HTTPS enabled. Browse https://teslausb.local/ (accept the self-signed cert once)."
log_progress "  cert: $CRT  (valid 10 years, regenerate by deleting it and re-running)"
