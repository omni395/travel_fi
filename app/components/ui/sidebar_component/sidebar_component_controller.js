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

    // На мобильных сайдбар скрыт по умолчанию
    if (this.isMobile()) {
      this.sidebarTarget.classList.add(this.hiddenClass)
    }
  }

  // ============================================================
  // УПРАВЛЕНИЕ ВИДИМОСТЬЮ
  // ============================================================

  // Переключение видимости сайдбара
  sidebarToggle() {
    this.sidebarTarget.classList.toggle(this.hiddenClass)
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
