import { Controller } from "@hotwired/stimulus"

/**
 * Контроллер для Poi::ListItemComponent
 * Иконка: mdi-format-list-bulleted
 *
 * Элемент списка POI в сайдбаре.
 * При клике диспатчит событие poi:show-detail для открытия модалки деталей.
 */
export default class extends Controller {
  /**
   * Показывает детали POI при клике на элемент списка
   * Диспатчит событие, которое ловит Poi::DetailComponent
   */
  showDetail() {
    const poiId = parseInt(this.element.dataset.poiId)
    if (poiId) {
      document.dispatchEvent(new CustomEvent("poi:show-detail", { detail: { poiId } }))
    }
  }
}
