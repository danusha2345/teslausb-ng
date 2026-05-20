#!/bin/bash -eu
#
# Phase 1.1.3 — CIFS credentials share (resolves upstream issue #460).
#
# When a user prefers not to leave their Wi-Fi passphrase, archive
# credentials, and Tesla API tokens on the SD card, this script wires up
# a read-only CIFS mount that holds the real teslausb_setup_variables.conf
# off-device. The Pi only needs the CIFS endpoint, share name, user, and a
# local password file — none of which expose the actual archive password
# or Wi-Fi PSK.
#
# Enable by setting in /root/teslausb_setup_variables.conf:
#     TESLAUSB_CREDS_SHARE="//nas.lan/teslausb-creds"
#     TESLAUSB_CREDS_USER="teslausb"
#     TESLAUSB_CREDS_PASSWORD_FILE="/root/.credshare-pass"   # 0600, one line
#     TESLAUSB_CREDS_PATH="setup_variables.conf"             # path inside the share
#
# The mount point is /var/teslausb-creds (read-only). Archiveloop reads
# the variables from that mount via a symlink at
# /root/teslausb_setup_variables.conf — no other code needs to change.

function log_progress() {
  if declare -F setup_progress > /dev/null
  then
    setup_progress "configure-creds: $1"
  else
    echo "configure-creds: $1"
  fi
}

if [[ -z "${TESLAUSB_CREDS_SHARE:-}" ]]; then
  log_progress "TESLAUSB_CREDS_SHARE not set, skipping CIFS creds share."
  exit 0
fi

for v in TESLAUSB_CREDS_USER TESLAUSB_CREDS_PASSWORD_FILE TESLAUSB_CREDS_PATH; do
  if [[ -z "${!v:-}" ]]; then
    log_progress "STOP: $v must also be set when TESLAUSB_CREDS_SHARE is set."
    exit 1
  fi
done

if [[ ! -r "$TESLAUSB_CREDS_PASSWORD_FILE" ]]; then
  log_progress "STOP: TESLAUSB_CREDS_PASSWORD_FILE ($TESLAUSB_CREDS_PASSWORD_FILE) is not readable."
  exit 1
fi

# Tighten perms on the password file in case the user forgot.
chmod 600 "$TESLAUSB_CREDS_PASSWORD_FILE"

log_progress "Installing cifs-utils..."
apt-get -y install cifs-utils

mount_point="/var/teslausb-creds"
mount_unit="var-teslausb\\x2dcreds.mount"
mount_unit_file="/etc/systemd/system/var-teslausb\\x2dcreds.mount"
override_dir="/etc/systemd/system/teslausb.service.d"

mkdir -p "$mount_point"
chmod 700 "$mount_point"

# CIFS credentials file expected by mount.cifs.
creds_file="/etc/teslausb-creds.cifs"
log_progress "Writing $creds_file..."
{
  echo "username=$TESLAUSB_CREDS_USER"
  echo "password=$(head -n 1 "$TESLAUSB_CREDS_PASSWORD_FILE")"
} > "$creds_file"
chmod 600 "$creds_file"

log_progress "Writing systemd mount unit $mount_unit_file..."
cat > "$mount_unit_file" << EOF
[Unit]
Description=teslausb-ng credentials share ($TESLAUSB_CREDS_SHARE)
DefaultDependencies=no
After=network-online.target
Wants=network-online.target

[Mount]
What=$TESLAUSB_CREDS_SHARE
Where=$mount_point
Type=cifs
Options=credentials=$creds_file,ro,vers=3.0,iocharset=utf8,uid=root,gid=root,file_mode=0400,dir_mode=0500,nofail
TimeoutSec=30s

[Install]
WantedBy=multi-user.target
EOF

log_progress "Writing systemd override so teslausb.service waits for the mount..."
mkdir -p "$override_dir"
cat > "$override_dir/20-creds-share.conf" << EOF
[Unit]
RequiresMountsFor=$mount_point
After=$mount_unit

[Service]
# Source the variables from the share. The symlink survives reboots and
# is replaced if TESLAUSB_CREDS_PATH ever changes.
ExecStartPre=/bin/ln -sf $mount_point/$TESLAUSB_CREDS_PATH /root/teslausb_setup_variables.conf
EOF

systemctl daemon-reload
systemctl enable "$mount_unit"
log_progress "Done. Reboot or run: systemctl start $mount_unit && systemctl restart teslausb"
