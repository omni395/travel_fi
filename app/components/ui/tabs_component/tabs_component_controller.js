import { Controller } from "@hotwired/stimulus"

/**
 * Ui::TabsComponent — универсальный контроллер для вкладок
 *
 * Targets:
 *   tab   — кнопки вкладок
 *   panel — панели содержимого
 *
 * Values:
 *   activeTab — идентификатор активной вкладки (String, default: "")
 *
 * Использование:
 *   <div data-controller="ui--tabs-component" data-ui--tabs-component-active-tab-value="activity">
 *     <button data-ui--tabs-component-target="tab" data-action="click->ui--tabs-component#switch" data-tab="activity">Activity</button>
 *     <button data-ui--tabs-component-target="tab" data-action="click->ui--tabs-component#switch" data-tab="wallet">Wallet</button>
 *     <div data-ui--tabs-component-target="panel" data-tab="activity">Content</div>
 *     <div data-ui--tabs-component-target="panel" data-tab="wallet" class="hidden">Content</div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { activeTab: { type: String, default: "" } }

  connect() {
    if (this.activeTabValue) {
      this._activate(this.activeTabValue)
    }
  }

  /**
   * Переключает вкладку по клику
   * @param {Event} event - click событие
   */
  switch(event) {
    const tab = event.currentTarget.dataset.tab
    if (tab) {
      this.activeTabValue = tab
      this._activate(tab)
    }
  }

  /**
   * Активирует указанную вкладку:
   * - переключает активные CSS-классы кнопок
   * - показывает/скрывает панели
   *
   * @param {string} tab - идентификатор вкладки
   */
  _activate(tab) {
    const activeClasses = ["is-active", "bg-primary", "text-primary", "shadow-sm", "border-secondary", "font-bold"]
    const inactiveClasses = ["text-secondary", "hover:text-primary"]

    this.tabTargets.forEach(btn => {
      const isActive = btn.dataset.tab === tab
      if (isActive) {
        btn.classList.add(...activeClasses)
        btn.classList.remove(...inactiveClasses)
      } else {
        btn.classList.remove(...activeClasses)
        btn.classList.add(...inactiveClasses)
      }
    })

    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.dataset.tab !== tab)
    })
  }
}
