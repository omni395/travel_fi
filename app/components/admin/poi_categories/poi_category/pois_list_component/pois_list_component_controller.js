import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::PoiCategory::PoisListComponent — список POI категории
 *
 * Actions:
 * - openOsmImport: открыть диалог импорта из OSM через custom event
 * - goToPage: переключить страницу пагинации списка POI через Reflex
 */
export default class extends ApplicationController {
  /**
   * Открывает диалог импорта из OSM
   * Диспатчит custom event, который слушает show_component_controller
   */
  openOsmImport() {
    document.dispatchEvent(new CustomEvent("osm-import:open"))
  }

  /**
   * Переключает страницу пагинации списка POI (вкладка POIs)
   */
  goToPage(event) {
    const page = event.currentTarget.dataset.page
    const categorySlug = document.querySelector("[data-admin-poi-category-id]")?.dataset.adminPoiCategoryId
    if (page && categorySlug) {
      this.stimulate("Admin::PoiCategoriesReflex#pois_page", { category_id: categorySlug, pois_page: page })
    }
  }

  connect() {
    super.connect()
  }
}
