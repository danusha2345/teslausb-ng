#!/bin/bash
#
# Unit tests for teslausb-www/html/cgi-bin/_validate_path.sh.
#
# Runs the validation helper against a set of attack payloads and verifies
# that it canonicalizes safe paths and rejects path-traversal attempts.
# Designed to run without bats-core or other extra dependencies — just bash.
#
# Usage:
#     bash tests/security/path-traversal-test.sh
#
# Exits 0 on success, 1 on any failed assertion.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$HERE/../.." && pwd)
HELPER="$REPO_ROOT/teslausb-www/html/cgi-bin/_validate_path.sh"

if [[ ! -f "$HELPER" ]]; then
  echo "FAIL: helper not found at $HELPER"
  exit 1
fi

# shellcheck source=/dev/null
. "$HELPER"

# Override _cgi_403 AFTER sourcing so the test sees our sentinel instead of
# the real HTTP 403 header dump. Use `exit 1` because resolve_under_root
# runs inside $(...) subshells and `return` would not stop it.
_cgi_403() {
  echo "__403__"
  exit 1
}

pass=0
fail=0

# assert_accept <root> <input> [<expected suffix>]
assert_accept() {
  local root="$1" input="$2" expect_suffix="${3:-}"
  local got
  got=$(resolve_under_root "$root" "$input" 2> /dev/null)
  if [[ "$got" == "__403__" || -z "$got" ]]; then
    echo "FAIL accept: root='$root' input='$input' got 403"
    fail=$((fail + 1))
    return
  fi
  if [[ -n "$expect_suffix" && "$got" != *"$expect_suffix" ]]; then
    echo "FAIL accept: root='$root' input='$input' expected suffix '$expect_suffix', got '$got'"
    fail=$((fail + 1))
    return
  fi
  pass=$((pass + 1))
}

assert_reject() {
  local root="$1" input="$2"
  local got
  got=$(resolve_under_root "$root" "$input" 2> /dev/null)
  if [[ "$got" == "__403__" ]]; then
    pass=$((pass + 1))
  else
    echo "FAIL reject: root='$root' input='$input' got '$got' (expected 403)"
    fail=$((fail + 1))
  fi
}

# Sandbox to use as DOCUMENT_ROOT.
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

mkdir -p "$ROOT/SavedClips/2024-01-01_12-34-56"
mkdir -p "$ROOT/RecentClips"
touch    "$ROOT/SavedClips/2024-01-01_12-34-56/front.mp4"

# --- accepts ----------------------------------------------------------------
assert_accept "$ROOT" ""                                 "$ROOT"
assert_accept "$ROOT" "."                                "$ROOT"
assert_accept "$ROOT" "SavedClips"                       "/SavedClips"
assert_accept "$ROOT" "SavedClips/2024-01-01_12-34-56"   "/2024-01-01_12-34-56"
assert_accept "$ROOT" "RecentClips/file with spaces.mp4" "/RecentClips/file with spaces.mp4"
# Leading slash is harmless: the helper prepends root and canonicalizes, so
# "/etc/passwd" becomes "<root>/etc/passwd" — still inside root.
assert_accept "$ROOT" "/etc/passwd"                      "$ROOT/etc/passwd"

# --- rejects (path traversal escapes root) ----------------------------------
assert_reject "$ROOT" "../etc/passwd"
assert_reject "$ROOT" "../../../etc/shadow"
assert_reject "$ROOT" "SavedClips/../../../../etc/passwd"
assert_reject "$ROOT" $'../etc\n200 OK'   # newline-injection / HTTP smuggling
assert_reject "$ROOT" $'foo\rbar'         # CR-injection (refused regardless of escape)

echo
echo "path-traversal tests: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
