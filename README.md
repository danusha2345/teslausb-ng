# teslausb-ng

[![Boosty](https://img.shields.io/badge/Boosty-Buy_me_a_coffee-FF7143?logo=boosty&logoColor=white&style=for-the-badge)](https://boosty.to/danusha/donate)

> **Community-maintained continuation of [marcone/teslausb](https://github.com/marcone/teslausb)** — the upstream repository has been inactive since January 2023. This fork aims to revive the project by fixing long-standing issues (BLE pairing, OneDrive sync, archive errors, audio skipping on Model Y) and modernizing the web UI. All original authors and the MIT license are preserved — see [LICENSE](LICENSE).

If `teslausb-ng` saves you time or makes your Tesla life better, consider supporting development via [Boosty](https://boosty.to/danusha/donate). Boosty accepts cards from anywhere in the world.

---

## 🧪 Testers Wanted — We Don't Have a Tesla

> **The maintainer of this fork does not own a Tesla and does not have a
> Raspberry Pi to test on.** Every change ships behind CI (ShellCheck,
> Playwright smoke, path-traversal unit tests), but the real archive loop,
> BLE pairing, USB-gadget enumeration, OneDrive sync, and Sentry recording
> can only be verified on actual hardware — by **you**.
>
> If you run this fork on a real Pi connected to a real Tesla, **please
> report what you see**, both good and bad:
>
> - ✅ **It works** → comment on the matching issue (or open a new one) with
>   your Pi model, Tesla model + firmware, archive backend, and confirm
>   the v1.0+ behavior. One short "works for me" comment from a real user
>   is worth a hundred green CI runs.
> - ❌ **It breaks** → open an issue with:
>     1. The teslausb-ng commit you're running (`git -C /root/bin log -1`
>        or the image filename).
>     2. Your hardware (`cat /sys/firmware/devicetree/base/model`).
>     3. Your Tesla model + current firmware version.
>     4. The archive backend (`rsync` / `rclone` / `cifs` / `nfs` / `none`).
>     5. The relevant slice of `journalctl -u teslausb` and
>        `/mutable/archiveloop.log`.
> - 🧪 **You're willing to be a recurring tester** → say so in the issue;
>   we'll ping you for pre-release smoke before tagging.
>
> Without a steady stream of hardware reports this fork will drift the
> same way upstream did. Help us not repeat that.
>
> **File issues at:** https://github.com/danusha2345/teslausb-ng/issues

---

## What's new in teslausb-ng vs upstream

| Area | upstream `marcone/teslausb` | this fork (`teslausb-ng`) |
|---|---|---|
| Last activity | January 2023 | active |
| BLE pairing on the prebuilt image | broken — missing `bluez`/`bluez-firmware` ([#958](https://github.com/marcone/teslausb/issues/958)) | works out of the box |
| Time sync | deprecated `sntp` ([#733](https://github.com/marcone/teslausb/issues/733)) | `chrony` |
| Sentry-mode BLE log noise | alarming "Failed to set Sentry Mode" ([#1029](https://github.com/marcone/teslausb/issues/1029)) | informative wording + [doc/Tesla_BLE.md](doc/Tesla_BLE.md) |
| rsync "broken pipe" recovery | bailout on exit 12/23/30 ([#942](https://github.com/marcone/teslausb/issues/942)) | exit 12/23/24/30 all retried |
| OneDrive sync via rclone | broken auth ([#948](https://github.com/marcone/teslausb/issues/948)) | bumped rclone install path + docs |
| Web UI `eval()` of CGI input | XSS / RCE risk | replaced with explicit parser |
| Web UI HTML injection | unescaped filenames in `innerHTML` | new `htmlEscape` helper, full sweep |
| CGI path-traversal | `cd $DOCUMENT_ROOT/${urlargs[0]}` unsafe | shared `_validate_path.sh` + 11 unit tests |
| Python deps | ad-hoc `pip install` | pinned `setup/pi/requirements.txt` |
| `tesla-control` binary | tracks "latest" | optional pin via `TESLA_BLE_BINARY_TAG` |
| systemd unit | bare `Restart=always` | `RestartSec=5s`, burst limits, journald routing — see [doc/Systemd.md](doc/Systemd.md) |
| Sync progress | silent | opt-in via `SEND_PROGRESS_NOTIFICATIONS=true` ([#759](https://github.com/marcone/teslausb/issues/759)) |
| Verbose archive output | none | opt-in `ARCHIVE_VERBOSE=true` ([#667](https://github.com/marcone/teslausb/issues/667)) |
| SavedClips minute filter | not available | cherry-picked PR [#1033](https://github.com/marcone/teslausb/pull/1033) |
| Upload throughput monitor | not available | cherry-picked PR [#1044](https://github.com/marcone/teslausb/pull/1044) |
| HTTP compression + preload toggle | not available | cherry-picked PR [#1046](https://github.com/marcone/teslausb/pull/1046) |
| Credentials at rest | plain text on SD card | optional `systemd-creds` encryption — see [doc/Credentials.md](doc/Credentials.md) |
| Reproducible image builds | manual | `tools/build-image.sh` + GitHub Actions matrix |
| CI coverage | ShellCheck on 12 files | ShellCheck (broader), shfmt, prettier, Playwright smoke, path-traversal tests |

See [the v1.0.0 release notes](https://github.com/danusha2345/teslausb-ng/releases/tag/v1.0.0) for the full changelog.

## Migrating from upstream `teslausb`

If you already run upstream `marcone/teslausb` and want to try this fork on
the same Pi:

```bash
# On the Pi, with the upstream install running:
curl -fsSL https://raw.githubusercontent.com/danusha2345/teslausb-ng/main-dev/tools/migrate-from-upstream.sh | sudo bash
```

The script snapshots `/mutable`, swaps `setup-teslausb` and `archiveloop`
in `/root/bin/` for the teslausb-ng versions, reloads the systemd unit,
and prints a rollback command in case something goes wrong. Your conf
file (`/root/teslausb_setup_variables.conf`) is left in place.

## Intro

Raspberry Pi and other [SBCs](## "Single Board Computers") can emulate a USB drive, so can act as a drive for your Tesla to write dashcam footage to. Because the SBC has full access to the emulated drive, it can:

- automatically copy the recordings to an archive server when you get home
- hold both dashcam recordings and music files
- automatically repair filesystem corruption produced by the Tesla's current failure to properly dismount the USB drives before cutting power to the USB ports
- serve up a web UI to view or download the recordings
- retain more than one hour of RecentClips (assuming large enough storage)

This video (not mine) has a nice overview of teslausb and how to install it:

[![teslausb intro and installation](http://img.youtube.com/vi/ETs6r1vKTO8/0.jpg)](http://www.youtube.com/watch?v=ETs6r1vKTO8 "teslausb intro and installation")

If you are interested in having more detailed information about how TeslaUsb works, have a look into the [wiki](https://github.com/marcone/teslausb/wiki).

## Prerequisites

### Assumptions

- You park in range of your wireless network.
- Your wireless network is configured with WPA2 PSK access.

### Hardware

Required:

- [A Raspberry Pi or other SBC that supports USB OTG](https://github.com/marcone/teslausb/wiki/Hardware).
- A Micro SD card, at least 64 GB in size, and an adapter (if necessary) to connect the card to your computer.
- Cable(s) to connect the SBC to the Tesla (USB A/Micro B cable for the Pi Zero, USB A/C cable for the Pi 4 and 5, other SBCs vary)

Optional:

- A case and/or cooler for the SBC. For the Raspberry Pi 4 I like the ["armor case"](https://www.amazon.com/s?k=Raspberry+Pi+4+Armor+Case) (available with or without fans), which appears to do a good job of protecting the Pi while keeping it cool.
- USB Splitter if you don't want to lose a front USB port. [The Onvian Splitter](https://www.amazon.com/gp/product/B01KX4TKH6) has been reported working by multiple people on reddit. Some SBCs require separate power and data connection, so may require a splitter or a USB hub to connect to the car.

## Installing

To install teslausb on a Raspberry Pi, it is recommended to use the [prebuilt image](https://github.com/marcone/teslausb/releases) and [one step setup instructions](doc/OneStepSetup.md). For other SBCs, start [here](https://github.com/marcone/teslausb/wiki/Installation)

## Contributing

You're welcome to contribute to this repo by submitting pull requests and creating issues.
For pull requests, please split complex changes into multiple pull requests when feasible, and follow the existing code style.

## Meta

This repo contains steps and scripts originally from [this thread on Reddit](https://www.reddit.com/r/teslamotors/comments/9m9gyk/build_a_smart_usb_drive_for_your_tesla_dash_cam/)

Many people in that thread suggested that the scripts be hosted on GitHub but the author didn't seem interested in making that happen, so GitHub user "cimryan" hosted the scripts on GitHub with the Reddit user's permission.

---

[![Boosty](https://img.shields.io/badge/Boosty-Buy_me_a_coffee-FF7143?logo=boosty&logoColor=white&style=for-the-badge)](https://boosty.to/danusha/donate)

Support `teslausb-ng` development via [Boosty](https://boosty.to/danusha/donate) — international cards accepted.
