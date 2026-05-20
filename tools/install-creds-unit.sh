#!/bin/bash
#
# Install a systemd drop-in for teslausb.service that decrypts an encrypted
# credentials file at boot using systemd-creds.
#
# Prereqs:
#   * systemd >= 250 (present on Bookworm).
#   * /root/teslausb_setup_variables.conf.cred already exists (see
#     doc/Credentials.md for the encrypt step).
#
# Usage (run once, as root, on the Pi):
#     sudo /root/bin/install-creds-unit.sh
#
# After installation, teslausb.service will receive the decrypted variables
# at /run/credentials/teslausb.service/setup_variables and archiveloop will
# source from there instead of /root/teslausb_setup_variables.conf.

set -euo pipefail

cred_file="/root/teslausb_setup_variables.conf.cred"
dropin_dir="/etc/systemd/system/teslausb.service.d"
dropin_file="$dropin_dir/10-credentials.conf"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: must run as root" >&2
  exit 1
fi

if [[ ! -f "$cred_file" ]]; then
  echo "ERROR: $cred_file not found." >&2
  echo "Encrypt your config first:" >&2
  echo "  systemd-creds encrypt --with-key=host \\" >&2
  echo "    /root/teslausb_setup_variables.conf \\" >&2
  echo "    $cred_file" >&2
  exit 1
fi

mkdir -p "$dropin_dir"
cat > "$dropin_file" <<EOF
[Service]
LoadCredentialEncrypted=setup_variables:$cred_file
# archiveloop reads /root/teslausb_setup_variables.conf by default — bind
# the decrypted credential there at runtime. The bind goes away when the
# service stops.
ExecStartPre=/usr/bin/install -m 600 \${CREDENTIALS_DIRECTORY}/setup_variables /root/teslausb_setup_variables.conf
EOF

systemctl daemon-reload
echo "Installed $dropin_file"
echo "Restart the service when ready: systemctl restart teslausb"
