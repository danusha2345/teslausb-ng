# Changelog

All notable changes to teslausb-ng vs upstream `marcone/teslausb` are
recorded here. Format follows [Keep a Changelog](https://keepachangelog.com/);
versions follow SemVer.

## Unreleased

### Added

- **Cloud-bucket viewer** (ROADMAP 1.1.4, cherry-pick of upstream
  [PR #1035](https://github.com/marcone/teslausb/pull/1035)): an optional
  `cloudviewer-api` Go service (+ Docker Compose + nginx) you run on a
  **local computer** to browse and play clips straight from a cloud archive
  (Google Cloud Storage or S3 / S3-compatible), via signed URLs with HTTP
  Range streaming. The web UI gains an additive **Local / Cloud** switch
  (`js/cloudsource.js`) that is revealed only when the page is served by that
  Docker stack with a configured cloud source — the Pi's own web UI is
  byte-for-byte unaffected (the switch stays hidden and `videolistUrl()` /
  `mediaSrc()` resolve to the exact same `cgi-bin/videolist.sh` and cachebusted
  `TeslaCam/` paths as before). The Go backend is brought in verbatim from the
  upstream PR (the maintainer can't run the Go toolchain locally) and is gated
  by a new `cloudviewer-api` CI job (`go vet` / `go build` / `go test`). New
  i18n keys `viewer.source*` (en/ru). See `doc/CloudViewerGCS.md`. _Cloud
  streaming itself awaits real-bucket verification; the local-viewer path is
  covered by the existing Playwright smoke._


- **`WIFI_POWER_SAVE_OFF` option** for client-interface link stability: the
  Pi's brcmfmac driver enables wifi power-save by default, which on a headless
  Pi can make the link flap or go sluggish — observed as archiving stalls and
  unresponsive SSH (issues #263, #654, and the "network going up and down" the
  #263 thread describes). `setup/pi/configure-wifi-powersave.sh` disables it
  the NetworkManager-native way (a `wifi.powersave = 2` drop-in, persistent
  across reboots/reconnects), with an `if-up.d` fallback for the legacy
  wpa_supplicant path. Opt-in; the access-point mode already disabled
  power-save for its interfaces. _Behavior change — awaiting hardware
  confirmation._

### Fixed (issues from upstream)

- **#728** — "rsync error: received SIGINT, SIGTERM, or SIGHUP (code 20)":
  on a fast link a full-speed transfer can saturate the connection badly
  enough that the `connectionmonitor` watchdog's reachability check times
  out, wrongly concludes the archive server is gone, and kills the transfer
  mid-cycle (the car is then allowed to sleep with archiving incomplete).
  New opt-in `ARCHIVE_BWLIMIT` passes `--bwlimit` to rsync for the cifs,
  rsync and nfs archive methods, leaving headroom for the watchdog ping —
  this is the remedy upstream recommended in the issue thread. Unset
  (default) keeps the previous unthrottled behavior, so nothing changes for
  users who aren't hitting the false-positive kill. rclone users add
  `--bwlimit` via `RCLONE_FLAGS` as before. The watchdog timing itself is
  left untouched (a behavior change there can't be verified without
  hardware). _Awaiting confirmation from an affected hardware tester._
- **#948** — "OneDrive sync is broken": the root cause is an out-of-date
  rclone (the OneDrive auth fix shipped in rclone 1.69.0). `setup-teslausb`
  now prints a clear WARNING, with the upgrade one-liner, when the installed
  rclone predates 1.69.0 instead of letting the user chase phantom
  "unauthenticated" errors. `doc/SetupRClone.md` gains a "Keeping rclone
  current" section covering the upgrade and the OneDrive config-option gotcha.
- **#263** — "Pi fails to respond to SSH when copying music from CIFS share":
  same root cause as #728 — a large music-library download saturates the
  wifi link to the point that SSH hangs (upstream attributed it to "slow
  wifi being saturated"). The `ARCHIVE_BWLIMIT` knob now also throttles the
  music sync in `copy-music.sh`, leaving headroom for SSH and the reachability
  watchdog. Opt-in; default behavior unchanged. For very large libraries a
  dedicated USB/SSD drive is still the better route, as the issue thread notes.

## v1.2.2 — 2026-05-23

Russian-UI coverage expands, the v1.1.2 module split gets test coverage,
and one more inline slice lands. No behavior changes for English users.

### Added

- **Expanded i18n coverage** (v1.3.4 follow-up): the en/ru string tables
  grow from 16 to 30 entries. Newly translatable UI: the Tools-tab
  buttons (refresh/download diagnostics, download logs, trigger sync),
  the settings dialog (title, both checkboxes, Cancel/OK), and four
  layout-dropdown items. `data-i18n` tags in `index.html` go from 15 to
  29. en/ru key parity verified. JS-managed button labels (speed-test,
  BLE-pair, reboot — text toggled at runtime) are intentionally left for
  a later pass to avoid half-translated toggle states.
- **Playwright unit tests for the extracted modules**: `modules.spec.mjs`
  (10 tests) locks in the v1.1.2 split — byteRate/bitRate thresholds,
  uptimeString/spaceString/timeString formatting, the scrubber
  parser round-trip, and global-export checks for utils.js + formatters.js.

### Refactored

- **Fifth slice of the `index.html` ES-module split** (v1.1.2):
  `js/settings.js` pulls out the settings-modal functions
  (`showsettings`, `closesettings`, `cancelsettings`,
  `confirmsettings`). `readconfig` / `initialize` stay inline (they're
  bootstrap glue coupled to FileBrowser, the tab DOM, and the
  status-poll functions). Also moved the `stringtoseconds` /
  `secondstostring` video-scrubber time parsers into
  `js/formatters.js`. Inline `<script>` is now 2660 lines.
  Cumulative since the fork: 3108 → 2660 (-448, ≈14%) across
  utils / cgi / formatters / throughput / recordings / settings.

[v1.2.2]: https://github.com/danusha2345/teslausb-ng/releases/tag/v1.2.2

## v1.2.1 — 2026-05-22

HTTPS support — the headline of this release — gives v1.2.0's Web Push the
secure context it needs. Plus two more ES-module slices off `index.html`.

### Added

- **HTTPS for the web UI** (`HTTPS_ENABLED=true`): `setup/pi/configure-https.sh`
  generates a self-signed cert (SANs for `teslausb.local` / `teslausb` /
  hostname, 10-year validity) and installs a 443 server block
  (`teslausb-ssl.nginx`) alongside the existing port-80 block — `http://`
  keeps working, `https://` is added. Mirrors the `auth_basic` setting from
  `configure-web.sh` so web auth covers both ports. This is the easiest way
  to give the Service Worker the secure context that v1.3.2 Web Push needs.
  See `doc/HTTPS.md` for the one-time cert-trust step. LAN-only — no ACME.

### Refactored

- **Third slice of the `index.html` ES-module split** (v1.1.2):
  `js/formatters.js` pulls out the pure formatter helpers — `byteRate`,
  `bitRate`, `uptimeString`, `spaceString`, `timeString`,
  `dateFromSeconds`, `dayNameFromDateString` — and the four
  `Intl.DateTimeFormat` constants. All pure, no DOM, no XHR.
- **Fourth slice of the `index.html` ES-module split** (v1.1.2):
  `js/throughput.js` pulls out the network speed-test UI — the
  `Speedometer` rolling-average class plus `showspeed`,
  `updatespeedspinner`, `startspeedtest`, `stopspeedtest` and their
  state. `setbuttonsdisabled` stays inline (shared with BLE-pairing
  and reboot flows).
  Inline `<script>` is now 2700 lines. Cumulative since the fork:
  3108 → 2700 (-408, ≈13% of the original inline block) across
  utils / cgi / formatters / throughput / recordings.

[v1.2.1]: https://github.com/danusha2345/teslausb-ng/releases/tag/v1.2.1

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
