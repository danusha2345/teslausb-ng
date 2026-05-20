#!/bin/bash
#
# Build a teslausb-ng Raspberry Pi OS image reproducibly.
#
# This wraps RPi-Distro/pi-gen in its Docker mode so the produced image
# does not depend on the host's apt cache, locale, or installed tools.
# CI uses this script verbatim; developers can run it locally to verify
# pi-gen changes before pushing.
#
# Usage:
#     tools/build-image.sh [<pi-gen-tag>]
#
# Optional argument pins the pi-gen revision; default is "master".
# Output appears in ./deploy/ inside the repo.

set -euo pipefail

PI_GEN_REF="${1:-master}"

HERE=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$HERE/.." && pwd)
WORKDIR="$REPO_ROOT/.pi-gen-build"
PI_GEN_DIR="$WORKDIR/pi-gen"
DEPLOY_DIR="$REPO_ROOT/deploy"

if [[ ! -d "$REPO_ROOT/pi-gen-sources" ]]; then
  echo "ERROR: $REPO_ROOT/pi-gen-sources not found — wrong working directory?" >&2
  exit 1
fi

mkdir -p "$WORKDIR" "$DEPLOY_DIR"

if [[ ! -d "$PI_GEN_DIR/.git" ]]; then
  echo ">>> Cloning RPi-Distro/pi-gen @ $PI_GEN_REF into $PI_GEN_DIR"
  git clone --depth 1 --branch "$PI_GEN_REF" https://github.com/RPi-Distro/pi-gen.git "$PI_GEN_DIR" \
    || git clone https://github.com/RPi-Distro/pi-gen.git "$PI_GEN_DIR"
fi

echo ">>> Preparing pi-gen with teslausb sources"
(
  cd "$PI_GEN_DIR"
  git fetch origin
  git checkout "$PI_GEN_REF" 2> /dev/null || git checkout master
  git reset --hard "origin/$PI_GEN_REF" 2> /dev/null || git reset --hard origin/master

  # Pi-gen master's stage2/01-sys-tweaks/00-packages lists several
  # Raspberry-Pi-specific packages that ship only in archive.raspberrypi.com
  # and miss the snapshot our chroot can reach. Some live on the same line
  # as other packages ("rpi-swap rpi-loop-utils", "rpi-usb-gadget
  # modemmanager-"), so a whole-line delete doesn't catch them. Use word-
  # boundary substitution to strip the individual tokens and tidy stray
  # leading/trailing whitespace afterwards.
  local_packages="stage2/01-sys-tweaks/00-packages"
  if [[ -f "$local_packages" ]]; then
    sed -i.bak \
        -e 's/\brpi-swap\b//g' \
        -e 's/\brpi-loop-utils\b//g' \
        -e 's/\brpi-usb-gadget\b//g' \
        -e 's/  */ /g' \
        -e 's/^ //' \
        -e 's/ $//' \
        "$local_packages"
    echo "Patched $local_packages to strip rpi-swap / rpi-loop-utils / rpi-usb-gadget."
    echo "--- effective stage2/01-sys-tweaks/00-packages ---"
    cat "$local_packages"
    echo "----------------------------------------------------"
  fi

  # 01-run.sh tries to `systemctl enable rpi-resize` — that service unit
  # is provided by one of the packages we just stripped (likely
  # rpi-loop-utils). Pi-gen treats the enable failure as fatal. Comment
  # out the line: teslausb-ng users can resize manually with
  # `sudo raspi-config --expand-rootfs` post-flash. Tracked in
  # ROADMAP §1.1.6 — eventually we should re-introduce the resize-on-
  # first-boot path via a self-contained systemd unit in
  # pi-gen-sources/00-teslausb-tweaks/files/systemd/.
  local_run="stage2/01-sys-tweaks/01-run.sh"
  if [[ -f "$local_run" ]] && grep -q 'systemctl enable rpi-resize' "$local_run"; then
    sed -i.bak \
        -e 's|systemctl enable rpi-resize|: # teslausb-ng: rpi-resize.service stripped, skip enable|' \
        "$local_run"
    echo "Patched $local_run to skip rpi-resize.service enable."
  fi

  # Skip pi-gen sub-stages that pull in RPi-only packages we don't need.
  # cloud-init: needs rpi-cloud-init-mods (RPi repo only); teslausb-ng
  # bootstraps via /etc/rc.local instead, no cloud-init involved.
  # Each entry below adds an empty SKIP file which makes pi-gen treat the
  # sub-stage as a no-op.
  for skip_dir in stage2/04-cloud-init; do
    if [[ -d "$skip_dir" ]]; then
      touch "$skip_dir/SKIP"
      echo "Marked $skip_dir as SKIP (RPi-only deps, not needed by teslausb-ng)."
    fi
  done

  "$REPO_ROOT/pi-gen-sources/prepare.sh"
)

echo ">>> Running pi-gen build (native mode)"
(
  cd "$PI_GEN_DIR"
  # Native build.sh runs on the host, which avoids the binfmt_misc-in-
  # privileged-container surface that breaks build-docker.sh on GitHub
  # runners. Caller is responsible for installing the apt deps (the CI
  # workflow does this; locally you'll get a missing-tool error and the
  # apt install command pi-gen prints).
  CONTINUE="${PI_GEN_CONTINUE:-0}" CLEAN="${PI_GEN_CLEAN:-1}" sudo ./build.sh
)

echo ">>> Copying artifacts to $DEPLOY_DIR"
shopt -s nullglob
copied=0
for f in "$PI_GEN_DIR"/deploy/*.zip "$PI_GEN_DIR"/deploy/*.img "$PI_GEN_DIR"/deploy/*.xz; do
  cp -v "$f" "$DEPLOY_DIR/"
  copied=$((copied + 1))
done
shopt -u nullglob

if (( copied == 0 )); then
  echo "ERROR: pi-gen finished but no image artifacts were found under $PI_GEN_DIR/deploy/" >&2
  exit 1
fi

echo ">>> Image build complete. Files:"
ls -lh "$DEPLOY_DIR"
