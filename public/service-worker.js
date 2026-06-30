// ponytail: minimal installable-shell service worker — pre-caches a few static
// icons so the install criteria + a fetch handler are satisfied, otherwise pure
// network pass-through. NO HTML/app-shell caching on purpose: would serve stale
// Turbo pages and fight the ActionCable real-time shopping sync. Offline data
// (read/check-off shopping list without signal) is a separate epic, add then.

const CACHE = "dieta-shell-v1";
const PRECACHE = ["/icon-192.png", "/icon-512.png", "/icon.svg", "/manifest.webmanifest"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  // Only handle GETs; let everything else (POST/PATCH, ActionCable) hit the network untouched.
  if (request.method !== "GET") return;
  event.respondWith(
    fetch(request).catch(() => caches.match(request))
  );
});
