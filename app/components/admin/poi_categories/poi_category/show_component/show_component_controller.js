import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::PoiCategory::ShowComponent — контроллер детальной страницы категории
 *
 * Actions:
 * - openOsmImport: найти OsmImportComponent на странице и показать его overlay
 * - goToPage: переключить страницу пагинации аудита через Reflex
 *
 * Слушает custom event 'osm-import:open' от PoisListComponent
 */
export default class extends ApplicationController {
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

  /**
   * Переключает страницу пагинации ленты аудита (вкладка Audit Log)
   */
  goToPage(event) {
    const page = event.currentTarget.dataset.page
    const categorySlug = document.querySelector("[data-admin-poi-category-id]")?.dataset.adminPoiCategoryId
    if (page && categorySlug) {
      this.stimulate("Admin::PoiCategoriesReflex#audit_page", { category_id: categorySlug, audit_page: page })
    }
  }

  connect() {
    super.connect()
    this._boundOpen = () => this.openOsmImport()
    document.addEventListener("osm-import:open", this._boundOpen)
  }

  disconnect() {
    document.removeEventListener("osm-import:open", this._boundOpen)
  }
}
