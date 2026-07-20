// Poi::FiltersComponent — фильтрация категорий POI через Apply-кнопку
//
// Логика:
//   - Чекбоксы категорий + текст поиска → только UI (без сервера)
//   - Кнопка "Apply" → один StimulusReflex для фильтрации
//   - Select All — ссылка, переключает все чекбоксы
//   - Сброс → очищает поля + StimulusReflex для снятия фильтра
//
import ApplicationController from "../../../javascript/controllers/application_controller"

export default class extends ApplicationController {
  static targets = ["searchInput", "summary", "applyBtn", "selectAllText"]

  connect() {
    super.connect()
    // Установить начальное состояние текста Select All / Deselect All
    this._updateSummary()
  }

  /**
   * StimulusReflex lifecycle — после успешного рефлекса
   * Триггерит map_component_controller для перезагрузки маркеров карты
   */
  afterReflex(element, reflex) {
    console.log('[FILTERS] afterReflex — reflex:', reflex)
    if (reflex.includes("PoiReflex#apply_filters") || reflex.includes("PoiReflex#reset_filters")) {
      document.dispatchEvent(new CustomEvent("poi:reload-features"))
    }
  }

  /**
   * Select All / Deselect All
   * Переключает состояние всех чекбоксов. Без сервера.
   */
  toggleAll() {
    const allCbs = this.element.querySelectorAll('input[type="checkbox"][value]')
    const allChecked = Array.from(allCbs).every((cb) => cb.checked)
    const newState = !allChecked
    allCbs.forEach((cb) => (cb.checked = newState))
    this._updateSummary()
  }

  /**
   * Изменение индивидуального чекбокса категории
   * Без сервера.
   */
  onCategoryChange() {
    this._updateSummary()
  }

  /**
   * Apply — отправляет фильтры на сервер
   * Сохраняет в session[:poi_filters] и перезагружает POI
   * Если карта ещё не инициализирована (bounds нет) — ничего не делает
   */
  applyFilters() {
    const mapEl = document.querySelector('[data-controller="poi--map-component"]')
    if (!mapEl || !mapEl.dataset.swLat) {
      console.warn("[FILTERS] Map not ready yet — skipping apply")
      return
    }

    const query = this.searchInputTarget?.value?.trim() || ""
    const categoryIds = Array.from(
      this.element.querySelectorAll('input[type="checkbox"][value]:checked')
    ).map((cb) => parseInt(cb.value))

    const reflexParams = {
      query,
      category_ids: categoryIds,
      sw_lat: parseFloat(mapEl.dataset.swLat),
      sw_lng: parseFloat(mapEl.dataset.swLng),
      ne_lat: parseFloat(mapEl.dataset.neLat),
      ne_lng: parseFloat(mapEl.dataset.neLng)
    }
    console.log('[FILTERS] applyFilters — params:', reflexParams)

    this.stimulate("PoiReflex#apply_filters", reflexParams)
  }

  /**
   * Сброс: очистить поля + снять фильтр на сервере + перезагрузить POI
   */
  resetFilters() {
    const mapEl = document.querySelector('[data-controller="poi--map-component"]')
    if (!mapEl || !mapEl.dataset.swLat) {
      console.warn("[FILTERS] Map not ready yet — skipping reset")
      return
    }

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = ""
    }

    // Сбросить все чекбоксы в выбранное состояние
    this.element
      .querySelectorAll('input[type="checkbox"]')
      .forEach((cb) => (cb.checked = true))

    this._updateSummary()

    const resetParams = {
      sw_lat: parseFloat(mapEl.dataset.swLat),
      sw_lng: parseFloat(mapEl.dataset.swLng),
      ne_lat: parseFloat(mapEl.dataset.neLat),
      ne_lng: parseFloat(mapEl.dataset.neLng)
    }
    console.log('[FILTERS] resetFilters — params:', resetParams)

    this.stimulate("PoiReflex#reset_filters", resetParams)
  }

  // ============================================================
  // ПРИВАТНЫЕ
  // ============================================================

  /**
   * Обновляет текст кнопки-суммари и переключает Select All / Deselect All
   */
  _updateSummary() {
    const checked = Array.from(
      this.element.querySelectorAll('input[type="checkbox"][value]:checked')
    )
    const total = this.element.querySelectorAll('input[type="checkbox"][value]').length

    if (checked.length === total) {
      this.summaryTarget.textContent = this.element.dataset.allLabel || "All categories"
    } else {
      this.summaryTarget.textContent =
        `${checked.length} ${this.element.dataset.selectedLabel || "selected"}`
    }

    // Переключаем текст Select All / Deselect All
    if (this.hasSelectAllTextTarget) {
      this.selectAllTextTarget.textContent = checked.length === total
        ? this.element.dataset.deselectAllLabel || "Deselect All"
        : this.element.dataset.selectAllLabel || "Select All"
    }
  }
}
