// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["toggle"];
  static values = { animation: String } // "slide", "fade", or leave empty for basic toggle

  toggle() {
    if (this.animationValue === "slide") {
      if (this.toggleTarget.classList.contains("hidden")) {
        this.slideDown(this.toggleTarget);
      } else {
        this.slideUp(this.toggleTarget);
      }
    } else if (this.animationValue === "fade") {
      if (this.toggleTarget.classList.contains("hidden")) {
        this.fadeIn(this.toggleTarget);
      } else {
        this.fadeOut(this.toggleTarget);
      }
    } else {
      // Default simple toggle without animation.
      this.toggleTarget.classList.toggle("hidden");
    }
  }

  // Slide up: collapse the element.
  slideUp(element) {
    element.style.height = `${element.scrollHeight}px`;
    // Force reflow:
    element.offsetHeight;
    element.style.transition = "height 300ms";
    element.style.height = "0px";
    element.addEventListener("transitionend", () => {
      element.classList.add("hidden");
      element.style.removeProperty("height");
      element.style.removeProperty("transition");
    }, { once: true });
  }

  // Slide down: expand the element.
  slideDown(element) {
    element.classList.remove("hidden");
    element.style.height = "0px";
    // Force reflow:
    element.offsetHeight;
    element.style.transition = "height 300ms";
    element.style.height = `${element.scrollHeight}px`;
    element.addEventListener("transitionend", () => {
      element.style.removeProperty("height");
      element.style.removeProperty("transition");
    }, { once: true });
  }

  // Fade out: reduce opacity then hide.
  fadeOut(element) {
    element.style.transition = "opacity 300ms";
    element.style.opacity = "0";
    element.addEventListener("transitionend", () => {
      element.classList.add("hidden");
      element.style.removeProperty("opacity");
      element.style.removeProperty("transition");
    }, { once: true });
  }

  // Fade in: show element and increase opacity.
  fadeIn(element) {
    element.classList.remove("hidden");
    element.style.opacity = "0";
    // Force reflow:
    element.offsetHeight;
    element.style.transition = "opacity 300ms";
    element.style.opacity = "1";
    element.addEventListener("transitionend", () => {
      element.style.removeProperty("opacity");
      element.style.removeProperty("transition");
    }, { once: true });
  }
}
