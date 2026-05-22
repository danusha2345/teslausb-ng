# HTTPS for the web UI

By default teslausb-ng serves its web UI over plain `http://` on port 80.
That's fine for viewing recordings on a trusted LAN, but two things want
HTTPS:

- **Web Push notifications** (see [WebPush.md](WebPush.md)) — the browser
  Service Worker refuses to load over `http://teslausb.local/`.
- **Login credentials** — if you enable web auth (`WEB_USERNAME` /
  `WEB_PASSWORD`), HTTP Basic sends them base64-encoded but unencrypted.

teslausb-ng ships an opt-in self-signed HTTPS setup. It's LAN-only, so
there's no Let's Encrypt / ACME path here — that needs a public hostname
and port forwarding teslausb isn't designed for.

## Enabling

Set in `/root/teslausb_setup_variables.conf` (or in
`boot/firmware/teslausb_setup_variables.conf` on a fresh image):

```sh
HTTPS_ENABLED=true
```

On the next boot (or after `sudo /tmp/configure-https.sh`), the setup:

1. Generates a self-signed cert at `/etc/nginx/ssl/teslausb.{crt,key}`,
   valid 10 years, with Subject Alternative Names for `teslausb.local`,
   `teslausb`, and your configured hostname (+`.local`).
2. Installs a 443 server block (`teslausb-ssl.nginx`) **alongside** the
   existing port-80 block — `http://` keeps working, `https://` is added.
3. Mirrors whatever `auth_basic` setting `configure-web.sh` applied, so
   if you enabled web auth it now covers both ports.

The cert is generated once and reused across reboots. To rotate it,
delete `/etc/nginx/ssl/teslausb.crt` and re-run the script.

## Trusting the self-signed cert

A self-signed cert means the browser shows a one-time "Not secure" /
"Your connection is not private" warning. You have to get past it once
per device:

- **Quick path** — click "Advanced" → "Proceed to teslausb.local
  (unsafe)". The UI loads; the address bar stays marked insecure.
  Web Push **will** work after this on Firefox; Chrome sometimes still
  refuses the Service Worker for click-through self-signed certs.
- **Proper path** — import `/etc/nginx/ssl/teslausb.crt` into your
  device/browser trust store. Then `https://teslausb.local/` is fully
  trusted, the warning is gone, and Web Push works on every browser.
  - Copy the cert off the Pi: `scp pi@teslausb.local:/etc/nginx/ssl/teslausb.crt .`
  - macOS: add to Keychain, set to "Always Trust".
  - Windows: import into "Trusted Root Certification Authorities".
  - Android: Settings → Security → Install a certificate → CA cert.
  - Firefox: Settings → Privacy & Security → Certificates → Import.

## Verifying

```bash
# From another machine on the LAN:
curl -k https://teslausb.local/        # -k skips cert validation
openssl s_client -connect teslausb.local:443 -servername teslausb.local </dev/null 2>/dev/null | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
```

You should see the SANs you'd expect (`teslausb.local`, `teslausb`, your
hostname).

## Not in scope

- **Let's Encrypt / ACME** — needs a public DNS name and inbound 80/443.
  teslausb is a LAN appliance; if you front it with a reverse proxy that
  already terminates TLS (Caddy, Traefik, a Tailscale funnel), point that
  at the Pi's port 80 and skip `HTTPS_ENABLED` entirely.
- **HTTP→HTTPS redirect** — the port-80 block is left intact on purpose
  (the cttseraser TeslaCam FUSE mount and any existing bookmarks keep
  working). If you want to force HTTPS, add a `return 301 https://...`
  to the `location /` of `teslausb.nginx` yourself.
