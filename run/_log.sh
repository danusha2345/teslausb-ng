#!/bin/bash
#
# Structured logging helper sourced by long-running runtime scripts.
#
# When the script runs under systemd (TESLAUSB_UNDER_SYSTEMD=1 is exported
# automatically by the unit), log lines are also forwarded to journald with
# proper priorities so `journalctl -u teslausb -p err` works. When run
# interactively or from rc.local, lines fall through to the regular text
# log file at $LOG_FILE.
#
# Usage:
#     . /root/bin/_log.sh
#     log_info  "archive starting"
#     log_warn  "rsync exit 23 — treating as transient"
#     log_error "BLE pairing failed"
#
# These names complement the existing log() function in archiveloop; both
# may coexist during the migration.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "$0 must be sourced, not executed" >&2
  exit 1
fi

# Default log file matches the rest of the codebase.
: "${LOG_FILE:=/mutable/archiveloop.log}"

_log_to_file() {
  local level="$1"
  shift
  if [[ -d "$(dirname "$LOG_FILE")" ]]; then
    echo "$(date): [$level]" "$@" >> "$LOG_FILE" 2> /dev/null || true
  fi
}

_log_to_journal() {
  local priority="$1"
  shift
  # systemd-cat lets us tag a single message with a priority. Fall back
  # silently if it's not available.
  if command -v systemd-cat > /dev/null 2>&1; then
    echo "$@" | systemd-cat --identifier=teslausb --priority="$priority"
  fi
}

# Numeric priorities from sd-daemon(3): err=3, warning=4, info=6.
log_error() { _log_to_journal 3 "$@"; _log_to_file ERROR "$@"; }
log_warn()  { _log_to_journal 4 "$@"; _log_to_file WARN  "$@"; }
log_info()  { _log_to_journal 6 "$@"; _log_to_file INFO  "$@"; }
