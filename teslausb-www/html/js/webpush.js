// teslausb-ng — Web Push subscribe / unsubscribe UI (v1.3.2).
//
// Reveals a button (#webpush-panel) when:
//   * the browser supports Service Workers and Push API
//   * the page is served over HTTPS or via localhost (otherwise SW won't load)
//   * /vapid_public_key.txt is reachable (i.e. configure-webpush.sh has run)
//
// Subscribe flow:
//   click → Notification.requestPermission → register SW → pushManager.subscribe
//        → POST the subscription JSON to cgi-bin/webpush_subscribe.sh
//
// Unsubscribe is local-only (calls subscription.unsubscribe()); the Pi
// cleans up stale subscriptions automatically on the next push attempt
// when the endpoint returns HTTP 404/410.

(function () {
  const panel = document.getElementById("webpush-panel");
  if (!panel) return;

  const btn = panel.querySelector("button[data-webpush-toggle]");
  const status = panel.querySelector("[data-webpush-status]");
  if (!btn || !status) return;

  const supported =
    "serviceWorker" in navigator &&
    "PushManager" in window &&
    (location.protocol === "https:" || location.hostname === "localhost" || location.hostname === "127.0.0.1");

  if (!supported) {
    // Stay hidden — non-secure context, browser too old, or no SW support.
    return;
  }

  async function fetchVapidKey() {
    const res = await fetch("vapid_public_key.txt", { cache: "no-cache" });
    if (!res.ok) throw new Error("vapid key not available");
    return (await res.text()).trim();
  }

  function urlBase64ToUint8Array(b64) {
    const padding = "=".repeat((4 - (b64.length % 4)) % 4);
    const base64 = (b64 + padding).replace(/-/g, "+").replace(/_/g, "/");
    const raw = atob(base64);
    const out = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
    return out;
  }

  async function currentSubscription() {
    const reg = await navigator.serviceWorker.getRegistration("/");
    if (!reg) return null;
    return reg.pushManager.getSubscription();
  }

  function setUi(state) {
    if (state === "subscribed") {
      btn.textContent = btn.dataset.labelSubscribed || "Disable browser notifications";
      btn.disabled = false;
      status.textContent = "✓";
    } else if (state === "unsubscribed") {
      btn.textContent = btn.dataset.labelUnsubscribed || "Enable browser notifications";
      btn.disabled = false;
      status.textContent = "";
    } else if (state === "busy") {
      btn.disabled = true;
    } else if (state === "blocked") {
      btn.disabled = true;
      btn.textContent = btn.dataset.labelBlocked || "Notifications blocked by browser";
      status.textContent = "✗";
    }
  }

  async function subscribe() {
    setUi("busy");
    const perm = await Notification.requestPermission();
    if (perm !== "granted") {
      setUi(perm === "denied" ? "blocked" : "unsubscribed");
      return;
    }
    const key = await fetchVapidKey();
    const reg = await navigator.serviceWorker.register("service-worker.js");
    await navigator.serviceWorker.ready;
    const sub = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(key),
    });
    const ok = await postSubscription(sub);
    setUi(ok ? "subscribed" : "unsubscribed");
  }

  async function unsubscribe() {
    setUi("busy");
    const sub = await currentSubscription();
    if (sub) await sub.unsubscribe();
    setUi("unsubscribed");
  }

  async function postSubscription(sub) {
    try {
      const res = await fetch("cgi-bin/webpush_subscribe.sh", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(sub),
      });
      const body = await res.json().catch(() => ({}));
      return Boolean(body.ok);
    } catch {
      return false;
    }
  }

  (async () => {
    panel.hidden = false;
    const existing = await currentSubscription();
    setUi(existing ? "subscribed" : "unsubscribed");
    btn.addEventListener("click", async () => {
      const sub = await currentSubscription();
      if (sub) await unsubscribe();
      else await subscribe();
    });
  })();
})();
