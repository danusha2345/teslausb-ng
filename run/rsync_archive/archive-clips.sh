#!/bin/bash -eu

# ARCHIVE_VERBOSE=true adds rsync -v (#667). --info=progress2 is added when
# SEND_PROGRESS_NOTIFICATIONS=true so the progress watcher can read live
# bytes-transferred status (#759).
rsync_extra=()
verbose_log="/mutable/archive-verbose.log"
if [[ "${ARCHIVE_VERBOSE:-false}" == "true" ]]; then
  rsync_extra+=("-v")
fi
if [[ "${SEND_PROGRESS_NOTIFICATIONS:-false}" == "true" ]]; then
  rsync_extra+=("--info=progress2")
fi

progress_interval="${PROGRESS_NOTIFY_INTERVAL_SECONDS:-300}"
notifier_pid=
if [[ -x /root/bin/_progress_notifier.sh && "${SEND_PROGRESS_NOTIFICATIONS:-false}" == "true" ]]; then
  /root/bin/_progress_notifier.sh "$progress_interval" "$verbose_log" &
  notifier_pid=$!
  trap 'kill $notifier_pid 2>/dev/null || true' EXIT
fi

while [ -n "${1+x}" ]
do
  # rsync exit codes treated as transient and retried by archiveloop on next cycle:
  #   12 — protocol data stream error (network glitch)
  #   23 — partial transfer due to errors (file disappeared / permission)
  #   24 — partial transfer due to vanished source files (normal on Tesla writes)
  #   30 — timeout in data send/receive (network stall, broken pipe)
  # See issue #942 ("Archiving Error - Broken pipe").
  if [[ "${ARCHIVE_VERBOSE:-false}" == "true" || "${SEND_PROGRESS_NOTIFICATIONS:-false}" == "true" ]]; then
    # Tee live rsync output into verbose_log for the progress watcher and
    # post-mortem review; keep the original /tmp/rsynclog capture intact.
    if ! ( rsync -avhRL --timeout=60 --remove-source-files --no-perms --omit-dir-times \
            "${rsync_extra[@]}" \
            --stats --log-file=/tmp/archive-rsync-cmd.log --ignore-missing-args \
            --files-from="$2" "$1" "$RSYNC_USER@$RSYNC_SERVER:$RSYNC_PATH" 2>&1 | tee -a "$verbose_log" > /tmp/rsynclog \
            || [[ "${PIPESTATUS[0]}" =~ ^(12|23|24|30)$ ]] ); then
      cat /tmp/archive-rsync-cmd.log /tmp/rsynclog > /tmp/archive-error.log
      exit 1
    fi
  else
    if ! (rsync -avhRL --timeout=60 --remove-source-files --no-perms --omit-dir-times \
          --stats --log-file=/tmp/archive-rsync-cmd.log --ignore-missing-args \
          --files-from="$2" "$1" "$RSYNC_USER@$RSYNC_SERVER:$RSYNC_PATH" &> /tmp/rsynclog || [[ "$?" =~ ^(12|23|24|30)$ ]] )
    then
      cat /tmp/archive-rsync-cmd.log /tmp/rsynclog > /tmp/archive-error.log
      exit 1
    fi
  fi
  shift 2
done
