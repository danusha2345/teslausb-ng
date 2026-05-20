# Credentials hardening

By default teslausb stores all secrets (Wi-Fi passphrase, archive-server
credentials, Tesla API tokens) in plain text in `/root/teslausb_setup_variables.conf`
on the SD card. If the card is removed and read on another machine, every
secret is visible.

teslausb-ng adds two opt-in paths to mitigate that:

## 1. systemd-creds at-rest encryption

`systemd-creds` (shipped with systemd ≥ 250, present on Bookworm) encrypts a
file against the host's TPM or a host-derived key so it can only be decrypted
on the same Pi. Use it for the most sensitive variables.

```bash
# On a configured Pi:
systemd-creds encrypt --with-key=host \
    /root/teslausb_setup_variables.conf \
    /root/teslausb_setup_variables.conf.cred
mv /root/teslausb_setup_variables.conf{,.plain.bak}   # keep a backup off-Pi
chmod 600 /root/teslausb_setup_variables.conf.plain.bak
# Set up the systemd unit to LoadCredentialEncrypted on start
# (see tools/install-creds-unit.sh).
```

The runtime helper `tools/install-creds-unit.sh` (added by teslausb-ng) writes
a drop-in for `teslausb.service` that calls `systemd-creds decrypt` into a
tmpfs mount at `/run/credentials/teslausb` and points archiveloop at it. The
decrypted material is gone the moment the service stops.

## 2. CIFS-mounted credentials share (issue #460)

For users who would rather not store credentials on the SD card at all,
teslausb-ng supports a read-only CIFS mount. Add to `teslausb_setup_variables.conf`:

```bash
TESLAUSB_CREDS_SHARE="//nas.lan/teslausb-creds"
TESLAUSB_CREDS_USER="teslausb"
TESLAUSB_CREDS_PASSWORD_FILE="/root/.credshare-pass"  # one-line file, mode 600
TESLAUSB_CREDS_PATH="/var/teslausb-creds/setup_variables.conf"
```

`setup/pi/configure-creds.sh` (run once during install) will:

1. Install `cifs-utils` if needed.
2. Add a systemd `var-teslausb\\x2dcreds.mount` unit that mounts the share
   read-only at boot.
3. Order `teslausb.service` `After=var-teslausb-creds.mount` and
   `Requires=var-teslausb-creds.mount`.
4. Modify `rc.local` / `archiveloop` to source the file from the mounted path
   instead of `/root/`.

When the share is unreachable (Wi-Fi down, NAS rebooting) the unit retries
without blocking the rest of boot, and archiveloop simply stays in its
"waiting for archive" state.

## What's NOT supported

* Hardware-backed encryption on Pi Zero W (no TPM, `--with-key=host` is the
  only option; full TPM-bound encryption needs Pi 4+).
* On-the-fly key rotation — re-encrypt the file when rotating.
* Network-share credentials for a CIFS share that itself requires Kerberos.
