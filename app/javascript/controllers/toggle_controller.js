import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["element"];

  toggle() {
    this.element.classList.toggle("translate-x-5");
    this.element.classList.toggle("translate-x-0");
  }
}