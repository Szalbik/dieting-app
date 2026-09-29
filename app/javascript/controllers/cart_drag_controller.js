import { Controller } from "@hotwired/stimulus"

const HOLD_MS = 2000
const MOVE_TOLERANCE_PX = 10
const EDGE_PX = 60
const SCROLL_STEP = 14

// Long-press (HOLD_MS) on an unbought row lifts it; drop on any
// [data-drop-category-id] element to PATCH the row's move URL.
// Lives inside the shopping_cart frame, so a frame replace disconnects it
// and cancels any drag in flight.
export default class extends Controller {
  static targets = ["row", "tiles"]

  connect() {
    this.state = null
    this.onDown = this.onDown.bind(this)
    this.onMove = this.onMove.bind(this)
    this.onUp = this.onUp.bind(this)
    this.onCancel = this.onCancel.bind(this)
    this.onKey = this.onKey.bind(this)
    this.onTouchMove = this.onTouchMove.bind(this)
    this.onContextMenu = this.onContextMenu.bind(this)
    this.swallowClick = this.swallowClick.bind(this)
    this.element.addEventListener("pointerdown", this.onDown)
    this.element.addEventListener("contextmenu", this.onContextMenu)
  }

  disconnect() {
    this.element.removeEventListener("pointerdown", this.onDown)
    this.element.removeEventListener("contextmenu", this.onContextMenu)
    this.cleanup()
  }

  onDown(event) {
    if (this.state || !navigator.onLine || event.button !== 0) return
    const row = event.target.closest("[data-cart-drag-target='row']")
    if (!row || !this.element.contains(row)) return

    this.state = {
      row, pointerId: event.pointerId,
      startX: event.clientX, startY: event.clientY, x: event.clientX, y: event.clientY,
      active: false, ghost: null, target: null, revealed: [], scrollTimer: null,
    }
    row.style.backgroundImage = "linear-gradient(to right, var(--color-brand-peach-soft, #fde3cf), var(--color-brand-peach-soft, #fde3cf))"
    row.style.backgroundRepeat = "no-repeat"
    row.style.backgroundSize = "0% 100%"
    // Force a reflow so the transition starts from 0%.
    void row.offsetWidth
    row.style.transition = `background-size ${HOLD_MS}ms linear`
    row.style.backgroundSize = "100% 100%"

    this.state.timer = setTimeout(() => this.activate(), HOLD_MS)
    document.addEventListener("pointermove", this.onMove)
    document.addEventListener("pointerup", this.onUp)
    document.addEventListener("pointercancel", this.onCancel)
    document.addEventListener("keydown", this.onKey)
    document.addEventListener("touchmove", this.onTouchMove, { passive: false })
  }

  onContextMenu(event) {
    if (this.state) event.preventDefault()
  }

  onTouchMove(event) {
    if (this.state?.active) event.preventDefault()
  }

  onMove(event) {
    const s = this.state
    if (!s || event.pointerId !== s.pointerId) return
    s.x = event.clientX
    s.y = event.clientY
    if (!s.active) {
      if (Math.hypot(s.x - s.startX, s.y - s.startY) > MOVE_TOLERANCE_PX) this.cleanup()
      return
    }
    this.track()
  }

  activate() {
    const s = this.state
    if (!s) return
    s.active = true
    s.row.style.transition = ""
    s.row.style.backgroundImage = ""
    navigator.vibrate?.(30)
    window.getSelection()?.removeAllRanges()

    const rect = s.row.getBoundingClientRect()
    s.offsetX = s.startX - rect.left
    s.offsetY = s.startY - rect.top
    const ghost = s.row.cloneNode(true)
    ghost.removeAttribute("id")
    ghost.style.cssText = `position:fixed;left:0;top:0;width:${rect.width}px;pointer-events:none;z-index:1000;` +
      "transform-origin:top left;box-shadow:0 12px 28px rgba(0,0,0,.25);opacity:.95"
    document.body.appendChild(ghost)
    s.ghost = ghost
    s.row.style.opacity = "0.35"

    document.querySelectorAll("[data-tabs-target='panel'][hidden]").forEach(panel => {
      panel.hidden = false
      s.revealed.push(panel)
    })
    if (this.hasTilesTarget) {
      this.tilesTarget.classList.remove("hidden")
      this.tilesTarget.classList.add("grid")
    }
    // Swallow the click the browser fires on release (press may start on a button).
    document.addEventListener("click", this.swallowClick, true)

    s.scrollTimer = setInterval(() => this.autoScroll(), 16)
    this.track()
  }

  track() {
    const s = this.state
    s.ghost.style.transform = `translate(${s.x - s.offsetX}px, ${s.y - s.offsetY}px) scale(1.03)`
    const el = document.elementFromPoint(s.x, s.y)
    const target = el?.closest("[data-drop-category-id]") || null
    if (target === s.target) return
    s.target?.classList.remove("ring-2", "ring-brand-navy")
    target?.classList.add("ring-2", "ring-brand-navy")
    s.target = target
  }

  autoScroll() {
    const s = this.state
    if (!s?.active) return
    if (s.y < EDGE_PX) window.scrollBy(0, -SCROLL_STEP)
    else if (s.y > window.innerHeight - EDGE_PX) window.scrollBy(0, SCROLL_STEP)
    else return
    this.track()
  }

  swallowClick(event) {
    event.preventDefault()
    event.stopPropagation()
    document.removeEventListener("click", this.swallowClick, true)
  }

  async onUp(event) {
    const s = this.state
    if (!s || event.pointerId !== s.pointerId) return
    const categoryId = s.active ? s.target?.dataset.dropCategoryId : null
    const { row } = s
    const url = row.dataset.moveUrl
    const changed = categoryId && categoryId !== row.dataset.categoryId
    this.cleanup()
    if (!changed) return

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content,
          "Accept": "text/vnd.turbo-stream.html",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({ category_id: categoryId }),
      })
      if (response.ok) Turbo.renderStreamMessage(await response.text())
    } catch (_) {
      // No retry: the row stays where it was.
    }
  }

  onCancel(event) {
    if (this.state && event.pointerId === this.state.pointerId) this.cleanup()
  }

  onKey(event) {
    if (event.key === "Escape") this.cleanup()
  }

  cleanup() {
    const s = this.state
    document.removeEventListener("pointermove", this.onMove)
    document.removeEventListener("pointerup", this.onUp)
    document.removeEventListener("pointercancel", this.onCancel)
    document.removeEventListener("keydown", this.onKey)
    document.removeEventListener("touchmove", this.onTouchMove)
    if (!s) return
    this.state = null
    clearTimeout(s.timer)
    clearInterval(s.scrollTimer)
    s.ghost?.remove()
    s.target?.classList.remove("ring-2", "ring-brand-navy")
    s.revealed.forEach(panel => { panel.hidden = true })
    if (this.hasTilesTarget) {
      this.tilesTarget.classList.add("hidden")
      this.tilesTarget.classList.remove("grid")
    }
    s.row.style.cssText = ""
    // A click swallow armed on activation must not outlive a click-less release (pointercancel etc.).
    if (s.active) setTimeout(() => document.removeEventListener("click", this.swallowClick, true), 100)
  }
}
