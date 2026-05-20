#!/bin/bash -eu

while [ -n "${1+x}" ]
do
  # rsync exit codes treated as transient and retried by archiveloop on next cycle:
  #   12 — protocol data stream error (network glitch)
  #   23 — partial transfer due to errors (file disappeared / permission)
  #   24 — partial transfer due to vanished source files (normal on Tesla writes)
  #   30 — timeout in data send/receive (network stall, broken pipe)
  # See issue #942 ("Archiving Error - Broken pipe").
  if ! (rsync -avhRL --timeout=60 --remove-source-files --no-perms --omit-dir-times \
        --stats --log-file=/tmp/archive-rsync-cmd.log --ignore-missing-args \
        --files-from="$2" "$1" "$RSYNC_USER@$RSYNC_SERVER:$RSYNC_PATH" &> /tmp/rsynclog || [[ "$?" =~ ^(12|23|24|30)$ ]] )
  then
    cat /tmp/archive-rsync-cmd.log /tmp/rsynclog > /tmp/archive-error.log
    exit 1
  fi
  shift 2
done
