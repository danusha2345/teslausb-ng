#!/bin/bash
#
# BLE-health watchdog (issue #1029 follow-up, v1.2.4).
#
# Tracks consecutive failures of /root/bin/tesla-control calls. When the
# counter crosses BLE_HEALTH_FAILURE_THRESHOLD (default 10), emits ONE
# notification via send-push-message asking the user to re-pair the BLE
# key — the most common cause of a sustained failure run is a Tesla
# firmware update that rotated the protocol or invalidated the key.
#
# After a successful call, the counter resets and the "notified" flag
# clears, so a recovered link can re-arm the watchdog without manual
# intervention.
#
# Sourced from awake_start, awake_stop, and ble_action.sh; provides:
#
#     _ble_health_record_success
#     _ble_health_record_failure
#
# State lives in /mutable/ble_health.state as a single line:
#     <consecutive_failures> <notified_bool>
# 0/1 for the flag.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "$0 must be sourced, not executed" >&2
  exit 1
fi

_BLE_HEALTH_STATE_FILE="${_BLE_HEALTH_STATE_FILE:-/mutable/ble_health.state}"
_BLE_HEALTH_THRESHOLD="${BLE_HEALTH_FAILURE_THRESHOLD:-10}"

_ble_health_read() {
  if [[ -r "$_BLE_HEALTH_STATE_FILE" ]]; then
    read -r _BLE_HEALTH_FAIL_COUNT _BLE_HEALTH_NOTIFIED < "$_BLE_HEALTH_STATE_FILE"
  fi
  : "${_BLE_HEALTH_FAIL_COUNT:=0}"
  : "${_BLE_HEALTH_NOTIFIED:=0}"
}

_ble_health_write() {
  mkdir -p "$(dirname "$_BLE_HEALTH_STATE_FILE")" 2> /dev/null || true
  echo "$_BLE_HEALTH_FAIL_COUNT $_BLE_HEALTH_NOTIFIED" > "$_BLE_HEALTH_STATE_FILE" 2> /dev/null || true
}

_ble_health_record_success() {
  _ble_health_read
  if (( _BLE_HEALTH_FAIL_COUNT > 0 )) || (( _BLE_HEALTH_NOTIFIED == 1 )); then
    if (( _BLE_HEALTH_NOTIFIED == 1 )) && command -v send-push-message > /dev/null 2>&1; then
      send-push-message "${NOTIFICATION_TITLE:-teslausb}:" \
        "Tesla BLE: link recovered after ${_BLE_HEALTH_FAIL_COUNT} failures." \
        ble-health 2> /dev/null || true
    elif (( _BLE_HEALTH_NOTIFIED == 1 )) && [[ -x /root/bin/send-push-message ]]; then
      /root/bin/send-push-message "${NOTIFICATION_TITLE:-teslausb}:" \
        "Tesla BLE: link recovered after ${_BLE_HEALTH_FAIL_COUNT} failures." \
        ble-health 2> /dev/null || true
    fi
    _BLE_HEALTH_FAIL_COUNT=0
    _BLE_HEALTH_NOTIFIED=0
    _ble_health_write
  fi
}

_ble_health_record_failure() {
  _ble_health_read
  _BLE_HEALTH_FAIL_COUNT=$((_BLE_HEALTH_FAIL_COUNT + 1))
  if (( _BLE_HEALTH_FAIL_COUNT >= _BLE_HEALTH_THRESHOLD )) && (( _BLE_HEALTH_NOTIFIED == 0 )); then
    local msg="Tesla BLE: ${_BLE_HEALTH_FAIL_COUNT} consecutive failures. Tesla firmware may have rotated the protocol or invalidated the key — re-pair via /pairBLEkey.sh or the web UI. See doc/Tesla_BLE.md."
    if [[ -x /root/bin/send-push-message ]]; then
      /root/bin/send-push-message "${NOTIFICATION_TITLE:-teslausb}:" "$msg" ble-health 2> /dev/null || true
    fi
    _BLE_HEALTH_NOTIFIED=1
  fi
  _ble_health_write
}
