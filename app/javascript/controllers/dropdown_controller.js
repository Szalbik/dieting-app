import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.isOpen = false
  }

  toggle(event) {
    event.stopPropagation()
    this.isOpen = !this.isOpen
    this.updateMenu()
  }

  hide(event) {
    // Don't hide if clicking inside the dropdown or button
    if (this.element.contains(event.target)) {
      return
    }
    
    // Only hide if dropdown is open
    if (this.isOpen) {
      this.isOpen = false
      this.updateMenu()
    }
  }

  updateMenu() {
    if (this.isOpen) {
      this.menuTarget.classList.remove("hidden")
      this.buttonTarget.setAttribute("aria-expanded", "true")
    } else {
      this.menuTarget.classList.add("hidden")
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }
  }
}

