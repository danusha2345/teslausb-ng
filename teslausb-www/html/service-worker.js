// teslausb-ng — Service Worker for Web Push notifications (v1.3.2).
//
// Registered by js/webpush.js once the user explicitly clicks the "enable
// browser notifications" button. The SW receives `push` events from the
// browser's push service, parses the JSON payload we send from
// run/send_webpush.py, and shows a system notification.
//
// Click a notification to focus the teslausb-ng tab if it's already open,
// or open it if it isn't.

self.addEventListener("install", () => {
  // Activate immediately on first install so the user doesn't have to refresh.
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("push", (event) => {
  let payload = { title: "teslausb-ng", body: "Notification" };
  if (event.data) {
    try {
      payload = { ...payload, ...event.data.json() };
    } catch (_) {
      payload.body = event.data.text();
    }
  }
  event.waitUntil(
    self.registration.showNotification(payload.title, {
      body: payload.body,
      tag: payload.tag || "teslausb-ng",
      icon: payload.icon || "/icons/teslausb.png",
      badge: payload.badge || payload.icon || "/icons/teslausb.png",
      data: { url: payload.url || "/" },
    })
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = event.notification.data?.url || "/";
  event.waitUntil(
    (async () => {
      const all = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
      for (const client of all) {
        if (client.url.endsWith(url) && "focus" in client) {
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(url);
      }
    })()
  );
});
