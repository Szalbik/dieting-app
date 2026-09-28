// Network-first service worker with a runtime cache, so the last-visited
// pages (today's plan, shopping list) and their fingerprinted assets render
// offline. Online behaviour is unchanged: every request still goes to the
// network first, the cache is only a fallback.
//
// Cacheability guards — a response is stored only when it is a same-origin
// GET for an HTML page or an /assets/ file, is ok and not a redirect (so a
// login redirect never becomes "the cart page"), has no Turbo-Frame header
// (frame responses are body-only and would render unstyled as a full page)
// and is not a turbo-stream response.
//
// Non-GET requests (check-off, ActionCable) are never touched here.

const CACHE = "dieta-v2";
const PRECACHE = ["/icon-192.png", "/icon-512.png", "/icon.svg", "/manifest.webmanifest"];

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
  <p>Ta strona nie została jeszcze zapisana na telefonie. Otwórz jedną z ostatnio odwiedzonych.</p>
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
  if (request.headers.has("Turbo-Frame")) return false;
  if ((request.headers.get("Accept") || "").includes("text/vnd.turbo-stream.html")) return false;
  return true;
}

function offlineResponse() {
  return new Response(OFFLINE_HTML, { status: 200, headers: { "Content-Type": "text/html; charset=utf-8" } });
}

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  const page = wantsHtml(request);
  const asset = url.pathname.startsWith("/assets/");

  if (!page && !asset) {
    event.respondWith(fetch(request).catch(() => caches.match(request)));
    return;
  }

  // Keyed by URL string and matched with ignoreVary: Rails answers with
  // `Vary: Accept`, and a Turbo Drive fetch and a cold browser navigation send
  // different Accept headers for the same page.
  event.respondWith(
    fetch(request)
      .then((response) => {
        if (cacheable(request, response)) {
          const copy = response.clone();
          event.waitUntil(caches.open(CACHE).then((cache) => cache.put(url.href, copy)));
        }
        return response;
      })
      .catch(async () => {
        const cached = await caches.match(url.href, { ignoreVary: true });
        if (cached) return cached;
        return page ? offlineResponse() : Response.error();
      })
  );
});
