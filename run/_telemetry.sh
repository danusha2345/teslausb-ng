#!/bin/bash
#
# Opt-in anonymous version telemetry.
#
# What it does: emits a single HTTP POST per boot containing the teslausb-ng
# version, the Pi model family, and the chosen archive backend type. Nothing
# more. No tokens, no IP, no Wi-Fi SSID, no Tesla VIN, no file metadata.
#
# Why: gives the fork a rough sense of active installs so we can prioritize
# bug fixes by reach. Without any signal at all, every fix is a shot in the
# dark.
#
# Opt-in only. The default is OFF. To enable, set in
# teslausb_setup_variables.conf:
#     TESLAUSB_TELEMETRY_OPT_IN=true
#     # Optional: override the default endpoint
#     # TESLAUSB_TELEMETRY_URL="https://example.com/teslausb-ng/ping"
#
# When TESLAUSB_TELEMETRY_DRY_RUN=true, the payload is logged but no network
# request is made — useful for verifying what you'd be sending.

set -u

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  TELEMETRY_LOG="${TELEMETRY_LOG:-/mutable/telemetry.log}"
else
  : "${TELEMETRY_LOG:=/mutable/telemetry.log}"
fi

# pi_model — readable Pi family identifier ("Pi 4", "Pi Zero 2 W", "other").
pi_model() {
  local raw
  if [[ -r /sys/firmware/devicetree/base/model ]]; then
    raw=$(tr -d '\0' < /sys/firmware/devicetree/base/model 2> /dev/null)
  fi
  case "$raw" in
    *"Pi 5"*) echo "Pi 5" ;;
    *"Pi 4"*) echo "Pi 4" ;;
    *"Pi 3"*) echo "Pi 3" ;;
    *"Pi Zero 2"*) echo "Pi Zero 2 W" ;;
    *"Pi Zero W"*) echo "Pi Zero W" ;;
    *"Raspberry"*) echo "other-pi" ;;
    *) echo "other" ;;
  esac
}

teslausb_ng_version() {
  if [[ -r /root/bin/VERSION ]]; then
    cat /root/bin/VERSION
  else
    echo "unknown"
  fi
}

# send_telemetry — the only public entry point. Call once per boot.
send_telemetry() {
  if [[ "${TESLAUSB_TELEMETRY_OPT_IN:-false}" != "true" ]]; then
    return 0
  fi

  local url="${TESLAUSB_TELEMETRY_URL:-https://telemetry.teslausb-ng.invalid/ping}"
  local payload
  payload=$(printf '{"version":"%s","pi_model":"%s","archive":"%s"}' \
    "$(teslausb_ng_version)" \
    "$(pi_model)" \
    "${ARCHIVE_SYSTEM:-unknown}")

  mkdir -p "$(dirname "$TELEMETRY_LOG")" 2> /dev/null || true
  echo "$(date -Is) telemetry: payload=$payload target=$url" >> "$TELEMETRY_LOG" 2> /dev/null || true

  if [[ "${TESLAUSB_TELEMETRY_DRY_RUN:-false}" == "true" ]]; then
    return 0
  fi

  curl --silent --max-time 5 \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$url" \
    >> "$TELEMETRY_LOG" 2>&1 || true
}

# Allow direct invocation for debugging: `./_telemetry.sh dry-run`.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    dry-run)
      TESLAUSB_TELEMETRY_OPT_IN=true TESLAUSB_TELEMETRY_DRY_RUN=true send_telemetry
      tail -n 1 "$TELEMETRY_LOG"
      ;;
    *)
      echo "Usage: $0 dry-run" >&2
      exit 1
      ;;
  esac
fi
