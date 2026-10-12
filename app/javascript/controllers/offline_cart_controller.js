import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Offline outbox for shopping-list check-off.
//
// Forms marked `data-offline-check` (the bought/unbought toggles) are
// intercepted while offline: the tap is applied to the DOM immediately and
// queued in localStorage keyed by the form's action URL (product / custom
// item id — survives cart rehydration). When the browser is back online the
// queue is flushed in order with the idempotent `bought` target, then the
// page is reloaded so the DOM matches server truth. Pending entries are
// re-applied after any cart re-render so an offline reopen or a partner's
// broadcast never hides an unsynced tap.
//
// ponytail: last write wins on replay — no conflict detection, cart sharing
// is dormant in MVP. Background Sync API deliberately not used (no iOS).

const STORAGE_KEY = "dieta:cart-outbox"
const CHECK_SVG = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#3AA48F" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path pathLength="1" d="M5 12 L10 17 L19 7" /></svg>'
const BOX_ON = ["border-brand-mint-strong", "bg-brand-mint"]
const BOX_OFF = ["border-brand-ink/20", "bg-white"]

// Strong ease-out (Emil Kowalski): starts fast, so the tap feels answered instantly.
const EASE_OUT = "cubic-bezier(0.23, 1, 0.32, 1)"
const reducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches

export default class extends Controller {
  static targets = ["pill"]

  connect() {
    this.flushing = false
    this.onSubmit = (event) => this.submit(event)
    this.onFetchError = (event) => this.fetchError(event)
    this.onOnline = () => { this.render(); this.flush() }
    this.onOffline = () => this.render()
    this.onStreamRender = (event) => {
      const original = event.detail.render
      event.detail.render = async (stream) => {
        // FLIP: remember where rows are, let Turbo swap the cart, then glide them from old to new.
        const before = event.target.getAttribute("target") === "shopping_cart" ? this.rowTops() : null
        await original(stream)
        this.applyPending()
        this.render()
        if (before) this.glide(before)
      }
    }

    // Capture phase: the forms live inside <turbo-frame id="shopping_cart">, whose
    // own submit observer stops propagation in the bubble phase before it reaches us.
    this.element.addEventListener("submit", this.onSubmit, true)
    this.element.addEventListener("turbo:fetch-request-error", this.onFetchError)
    window.addEventListener("online", this.onOnline)
    window.addEventListener("offline", this.onOffline)
    document.addEventListener("turbo:before-stream-render", this.onStreamRender)

    this.applyPending()
    this.render()
    this.flush()
  }

  disconnect() {
    this.element.removeEventListener("submit", this.onSubmit, true)
    this.element.removeEventListener("turbo:fetch-request-error", this.onFetchError)
    window.removeEventListener("online", this.onOnline)
    window.removeEventListener("offline", this.onOffline)
    document.removeEventListener("turbo:before-stream-render", this.onStreamRender)
  }

  // --- events -------------------------------------------------------------

  submit(event) {
    const form = this.checkForm(event.target)
    if (!form) return
    if (navigator.onLine) {
      // Remember what went out, so a late network error enqueues that intent
      // and not whatever a re-tap changed the form to meanwhile.
      form.dataset.submittedBought = form.elements.bought.value
      this.paint(form, form.elements.bought.value === "true", true) // optimistic, before the round trip
      return
    }
    // Turbo's submit handlers bail on defaultPrevented, so the request never starts.
    event.preventDefault()
    this.enqueue(form)
  }

  fetchError(event) {
    // navigator.onLine said yes but the request failed: treat as offline.
    const form = this.checkForm(event.target)
    if (!form) return
    event.preventDefault()
    if (form.elements.bought.value === form.dataset.submittedBought) this.enqueue(form)
  }

  // --- queue --------------------------------------------------------------

