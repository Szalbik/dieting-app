// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"

import 'alpine-turbo-drive-adapter'
import Alpine from 'alpinejs'

window.Alpine = Alpine
Alpine.start()

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js").catch((e) => console.error("SW registration failed", e))
  })
}
