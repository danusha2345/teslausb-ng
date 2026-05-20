#! /bin/bash
#
# Lint shell scripts in teslausb-ng with ShellCheck.
#
# Two passes:
#   1. Strict pass on the historically clean core scripts. Fails on any issue
#      except SC1091 (sourced files we cannot follow).
#   2. Warning-and-up pass on the broader script tree. Catches real bugs
#      without breaking CI on minor style notes that upstream never fixed.
#
# Add files to the strict list once they cleanly pass --severity=style on
# the broader pass.

set -eu

shopt -s globstar nullglob extglob

# print shellcheck version so we know what Github uses
shellcheck -V

# --- Pass 1: strict ---------------------------------------------------------
shellcheck --exclude=SC1091 \
           ./setup/pi/setup-teslausb \
           ./pi-gen-sources/00-teslausb-tweaks/files/rc.local \
           ./run/archiveloop \
           ./run/auto.teslausb \
           ./run/awake_start \
           ./run/awake_stop \
           ./run/mountimage \
           ./run/mountoptsforimage \
           ./run/remountfs_rw \
           ./run/send-push-message \
           ./run/temperature_monitor \
           ./run/waitforidle

# --- Pass 2: warning-and-up on the rest -------------------------------------
broader=(
  ./run/**/*.sh
  ./setup/**/*.sh
  ./tools/*.sh
  ./tests/*.sh
  ./teslausb-www/html/cgi-bin/*.sh
)

# Filter out files already covered by pass 1 (they're not .sh anyway, but be safe).
declare -A seen=()
to_check=()
for f in "${broader[@]}"; do
  [[ -z "${seen[$f]:-}" ]] || continue
  seen[$f]=1
  to_check+=("$f")
done

if [[ ${#to_check[@]} -gt 0 ]]; then
  shellcheck --severity=warning --exclude=SC1091 "${to_check[@]}"
fi
