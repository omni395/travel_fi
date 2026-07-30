import { Controller } from "@hotwired/stimulus"

/**
 * Admin::PoiCategories::PoiCategory::ShowComponent — контроллер детальной страницы категории
 *
 * Actions:
 * - openOsmImport: найти OsmImportComponent на странице и показать его overlay
 *
 * Слушает custom event 'osm-import:open' от PoisListComponent
 */
export default class extends Controller {
  /**
   * Открывает диалог импорта из OSM
   * Находит overlay OsmImportComponent и убирает hidden
   */
  openOsmImport() {
    const overlay = document.querySelector(
      "[data-admin--poi-categories--poi-category--osm-import-component-target='overlay']"
    )
    if (overlay) {
      overlay.classList.remove("hidden")
    }
  }

  connect() {
    this._boundOpen = () => this.openOsmImport()
    document.addEventListener("osm-import:open", this._boundOpen)
  }

  disconnect() {
    document.removeEventListener("osm-import:open", this._boundOpen)
  }
}
