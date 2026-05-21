# Changelog

All notable changes to teslausb-ng vs upstream `marcone/teslausb` are
recorded here. Format follows [Keep a Changelog](https://keepachangelog.com/);
versions follow SemVer.

## Unreleased

### Refactored

- **Third slice of the `index.html` ES-module split** (v1.1.2):
  `js/formatters.js` pulls out the pure formatter helpers — `byteRate`,
  `bitRate`, `uptimeString`, `spaceString`, `timeString`,
  `dateFromSeconds`, `dayNameFromDateString` — and the four
  `Intl.DateTimeFormat` constants. All pure, no DOM, no XHR.
  Inline `<script>` shrinks 2868 → 2801 lines. Cumulative since the
  fork: 3108 → 2801 lines extracted (-307, ≈10% of the inline block).

## v1.2.0 — 2026-05-21

Visible-feature release on top of v1.1.0. The prebuilt-image pipeline
that started working on v1.1.0 is still in place; this tag's image is
attached automatically.

### Added

- **Web Push notifications** (v1.3.2): the web UI can subscribe a
  browser as a `send-push-message` recipient. No Pushover / Telegram /
  Gotify account needed; the Pi signs VAPID-encrypted pushes via
  `pywebpush`. Opt-in with `WEBPUSH_ENABLED=true` in the conf file.
  Service Workers require a secure context, so see `doc/WebPush.md`
  for the HTTPS-setup options (reverse proxy with self-signed cert,
  Tailscale, or `https://localhost`).
- **CONTRIBUTING.md** and **CODE_OF_CONDUCT.md** spell out how to
  send patches, the CI gates a PR has to clear, what we won't promise
  (no stable internal API, no Buster/Bullseye support, no long-term
  security backports), and the tone we expect.
- **Project tool policy in `CLAUDE.md`** for AI-assisted editors:
  GitNexus first, Serena only for the small Python surface, skip
  graphify. Includes a hotspot cheat sheet and reindex policy
  (`--skip-agents-md` required).

### Refactored

- **Second slice of the `index.html` ES-module split** (v1.1.2):
  `js/recordings.js` pulls out `setLayout`, `cycleLayout`,
  `hideRecordingParent`, `showDebugInfo`, `showcontrols`, the three
  player skip/play functions, and the `currentLayout` state. The
  inline `<script>` block shrinks from 2978 → 2868 lines; the 16
  HTML `onclick` references and two immediate-call sites continue to
  resolve through global scope. utils.js + cgi.js + recordings.js
  cumulatively pull about 240 lines out of `index.html`.

### Docs

- `README.md` "Installing" gained a six-step Quick Start that
  references our own `image_*-teslausb.zip` asset (not upstream's
  inactive releases page) and includes the migration one-liner.
- `doc/OneStepSetup.md` was updated from "Raspbian Buster Lite" to
  Raspberry Pi OS Bookworm and now points at danusha2345/teslausb-ng
  in all three of its outbound links.

### Notes

- Issue templates now sit at `.github/ISSUE_TEMPLATE/` —
  `bug_report.yml`, `works_for_me.yml`, and `config.yml`. The
  works-for-me template includes an opt-in checkbox to be pinged
  before pre-release smoke tests.
- All CI workflows green at v1.2.0 cut: ShellCheck, Lint & Format,
  Build Image (~47 min on tag pushes, attaches the .img.xz to the
  release).

[v1.2.0]: https://github.com/danusha2345/teslausb-ng/releases/tag/v1.2.0

## v1.1.0 — 2026-05-20

Quality release after `v1.0.0`. Several Tesla-side reliability problems
addressed; most v1.0 doc stubs are now real implementations. Awaiting
real-hardware verification — see the README banner.

### Fixed (issues from upstream)

- **#460** — Store credentials on a network share: real
  `setup/pi/configure-creds.sh` lands, with a systemd CIFS mount unit
  (`nofail`, 30s timeout) and a service override that symlinks the
  decrypted conf into the path archiveloop already reads.

### Added

- **PMIC under-voltage + throttling monitor** (v1.2.5): `run/pmic_monitor`
  polls `vcgencmd get_throttled`, edge-triggers one notification per
  state change (under-voltage, ARM cap, throttled, soft-temp).
  `PMIC_MONITOR=true` opts in.
- **BLE health watchdog** (v1.2.4): `run/_ble_health.sh` tracks
  consecutive `tesla-control` failures. After
  `BLE_HEALTH_FAILURE_THRESHOLD=10` (default) consecutive failures,
  sends one "Re-pair your BLE key" notification, then suppresses
  until a success. On recovery, one "link recovered" message.
- **BLE retry with exponential backoff** (v1.2.1): Sentry-mode
  toggles use `retry_with_backoff 3 10` from `run/_retry.sh`.
- **Quick-actions panel** (v1.3.5): six-button strip in the web UI
  (Lock / Unlock / Honk / Sentry on/off / Wake) via a new
  `cgi-bin/ble_action.sh` endpoint with the `_validate_path` /
  `_retry` / `_ble_health` helpers wired in.
- **Prominent "testers wanted" banner** in README + revised
  `.github/ISSUE_TEMPLATE/{bug_report,works_for_me,config}.yml`
  asking for commit hash, Pi model, Tesla firmware, archive
  backend, and journalctl slice.
- **ROADMAP.md** documents v1.1 → v2.0 milestones with sized
  work items and per-section verification plans.
- **GitNexus index** lands as a committed artifact (`.claude/skills/`,
  `AGENTS.md`, `CLAUDE.md` — 719 nodes / 1360 edges / 40 flows).

### Changed

- **Dropped marcone/rsync 30 MB vendored binary** (v1.1.1).
  `install_prebuilt_rsync` is deleted; stock Bookworm rsync 3.2.7
  supersedes the prebuilt 3.2.3. `00-packages` gains an explicit
  `rsync` entry. The marcone/rsync release notes confirm both
  builds were plain compilations, no patches.
- **ShellCheck strict scope expanded** from 12 to 30+ files
  (v1.1.5). Eleven concrete fixes across nine files
  (SC2155 / SC2124 / SC2046 / SC2034 / SC2038). Three-pass
  `check.sh`: 1A strict / 1B warning / 2 error-only.

### CI

- `.github/workflows/build-image.yml` now successfully builds the
  pi-gen image on tag push. After six wrong turns we finally read
  pi-gen's `depends` file correctly: the format is `tool:package`,
  so the entry `qemu-arm:qemu-user-binfmt` means pi-gen checks
  `hash qemu-arm` and only suggests `qemu-user-binfmt` as a hint
  when the tool is missing. The qemu-arm binary actually lives in
  the `qemu-user` package, which does NOT conflict with
  `qemu-user-static` on Ubuntu Noble. Installing both packages
  satisfies pi-gen's tool check and gives debootstrap the static
  binary it needs for the chroot. Tag pushes attach the resulting
  .img.xz to the matching GitHub Release via
  softprops/action-gh-release.

[v1.1.0]: https://github.com/danusha2345/teslausb-ng/releases/tag/v1.1.0

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
