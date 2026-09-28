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
const CHECK_SVG = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#3AA48F" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12 L10 17 L19 7" /></svg>'
const BOX_ON = ["border-brand-mint-strong", "bg-brand-mint"]
const BOX_OFF = ["border-brand-ink/20", "bg-white"]

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
        await original(stream)
        this.applyPending()
        this.render()
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
      const form = this.element.querySelector(`form[data-offline-check][action="${entry.url}"]`)
      // hidden field holds the *target* value, so it equals entry.bought only when the DOM still shows the old state
      if (form && form.elements.bought.value === String(entry.bought)) this.patch(form, entry.bought)
    }
  }

  async flush() {
    if (this.flushing || !navigator.onLine) return
    let entries = this.queue
    if (entries.length === 0) return

    this.flushing = true
    this.render()
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    while (entries.length) {
      const entry = entries[0]
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
      // opaqueredirect = session gone (login redirect); 5xx = try later. 404 = item removed meanwhile, drop it.
      if (!(response.ok || response.status === 404)) break
      entries = entries.slice(1)
      this.queue = entries
    }

    this.flushing = false
    this.render()
    if (entries.length === 0) Turbo.visit(window.location.pathname, { action: "replace" })
  }

  // --- DOM ----------------------------------------------------------------

  checkForm(target) {
    return target instanceof Element ? target.closest("form[data-offline-check]") : null
  }

  patch(form, bought) {
    form.elements.bought.value = String(!bought)
    const box = form.querySelector("button")
    box.classList.remove(...(bought ? BOX_OFF : BOX_ON))
    box.classList.add(...(bought ? BOX_ON : BOX_OFF))
    box.innerHTML = bought ? CHECK_SVG : '<span class="sr-only">Odhacz</span>'
    const row = form.parentElement
    row.classList.toggle("opacity-60", bought)
    row.querySelector("span.font-semibold")?.classList.toggle("line-through", bought)
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
    // Online-only actions (delete, clear bought, add custom) can't be queued: disable them while offline.
    this.element.querySelectorAll("form:not([data-offline-check]) button, form:not([data-offline-check]) input[type=submit]").forEach((button) => {
      button.disabled = offline
      button.classList.toggle("opacity-40", offline)
    })
  }
}
