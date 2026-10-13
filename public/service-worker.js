// Network-first service worker with a runtime cache, so the last-visited
// pages (plan days, meals, shopping list) and their fingerprinted assets
// render offline. Every request still goes to the network first; a page that
// is already cached gets NETWORK_TIMEOUT_MS before the cached copy is shown
// (weak in-store signal), while the network answer still refreshes the cache.
//
// Cacheability guards — a response is stored only when it is a same-origin
// GET for an HTML page or an /assets/ file, is ok and not a redirect (so a
// login redirect never becomes "the cart page"), has no Turbo-Frame header
// (frame responses are body-only and would render unstyled as a full page)
// and is not a turbo-stream response.
//
// Non-GET requests (check-off, ActionCable) are never touched here.

const CACHE = "dieta-v3";
const PRECACHE = ["/icon-192.png", "/icon-512.png", "/icon.svg", "/manifest.webmanifest"];
// Only the daily pages are stored offline (authenticated HTML on disk stays scoped to daily use).
const PAGE_PATHS = ["/shopping_cart", "/diet_set_plans"];
const MEAL_PAGE = /^\/meal_plans\/\d+$/;
const NETWORK_TIMEOUT_MS = 2500;
const MAX_ASSET_ENTRIES = 40;

const OFFLINE_HTML = `<!doctype html>
<html lang="pl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Brak połączenia</title>
<style>
  body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #FBF8F1; color: #2B2A28; font-family: -apple-system, system-ui, sans-serif; }
  main { padding: 32px 24px; text-align: center; max-width: 360px; }
  h1 { font-size: 22px; margin: 0 0 8px; }
  p { margin: 0 0 24px; color: #5A5448; font-size: 15px; line-height: 1.5; }
  a { display: block; margin: 0 0 10px; padding: 12px 20px; border-radius: 999px; background: #496580; color: #fff; text-decoration: none; font-weight: 600; }
  a.secondary { background: #fff; color: #496580; border: 1px solid #49658033; }
</style>
</head>
<body>
<main>
  <h1>Brak połączenia</h1>
  <p>Ta strona nie jest dostępna offline. Otwórz plan dnia lub listę zakupów.</p>
  <a href="/diet_set_plans">Twój plan dnia</a>
  <a class="secondary" href="/shopping_cart">Lista zakupów</a>
</main>
</body>
</html>`;

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

function wantsHtml(request) {
  return request.mode === "navigate" || (request.headers.get("Accept") || "").includes("text/html");
}

function cacheable(request, response) {
  if (!response || !response.ok || response.redirected || response.type !== "basic") return false;
  if ((response.headers.get("Cache-Control") || "").includes("no-store")) return false;
  if (request.headers.has("Turbo-Frame")) return false;
  if ((request.headers.get("Accept") || "").includes("text/vnd.turbo-stream.html")) return false;
  return true;
}

function offlinePage(url) {
  return PAGE_PATHS.includes(url.pathname) || MEAL_PAGE.test(url.pathname);
}

// Fingerprinted assets accumulate across deploys; keep only the newest few (Cache API keys are in insertion order).
async function trimAssets(cache) {
  const assetKeys = (await cache.keys()).filter((req) => new URL(req.url).pathname.startsWith("/assets/"));
  await Promise.all(assetKeys.slice(0, Math.max(0, assetKeys.length - MAX_ASSET_ENTRIES)).map((req) => cache.delete(req)));
}

function offlineResponse() {
  return new Response(OFFLINE_HTML, { status: 200, headers: { "Content-Type": "text/html; charset=utf-8" } });
}

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;
  // The outbox fetches a live page this way to renew a stale CSRF token: never answer it from cache.
  if (request.cache === "no-store") return;
  // Range requests for media: let the browser stream them directly.
  if (request.destination === "video" || request.destination === "audio") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  const page = wantsHtml(request);
  const asset = url.pathname.startsWith("/assets/");

  if (!page && !asset) {
    event.respondWith(fetch(request).catch(() => caches.match(request).then((cached) => cached || Response.error())));
    return;
  }

  // Keyed by URL string and matched with ignoreVary: Rails answers with
  // `Vary: Accept`, and a Turbo Drive fetch and a cold browser navigation send
  // different Accept headers for the same page.
  const network = fetch(request).then((response) => {
    if (cacheable(request, response) && (asset || offlinePage(url))) {
      const copy = response.clone();
      event.waitUntil(
        caches.open(CACHE).then(async (cache) => {
          await cache.put(url.href, copy);
          if (asset) await trimAssets(cache);
        })
      );
    }
    return response;
  });
  // Keep the SW alive until the network settles, so a late answer still refreshes the cache.
  event.waitUntil(network.catch(() => {}));

  event.respondWith(
    (async () => {
      const cached = await caches.match(url.href, { ignoreVary: true });
      // Lie-fi: the browser says online but the network crawls. Give it a moment, then show what we have.
      if (cached && page) {
        const timeout = new Promise((resolve) => setTimeout(() => resolve(cached), NETWORK_TIMEOUT_MS));
        return Promise.race([network.catch(() => cached), timeout]);
      }
      try {
        return await network;
      } catch {
        if (cached) return cached;
        return page ? offlineResponse() : Response.error();
      }
    })()
  );
});
