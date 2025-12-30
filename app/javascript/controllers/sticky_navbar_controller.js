import { Controller } from "@hotwired/stimulus"

// Fixes Safari iOS fixed positioning issue when address bar shows/hides during scroll
export default class extends Controller {
  connect() {
    // Only apply fix on iOS Safari
    if (this.isIOSSafari()) {
      this.setupSafariFix()
    }
  }

  disconnect() {
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler)
    }
    if (this.scrollHandler) {
      window.removeEventListener('scroll', this.scrollHandler, { passive: true })
    }
    if (this.orientationHandler) {
      window.removeEventListener('orientationchange', this.orientationHandler)
    }
  }

  isIOSSafari() {
    const ua = window.navigator.userAgent
    const iOS = !!ua.match(/iPad|iPhone|iPod/)
    const webkit = !!ua.match(/WebKit/)
    const iOSSafari = iOS && webkit && !ua.match(/CriOS/)
    return iOSSafari
  }

  setupSafariFix() {
    // Store the initial viewport height
    let lastViewportHeight = window.innerHeight
    let ticking = false
    
    // Function to update the navbar position
    const updatePosition = () => {
      const currentViewportHeight = window.innerHeight
      
      // When viewport height changes (address bar shows/hides), 
      // force the navbar to stay at bottom: 0
      if (currentViewportHeight !== lastViewportHeight) {
        // Use transform to ensure it stays at the bottom
        // This works better than just setting bottom in Safari
        this.element.style.transform = 'translate3d(0, 0, 0)'
        this.element.style.bottom = '0px'
        
        // Force a repaint to ensure Safari applies the change
        void this.element.offsetHeight
        
        lastViewportHeight = currentViewportHeight
      }
      ticking = false
    }
    
    // Throttled update function
    const requestUpdate = () => {
      if (!ticking) {
        requestAnimationFrame(updatePosition)
        ticking = true
      }
    }
    
    // Update on scroll (when address bar shows/hides)
    this.scrollHandler = () => {
      requestUpdate()
    }
    
    // Update on resize
    this.resizeHandler = () => {
      requestUpdate()
    }
    
    // Also listen for orientation changes
    this.orientationHandler = () => {
      setTimeout(updatePosition, 100)
    }
    
    window.addEventListener('scroll', this.scrollHandler, { passive: true })
    window.addEventListener('resize', this.resizeHandler)
    window.addEventListener('orientationchange', this.orientationHandler)
    
    // Set initial position
    updatePosition()
  }
}

