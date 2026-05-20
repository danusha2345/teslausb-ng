#!/bin/bash
#
# Retry helper used by long-running runtime scripts.
#
# Sourced — not executed. The existing archiveloop has a fixed 1-second
# sleep / 10-attempt retry loop; this helper exposes exponential backoff
# with full jitter so flaky archive targets (CIFS that comes and goes,
# rclone OAuth refresh storms) don't hammer the upstream service.
#
# Usage:
#     . /root/bin/_retry.sh
#     retry_with_backoff <max_attempts> <base_seconds> -- <cmd> [args...]
#
# Behavior:
#   * Returns 0 on first successful invocation of <cmd>.
#   * On failure sleeps random(0, base * 2^attempt) seconds before retrying.
#   * After max_attempts unsuccessful tries, returns the last exit code.
#   * Caps sleep at 300 seconds so we never lose more than 5 minutes per try.

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "$0 must be sourced, not executed" >&2
  exit 1
fi

# retry_with_backoff <max_attempts> <base_seconds> -- <cmd> [args...]
retry_with_backoff() {
  local max_attempts="$1"
  local base="$2"
  shift 2

  # Optional `--` separator.
  if [[ "${1:-}" == "--" ]]; then
    shift
  fi

  if (( max_attempts < 1 )); then
    max_attempts=1
  fi

  local attempt=0
  local exit_code=0
  while (( attempt < max_attempts )); do
    if "$@"; then
      return 0
    fi
    exit_code=$?
    attempt=$((attempt + 1))
    if (( attempt >= max_attempts )); then
      break
    fi
    local window=$(( base * (1 << (attempt - 1)) ))
    if (( window > 300 )); then
      window=300
    fi
    # Random in [0, window]. /dev/urandom is more portable than $RANDOM
    # for ranges over 32767.
    local jitter=0
    if (( window > 0 )); then
      jitter=$(( $(od -An -N4 -tu4 < /dev/urandom) % (window + 1) ))
    fi
    sleep "$jitter"
  done

  return "$exit_code"
}
