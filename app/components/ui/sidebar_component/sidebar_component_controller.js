import ApplicationController from '../../../javascript/controllers/application_controller'

// Ui::SidebarComponent — контроллер тоглера сайдбара-оверлея
//
// Управляет:
//   - Состояниями collapsed (полоска) ↔ expanded (overlay) через
//     классы ui-sidebar--collapsed / ui-sidebar--expanded на обёртке.
//   - Переключением иконки шеврона.
//   - Закрытием развёрнутого сайдбара по клику ВНЕ его зоны.
//
// Обёртка всегда имеет фиксированную ширину полоски и остаётся в
// flex-потоке, поэтому переключение состояния НЕ меняет размер карты
// (flex-1) и не вызывает пересчёт границ на карте.
//
export default class extends ApplicationController {
  static targets = ["wrapper", "sidebar", "chevron"]

  // Подключение контроллера: синхронизируем иконку шеврона и навешиваем
  // обработчик клика вне сайдбара для автозакрытия.
  connect() {
    super.connect()
    this.toggleChevron()
    this._boundOnDocClick = this._onDocumentClick.bind(this)
    document.addEventListener("click", this._boundOnDocClick)
  }

  // Отписка от глобального обработчика при уничтожении контроллера
  disconnect() {
    document.removeEventListener("click", this._boundOnDocClick)
    super.disconnect()
  }

  // ============================================================
  // УПРАВЛЕНИЕ ВИДИМОСТЬЮ
  // ============================================================

  // Переключение состояния сайдбара (collapsed ↔ expanded)
  sidebarToggle(event) {
    // Останавливаем всплытие, чтобы глобальный обработчик клика вне
    // сайдбара не сработал и не закрыл только что открытую панель.
    event.stopPropagation()

    if (this.wrapperTarget.classList.contains("ui-sidebar--expanded")) {
      this._close()
    } else {
      this._open()
    }
  }

  // Глобальный клик: если сайдбар открыт и клик произошёл ВНЕ зоны
  // сайдбара (обёртки) — закрываем его.
  _onDocumentClick(event) {
    if (!this.wrapperTarget.classList.contains("ui-sidebar--expanded")) return
    if (this.wrapperTarget.contains(event.target)) return
    this._close()
  }

  // Развернуть сайдбар — как overlay поверх контента (панель + кнопка absolute).
  _open() {
    this.wrapperTarget.classList.remove("ui-sidebar--collapsed")
    this.wrapperTarget.classList.add("ui-sidebar--expanded")
    this.toggleChevron()
  }

  // Свернуть сайдбар — узкая полоска с шевроном слева.
  _close() {
    this.wrapperTarget.classList.remove("ui-sidebar--expanded")
    this.wrapperTarget.classList.add("ui-sidebar--collapsed")
    this.toggleChevron()
  }

  // Обновление иконки шеврона по текущему состоянию
  toggleChevron() {
    const icon = this.chevronTarget?.querySelector(".mdi")
    if (!icon) return

    const isExpanded = this.wrapperTarget.classList.contains("ui-sidebar--expanded")

    icon.className = isExpanded
      ? "mdi mdi-chevron-double-left text-gray-500"
      : "mdi mdi-chevron-double-right text-gray-500"
  }

  // ============================================================
  // ПАГИНАЦИЯ СПИСКА POI (вызов PoiReflex)
  // ============================================================

  /**
   * Загружает следующую страницу POI в сайдбар.
   * Вызывается с кнопки "Load more"
   * (data-action="click->ui--sidebar-component#loadMore").
   *
   * Параметры берутся из data-атрибутов кнопки:
   *   data-offset, data-sw-lat, data-sw-lng, data-ne-lat, data-ne-lng
   */
  loadMore(e) {
    const btn = e.currentTarget
    const offset = parseInt(btn.dataset.offset) || 0
    const sw_lat = parseFloat(btn.dataset.swLat)
    const sw_lng = parseFloat(btn.dataset.swLng)
    const ne_lat = parseFloat(btn.dataset.neLat)
    const ne_lng = parseFloat(btn.dataset.neLng)

    if (!sw_lat || !sw_lng || !ne_lat || !ne_lng) return

    this.stimulate("PoiReflex#load_more_pois", { offset, sw_lat, sw_lng, ne_lat, ne_lng })
  }
}
