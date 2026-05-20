# Tesla BLE — Notes for teslausb-ng

This document explains the Tesla BLE integration used to keep the car awake while
teslausb is archiving, and how to read its log messages.

## What it does

When `TESLA_BLE_VIN` is set in `teslausb_setup_variables.conf`, teslausb uses the
[`tesla-control`](https://github.com/MikeBishop/tesla-vehicle-command-arm-binaries)
binary over Bluetooth Low Energy to toggle Sentry Mode at the start and end of an
archive cycle:

- `run/awake_start` — calls `tesla-control … sentry-mode on`
- `run/awake_stop`  — calls `tesla-control … sentry-mode off`

BLE is convenient because it does not require an internet connection on the car
side, and there are no Tesla API rate limits.

## Expected log messages

You may see any of the following in `/mutable/archiveloop.log`:

```
Tesla BLE: Command sent to enable Sentry Mode.
Tesla BLE: Command sent to disable Sentry Mode.
Tesla BLE: Could not enable Sentry Mode (car may be asleep, BLE out of range, or pairing invalid). This is often transient.
Tesla BLE: Could not disable Sentry Mode (car may be asleep, BLE out of range, or pairing invalid). This is often transient.
Skip sending command to enable Sentry Mode.
```

`Skip sending command…` means teslausb determined Sentry Mode was already on and
did not need to toggle it. It is **informational**, not an error.

`Could not enable/disable Sentry Mode…` means the BLE call failed. The common
causes are:

1. **Car is fully asleep.** BLE wakeup is best-effort. If the 12 V system is
   in deep sleep, `tesla-control` returns an error.
2. **BLE range / antenna.** A Raspberry Pi in the glove box may be at the edge
   of the BLE range to the car's BCM (body controller). Try a Pi 4 / Pi 5 (which
   have a stronger BLE radio than Pi Zero W) or relocate the Pi.
3. **Pairing not valid.** If you replaced the car's key card pool, the cloud key
   used by teslausb may need re-pairing. See `Setup-BLE.md` for the pairing
   procedure.
4. **Tesla firmware updated.** Tesla occasionally rotates protocol details; if
   `tesla-control` itself fails on multiple consecutive cycles, check the
   [`MikeBishop/tesla-vehicle-command-arm-binaries`](https://github.com/MikeBishop/tesla-vehicle-command-arm-binaries)
   releases for a fix.

## Why the wording was softened (issue #1029)

Earlier versions of teslausb logged `Tesla BLE: Failed to set Sentry Mode.` for
the failure case. Multiple users reported this as a bug (`marcone/teslausb#1029`)
because the message reads like a teslausb defect, but in practice the failure is
almost always a transient external condition (sleeping car, BLE range, pairing).
teslausb-ng now logs `Could not … (car may be asleep, BLE out of range, or
pairing invalid). This is often transient.` to make the operator's expected
response clear: usually no action is needed, just verify that archiving still
completes.

If the message appears on **every** archive cycle for several days in a row,
that is worth investigating — see "common causes" above.

## Debugging

You can run the BLE command interactively on the Pi:

```bash
sudo /root/bin/tesla-control \
    -ble \
    -key-file /root/.ble/key_private.pem \
    -vin "${TESLA_BLE_VIN}" \
    body-controller-state
```

If `body-controller-state` succeeds but `sentry-mode on` fails, the car is
reachable but in a state that refuses the command (often: asleep, in service
mode, or already in Sentry).
