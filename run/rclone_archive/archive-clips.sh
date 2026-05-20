#!/bin/bash -eu

# read the setup variables again because arrays, like RCLONE_FLAGS, don't export to subshells/child scripts
source /root/bin/envsetup.sh

flags=("-L" "--transfers=1")
if [[ -v RCLONE_FLAGS ]]
then
  flags+=("${RCLONE_FLAGS[@]}")
fi

# ARCHIVE_VERBOSE=true adds -v and tees rclone output to a dedicated verbose
# log so users can see exactly what was transferred (issue #667).
verbose_log="/mutable/archive-verbose.log"
if [[ "${ARCHIVE_VERBOSE:-false}" == "true" ]]
then
  flags+=("-v")
fi

# SEND_PROGRESS_NOTIFICATIONS=true asks rclone to print periodic stats; the
# background notifier polls them and forwards via send-push-message (#759).
progress_interval="${PROGRESS_NOTIFY_INTERVAL_SECONDS:-300}"
if [[ "${SEND_PROGRESS_NOTIFICATIONS:-false}" == "true" ]]
then
  flags+=("--stats=${progress_interval}s" "--progress" "--stats-one-line")
fi

# Launch the watcher (no-op when SEND_PROGRESS_NOTIFICATIONS!=true).
notifier_pid=
if [[ -x /root/bin/_progress_notifier.sh && "${SEND_PROGRESS_NOTIFICATIONS:-false}" == "true" ]]
then
  /root/bin/_progress_notifier.sh "$progress_interval" "$verbose_log" &
  notifier_pid=$!
  trap 'kill $notifier_pid 2>/dev/null || true' EXIT
fi

while [ -n "${1+x}" ]
do
  if [[ "${ARCHIVE_VERBOSE:-false}" == "true" || "${SEND_PROGRESS_NOTIFICATIONS:-false}" == "true" ]]
  then
    # Tee to verbose log so the progress watcher and end-of-archive review
    # both have something to read. The main LOG_FILE still gets a copy.
    rclone --config /root/.config/rclone/rclone.conf move "${flags[@]}" --files-from "$2" "$1" "$RCLONE_DRIVE:$RCLONE_PATH" 2>&1 | tee -a "$verbose_log" >> "$LOG_FILE"
  else
    rclone --config /root/.config/rclone/rclone.conf move "${flags[@]}" --files-from "$2" "$1" "$RCLONE_DRIVE:$RCLONE_PATH" >> "$LOG_FILE" 2>&1
  fi
  shift 2
done
