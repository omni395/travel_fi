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
      this._closeHandler = this._handleClose.bind(this)
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
   *
   * Idempotency-защита от дублирующего trigger: клик по элемент сайдбара
   * может сработать дважды — через документ-делегирование (_onDocumentClick)
   * и через CustomEvent poi:show-detail (list_item_component). Повторный
   * stimulate того же poiId блокируется, чтобы не слать дублирующий Reflex.
   *
   * @param {CustomEvent|Object} event - событие/объект с poiId в event.detail.poiId
   */
  showDetail(event) {
    const poiId = event.detail?.poiId
    if (!poiId) return
    // Данные для подсветки (например из RewardsComponent#openSource):
    // { tab: "comments", selector: "[data-comment-id='1']" }.
    const highlight = event.detail?.highlight || null
    // Idempotency-гейт пропускается, когда запрошена подсветка: повторный клик на
    // тот же POI из истории наград (RewardsComponent#openSource) должен заново открыть
    // модалку и подсветить комментарий даже если этот POI уже показывался (уже открыт).
    if (!highlight && this._lastPoiId === poiId) return
    this._lastPoiId = poiId
    this._pendingHighlight = highlight
    this.stimulate("PoiReflex#show_detail_modal", poiId)
  }

  /**
   * Lifecycle StimulusReflex — после загрузки контента модалки POI.
   * Переключает нужную вкладку и подсвечивает целевой узел (мигание 3с).
   * @param {HTMLElement} element
   * @param {String} reflex
   */
  reflexSuccess(element, reflex) {
    if (!this._pendingHighlight) return
    const highlight = this._pendingHighlight
    this._pendingHighlight = null

    if (highlight.tab && typeof this._activateTab === "function") {
      this._activateTab(highlight.tab)
    }

    if (highlight.selector) {
      setTimeout(() => this._flashNode(highlight.selector), 0)
    }
  }

  /**
   * Переключает активную вкладку в открытой модалке через ui--tabs-component.
   * @param {String} tab - идентификатор вкладки (details/comments/ratings/gallery)
   */
  _activateTab(tab) {
    const root = this.element.closest("[data-poi--show-component-target='overlay']")
    const tabs = root && root.querySelector("[data-controller='ui--tabs-component']")
    const controller = tabs && this.application.getControllerForElementAndIdentifier(tabs, "ui--tabs-component")
    if (controller && typeof controller.switch === "function") {
      // switch ожидает event; передаём фейковый currentTarget с dataset.tab.
      controller.switch({ currentTarget: { dataset: { tab } } })
    }
  }

  /**
   * Подсвечивает узел зелёной рамкой с пульсацией на 3 секунды.
   * @param {String} selector - CSS-селектор цели
   */
  _flashNode(selector) {
    const root = this.element.closest("[data-poi--show-component-target='overlay']")
    const node = root && root.querySelector(selector)
    if (!node) return
    const HIGHLIGHT_CLASS = "rew-source-highlight"
    node.classList.add(HIGHLIGHT_CLASS)
    setTimeout(() => node.classList.remove(HIGHLIGHT_CLASS), 3000)
  }

  /**
   * Публичный метод закрытия модалки (кнопка X в шапке карточки, бэкдроп, ESC).
   *
   * Диспатчит глобальное событие poi:close-detail, которое обрабатывает ТОЛЬКО
   * "оверлейный" экземпляр (_handleClose). Это критично: кнопка X живёт во
   * вставленном контенте (#poi-detail-modal-body), т.е. на вложенном экземпляре
   * контроллера, у которого нет своего _lastPoiId. Если скрывать/сбрасывать флаг
   * здесь (на вложенном), idempotency-флаг оверлея останется = poiId и повторный
   * клик по той же точке будет заблокирован (баг «второй раз точка не открывается»).
   * Единое место сброса флага и скрытия — _handleClose на оверлее.
   */
  close() {
    document.dispatchEvent(new CustomEvent("poi:close-detail"))
  }

  /**
   * Единый обработчик закрытия на "оверлейном" экземпляре.
   * Слушает poi:close-detail (приходит от кнопки X / бэкдропа / карты) и
   * вызывается напрямую из close() вложенного экземпляра.
   * Сбрасывает idempotency-флаг и скрывает оверлей.
   */
  _handleClose() {
    this._lastPoiId = null
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
