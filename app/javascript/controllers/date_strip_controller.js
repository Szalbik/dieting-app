import { Controller } from "@hotwired/stimulus"

// Centers the selected date tile in the scrollable strip. Reconnects after
// every Turbo Frame swap, so the new selection re-centers automatically.
export default class extends Controller {
  static targets = ["track"]

  connect() {
    // setTimeout 0: on a fresh page load the strip isn't laid out yet when
    // connect() runs, so scrollIntoView would compute against a 0-width
    // container and no-op. Deferring a macrotask lets layout settle first.
    setTimeout(() => {
      const selected = this.element.querySelector("[aria-current='date']")
      // "instant" skips the container's scroll-smooth CSS so the jump to
      // today doesn't visibly animate on every page load; swipe scrolling
      // still animates via CSS (scroll-snap + scroll-smooth).
      if (selected) selected.scrollIntoView({ inline: "center", block: "nearest", behavior: "instant" })
    }, 0)
  }
}
