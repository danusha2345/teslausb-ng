# Web Push notifications (v1.3.2)

teslausb-ng can deliver archive-start / archive-finish / progress / PMIC /
BLE-health notifications directly to your browser, with no Pushover /
Telegram / Gotify account in the middle. The page registers a Service
Worker, subscribes through the browser's push service, and `run/send_webpush.py`
on the Pi posts to that endpoint over VAPID-signed Web Push.

## Browser requirements

- A modern Chrome, Edge, Firefox, or Safari (16.4+).
- **Secure context.** Service Workers refuse to load over plain `http://`
  unless the hostname is `localhost` or `127.0.0.1`. Hitting your Pi at
  `http://teslausb.local/` will NOT work — the panel stays hidden.

For HTTPS you have three practical options:

| Approach | Effort | Notes |
|----------|--------|-------|
| Run a reverse proxy (caddy / nginx) in front of the Pi with a self-signed cert | Medium | Have to trust the cert in your browser. Works on every device. |
| Tailscale / WireGuard with HTTPS termination at the gateway | Medium | Single-user setups; uses your VPN's TLS. |
| Access via local IP and accept the security warning | Low | Some browsers (Chrome) silently refuse SW even after accepting; Firefox is more permissive. |

A built-in self-signed-cert option is on the [ROADMAP](../ROADMAP.md) under
Operations & community → "HTTPS by default".

## Enabling on the Pi

Set in `/root/teslausb_setup_variables.conf` (or in `boot/firmware/teslausb_setup_variables.conf`
on a fresh image):

```sh
WEBPUSH_ENABLED=true
# Optional. Defaults to mailto:teslausb@local.
# Push providers use this in their abuse-contact path; using a real address
# is good citizenship but not required.
# VAPID_CONTACT="mailto:you@example.com"
```

Then reboot the Pi (or run `sudo /tmp/configure-webpush.sh` if the file is
already on disk). The script:

1. Generates a P-256 VAPID keypair at
   `/root/.config/teslausb-webpush/{vapid_private,vapid_public}.pem`.
2. Installs `pywebpush` + `cryptography` via the pinned `requirements.txt`.
3. Drops the browser-facing public key at `/var/www/html/vapid_public_key.txt`.
4. Creates the subscriptions directory at `/mutable/webpush_subscriptions/`.

The keypair is generated once and kept across reboots. Re-running the
script reuses the existing keys.

## Subscribing from the browser

1. Open the teslausb-ng UI from a secure context (see above).
2. Scroll to the bottom of the page; click the **Enable browser
   notifications** button.
3. The browser will ask for permission. Allow it. The button flips to
   **Disable browser notifications**, and a `✓` shows up beside it.
4. The Pi now has your subscription. Every notification that the
   existing `send-push-message` would have sent through other backends
   also fires here.

Click again to unsubscribe locally. The next push attempt for that
endpoint will return HTTP 410 and the Pi will purge the stale
subscription automatically.

## What gets pushed

Anything that calls `/root/bin/send-push-message` — that includes:

- Archive start / finish (with file counts and duration)
- Sync-progress lines (every `PROGRESS_NOTIFY_INTERVAL_SECONDS` if
  `SEND_PROGRESS_NOTIFICATIONS=true`)
- PMIC under-voltage / throttling alerts (if `PMIC_MONITOR=true`)
- BLE health "re-pair your key" warnings (after 10 consecutive
  failures by default)

## Why the panel is hidden in my browser

`js/webpush.js` probes three conditions on load. The panel is hidden if
any fail:

- `navigator.serviceWorker` is available? (rules out very old browsers
  and some embedded WebViews)
- `window.PushManager` is available?
- `location.protocol === 'https:'` OR
  `location.hostname` is `localhost` / `127.0.0.1`?

If you expect the panel to show but it doesn't, check the browser
console — there's nothing chatty there, but a missing condition or a
404 on `/vapid_public_key.txt` (i.e. `configure-webpush.sh` hasn't run)
will explain the silence.

## Security model

- The VAPID private key never leaves the Pi.
- Subscription files in `/mutable/webpush_subscriptions/` are mode 0600
  and named by the SHA-256 prefix of the endpoint URL.
- `cgi-bin/webpush_subscribe.sh` enforces a Content-Length cap of 8 KiB
  and validates the JSON body has `endpoint`, `keys.p256dh`, and
  `keys.auth` before saving.
- The CGI endpoint does not authenticate — anyone reachable on your LAN
  can subscribe. If you expose the web UI to the internet, gate it
  behind HTTP Basic auth (already supported in nginx config) or a
  reverse proxy with auth.
