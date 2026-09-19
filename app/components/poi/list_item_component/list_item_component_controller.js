import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Контроллер для Poi::ListItemComponent
 * Иконка: mdi-format-list-bulleted
 *
 * Элемент списка POI в сайдбаре.
 * При клике диспатчит событие poi:show-detail для открытия модалки деталей.
 */
export default class extends ApplicationController {
  /**
   * Показывает детали POI при клике на элемент списка
   * Диспатчит событие, которое ловит Poi::ShowComponent (оверлей)
   */
  showDetail() {
    const poiId = parseInt(this.element.dataset.poiId)
    if (poiId) {
      document.dispatchEvent(new CustomEvent("poi:show-detail", { detail: { poiId } }))
    }
  }
}
