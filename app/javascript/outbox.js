// Offline outbox shared by every queued write (shopping-list ticks and own
// items, "Zjadłem", servings).
//
// Each write is applied to the DOM by its controller first, then enqueued
// here and sent in the background, the same way online and offline, so the
// UI never waits on the network. Entries are coalesced by `key` (last tap
// wins), persisted in localStorage and replayed in order against idempotent,
// set-shaped endpoints whenever the page has a chance: `online`, coming back
// to the foreground, page load, and every 30 s while anything is pending
// (iOS standalone PWAs fire `online` unreliably; no Background Sync on iOS).
//
// Nothing is dropped silently: a vanished target (404) counts as lost and is
// reported, a dead session keeps the queue and asks for a login.
//
// ponytail: last write wins by arrival, no conflict detection — cart sharing
// is dormant in MVP.

const STORAGE_KEY = "dieta:outbox"
const LEGACY_KEY = "dieta:cart-outbox" // pre-offline-first cart queue: [{ url, bought, at }]
const REQUEST_TIMEOUT_MS = 8000
const RETRY_MS = 30000
const SYNCED_FLASH_MS = 2000
const MAX_SERVER_FAILURES = 5 // a 5xx that keeps coming back is a bug, not a blip: stop blocking the queue

const listeners = new Set()
let flushing = false
let authRequired = false
let lost = 0
let synced = false
let syncedTimer = null

function read() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]")
  } catch {
    return []
  }
}

function write(entries) {
  try {
    if (entries.length) localStorage.setItem(STORAGE_KEY, JSON.stringify(entries))
    else localStorage.removeItem(STORAGE_KEY)
  } catch {
    // storage unavailable (private mode): the optimistic UI still works, nothing persists
  }
}

function migrateLegacy() {
  try {
    const legacy = JSON.parse(localStorage.getItem(LEGACY_KEY) || "null")
    if (!legacy) return
    const entries = read()
    for (const { url, bought, at } of legacy) {
      if (!entries.some((e) => e.key === url)) {
        entries.push({ key: url, url, method: "PATCH", params: { bought: String(bought) }, kind: "cart", at })
      }
    }
    write(entries)
    localStorage.removeItem(LEGACY_KEY)
  } catch {
    // nothing to migrate
  }
}

function notify() {
  const snapshot = state()
  listeners.forEach((fn) => fn(snapshot))
}

export function state() {
  return {
    offline: !navigator.onLine,
    pending: read().length,
    syncing: flushing,
    authRequired,
    lost,
    synced
  }
}

export function subscribe(fn) {
  listeners.add(fn)
  fn(state())
  return () => listeners.delete(fn)
}

export function pending(kind) {
  const entries = read()
  return kind ? entries.filter((e) => e.kind === kind) : entries
}

// Entries belong to whoever was signed in when they were made: on a shared device
// a queue left by user A must never replay into user B's account.
function currentUser() {
  return document.querySelector('meta[name="current-user-id"]')?.content
}

// entry: { key, url, method, params, kind }
export function enqueue(entry) {
  const entries = read().filter((e) => e.key !== entry.key)
  entries.push({ ...entry, user: currentUser(), at: Date.now() })
  write(entries)
  synced = false
  notify()
  flush()
}

export function clear() {
  write([])
  notify()
}

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content
}

// The token in a page served from the SW cache can be stale. Fetch a live page
// past the cache (the SW leaves `cache: "no-store"` requests alone) and adopt its token.
// Returns null when there is no live session; a network failure throws (= retry later).
async function refreshCsrfToken() {
  const response = await fetch("/shopping_cart", {
    cache: "no-store",
    credentials: "same-origin",
    redirect: "manual",
    headers: { Accept: "text/html" },
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS)
  })
  if (!response.ok) return null
  const html = await response.text()
  const token = new DOMParser().parseFromString(html, "text/html").querySelector('meta[name="csrf-token"]')?.content
  if (token) document.querySelector('meta[name="csrf-token"]')?.setAttribute("content", token)
  return token || null
}

function send(entry, token) {
  return fetch(entry.url, {
    method: entry.method,
    headers: { "X-CSRF-Token": token, Accept: "text/vnd.turbo-stream.html, text/html" },
    body: new URLSearchParams(entry.params),
    credentials: "same-origin",
    redirect: "manual",
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS)
  })
}

function remove(entry) {
  write(read().filter((e) => !(e.key === entry.key && e.at === entry.at)))
}

export async function flush() {
  const user = currentUser()
  if (flushing || !navigator.onLine || !user || read().length === 0) return

  flushing = true
  authRequired = false
  notify()

  let token = csrfToken()
  let freshToken = false
  const sentKinds = new Set()

  // Re-read the queue each step and remove by identity: a tap that lands
  // mid-flush must not be overwritten by a stale snapshot.
  for (let entry = read()[0]; entry; entry = read()[0]) {
    if (entry.user && entry.user !== user) {
      remove(entry) // another account's change: never send it as this user
      continue
    }

    let response
    try {
      response = await send(entry, token)
      if (response.status === 422 && !freshToken) {
        const refreshed = await refreshCsrfToken()
        if (refreshed) {
          token = refreshed
          freshToken = true
          response = await send(entry, token)
        }
      }
    } catch {
      break // offline or lie-fi timeout: keep the queue, retry later
    }

    // Session gone (redirect to login, 401/403, or no live token to be had): keep everything until the user logs in.
    const unauthorized = response.type === "opaqueredirect" || [401, 403].includes(response.status) ||
      (response.status === 422 && !freshToken)
    if (unauthorized) {
      authRequired = true
      break
    }
    if (response.status >= 500) {
      const failures = (entry.failures || 0) + 1
      if (failures < MAX_SERVER_FAILURES) {
        write(read().map((e) => (e.key === entry.key && e.at === entry.at ? { ...e, failures } : e)))
        break // server hiccup: retry later
      }
    }

    // Anything else that isn't a success will never land (404 target vanished, 422 with a live
    // token = content rejected, 409 refused, repeated 5xx): drop it and tell the user.
    if (!response.ok) lost += 1
    remove(entry)
    sentKinds.add(entry.kind)
  }

  flushing = false
  if (read().length === 0 && sentKinds.size > 0) {
    synced = true
    clearTimeout(syncedTimer)
    syncedTimer = setTimeout(() => { synced = false; notify() }, SYNCED_FLASH_MS)
    window.dispatchEvent(new CustomEvent("outbox:drained", { detail: { kinds: [...sentKinds] } }))
  }
  notify()
}

export function acknowledgeLost() {
  lost = 0
  notify()
}

migrateLegacy()
window.addEventListener("online", () => { notify(); flush() })
window.addEventListener("offline", notify)
window.addEventListener("pageshow", flush)
document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") flush() })
document.addEventListener("turbo:load", flush)
setInterval(() => { if (read().length) flush() }, RETRY_MS)
