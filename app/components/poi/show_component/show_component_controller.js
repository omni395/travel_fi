import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Poi::ShowComponent Controller
 * Иконка: mdi-information-outline
 *
 * Управляет:
 *   - Слушателем poi:show-detail / poi:close-detail (ТОЛЬКО на "оверлейном" экземпляре,
 *     чтобы избежать двойного stimulate при вложенном рендере контента в #poi-detail-modal-body)
 *   - Делегированием кликов по элементам списка [data-poi-id] (сайдбар):
 *     список вставляется через CableReady inner_html, и Stimulus-контроллеры на
 *     вставленных элементах могут не инициализироваться — поэтому клик обрабатывается
 *     на document уровне.
 *   - Закрытием модалки (close)
 *   - Кнопкой Edit (открывает форму редактирования)
 */
export default class extends ApplicationController {
  connect() {
    super.connect()
    // Слушатель вешаем только на "оверлейном" экземпляре (корень с target overlay).
    // Вставляемый через Reflex контент (шапка+табы) НЕ слушает события — иначе
    // двойной stimulate("PoiReflex#show_detail_modal") при клике на маркер.
    if (this.element.matches("[data-poi--show-component-target='overlay']")) {
      this._showDetailHandler = this.showDetail.bind(this)
      this._closeHandler = this.close.bind(this)
      this._documentClickHandler = this._onDocumentClick.bind(this)
      document.addEventListener("poi:show-detail", this._showDetailHandler)
      document.addEventListener("poi:close-detail", this._closeHandler)
      document.addEventListener("click", this._documentClickHandler)
    }
  }

  disconnect() {
    super.disconnect()
    if (this._showDetailHandler) {
      document.removeEventListener("poi:show-detail", this._showDetailHandler)
      document.removeEventListener("poi:close-detail", this._closeHandler)
      document.removeEventListener("click", this._documentClickHandler)
      this._showDetailHandler = null
      this._closeHandler = null
      this._documentClickHandler = null
    }
  }

  /**
   * Делегирование клика по элементу списка POI в сайдбаре.
   * Элементы списка имеют data-poi-id. Открывает детали того же POI.
   * @param {MouseEvent} event - клик
   */
  _onDocumentClick(event) {
    const item = event.target.closest("[data-poi-id]")
    if (!item) return
    const poiId = parseInt(item.dataset.poiId)
    if (!poiId) return
    this.showDetail({ detail: { poiId } })
  }

  /**
   * Показывает детальную информацию о POI в модалке.
   * Вызывается при клике на маркер карты или элемент списка.
   * @param {CustomEvent|Object} event - событие/объект с poiId в event.detail.poiId
   */
  showDetail(event) {
    const poiId = event.detail?.poiId
    if (!poiId) return
    this.stimulate("PoiReflex#show_detail_modal", poiId)
  }

  /**
   * Закрыть модалку просмотра (скрывает оверлей)
   */
  close() {
    const overlay = this.element.closest("[data-poi--show-component-target='overlay']")
    if (overlay) overlay.classList.add("hidden")
  }

  /**
   * Открыть форму редактирования POI
   */
  editPoi() {
    const poiId = parseInt(this.element.dataset.poiShowComponentPoiId)
    if (!poiId) return
    this.stimulate("PoiReflex#edit_poi", poiId)
  }
}
