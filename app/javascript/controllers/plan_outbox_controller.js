import { Controller } from "@hotwired/stimulus"
import { enqueue, pending } from "../outbox"

// Offline-capable plan actions: "Zjadłem" (`form[data-offline-eaten]`) and
// servings ± (`form[data-offline-servings]`). Like the shopping list, they are
// painted immediately and sent through the shared outbox with explicit target
// values, so replays are idempotent. Pending entries are re-applied when a
// (possibly cached) plan or meal page renders.
export default class extends Controller {
  connect() {
    this.onSubmit = (event) => this.submit(event)
    this.onRender = () => this.applyPending()
    // Capture phase: the servings forms live inside <turbo-frame id="day_view">.
    this.element.addEventListener("submit", this.onSubmit, true)
    document.addEventListener("turbo:render", this.onRender)
    this.applyPending()
  }

  disconnect() {
    this.element.removeEventListener("submit", this.onSubmit, true)
    document.removeEventListener("turbo:render", this.onRender)
  }

  submit(event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return
    const url = form.getAttribute("action")
    if (form.matches("[data-offline-eaten]")) {
      event.preventDefault()
      const eaten = form.elements.eaten.value === "true"
      this.paintEaten(url, eaten)
      enqueue({ key: url, url, method: "PATCH", params: { eaten: String(eaten) }, kind: "plan" })
    } else if (form.matches("[data-offline-servings]")) {
      event.preventDefault()
      const date = form.elements.date.value
      const servings = form.elements.servings.value
      this.paintServings(date, Number(servings))
      enqueue({ key: `servings:${date}`, url, method: "PATCH", params: { date, servings }, kind: "plan" })
    }
  }

  applyPending() {
    for (const entry of pending("plan")) {
      if ("eaten" in entry.params) this.paintEaten(entry.url, entry.params.eaten === "true")
      else if ("servings" in entry.params) this.paintServings(entry.params.date, Number(entry.params.servings))
    }
  }

  paintEaten(url, eaten) {
    this.element.querySelectorAll(`form[data-offline-eaten][action="${CSS.escape(url)}"]`).forEach((form) => {
      form.elements.eaten.value = String(!eaten)
      const button = form.querySelector("button")
      button.classList.toggle("bg-brand-mint-soft", eaten)
      button.classList.toggle("text-brand-mint-strong", eaten)
      button.classList.toggle("bg-brand-navy", !eaten)
      button.classList.toggle("text-white", !eaten)
      const label = button.querySelector("[data-eaten-label]")
      if (label) label.textContent = eaten ? "Zjedzone" : "Zjadłem"
    })
    this.element.querySelectorAll(`[data-eaten-url="${CSS.escape(url)}"]`).forEach((card) => {
      card.querySelector('[data-eaten-tile="done"]')?.toggleAttribute("hidden", !eaten)
      card.querySelector('[data-eaten-tile="todo"]')?.toggleAttribute("hidden", eaten)
    })
  }

  paintServings(date, servings) {
    const forms = [...this.element.querySelectorAll("form[data-offline-servings]")].filter((f) => f.elements.date.value === date)
    if (!forms.length) return
    forms.forEach((form) => {
      const next = servings + Number(form.dataset.step)
      form.elements.servings.value = String(next)
      form.querySelector("button").disabled = next < Number(form.dataset.min) || next > Number(form.dataset.max)
    })
    const count = forms[0].parentElement.querySelector("[data-servings-count]")
    if (count) count.textContent = `${servings} os.`
  }
}
