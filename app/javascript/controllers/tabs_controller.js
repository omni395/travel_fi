import { Controller } from "@hotwired/stimulus"

/**
 * Tabs Controller
 *
 * Управляет переключением табов с targets tab/panel.
 * Используется в admin/users/show.html.erb
 */
export default class extends Controller {
  static targets = ["tab", "panel"]

  /**
   * Переключает активный таб
   * @param {Event} event
   */
  switch(event) {
    const tabName = event.currentTarget.dataset.tab
    if (!tabName) return

    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === tabName
      tab.classList.toggle("tab-active", isActive)
    })

    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.dataset.tab !== tabName)
    })
  }
}
