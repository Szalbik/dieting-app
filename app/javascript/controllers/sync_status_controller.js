import { Controller } from "@hotwired/stimulus"
import { subscribe, flush, clear, pending, acknowledgeLost } from "../outbox"

// One connection/sync pill for every signed-in page, plus the offline lock on
// controls that need the server (`[data-online-only]`: a form, button or link).
//
// Pill states, most urgent first: login needed > lost changes > syncing >
// offline (with pending count) > pending on weak signal > synced (brief).

const LOST_FLASH_MS = 5000
const OFFLINE_TITLE = "Wymaga połączenia"

export default class extends Controller {
  static targets = ["pill"]

  connect() {
    this.snapshot = null
    this.unsubscribe = subscribe((snapshot) => this.update(snapshot))
    this.onOnlineChange = () => this.lockOnlineOnly()
    window.addEventListener("online", this.onOnlineChange)
    window.addEventListener("offline", this.onOnlineChange)
    // Pages, frames and streams keep adding controls: re-lock whatever appears.
    this.observer = new MutationObserver(() => this.lockOnlineOnly())
    this.observer.observe(document.body, { childList: true, subtree: true })
    this.onLogout = (event) => this.logout(event)
    document.addEventListener("submit", this.onLogout, true)
    this.lockOnlineOnly()
  }

  disconnect() {
    this.unsubscribe()
    window.removeEventListener("online", this.onOnlineChange)
    window.removeEventListener("offline", this.onOnlineChange)
    this.observer.disconnect()
    document.removeEventListener("submit", this.onLogout, true)
    clearTimeout(this.lostTimer)
  }

  update(snapshot) {
    if (snapshot.lost > 0 && !this.lostTimer) {
      this.lostTimer = setTimeout(() => { this.lostTimer = null; acknowledgeLost() }, LOST_FLASH_MS)
    }
    this.snapshot = snapshot
    this.render()
  }

  render() {
    const { offline, pending: count, syncing, authRequired, lost, synced } = this.snapshot
    let text = null
    let tone = "neutral"
    if (authRequired) {
      text = `Zaloguj się, aby zsynchronizować (${count})`
      tone = "warn"
    } else if (lost > 0) {
      text = lost === 1 ? "Nie udało się zapisać 1 zmiany" : `Nie udało się zapisać ${lost} zmian`
      tone = "warn"
    } else if (syncing) {
      text = "Synchronizuję…"
    } else if (offline) {
      text = count > 0 ? `Offline · ${count} do zsynchronizowania` : "Offline"
    } else if (count > 0) {
      text = `${count} do zsynchronizowania`
    } else if (synced) {
      text = "✓ Zsynchronizowano"
      tone = "ok"
    }

    const pill = this.pillTarget
    pill.hidden = !text
    if (!text) return
    pill.textContent = text
    pill.classList.toggle("text-rose-600", tone === "warn")
    pill.classList.toggle("text-brand-mint-strong", tone === "ok")
    pill.classList.toggle("text-brand-ink", tone === "neutral")
    if (authRequired) {
      pill.setAttribute("href", "/session/new")
      pill.removeAttribute("aria-disabled")
    } else {
      pill.removeAttribute("href")
    }
  }

  lockOnlineOnly() {
    const offline = !navigator.onLine
    document.querySelectorAll("[data-online-only]").forEach((el) => {
      const controls = el.matches("form") ? el.querySelectorAll("button, input[type=submit], select") : [el]
      controls.forEach((control) => {
        if (control.matches("a")) {
          control.toggleAttribute("aria-disabled", offline)
          control.classList.toggle("pointer-events-none", offline)
        } else if (offline) {
          // remember a server-side disabled state so coming back online doesn't enable it
          if (!control.disabled) control.dataset.offlineLocked = ""
          control.disabled = true
        } else if (control.hasAttribute("data-offline-locked")) {
          control.disabled = false
          delete control.dataset.offlineLocked
        }
        control.classList.toggle("opacity-40", offline)
        if (offline) control.title = OFFLINE_TITLE
        else if (control.title === OFFLINE_TITLE) control.removeAttribute("title")
      })
    })
  }

  // Sign-out ends the session and wipes local storage (Clear-Site-Data): send what's pending first.
  async logout(event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement) || !form.matches("[data-outbox-logout]") || form.dataset.flushed) return
    if (pending().length === 0) return
    event.preventDefault()
    event.stopImmediatePropagation()
    await flush()
    clear()
    form.dataset.flushed = ""
    form.requestSubmit()
  }
}
