# teslausb-ng — Roadmap

This is the forward-looking plan after [v1.0.0](https://github.com/danusha2345/teslausb-ng/releases/tag/v1.0.0). Each milestone is sized so a single engineer can land it in one to three weekends. Use it as a contract between maintainer and contributors — don't read it as a deadline.

Conventions:
- **(S)** small, **(M)** medium, **(L)** large, **(XL)** multi-week.
- Issue numbers without a `#ng-` prefix refer to upstream `marcone/teslausb`.
- All work continues on `main-dev`; tagged releases are cut from there.

---

## v1.1 — Finish what v1.0 started (4–6 weeks)

Theme: close every loose end the v1.0 plan explicitly deferred. After this release the fork stops being "v1.0 plus stubs" and starts being a complete product.

### 1.1.1 Drop the custom rsync (M)
- **Why deferred in v1.0**: `setup/pi/configure.sh` downloads a custom `marcone/rsync` build for armv6/armv7. We didn't know if it had Pi-specific patches.
- **Action**: diff `marcone/rsync` HEAD against the Bookworm-shipped rsync 3.2.7. If the delta is zero or purely cosmetic, delete the download path. If it's a real patch, upstream it or vendor it with a comment.
- **Files**: `setup/pi/configure.sh` lines 82–85, `setup/pi/install-rsync.sh` if it exists.
- **Verification**: archive a 5 GB test corpus over rsync, then again over rsync+CIFS, with the stock binary. Compare `--stats` to a baseline run.

### 1.1.2 ES-module split of `index.html` (L, in progress — 4 slices shipped, more to go)
- **Why deferred in v1.0**: `index.html` was 3108 lines; the v1.0 Playwright smoke gives the safety net.
- **Progress** (3108 → 2801, ≈10% extracted):
  - **Slice 1** (v1.1.0): `js/utils.js` + `js/cgi.js` — pure utilities (`localStorageGet/Set`, `log`, `download`, `cachebustingurl`, `isElementVisible`) and CGI helpers (`readyState`, `starttailing`, `readfile`, `callcgi`).
  - **Slice 2** (v1.2.0): `js/recordings.js` — layout / playback / debug helpers (`setLayout`, `cycleLayout`, `skipBack`, `startPlaying`, `skipForward`, `hideRecordingParent`, `showDebugInfo`, `showcontrols`) plus `currentLayout` state.
  - **Slice 3** (unreleased on `main-dev`): `js/formatters.js` — pure formatter helpers (`byteRate`, `bitRate`, `uptimeString`, `spaceString`, `timeString`, `dateFromSeconds`, `dayNameFromDateString`) plus the four `Intl.DateTimeFormat` constants.
- **Remaining**: `js/wifi.js` (status WIFI + IP rendering), `js/status.js` (status polling + uptime + drive usage), `js/throughput.js` (Speedometer + speed-test UI), `js/settings.js`, BLE pairing UI, reboot UI.
- **Files**: `teslausb-www/html/index.html`, new files under `teslausb-www/html/js/`. Loaded as classic `<script>` (not type=module) so existing HTML `onclick` attributes keep resolving via global scope.
- **Verification**: `tests/webui/smoke.spec.mjs` already exercises `FileBrowser.htmlEscape` against the harness; extend to import each module directly and assert exported functions exist when more slices land. Full-page load still passes the no-errors check.

### 1.1.3 CIFS credentials share (M)
- **Why deferred in v1.0**: `doc/Credentials.md` documents the approach but only the systemd-creds path is implemented.
- **Action**: write `setup/pi/configure-creds.sh` that installs `cifs-utils`, creates `var-teslausb\x2dcreds.mount` systemd unit, and orders `teslausb.service` `After=` / `Requires=` it.
- **Files**: new `setup/pi/configure-creds.sh`, edits to `setup/pi/configure.sh` to call it when `TESLAUSB_CREDS_SHARE` is set.
- **Verification**: smoke test on a NAS share; confirm archive cycle waits for mount rather than racing past it.

### 1.1.4 Cherry-pick PR #1035 — cloud-source viewing (L)
- **Action**: merge upstream PR #1035 (GCS/S3 sources for the local viewer). This was held in v1.0 because the plan called for backend abstraction first. The abstraction is now light enough (each `*_archive` module is self-contained) to merge as-is and add the viewer hook.
- **Files**: viewer paths under `teslausb-www/`, new `setup/pi/configure-cloud-viewer.sh`.
- **Verification**: download a known clip from a sandbox GCS bucket, then S3.

### 1.1.6 ~~Reproducible pi-gen image build in CI~~ (DONE in v1.1.0)

Originally blocked because we read `depends` as a flat package list and
tried to satisfy the literal entry `qemu-user-binfmt` (which conflicts
with `qemu-user-static` on Ubuntu Noble). The actual format is
`tool:package` — `qemu-arm:qemu-user-binfmt` means pi-gen runs
`hash qemu-arm` and only mentions `qemu-user-binfmt` as a hint when
the tool is missing. The binary `/usr/bin/qemu-arm` lives in the
`qemu-user` package, which does NOT conflict with `qemu-user-static`.
Installing both makes pi-gen's tool check pass and gives debootstrap
the static binary it needs to bind into the chroot.

### 1.1.5 Promote files to strict ShellCheck (M)
- **Action**: fix the pre-existing warnings in the broader script tree (SC2155 declare-and-assign, SC2034 unused vars, SC2124 array-to-string, SC2046 word-split, SC2038 xargs without `-print0`) and promote each cleaned file from `check.sh` pass 2 into the strict pass 1 list.
- **Files**: `setup/pi/configure-ap.sh`, `setup/pi/configure.sh`, `setup/pi/envsetup.sh`, `setup/pi/create-backingfiles*.sh`, `tools/merge_config.sh`, `tests/*.sh`, `run/make_snapshot.sh`, plus the CGI scripts.
- **Verification**: `check.sh` runs at `--severity=warning` on the whole tree without failure.

---

## v1.2 — Tesla integration depth (6–8 weeks)

Theme: stop apologizing for what BLE/Tesla can't do and start using what it actually offers.

### 1.2.1 BLE wake retry with backoff (S)
- **Action**: replace the fixed `retry()` loop in `run/awake_start` and `run/awake_stop` with the `retry_with_backoff` helper from `run/_retry.sh`. Tune base=10s, max=5 attempts so a sleeping car gets ~5 min of patient retries instead of 10 hammered ones.
- **Files**: `run/awake_start`, `run/awake_stop`.
- **Verification**: simulate a sleeping car (drop BLE), confirm 5 attempts spread over ~5 minutes with jitter, then graceful give-up.

### 1.2.2 Multi-vehicle support (L)
- **Action**: replace the single `TESLA_BLE_VIN` variable with `TESLA_BLE_VINS=("VIN_A" "VIN_B")`. Iterate all known cars in `awake_start`/`awake_stop`; tag archived clips by VIN. Requires a `select_vehicle()` helper that probes which car is in range.
- **Files**: `run/envsetup.sh`, `run/awake_start`, `run/awake_stop`, conf sample.
- **Verification**: pair against two cars; confirm Sentry toggles on whichever is currently in range.

### 1.2.3 AI-powered clip search (XL)
- **Action**: integrate with [`ssrajadh/sentrysearch`](https://github.com/ssrajadh/sentrysearch) so a user can ask "show me clips with a red truck" from the web UI. Run the local Qwen model by default to keep it free; fall back to Gemini for users who opt in. Add a search box to the web UI.
- **Files**: new `setup/pi/configure-clip-search.sh`, `teslausb-www/html/cgi-bin/search.sh`, `teslausb-www/html/js/search.js`.
- **Verification**: index a 50-clip Sentry archive, query "person near vehicle", confirm correct clips ranked top-5.

### 1.2.4 Better Tesla key rotation (M)
- **Action**: detect when Tesla rotates the protocol and `tesla-control` starts failing every call. Surface a single clear "Re-pair your BLE key" notification via `send-push-message` instead of dozens of "Could not enable Sentry Mode" log lines.
- **Files**: `run/awake_start`, `run/awake_stop`, new `run/_ble_health.sh`.
- **Verification**: simulate a permanent BLE auth failure; confirm one notification and the watchdog backs off.

### 1.2.5 Pi 5 PMIC monitoring polish (S)
- **Action**: upstream merged Pi 5 PMIC readouts (#1041) into the web UI; extend it with `under-voltage` alerts via `send-push-message`.
- **Files**: `teslausb-www/html/index.html`, `run/temperature_monitor`.
- **Verification**: simulate `vcgencmd get_throttled` returning a non-zero value; confirm notification.

---

## v1.3 — UX & deployment (4–6 weeks)

Theme: meet users where they live (phones, Home Assistant, non-English locales).

### 1.3.1 Home Assistant Add-on (M)
- **Action**: package teslausb-ng as a HA Supervisor add-on. The archive loop and web UI run as a HA-managed container; the Pi USB gadget side stays bare-metal.
- **Files**: new `ha-addon/` directory with `config.yaml`, `Dockerfile`, `apparmor.txt`.
- **Verification**: install on a HA OS 13 host; smoke-test the web UI through HA's ingress.

### 1.3.2 Web Push notifications (M)
- **Action**: add a Service Worker to the web UI and a new `send-push-message` backend (`web-push`). Users get OS-level notifications without needing Pushover / Telegram setup.
- **Files**: `teslausb-www/html/service-worker.js`, `run/send-push-message`, new `setup/pi/configure-webpush.sh` for VAPID-key generation.
- **Verification**: trigger an archive on a phone with the PWA installed; confirm the notification arrives within 2s.

### 1.3.3 Mobile-responsive UI overhaul (L)
- **Action**: rebuild the filebrowser layout so portrait phones get a usable view of Sentry events. Use CSS Grid + dialog `<details>` instead of the desktop split-pane.
- **Files**: `teslausb-www/html/filebrowser.css`, `index.html`.
- **Verification**: Playwright smoke matrix at 360×800 (Pixel) and 390×844 (iPhone) viewports.

### 1.3.4 Multi-language UI (M)
- **Action**: extract user-visible strings into `teslausb-www/html/i18n/<lang>.json`; load by `Accept-Language` or explicit toggle. Ship `en`, `ru`, `de`, `fr` to start.
- **Files**: `teslausb-www/html/i18n/`, JS loader in `js/i18n.js`.
- **Verification**: Playwright opens with `?lang=ru`, asserts a known string is translated.

### 1.3.5 Quick-actions panel via BLE (S)
- **Action**: add three buttons to the web UI — "Lock", "Honk", "Sentry on/off" — that call `tesla-control` via CGI. Available only when `TESLA_BLE_VIN` is set.
- **Files**: new `teslausb-www/html/cgi-bin/ble_action.sh`, `js/quickactions.js`.
- **Verification**: lock/honk on the actual car from the UI.

---

## v2.0 — Architecture (XL, 3+ months)

Theme: surgical rewrites where bash hurts, not "rewrite it all in Rust".

### 2.0.1 Hot-path archive loop in Rust (XL)
- **Action**: the inner loop that watches `/mnt/cam`, validates clip integrity, and queues files for transfer is the bash code that fails most often (race conditions, partial reads). Port just that loop to a small Rust binary that exposes the same interface to the surrounding bash. Keep notifications, archive backends, and setup in bash.
- **Files**: new `crates/teslausb-archiver/`, `run/archiveloop` calls the binary instead of doing the work inline.
- **Verification**: 30-day soak test with simulated mid-clip USB ejection; zero corrupted clips in the archive vs current ~1-2/week.

### 2.0.2 MCP server for AI agents (M)
- **Action**: expose archive metadata and clip search via an MCP server so Claude / Cursor can answer "did anything notable happen yesterday?" against the archive. Builds on v1.2.3 clip search.
- **Files**: new `crates/teslausb-mcp/` or `mcp/server.py`.
- **Verification**: connect from Claude Desktop; query for events; verify results match `find /mnt/archive`.

### 2.0.3 Containerized runtime for SBCs without OTG (L)
- **Action**: for users with an x86 home server, decouple the USB-gadget half (must run on the Pi) from the archive/web half (can run in Docker on the server). Use a small gRPC bridge.
- **Files**: new `crates/teslausb-gadget/` (Pi side), Compose file (server side).
- **Verification**: archive to a server-side Docker volume from a Pi Zero that only handles USB.

### 2.0.4 Plugin system (L)
- **Action**: lock down a stable contract between `archiveloop` and the `*_archive` modules so community archive backends (Backblaze B2, Wasabi, Hetzner Storage Box) can ship as one-file plugins.
- **Files**: new `doc/Archive_Plugin_API.md`, refactored `run/archiveloop`.
- **Verification**: a `b2_archive/` module ships against the API and round-trips clips.

---

## Operations & community (ongoing)

### Sustainability
- **HTTPS by default** — generate a self-signed cert on first boot, auto-renew via certbot for users with a public hostname. (M)
- **2FA for the web UI** — TOTP via a CGI helper. (S)
- **Audit log** — every CGI mutation records who/what/when to `/mutable/audit.log`. (S)

### Outreach
- **Russian localization first** — landing page + README in Russian since Boosty is the funding rail. (S)
- **Wiki migration to MkDocs** — replace the GitHub Wiki with a versioned `docs/` site so contributors can PR documentation. (M)
- **Discord and/or Telegram channel** — for migration help and bug triage. (S)
- **CONTRIBUTING.md and CODE_OF_CONDUCT.md** — standard adoption hygiene. (S)
- **Reddit post in `r/teslamotors`** once v1.1 ships with the OneDrive fix and the prebuilt image — the two most googled symptoms. (S)

### Telemetry & analytics
- Once `_telemetry.sh` has been live for a release, set up a minimal endpoint that aggregates pings (count by Pi model, by archive backend) into a public dashboard. No personal data, just install counts. (M)

---

## Issue triage (deferred from v1.0)

| Issue | Status | Target |
|---|---|---|
| #948 OneDrive sync | rclone bumped + docs in v1.0; full deferred fix here | v1.1.1 (rsync audit may surface a deeper rclone change) |
| #887 Audio skipping Model Y | Wontfix — Tesla firmware | n/a, document in FAQ |
| #909 Not recording continuously | Mostly fixed by v1.0 systemd hardening; reopen if reports continue | monitor |
| #825 Sentry & Saved has just 2 files | Needs reproducer | v1.1, ask the reporter for a /mutable snapshot |
| #654 Stops mounting after weeks | Mostly fixed by v1.0 systemd `Restart=`; reopen if reports continue | monitor |
| #460 Network-share creds | Documented in v1.0; CIFS implementation in v1.1.3 | v1.1.3 |
| #759 Sync progress | Shipped in v1.0 (`SEND_PROGRESS_NOTIFICATIONS=true`) | done |
| #667 Verbose output | Shipped in v1.0 (`ARCHIVE_VERBOSE=true`) | done |
| #733 NTP | Shipped in v1.0 (`chrony`) | done |
| #942 Broken pipe | Shipped in v1.0 (exit-code allowlist) | done |
| #958 BLE pairing | Shipped in v1.0 (bluez in image) | done |
| #1029 Sentry BLE log noise | Shipped in v1.0 (wording + doc) | done |

---

## Hotspots from the GitNexus index

The codebase is indexed by GitNexus (139 files, 658 nodes, 1,296 edges, 17
clusters, 39 execution flows). A few findings from `gitnexus query` that
shape the roadmap:

- **`run/tesla_api.py:_get_log_timestamp` is the highest-fanout helper** —
  it participates in 5+ execution flows (`streaming_ping`, `toggle_sentry_mode`,
  `get_service_data`, `main`, etc.). It's a low-risk candidate to migrate
  from "print to stderr" to the new `run/_log.sh` helpers, with outsized
  log-consistency payoff. (Targeted in v1.2.4 BLE health work.)
- **The Html cluster carries most of the web UI surface** — 86 symbols
  across `filebrowser.js` and `index.html`. The Teslausb-www cluster is
  only 9 symbols and is largely nginx/CGI scaffolding. The v1.1.2 ES-module
  split should keep the Html cluster cohesive instead of fragmenting it.
- **CGI endpoints are correctly captured as separate definitions** — the
  path-traversal patches in v1.0 covered all 8 mutating endpoints
  (`ls/cp/mv/rm/mkdir/upload/download/downloadzip`). When v1.3.5 adds a
  `ble_action.sh` endpoint, run `gitnexus_impact` on `_CGI_BASE` first to
  confirm the new file sources the validator.
- **`run/tesla_api.py:main` (proc_33_main)** is the only deep cross-community
  flow in the Python layer. The v2.0.1 Rust port should _not_ touch this —
  it's a CLI entry point used by setup scripts, not part of the hot archive
  loop. Keep it in Python.
- **The Run cluster has 41 symbols across 2 files** — concentrated in
  `tesla_api.py` and `filter_savedclips_window.py`. When migrating to
  pinned deps (v1.0 shipped `requirements.txt`), watch this cluster for
  import breakage on `teslapy` version bumps.

To replicate this analysis locally:

```bash
npx gitnexus analyze .           # 4 seconds on this repo
# Then via MCP tools:
gitnexus_query  query="archive loop main execution flow"  repo=teslausb-ng
gitnexus_context name="_get_log_timestamp"               repo=teslausb-ng
gitnexus_impact  target="_validate_path.sh"              repo=teslausb-ng
```

## How to contribute

Pick anything above marked **(S)** or **(M)** and open a PR against `main-dev`. Mention the section number in the PR title (e.g. `v1.1.3: CIFS creds share`). For **(L)** / **(XL)** items, open an issue first to align on scope.

Before any non-trivial code change, run `gitnexus_impact` on the symbol
you're touching — it shortcuts "what calls this?" investigation and
flags HIGH/CRITICAL blast-radius changes before review.
