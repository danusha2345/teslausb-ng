# Changelog

All notable changes to teslausb-ng vs upstream `marcone/teslausb` are
recorded here. Format follows [Keep a Changelog](https://keepachangelog.com/);
versions follow SemVer.

## v1.0.0 — 2026-05-20

First public release of the community continuation. Upstream `marcone/teslausb`
has been inactive since January 2023; this baseline collects every fix and
modernization landed since the fork.

### Fixed (issues from upstream)

- **#958** — BLE pairing on the prebuilt image: `bluez`, `bluez-firmware`,
  `libbluetooth3` now ship in the pi-gen package list, so `hcitool dev`
  returns a device out of the box.
- **#1029** — "Tesla BLE: Failed to set Sentry Mode" log noise: softened
  the message to explain the failure is usually transient (car asleep,
  out of BLE range, or pairing invalid). New `doc/Tesla_BLE.md` walks
  operators through diagnosis.
- **#733** — NTP "error resolving pool": replaced deprecated `sntp` with
  `chronyd -q` in 00-packages, archiveloop, and rc.local. chrony is
  systemd-native and present in Bookworm.
- **#942** — Archiving error "broken pipe": rsync exit codes 12 / 23 /
  30 (network glitches, partial transfer, timeout) are now treated as
  transient alongside the existing 24 (vanished source files). The next
  archive cycle retries cleanly instead of bailing out.

### Added

- **CI** — broader ShellCheck coverage (2-pass), shfmt and prettier
  advisory checks, Playwright smoke for the web UI, reproducible
  pi-gen image builds, path-traversal unit tests.
- **Web UI** — HTTP compression, optional preload toggle, upload
  throughput monitor, SavedClips minute-window filter (cherry-picks of
  upstream PRs #1046, #1044, #1033).
- **Runtime** — `run/_retry.sh` (exponential backoff with jitter),
  `run/_log.sh` (journald-friendly structured log helpers),
  `run/_progress_notifier.sh` (opt-in periodic "still archiving"
  notifications, resolving #759), `run/_telemetry.sh` (opt-in
  anonymous version ping for install-count signal).
- **Verbose mode** — `ARCHIVE_VERBOSE=true` adds `-v` to rsync/rclone
  and tees output to `/mutable/archive-verbose.log` (#667).
- **Sync progress notifications** — `SEND_PROGRESS_NOTIFICATIONS=true`
  with `PROGRESS_NOTIFY_INTERVAL_SECONDS=…` emits periodic pushes via
  the existing `send-push-message` backends (#759).
- **Dependency hygiene** — `setup/pi/requirements.txt` pins teslapy,
  requests, boto3, matrix-nio. `TESLA_BLE_BINARY_TAG` lets users pin
  the MikeBishop/tesla-vehicle-command-arm-binaries release.
- **Hardened systemd unit** — `RestartSec=5s`, `StartLimitBurst=20`,
  journald routing, accounting. Documented in `doc/Systemd.md`.
- **Credentials hardening** — `tools/install-creds-unit.sh` and
  `doc/Credentials.md` document `systemd-creds` at-rest encryption
  and a planned CIFS read-only share (#460).
- **Migration tooling** — `tools/migrate-from-upstream.sh` swaps an
  existing marcone/teslausb install over to teslausb-ng with a
  rollback path.

### Security

- **eval() removal** — `wifi_strength` (an `N/M` string from `iwconfig`)
  was being passed to `eval()` in `index.html`. Replaced with explicit
  split-and-divide parsing.
- **innerHTML XSS sweep** in `filebrowser.js`: new `htmlEscape` helper;
  drive labels, single-drive label, tree item labels and `data-fullpath`
  attributes, and the audio player title now all go through it.
- **Path-traversal hardening** in CGI: shared
  `teslausb-www/html/cgi-bin/_validate_path.sh` (resolve_under_root,
  validate_cgi_base, validate_cgi_operands) sourced from `ls`, `cp`,
  `mv`, `rm`, `mkdir`, `upload`, `download`, `downloadzip`.
  `tests/security/path-traversal-test.sh` exercises 11 attack payloads.

### Branding

- Rebranded as `teslausb-ng`. Original MIT license, copyright, and
  attribution preserved. Boosty support links at the top and bottom
  of the README — international cards accepted.

### Documentation

- `doc/Tesla_BLE.md` — Tesla BLE Sentry-mode behavior and diagnosis.
- `doc/Systemd.md` — service hardening and operating commands.
- `doc/Credentials.md` — at-rest encryption and credentials share.

[v1.0.0]: https://github.com/danusha2345/teslausb-ng/releases/tag/v1.0.0
