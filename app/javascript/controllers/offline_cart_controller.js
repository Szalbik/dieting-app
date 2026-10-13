import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { enqueue, pending } from "../outbox"

// Outbox-first shopping list.
//
// Ticks (`form[data-offline-check]`) and own-item adds (`form[data-offline-add]`)
// never go through a Turbo submit: they are painted immediately and handed to
// the shared outbox, which sends them in the background — same path online,
// offline and on weak in-store signal, so a tap never waits on the network.
// Tick entries are keyed by the form's action URL (product / custom item id —
// survives cart rehydration); adds carry a client-minted id the server
// dedupes on. Pending entries are re-applied after any cart re-render so an
// offline reopen or a partner's broadcast never hides an unsynced change.
// When the queue drains, the page refreshes quietly (morph) so it — and the
// service worker's cached copy — match the server.

const CHECK_SVG = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#3AA48F" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path pathLength="1" d="M5 12 L10 17 L19 7" /></svg>'
const BOX_ON = ["border-brand-mint-strong", "bg-brand-mint"]
const BOX_OFF = ["border-brand-ink/20", "bg-white"]
const REFRESH_MIN_INTERVAL_MS = 10000

// Strong ease-out (Emil Kowalski): starts fast, so the tap feels answered instantly.
const EASE_OUT = "cubic-bezier(0.23, 1, 0.32, 1)"
const reducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches

export default class extends Controller {
  static targets = ["pendingRow", "customList", "customEmpty"]

  connect() {
    this.lastRefresh = Date.now()
    this.onSubmit = (event) => this.submit(event)
    this.onDrained = (event) => { if (event.detail.kinds.some((k) => k.startsWith("cart"))) this.refresh(true) }
    this.onVisible = () => { if (document.visibilityState === "visible") this.refresh(false) }
    this.onRender = () => {
      this.applyPending()
      if (this.glideFrom) this.glide(this.glideFrom)
      this.glideFrom = null
    }
    this.onStreamRender = (event) => {
      const original = event.detail.render
      event.detail.render = async (stream) => {
        // FLIP: remember where rows are, let Turbo swap the cart, then glide them from old to new.
        const before = event.target.getAttribute("target") === "shopping_cart" ? this.rowTops() : null
        await original(stream)
        this.applyPending()
        if (before) this.glide(before)
      }
    }

    // Capture phase: the forms live inside <turbo-frame id="shopping_cart">, whose
    // own submit observer stops propagation in the bubble phase before it reaches us.
    this.element.addEventListener("submit", this.onSubmit, true)
    window.addEventListener("outbox:drained", this.onDrained)
    document.addEventListener("visibilitychange", this.onVisible)
    document.addEventListener("turbo:render", this.onRender)
    document.addEventListener("turbo:before-stream-render", this.onStreamRender)

    this.applyPending()
  }

  disconnect() {
    this.element.removeEventListener("submit", this.onSubmit, true)
    window.removeEventListener("outbox:drained", this.onDrained)
    document.removeEventListener("visibilitychange", this.onVisible)
    document.removeEventListener("turbo:render", this.onRender)
    document.removeEventListener("turbo:before-stream-render", this.onStreamRender)
  }

  // --- events -------------------------------------------------------------

  submit(event) {
    if (!(event.target instanceof HTMLFormElement)) return
    const form = event.target
    if (form.matches("[data-offline-check]")) {
      // Turbo's submit handlers bail on defaultPrevented, so no request starts here.
      event.preventDefault()
      this.tick(form)
    } else if (form.matches("[data-offline-add]")) {
      event.preventDefault()
      this.add(form)
    }
  }

  tick(form) {
    const url = form.getAttribute("action")
    const bought = form.elements.bought.value === "true"
    this.patch(form, bought)
    enqueue({ key: url, url, method: "PATCH", params: { bought: String(bought) }, kind: "cart" })
  }

  add(form) {
    const name = form.elements["custom_cart_item[name]"].value.trim()
    if (!name) return
    const clientId = crypto.randomUUID()
    const params = {
      "custom_cart_item[name]": name,
      "custom_cart_item[quantity]": form.elements["custom_cart_item[quantity]"].value || "1",
      "custom_cart_item[unit]": form.elements["custom_cart_item[unit]"].value || "szt",
      "custom_cart_item[client_id]": clientId
    }
    enqueue({ key: `custom:${clientId}`, url: form.getAttribute("action"), method: "POST", params, kind: "cart-add" })
    this.showPendingAdd(clientId, params)
    form.elements["custom_cart_item[name]"].value = ""
    form.elements["custom_cart_item[quantity]"].value = "1"
  }

  // Quiet refresh: morph the page to server truth (and let the SW store it).
  // Only with nothing pending, so it never fights an optimistic state.
  refresh(force) {
    if (!navigator.onLine || pending().length > 0) return
    if (!force && Date.now() - this.lastRefresh < REFRESH_MIN_INTERVAL_MS) return
    this.lastRefresh = Date.now()
    this.glideFrom = this.rowTops() // bought rows move to "kupione" in the refreshed page: glide them there
    Turbo.visit(window.location.href, { action: "replace" })
  }

  // --- pending state ------------------------------------------------------

  applyPending() {
    for (const entry of pending()) {
      if (entry.kind === "cart") {
        const form = this.element.querySelector(`form[data-offline-check][action="${CSS.escape(entry.url)}"]`)
        const bought = entry.params.bought === "true"
        // hidden field holds the *target* value, so it equals the entry only while the DOM still shows the old state
        if (form && form.elements.bought.value === String(bought)) this.patch(form, bought, false)
      } else if (entry.kind === "cart-add") {
        this.showPendingAdd(entry.params["custom_cart_item[client_id]"], entry.params, false)
      }
    }
  }

  showPendingAdd(clientId, params, animate = true) {
    if (!this.hasPendingRowTarget || !this.hasCustomListTarget) return
    if (this.customListTarget.querySelector(`[data-client-id="${CSS.escape(clientId)}"]`)) return
    const row = this.pendingRowTarget.content.firstElementChild.cloneNode(true)
    row.dataset.clientId = clientId
    row.querySelector("[data-name]").textContent = params["custom_cart_item[name]"]
    row.querySelector("[data-amount]").textContent = ` · ${params["custom_cart_item[quantity]"]} ${params["custom_cart_item[unit]"]}`
    this.customListTarget.prepend(row)
    if (this.hasCustomEmptyTarget) this.customEmptyTarget.hidden = true
    if (animate && !reducedMotion()) {
      row.animate([{ opacity: 0, transform: "translateY(-4px)" }, { opacity: 1, transform: "translateY(0)" }],
        { duration: 200, easing: EASE_OUT })
    }
  }

  // --- DOM ----------------------------------------------------------------

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
}
