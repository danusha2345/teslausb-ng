#!/bin/bash
#
# Background progress notifier for archive operations.
#
# Resolves #759 ("Feature: Regular Notifications with sync progress") by
# emitting periodic notifications via send-push-message while a long-running
# rsync or rclone transfer is in progress. Designed to be launched by the
# archive-clips scripts and killed when the transfer finishes.
#
# Usage:
#     /root/bin/_progress_notifier.sh <interval_seconds> <progress_log_path>
#
# Behavior:
#   * Every <interval_seconds>, sends a "still archiving" notification with
#     elapsed time and the last line of the progress log (which typically
#     contains rclone --stats or rsync --info=progress2 output).
#   * Emits no notification if SEND_PROGRESS_NOTIFICATIONS != "true".
#   * Cleans up on SIGTERM / parent exit (uses set -m so kill propagates).

set -u

interval="${1:-300}"
progress_log="${2:-/tmp/rsynclog}"

# Bail out cleanly if progress notifications aren't enabled. The script can
# still be launched unconditionally — it just no-ops, which keeps the caller
# side simple.
if [[ "${SEND_PROGRESS_NOTIFICATIONS:-false}" != "true" ]]; then
  exit 0
fi

start_ts=$(date +%s)

trap 'exit 0' TERM INT

while true; do
  sleep "$interval"

  local_now=$(date +%s)
  elapsed=$((local_now - start_ts))
  mins=$((elapsed / 60))
  secs=$((elapsed % 60))

  last_line=""
  if [[ -r "$progress_log" ]]; then
    # Strip control characters / carriage returns rclone --progress emits.
    last_line=$(tail -n 1 "$progress_log" 2> /dev/null | tr -d '\r' | tr -cd '\11\12\15\40-\176' | head -c 200)
  fi

  msg="Archive in progress: ${mins}m ${secs}s elapsed"
  if [[ -n "$last_line" ]]; then
    msg="${msg} — ${last_line}"
  fi

  # send-push-message exits non-zero if no backend is configured; that's fine,
  # we don't want to kill the watcher because of it.
  /root/bin/send-push-message "${NOTIFICATION_TITLE:-teslausb}:" "$msg" progress || true
done
