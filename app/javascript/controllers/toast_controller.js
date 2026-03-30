import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: { type: Number, default: 8000 } }

  connect() {
    this.element.classList.remove("opacity-0", "translate-y-4")
    this.dismissTimer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.dismissTimer)
  }

  dismiss() {
    clearTimeout(this.dismissTimer)
    this.element.classList.add("opacity-0", "translate-y-4")
    setTimeout(() => this.element.remove(), 300)
  }
}
