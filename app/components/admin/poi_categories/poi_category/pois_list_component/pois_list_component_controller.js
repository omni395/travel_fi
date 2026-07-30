import { Controller } from "@hotwired/stimulus"

/**
 * Admin::PoiCategories::PoiCategory::PoisListComponent — список POI категории
 *
 * Actions:
 * - openOsmImport: открыть диалог импорта из OSM через custom event
 */
export default class extends Controller {
  /**
   * Открывает диалог импорта из OSM
   * Диспатчит custom event, который слушает show_component_controller
   */
  openOsmImport() {
    document.dispatchEvent(new CustomEvent("osm-import:open"))
  }

  connect() {
    // Пассивный контроллер
  }
}
