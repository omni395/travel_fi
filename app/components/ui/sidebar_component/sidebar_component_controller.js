import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Ui::SidebarComponent — контроллер тоглера сайдбара-оверлея
 *
 * Управляет:
 *   - Состояниями collapsed ↔ expanded через классы ui-sidebar--collapsed / ui-sidebar--expanded.
 *   - Переключением иконки шеврона.
 *   - Закрытием развёрнутого сайдбара по клику ВНЕ его зоны.
 *
 * Targets:
 *   wrapper - внешняя обертка
 *   sidebar - панель контента
 *   chevron - кнопка переключения
 */
export default class extends Controller {
  static targets = ["wrapper", "sidebar", "chevron"]

  connect() {
    this.toggleChevron()
    this._boundOnDocClick = this._onDocumentClick.bind(this)
    document.addEventListener("click", this._boundOnDocClick)
  }

  disconnect() {
    document.removeEventListener("click", this._boundOnDocClick)
  }

  // ============================================================
  // УПРАВЛЕНИЕ ВИДИМОСТЬЮ
  // ============================================================

  sidebarToggle(event) {
    event.stopPropagation()

    if (this.wrapperTarget.classList.contains("ui-sidebar--expanded")) {
      this._close()
    } else {
      this._open()
    }
  }

  _onDocumentClick(event) {
    if (!this.wrapperTarget.classList.contains("ui-sidebar--expanded")) return
    if (this.wrapperTarget.contains(event.target)) return
    this._close()
  }

  _open() {
    this.wrapperTarget.classList.remove("ui-sidebar--collapsed")
    this.wrapperTarget.classList.add("ui-sidebar--expanded")
    this.toggleChevron()
  }

  _close() {
    this.wrapperTarget.classList.remove("ui-sidebar--expanded")
    this.wrapperTarget.classList.add("ui-sidebar--collapsed")
    this.toggleChevron()
  }

  toggleChevron() {
    const icon = this.chevronTarget?.querySelector(".mdi")
    if (!icon) return

    const isExpanded = this.wrapperTarget.classList.contains("ui-sidebar--expanded")

    if (isExpanded) {
      icon.classList.remove("mdi-chevron-double-right")
      icon.classList.add("mdi-chevron-double-left")
    } else {
      icon.classList.remove("mdi-chevron-double-left")
      icon.classList.add("mdi-chevron-double-right")
    }
  }

  // ============================================================
  // ПАГИНАЦИЯ СПИСКА POI (вызов PoiReflex)
  // ============================================================

  /**
   * Загружает следующую страницу POI в сайдбар.
   * @param {Event} e 
   */
  loadMore(e) {
    const btn = e.currentTarget
    const offset = parseInt(btn.dataset.offset) || 0
    const sw_lat = parseFloat(btn.dataset.swLat)
    const sw_lng = parseFloat(btn.dataset.swLng)
    const ne_lat = parseFloat(btn.dataset.neLat)
    const ne_lng = parseFloat(btn.dataset.neLng)

    if (!sw_lat || !sw_lng || !ne_lat || !ne_lng) return

    if (typeof this.stimulate === "function") {
      this.stimulate("PoiReflex#load_more_pois", { offset, sw_lat, sw_lng, ne_lat, ne_lng })
    }
  }
}
