#!/bin/bash
#
# Quick-action CGI endpoint for BLE-controlled Tesla commands.
#
# Exposed actions: lock, unlock, honk, sentry-on, sentry-off, wake, status.
# Only available when TESLA_BLE_VIN is set in
# /root/teslausb_setup_variables.conf; otherwise returns 503.
#
# The status action returns whether BLE is configured — used by the
# Quick-actions panel JS to decide if the buttons should be visible.
#
# This endpoint does not handle file paths, so it doesn't source
# _validate_path.sh; the only user input is the 'action' parameter which
# is validated against a hard-coded allowlist.

# shellcheck disable=SC1091
. /root/teslausb_setup_variables.conf 2> /dev/null || true
# shellcheck disable=SC1091
. /root/bin/_retry.sh 2> /dev/null || true
# shellcheck disable=SC1091
. /root/bin/_ble_health.sh 2> /dev/null || true

# Parse QUERY_STRING into key=value pairs and extract action=.
declare -a urlargs
IFS='&' read -r -a urlargs <<< "${QUERY_STRING:-}"
action=""
for ((i = 0; i < ${#urlargs[@]}; i++)); do
  val="${urlargs[i]//+/ }"
  decoded="$(echo -e "${val//%/\\x}")"
  case "$decoded" in
    action=*) action="${decoded#action=}" ;;
  esac
done

# Status query: report whether BLE is configured. Always 200.
if [[ "$action" == "status" ]]; then
  echo "HTTP/1.0 200 OK"
  echo "Content-type: application/json"
  echo "Cache-Control: no-store"
  echo
  if [[ -n "${TESLA_BLE_VIN:-}" ]]; then
    echo "{\"ble_enabled\":true}"
  else
    echo "{\"ble_enabled\":false}"
  fi
  exit 0
fi

# Validate action against a hard-coded allowlist.
case "$action" in
  lock | unlock | honk | sentry-on | sentry-off | wake) ;;
  *)
    echo "HTTP/1.0 400 Bad Request"
    echo "Content-type: application/json"
    echo
    echo "{\"ok\":false,\"error\":\"unknown action\"}"
    exit 0
    ;;
esac

# Refuse if BLE isn't configured.
if [[ -z "${TESLA_BLE_VIN:-}" ]]; then
  echo "HTTP/1.0 503 Service Unavailable"
  echo "Content-type: application/json"
  echo
  echo "{\"ok\":false,\"error\":\"TESLA_BLE_VIN not configured\"}"
  exit 0
fi

# Map action → tesla-control arguments.
case "$action" in
  lock) cmd=(door-lock) ;;
  unlock) cmd=(door-unlock) ;;
  honk) cmd=(honk-horn) ;;
  sentry-on) cmd=(sentry-mode on) ;;
  sentry-off) cmd=(sentry-mode off) ;;
  wake) cmd=(wake) ;;
esac

run_tesla_control() {
  /root/bin/tesla-control -ble \
    -key-file /root/.ble/key_private.pem \
    -vin "${TESLA_BLE_VIN^^}" \
    "${cmd[@]}" 2>&1
}

# Run the command with backoff (sleeping cars typically wake on retry 2-3).
# Fall back to a single direct call if _retry.sh wasn't sourced.
if command -v retry_with_backoff > /dev/null \
  && retry_with_backoff 3 5 -- run_tesla_control > /dev/null
then
  command -v _ble_health_record_success > /dev/null && _ble_health_record_success
  echo "HTTP/1.0 200 OK"
  echo "Content-type: application/json"
  echo
  echo "{\"ok\":true,\"action\":\"$action\"}"
elif run_tesla_control > /dev/null
then
  command -v _ble_health_record_success > /dev/null && _ble_health_record_success
  echo "HTTP/1.0 200 OK"
  echo "Content-type: application/json"
  echo
  echo "{\"ok\":true,\"action\":\"$action\"}"
else
  command -v _ble_health_record_failure > /dev/null && _ble_health_record_failure
  echo "HTTP/1.0 503 Service Unavailable"
  echo "Content-type: application/json"
  echo
  echo "{\"ok\":false,\"action\":\"$action\",\"error\":\"BLE command failed (car asleep or out of range)\"}"
fi
