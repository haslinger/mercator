// Service worker of the Mercator PWA.
//
// Deliberately minimal: all requests go to the network (LiveView needs live
// data, assets are fingerprinted), only page navigations fall back to a
// static offline page when the network is unavailable.
//
// It also shows the phone notifications of the sales desk (Web Push, #151),
// also when no page of the shop is open.
const OFFLINE_CACHE = "mercator-offline-v1";
const OFFLINE_URL = "/offline.html";

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(OFFLINE_CACHE).then((cache) => cache.add(OFFLINE_URL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== OFFLINE_CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.mode !== "navigate") return;

  event.respondWith(fetch(event.request).catch(() => caches.match(OFFLINE_URL)));
});

// A notification from the shop (Mercator.WebPush): {title, body, url, tag}.
// The same tag replaces the previous notification of a conversation.
self.addEventListener("push", (event) => {
  const data = event.data ? event.data.json() : {};

  event.waitUntil(
    self.registration.showNotification(data.title || "Mercator", {
      body: data.body,
      tag: data.tag,
      renotify: Boolean(data.tag),
      icon: "/brand/apple-touch-icon",
      data: {url: data.url || "/"},
    })
  );
});

// Tapping it opens the conversation, in an open tab of the shop if there is one.
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = new URL(event.notification.data?.url || "/", self.location.origin).href;

  event.waitUntil(
    self.clients.matchAll({type: "window", includeUncontrolled: true}).then((windows) => {
      const open = windows.find((client) => client.url === url);
      if (open) return open.focus();

      const shop = windows.find((client) => "navigate" in client);
      if (!shop) return self.clients.openWindow(url);

      // navigating fails for a tab the service worker does not control
      return shop
        .navigate(url)
        .then((client) => (client ? client.focus() : self.clients.openWindow(url)))
        .catch(() => self.clients.openWindow(url));
    })
  );
});