  get queue() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]")
    } catch {
      return []
    }
  }

  set queue(entries) {
    try {
      if (entries.length) localStorage.setItem(STORAGE_KEY, JSON.stringify(entries))
      else localStorage.removeItem(STORAGE_KEY)
    } catch {
      // storage unavailable (private mode): optimistic UI still works, nothing persists
    }
  }

  enqueue(form) {
    const url = form.getAttribute("action")
    const bought = form.elements.bought.value === "true"
    const entries = this.queue.filter((entry) => entry.url !== url)
    entries.push({ url, bought, at: Date.now() })
    this.queue = entries
    this.patch(form, bought)
    this.render()
  }

  applyPending() {
    for (const entry of this.queue) {
      const form = this.element.querySelector(`form[data-offline-check][action="${CSS.escape(entry.url)}"]`)
      // hidden field holds the *target* value, so it equals entry.bought only when the DOM still shows the old state
      if (form && form.elements.bought.value === String(entry.bought)) this.patch(form, entry.bought, false)
    }
  }

  async flush() {
    if (this.flushing || !navigator.onLine || this.queue.length === 0) return

    this.flushing = true
    this.render()
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    // Re-read the queue each iteration and remove by identity: a tap that lands
    // mid-flush (network flapping) must not be overwritten by a stale snapshot.
    for (let entry = this.queue[0]; entry; entry = this.queue[0]) {
      let response
      try {
        response = await fetch(entry.url, {
          method: "PATCH",
          headers: { "X-CSRF-Token": token, Accept: "text/vnd.turbo-stream.html, text/html" },
          body: new URLSearchParams({ bought: String(entry.bought) }),
          credentials: "same-origin",
          redirect: "manual"
        })
      } catch {
        break // still offline: keep the queue
      }
      // Keep and retry later on: opaqueredirect (session gone), 401/403, 5xx.
      // Drop on any other 4xx (404 item removed meanwhile, 422 stale token) so a dead entry can't block the queue forever.
      const retryLater = response.type === "opaqueredirect" || response.status === 401 || response.status === 403 || response.status >= 500
      if (retryLater) break
      this.queue = this.queue.filter((e) => !(e.url === entry.url && e.at === entry.at))
    }

    this.flushing = false
    this.render()
    if (this.queue.length === 0) Turbo.visit(window.location.pathname, { action: "replace" })
  }

  // --- DOM ----------------------------------------------------------------

  checkForm(target) {
    return target instanceof Element ? target.closest("form[data-offline-check]") : null
  }

  patch(form, bought, animate = true) {
    form.elements.bought.value = String(!bought)
    this.paint(form, bought, animate)
  }

  paint(form, bought, animate) {
    const box = form.querySelector("button")
    box.classList.remove(...(bought ? BOX_OFF : BOX_ON))
    box.classList.add(...(bought ? BOX_ON : BOX_OFF))
    box.innerHTML = bought ? CHECK_SVG : '<span class="sr-only">Odhacz</span>'
    const row = form.parentElement
    row.classList.toggle("opacity-60", bought)
    row.querySelector("span.font-semibold")?.classList.toggle("line-through", bought)
    if (animate && !reducedMotion()) this.pop(box, row, bought)
  }

  // Feedback: box pops (never from scale 0), tick draws itself, row settles to its new opacity.
  pop(box, row, bought) {
    box.animate(
      [{ transform: bought ? "scale(0.8)" : "scale(1.1)" }, { transform: "scale(1)" }],
      { duration: 200, easing: EASE_OUT }
    )
    const tick = box.querySelector("path")
    tick?.animate([{ strokeDasharray: 1, strokeDashoffset: 1 }, { strokeDasharray: 1, strokeDashoffset: 0 }],
      { duration: 220, easing: EASE_OUT })
    row.animate([{ opacity: bought ? 1 : 0.6 }, { opacity: bought ? 0.6 : 1 }], { duration: 200, easing: "ease" })
  }

  rowTops() {
    const tops = new Map()
    this.element.querySelectorAll("[data-flip]").forEach((el) => tops.set(el.id, el.getBoundingClientRect().top))
    return tops
  }

  // Rows that moved slide from where they were.
  glide(before) {
    if (reducedMotion()) return
    this.element.querySelectorAll("[data-flip]").forEach((el) => {
      const from = before.get(el.id)
      if (from === undefined) return
      const dy = from - el.getBoundingClientRect().top
      if (Math.abs(dy) < 1) return
      el.animate([{ transform: `translateY(${dy}px)` }, { transform: "translateY(0)" }],
        { duration: 260, easing: EASE_OUT })
    })
  }

  render() {
    const offline = !navigator.onLine
    const pending = this.queue.length
    if (this.hasPillTarget) {
      this.pillTarget.hidden = !(offline || pending > 0)
      this.pillTarget.textContent = this.flushing
        ? "Synchronizuję…"
        : pending > 0 ? `Offline · ${pending} do zsynchronizowania` : "Offline"
    }
    // Online-only actions (delete, move, clear bought, add custom) can't be queued: disable them while offline.
    this.element.querySelectorAll("form:not([data-offline-check]) button, form:not([data-offline-check]) input[type=submit], form:not([data-offline-check]) select").forEach((button) => {
      button.disabled = offline
      button.classList.toggle("opacity-40", offline)
    })
  }
}
