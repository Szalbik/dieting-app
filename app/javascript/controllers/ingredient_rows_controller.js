import { Controller } from "@hotwired/stimulus"

// Structured add/remove ingredient rows (name + amount + unit) for the
// recipe form and the manual-meal form. Both forms actually submit a single
// free-text field (ingredients_text / meal[ingredients_text]) parsed
// server-side as "Name - amount unit" per line (see Recipe.parse_ingredient_line);
// this controller is a UI layer only — on submit it serializes the rows back
// into that same hidden field, so no backend/schema change is needed.
export default class extends Controller {
  static targets = ["list", "template", "hidden"]
  static values = { seed: Array }

  connect() {
    const seed = this.seedValue
    if (seed.length) {
      seed.forEach(ing => this.addRow(ing))
    } else {
      this.addRow()
    }
  }

  add() {
    this.addRow()
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-ingredient-rows-target='row']")
    row?.remove()
    if (!this.listTarget.children.length) this.addRow()
  }

  serialize() {
    const lines = Array.from(this.listTarget.children)
      .map(row => {
        const name = row.querySelector("[data-field='name']")?.value.trim()
        const amount = row.querySelector("[data-field='amount']")?.value.trim()
        const unit = row.querySelector("[data-field='unit']")?.value.trim()
        if (!name) return null
        const quantity = [amount, unit].filter(Boolean).join(" ")
        return quantity ? `${name} - ${quantity}` : name
      })
      .filter(Boolean)

    this.hiddenTarget.value = lines.join("\n")
  }

  addRow(ing = {}) {
    const fragment = this.templateTarget.content.cloneNode(true)
    const row = fragment.querySelector("[data-ingredient-rows-target='row']")
    if (ing.name) row.querySelector("[data-field='name']").value = ing.name
    if (ing.amount) row.querySelector("[data-field='amount']").value = ing.amount
    if (ing.unit) row.querySelector("[data-field='unit']").value = ing.unit
    this.listTarget.appendChild(fragment)
  }
}
