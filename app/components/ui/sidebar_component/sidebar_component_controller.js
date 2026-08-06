import ApplicationController from '../../../javascript/controllers/application_controller'

// Ui::SidebarComponent — контроллер тоглера сайдбара
//
// Управляет:
//   - Сворачиванием/разворачиванием через ui-sidebar--hidden
//   - Переключением иконки шеврона
//
export default class extends ApplicationController {
  static targets = ["sidebar"]
  static classes = ["hidden"]

  connect() {
    super.connect()

    // Сайдбар скрыт по умолчанию на ВСЕХ экранах — остаётся узкая колонка с шевроном,
    // контент справа (две колонки). Открывается шевроном как оверлей поверх контента.
    this.sidebarTarget.classList.add(this.hiddenClass)
  }

  // ============================================================
  // УПРАВЛЕНИЕ ВИДИМОСТЬЮ
  // ============================================================

  // Переключение видимости сайдбара
  sidebarToggle() {
    if (this.sidebarTarget.classList.contains(this.hiddenClass)) {
      this._open()
    } else {
      this._close()
    }
  }

  /**
   * Открыть сайдбар — как оверлей поверх контента (сайдбар absolute, контент flex-1 на всю ширину)
   */
  _open() {
    this.sidebarTarget.classList.remove(this.hiddenClass)
    this.element.classList.add("ui-sidebar--overlay")
    this.toggleChevron()
  }

  /**
   * Закрыть сайдбар — узкая колонка слева (две колонки), контент справа
   */
  _close() {
    this.sidebarTarget.classList.add(this.hiddenClass)
    this.element.classList.remove("ui-sidebar--overlay")
    this.toggleChevron()
  }

  // Обновление иконки шеврона
  toggleChevron() {
    const btn = this.element.querySelector('[data-action*="ui--sidebar-component#sidebarToggle"]')
    if (!btn) return
    const icon = btn.querySelector(".mdi")
    if (!icon) return

    const isHidden = this.sidebarTarget.classList.contains(this.hiddenClass)

    icon.className = isHidden
      ? "mdi mdi-chevron-double-right text-gray-500"
      : "mdi mdi-chevron-double-left text-gray-500"
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

  // Проверка мобильного устройства
  isMobile() {
    return window.matchMedia("(max-width: 767px)").matches
  }
}
