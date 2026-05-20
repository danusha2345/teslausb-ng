#!/bin/bash
# Path-traversal hardening for teslausb-ng CGI scripts.
#
# Most CGI scripts in this directory accept user-supplied paths via
# QUERY_STRING and use them as follows:
#
#   urlargs[0]    — base directory relative to DOCUMENT_ROOT (for cd)
#   urlargs[1..]  — file/dir operands relative to that base
#
# Without validation, a payload like urlargs[0]="../../etc" would let any
# browser-side request read or write outside the web root. This helper
# canonicalizes every resolved path and refuses anything that escapes
# DOCUMENT_ROOT.
#
# Usage in a CGI script (after parsing urlargs[]):
#
#     . "$(dirname "$0")/_validate_path.sh"
#     validate_cgi_base                  # sets $_CGI_BASE
#     validate_cgi_operands              # rejects ../-escapes in operands
#     cd "$_CGI_BASE"                    # safe: absolute, canonical path
#
# Scripts that don't cd (e.g. download.sh) can call resolve_under_root
# directly for each path they touch.

_cgi_403() {
  cat <<EOF
HTTP/1.0 403 Forbidden
Content-type: text/plain

403 Forbidden: path traversal attempt blocked.
EOF
  exit 0
}

# resolve_under_root <root> <relative_path>
# Echoes the canonicalized absolute path if it stays inside <root>.
# Calls _cgi_403 (and exits) otherwise.
resolve_under_root() {
  local root="$1"
  local relpath="${2:-}"

  # Refuse embedded newlines/CR — they confuse CGI header handling and
  # let an attacker inject HTTP responses through the path argument.
  case "$relpath" in
    *$'\n'*|*$'\r'*) _cgi_403 ;;
  esac

  local resolved
  resolved=$(realpath --canonicalize-missing -- "$root/$relpath" 2>/dev/null) || _cgi_403

  case "$resolved" in
    "$root"|"$root"/*) printf '%s\n' "$resolved" ;;
    *) _cgi_403 ;;
  esac
}

# validate_cgi_base
# Validates urlargs[0] (the cd target) against DOCUMENT_ROOT.
# Sets _CGI_BASE to the resolved absolute path.
validate_cgi_base() {
  : "${DOCUMENT_ROOT:?DOCUMENT_ROOT must be set by the web server}"
  _CGI_BASE=$(resolve_under_root "$DOCUMENT_ROOT" "${urlargs[0]:-}")
}

# validate_cgi_operands
# Verifies that every urlargs[1..] entry resolves inside _CGI_BASE.
# Must be called after validate_cgi_base.
validate_cgi_operands() {
  : "${_CGI_BASE:?validate_cgi_base must be called first}"
  local i
  for ((i = 1; i < ${#urlargs[@]}; i++)); do
    resolve_under_root "$_CGI_BASE" "${urlargs[i]}" > /dev/null
  done
}
