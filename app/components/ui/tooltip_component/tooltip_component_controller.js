import { Controller } from "@hotwired/stimulus"

/**
 * Ui::TooltipComponent Controller
 *
 * Управляет интерактивным показом/скрытием тултипа при click/hover.
 */
export default class extends Controller {
  static targets = ["panel"]
  static values = { trigger: String }

  connect() {
    this.isOpen = false
  }

  show() {
    if (this.triggerValue === "hover" && this.hasPanelTarget) {
      this.panelTarget.classList.remove("hidden")
    }
  }

  hide() {
    if (this.triggerValue === "hover" && this.hasPanelTarget) {
      this.panelTarget.classList.add("hidden")
    }
  }

  toggle(event) {
    if (this.triggerValue === "click" && this.hasPanelTarget) {
      event.preventDefault()
      this.isOpen = !this.isOpen
      this.panelTarget.classList.toggle("hidden", !this.isOpen)
    }
  }
}
