import { Controller } from "@hotwired/stimulus"

// Warms the service worker cache with the next few plan days and their meal
// pages, so the plan can be browsed in a shop without signal. Plain GETs with
// `Accept: text/html` — the service worker stores them like any visited page.
// Throttled per device; re-run after queued plan changes sync.
//
// ponytail: sequential fetches (~4 days + their meals), fine at this size.

const THROTTLE_KEY = "dieta:prefetch-at"
const THROTTLE_MS = 30 * 60 * 1000

export default class extends Controller {
  static values = { today: String, days: { type: Number, default: 3 } }

  connect() {
    this.onDrained = (event) => { if (event.detail.kinds.includes("plan")) this.run(true) }
    window.addEventListener("outbox:drained", this.onDrained)
    this.run(false)
  }

  disconnect() {
    window.removeEventListener("outbox:drained", this.onDrained)
  }

  async run(force) {
    if (this.running || !navigator.onLine || (!force && this.throttled())) return
    this.running = true
    try {
      for (const date of this.dates()) {
        if (!navigator.onLine) break
        const html = await this.get(`/diet_set_plans?date=${date}`)
        if (!html) continue
        const meals = new DOMParser().parseFromString(html, "text/html").querySelectorAll('a[href^="/meal_plans/"]')
        for (const href of new Set([...meals].map((a) => a.getAttribute("href")))) {
          if (!navigator.onLine) break
          await this.get(href)
        }
      }
      this.stamp()
    } finally {
      this.running = false
    }
  }

  // today..today+N from the server's date (not the device clock), as YYYY-MM-DD
  dates() {
    const start = new Date(`${this.todayValue}T00:00:00Z`)
    return Array.from({ length: this.daysValue + 1 }, (_, i) => {
      const d = new Date(start)
      d.setUTCDate(d.getUTCDate() + i)
      return d.toISOString().slice(0, 10)
    })
  }

  async get(url) {
    try {
      const response = await fetch(url, { headers: { Accept: "text/html" }, credentials: "same-origin" })
      return response.ok && !response.redirected ? await response.text() : null
    } catch {
      return null
    }
  }

  throttled() {
    try {
      return Date.now() - Number(localStorage.getItem(THROTTLE_KEY) || 0) < THROTTLE_MS
    } catch {
      return false
    }
  }

  stamp() {
    try {
      localStorage.setItem(THROTTLE_KEY, String(Date.now()))
    } catch {
      // storage unavailable: prefetch simply runs again next time
    }
  }
}
