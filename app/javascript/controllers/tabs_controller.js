import { Controller } from "@hotwired/stimulus"

// Client-side show/hide tabs. Each pill carries data-tab-value; each panel
// carries data-tab-value. Selecting a pill marks it aria-selected and hides
// every panel whose value differs (the special value "all" shows everything).
// Styling lives in the markup via Tailwind aria-selected: variants.
export default class extends Controller {
  static targets = ["pill", "panel"]

  connect() {
    const selected = this.pillTargets.find(p => p.getAttribute("aria-selected") === "true")
    if (selected) this.apply(selected.dataset.tabValue)
  }

  select(event) {
    this.apply(event.currentTarget.dataset.tabValue)
  }

  apply(value) {
    this.pillTargets.forEach(p =>
      p.setAttribute("aria-selected", String(p.dataset.tabValue === value))
    )
    this.panelTargets.forEach(panel => {
      panel.hidden = value !== "all" && panel.dataset.tabValue !== value
    })
  }
}
