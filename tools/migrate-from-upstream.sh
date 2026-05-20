#!/bin/bash
#
# Migrate an existing marcone/teslausb installation to teslausb-ng.
#
# Behavior:
#   1. Snapshot /mutable and the current /root/bin/ contents so we can roll
#      back if anything goes wrong.
#   2. Stop the teslausb.service while we swap files.
#   3. Pull the teslausb-ng tarball and replace runtime scripts in
#      /root/bin/ with the new versions. The user's
#      /root/teslausb_setup_variables.conf is preserved verbatim.
#   4. Reload + restart the service.
#
# Usage (on the Pi, as root):
#     curl -fsSL https://raw.githubusercontent.com/danusha2345/teslausb-ng/main-dev/tools/migrate-from-upstream.sh | sudo bash
#
# Or with a specific branch / tag:
#     TESLAUSB_NG_REF=v1.0.0 sudo bash migrate-from-upstream.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: must run as root (use sudo)" >&2
  exit 1
fi

REPO="${TESLAUSB_NG_REPO:-danusha2345/teslausb-ng}"
REF="${TESLAUSB_NG_REF:-main-dev}"
BACKUP_DIR="/mutable/teslausb-ng-migration-$(date +%Y%m%d-%H%M%S)"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "==> Snapshotting current install into $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a /root/bin "$BACKUP_DIR/bin" 2> /dev/null || true
cp -a /root/teslausb_setup_variables.conf "$BACKUP_DIR/teslausb_setup_variables.conf" 2> /dev/null || true
systemctl show teslausb.service > "$BACKUP_DIR/teslausb.service.unit" 2> /dev/null || true

echo "==> Stopping teslausb.service"
systemctl stop teslausb.service || true

echo "==> Fetching teslausb-ng @ $REF"
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$REF" 2> /dev/null \
  | tar -xz -C "$WORKDIR" --strip-components=1 \
  || curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/tags/$REF" \
       | tar -xz -C "$WORKDIR" --strip-components=1

echo "==> Replacing runtime scripts in /root/bin/"
install -m 755 "$WORKDIR/run/archiveloop"                /root/bin/archiveloop
install -m 755 "$WORKDIR/run/awake_start"                /root/bin/awake_start
install -m 755 "$WORKDIR/run/awake_stop"                 /root/bin/awake_stop
install -m 755 "$WORKDIR/run/_retry.sh"                  /root/bin/_retry.sh
install -m 755 "$WORKDIR/run/_log.sh"                    /root/bin/_log.sh
install -m 755 "$WORKDIR/run/_progress_notifier.sh"      /root/bin/_progress_notifier.sh
install -m 755 "$WORKDIR/run/_telemetry.sh"              /root/bin/_telemetry.sh
install -m 644 "$WORKDIR/setup/pi/requirements.txt"      /root/bin/requirements.txt
install -m 755 "$WORKDIR/tools/install-creds-unit.sh"    /root/bin/install-creds-unit.sh

# Archive-backend modules (only the one currently in use needs the new
# exit-code allowlist, but copy them all for parity).
for backend in rsync_archive cifs_archive rclone_archive nfs_archive none_archive; do
  if [[ -d "/root/bin" && -f "$WORKDIR/run/$backend/archive-clips.sh" ]]; then
    install -m 755 "$WORKDIR/run/$backend/archive-clips.sh" "/root/bin/archive-clips.sh.$backend"
  fi
done
# The active backend's archive-clips.sh lives directly at /root/bin/.
# Detect which one by reading ARCHIVE_SYSTEM from the conf and overwrite.
active=$(grep -E '^ARCHIVE_SYSTEM=' /root/teslausb_setup_variables.conf 2> /dev/null | tail -1 | sed 's/^ARCHIVE_SYSTEM=//; s/[ "'\'']//g')
if [[ -n "$active" && -f "/root/bin/archive-clips.sh.${active}_archive" ]]; then
  install -m 755 "/root/bin/archive-clips.sh.${active}_archive" /root/bin/archive-clips.sh
fi

echo "==> Replacing web UI assets"
if [[ -d /var/www/html ]]; then
  cp -a "$WORKDIR/teslausb-www/html/." /var/www/html/
fi

echo "==> Reinstalling pinned Python deps"
if command -v pip3 > /dev/null 2>&1 && [[ -f /root/bin/requirements.txt ]]; then
  pip3 install --break-system-packages -r /root/bin/requirements.txt || true
fi

echo "==> Reloading and restarting teslausb.service"
systemctl daemon-reload
systemctl start teslausb.service

echo
echo "Migration complete. Backup of the previous install: $BACKUP_DIR"
echo "Rollback if needed:"
echo "  systemctl stop teslausb"
echo "  rm -rf /root/bin && cp -a $BACKUP_DIR/bin /root/bin"
echo "  systemctl start teslausb"
