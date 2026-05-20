#! /bin/bash
#
# Lint shell scripts in teslausb-ng with ShellCheck.
#
# Three passes:
#   1A. Strict pass on historically-clean core scripts. Fails on any issue
#       (including style/info) except SC1091 (sourced files we cannot follow).
#   1B. Warning-and-up pass on files that v1.0/v1.1 swept clean of real bugs
#       but still carry upstream style/info nits. Fails on warnings and
#       errors; ignores style and info.
#   2.  Error-only pass on the broader script tree. Catches SC1xxx parse
#       errors and high-confidence SC2xxx errors; ignores everything else.
#
# Files migrate: 2 → 1B (once warnings cleaned) → 1A (once style cleaned).

set -eu

shopt -s globstar nullglob extglob

# print shellcheck version so we know what Github uses
shellcheck -V

# --- Pass 1A: strict --------------------------------------------------------
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
           ./run/waitforidle \
           ./run/_retry.sh \
           ./run/_log.sh \
           ./run/_progress_notifier.sh \
           ./run/_telemetry.sh \
           ./run/rsync_archive/archive-clips.sh \
           ./run/cifs_archive/archive-clips.sh \
           ./run/rclone_archive/archive-clips.sh \
           ./teslausb-www/html/cgi-bin/_validate_path.sh \
           ./teslausb-www/html/cgi-bin/ble_action.sh

# --- Pass 1B: warning-and-up ------------------------------------------------
# Files that have been swept clean of real bugs (Phase 1.1.5) but still
# carry upstream SC2004/SC2086/SC2129/SC2162/SC2317 style+info noise. We
# enforce no new warnings or errors creep in; style cleanup is incremental.
shellcheck --severity=warning --exclude=SC1091 \
           ./setup/pi/configure-ap.sh \
           ./setup/pi/configure.sh \
           ./setup/pi/create-backingfiles-partition.sh \
           ./setup/pi/create-backingfiles.sh \
           ./setup/pi/envsetup.sh \
           ./tools/merge_config.sh \
           ./tests/create-backingfiles-partition-test.sh \
           ./tests/create-backingfiles-test.sh \
           ./run/make_snapshot.sh \
           ./teslausb-www/html/cgi-bin/ls.sh \
           ./teslausb-www/html/cgi-bin/cp.sh \
           ./teslausb-www/html/cgi-bin/mv.sh \
           ./teslausb-www/html/cgi-bin/rm.sh \
           ./teslausb-www/html/cgi-bin/mkdir.sh \
           ./teslausb-www/html/cgi-bin/upload.sh \
           ./teslausb-www/html/cgi-bin/download.sh \
           ./teslausb-www/html/cgi-bin/downloadzip.sh

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
  # Pass 2: error-only safety net for files not yet promoted to 1A/1B.
  # Catches SC1xxx parse errors and high-confidence SC2xxx errors; ignores
  # all warnings/style/info. Files migrate into 1B once their warnings are
  # cleaned, then into 1A once their style nits are cleaned.
  shellcheck --severity=error --exclude=SC1091 "${to_check[@]}"
fi
