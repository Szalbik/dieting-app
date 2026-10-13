// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"

import 'alpine-turbo-drive-adapter'
import Alpine from 'alpinejs'

window.Alpine = Alpine
Alpine.start()

// Turbo morph syncs attributes to the server HTML, which strips Alpine's inline `display: none`
// from x-show elements — e.g. the mobile menu then sits invisibly over the page eating taps.
document.addEventListener("turbo:before-morph-attribute", (event) => {
  if (event.detail.attributeName === "style" && event.target.hasAttribute("x-show")) event.preventDefault()
})

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch((e) => console.error("SW registration failed", e))
  })
}
