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
