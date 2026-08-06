import ApplicationController from '../../../javascript/controllers/application_controller'
import Map from "ol/Map"
import View from "ol/View"
import TileLayer from "ol/layer/Tile"
import VectorLayer from "ol/layer/Vector"
import VectorSource from "ol/source/Vector"
import OSM from "ol/source/OSM"
import Feature from "ol/Feature"
import Point from "ol/geom/Point"
import Circle from "ol/geom/Circle"
import { fromLonLat, toLonLat } from "ol/proj"
import { Circle as CircleStyle, Fill, Stroke, Style } from "ol/style"
import DragPan from "ol/interaction/DragPan"

/**
 * Poi::FormComponent Controller
 * Иконка: mdi-form-textbox
 *
 * Управляет:
 *   - Открытием/закрытием формы (create/edit)
 *   - OpenLayers мини-картой с маркером в центре (Overlay)
 *   - Круг 100м (только контур, без заливки) как Feature
 *   - Выбором категории через Ui::DropdownComponent
 *   - Загрузкой динамических полей категории
 *   - Рендером полей (boolean/select/multiselect/number/text)
 *   - Отображением координат под картой
 *   - Reverse geocoding через HuggingFace (moveend с debounce)
 */
export default class extends ApplicationController {
  static targets = [
    "categoryDropdown", "categoryName", "categoryId",
    "fieldsContainer",
    "latitude", "longitude", "miniMap",
    "coordDisplayLat", "coordDisplayLng",
    "photosInput", "photosPreview", "removePhotosInput"
  ]

  static MAX_RADIUS_METERS = 100
  static REVERSE_GEOCODE_DEBOUNCE_MS = 800

  connect() {
    super.connect()
    document.addEventListener("poi:open-modal", this.open.bind(this))
  }

  disconnect() {
    super.disconnect()
    document.removeEventListener("poi:open-modal", this.open.bind(this))
    if (this._map) {
      this._map.setTarget(null)
      this._map = null
    }
    clearTimeout(this._reverseGeocodeTimer)
  }

  // ============================================================
  // УПРАВЛЕНИЕ ФОРМОЙ
  // ============================================================

  /**
   * Открыть модалку — инициализировать карту
   */
  open() {
    const overlay = this.element.closest("[data-poi--show-component-target='overlay']")
    if (overlay) overlay.classList.remove("hidden")

    // Показываем контейнер формы, скрываем контейнер детального просмотра
    const formContent = document.getElementById("poi-form-content")
    if (formContent) formContent.classList.remove("hidden")
    const detailBody = document.getElementById("poi-detail-modal-body")
    if (detailBody) detailBody.classList.add("hidden")

    // Инициализируем карту при первом открытии (только один раз)
    if (!this._map) {
      setTimeout(() => this.initMiniMap(), 100)
    } else {
      this._map.updateSize()
    }
  }

  /**
   * Закрыть модалку
   */
  close() {
    const overlay = this.element.closest("[data-poi--show-component-target='overlay']")
    if (overlay) overlay.classList.add("hidden")
  }

  /**
   * Открыть выбор фото (системный пикер: галерея + камера на мобильных).
   */
  openGallery() {
    if (this.hasPhotosInputTarget) {
      this.photosInputTarget.click()
    }
  }

  // ============================================================
  // ВЫБОР КАТЕГОРИИ
  // ============================================================

  /**
   * Обработчик выбора категории из Ui::DropdownComponent
   * Обновляет скрытое поле и триггерит загрузку динамических полей
   *
   * @param {Event} e
   */
  selectCategory(e) {
    const id = e.currentTarget.dataset.categoryId
    const name = e.currentTarget.dataset.categoryName

    if (this.hasCategoryIdTarget) {
      this.categoryIdTarget.value = id
    }
    if (this.hasCategoryNameTarget) {
      this.categoryNameTarget.textContent = name
    }

    // Закрываем дропдаун
    const dropdown = e.currentTarget.closest('[data-controller="ui--dropdown-component"]')
    const menu = dropdown?.querySelector('[data-ui--dropdown-component-target="menu"]')
    if (menu) menu.classList.add("hidden")

    // Загружаем поля для выбранной категории
    this.loadFields(id)
  }

  /**
   * Загружает динамические поля для выбранной категории
   *
   * @param {string} categoryId
   */
  loadFields(categoryId) {
    if (!categoryId) return

    fetch(`/poi_categories/${categoryId}/fields.json`)
      .then(r => r.json())
      .then(data => this.renderFields(data))
      .catch(e => console.error("Fields load error:", e))
  }

  // ============================================================
  // МИНИ-КАРТА
  // ============================================================

  /**
   * Инициализация OL мини-карты
   * Круг 100м — антифрод, центрирован на местоположении пользователя.
   * Маркер — точка (CircleStyle Feature), ставится кликом.
   * Карта статична по умолчанию (только зум).
   * При изменении зума включается панорамирование в пределах круга.
   */
  initMiniMap() {
    // Берём координаты из data-атрибутов карты (установлены map_component_controller при GPS)
    const mapEl = document.querySelector('[data-controller="poi--map-component"] .poi-map')
    const userLat = mapEl?.dataset.userLat
    const userLng = mapEl?.dataset.userLng

    const lat = parseFloat(this.element.dataset.poiFormComponentInitialLat) || parseFloat(userLat) || 0
    const lng = parseFloat(this.element.dataset.poiFormComponentInitialLng) || parseFloat(userLng) || 0
    const center = fromLonLat([lng || 0, lat || 0])

    // Слой подложки OSM
    const tileLayer = new TileLayer({
      source: new OSM()
    })

    // Векторный слой для маркера и круга
    this._vectorSource = new VectorSource({ features: [] })
    const vectorLayer = new VectorLayer({
      source: this._vectorSource
    })

    this._map = new Map({
      target: this.miniMapTarget,
      layers: [tileLayer, vectorLayer],
      view: new View({
        center,
        zoom: 17,
        maxZoom: 19,
        enableRotation: false
      }),
      controls: []
    })

    // Отключаем панорамирование (статичная карта)
    this._map.getInteractions().forEach((interaction) => {
      if (interaction instanceof DragPan) {
        interaction.setActive(false)
      }
    })

    // Круг 100м (антифрод, центр = позиция пользователя, НЕ двигается)
    this._userCenter = center
    this._circleFeature = new Feature({
      geometry: new Circle(center, this.constructor.MAX_RADIUS_METERS)
    })
    this._circleFeature.setStyle(
      new Style({
        stroke: new Stroke({ color: "#10b981", width: 2 })
      })
    )
    this._vectorSource.addFeature(this._circleFeature)

    // Маркер как CircleStyle Feature (точка, не иконка)
    this._markerFeature = new Feature({
      geometry: new Point(center)
    })
    this._markerFeature.setStyle(
      new Style({
        image: new CircleStyle({
          radius: 6,
          fill: new Fill({ color: "#10b981" }),
          stroke: new Stroke({ color: "#ffffff", width: 2 })
        })
      })
    )
    this._vectorSource.addFeature(this._markerFeature)

    // Клик по карте — ставим маркер (только если в пределах круга)
    this._map.on("click", (evt) => {
      const coords = toLonLat(evt.coordinate)
      const projected = fromLonLat([coords[0], coords[1]])

      // Проверка антифрода
      const dx = projected[0] - this._userCenter[0]
      const dy = projected[1] - this._userCenter[1]
      const scale = this._map.getView().getProjection().getMetersPerUnit()
      const distance = scale * Math.sqrt(dx * dx + dy * dy)

      if (distance > this.constructor.MAX_RADIUS_METERS) {
        return // за пределами круга — не ставим
      }

      // Перемещаем маркер-точку
      this._markerFeature.getGeometry().setCoordinates(projected)

      // Обновляем координаты
      this.updateCoords(coords[1], coords[0])

      // Reverse geocoding
      this._debouncedReverseGeocode(coords[1], coords[0])
    })

    // При изменении зума — включаем панорамирование в пределах круга
    this._map.getView().on("change:resolution", () => {
      const currentZoom = this._map.getView().getZoom()
      if (currentZoom !== this._lastZoom) {
        this._lastZoom = currentZoom
        // Включаем dragPan с ограничением
        this._map.getInteractions().forEach((interaction) => {
          if (interaction instanceof DragPan) {
            interaction.setActive(true)
          }
        })
      }
    })

    // Ограничиваем панорамирование при moveend
    this._map.on("moveend", () => {
      const mapCenter = toLonLat(this._map.getView().getCenter())
      const projected = fromLonLat([mapCenter[0], mapCenter[1]])
      const dx = projected[0] - this._userCenter[0]
      const dy = projected[1] - this._userCenter[1]
      const scale = this._map.getView().getProjection().getMetersPerUnit()
      const distance = scale * Math.sqrt(dx * dx + dy * dy)

      if (distance > this.constructor.MAX_RADIUS_METERS) {
        // Возвращаем центр карты на границу круга
        const ratio = this.constructor.MAX_RADIUS_METERS / distance
        const constrainedX = this._userCenter[0] + dx * ratio
        const constrainedY = this._userCenter[1] + dy * ratio
        this._map.getView().setCenter([constrainedX, constrainedY])
      }
    })

    // Обновить скрытые поля начальными координатами
    this.updateCoords(lat, lng)

    this._map.updateSize()

    // Вызываем HF сразу при открытии формы (если координаты валидны)
    if (lat !== 0 && lng !== 0) {
      this._debouncedReverseGeocode(lat, lng)
    }
  }

  /**
   * Обновляет hidden поля latitude/longitude и дисплей координат под картой
   *
   * @param {number} lat
   * @param {number} lng
   */
  updateCoords(lat, lng) {
    if (this.hasLatitudeTarget) this.latitudeTarget.value = lat.toFixed(6)
    if (this.hasLongitudeTarget) this.longitudeTarget.value = lng.toFixed(6)
    if (this.hasCoordDisplayLatTarget) this.coordDisplayLatTarget.textContent = lat.toFixed(6)
    if (this.hasCoordDisplayLngTarget) this.coordDisplayLngTarget.textContent = lng.toFixed(6)
  }

  // ============================================================
  // REVERSE GEOCODING (HuggingFace)
  // ============================================================

  /**
   * Debounced reverse geocoding через StimulusReflex
   * Вызывается при каждом moveend карты (с debounce для избежания спама)
   *
   * @param {number} lat
   * @param {number} lng
   */
  _debouncedReverseGeocode(lat, lng) {
    clearTimeout(this._reverseGeocodeTimer)
    this._reverseGeocodeTimer = setTimeout(() => {
      this._reverseGeocode(lat, lng)
    }, this.constructor.REVERSE_GEOCODE_DEBOUNCE_MS)
  }

  /**
   * Выполняет reverse geocoding через HuggingFaceService
   * Заполняет поля city, country, address при успехе
   */
  _reverseGeocode(lat, lng) {
    this.stimulate("PoiReflex#reverse_geocode", { lat, lng })
  }

  /**
   * CableReady callback: заполняет поля результатами reverse geocoding
   * Вызывается из PoiReflex после ответа от HuggingFace
   *
   * @param {Object} data { country, city, address }
   */
  fillReverseGeocode(data) {
    if (!data) return

    const cityInput = this.element.querySelector("[name='poi[city]']")
    const countryInput = this.element.querySelector("[name='poi[country]']")
    const addressInput = this.element.querySelector("[name='poi[address]']")

    if (data.city && cityInput && !cityInput.value) {
      cityInput.value = data.city
    }
    if (data.country && countryInput && !countryInput.value) {
      countryInput.value = data.country
    }
    if (data.address && addressInput && !addressInput.value) {
      addressInput.value = data.address
    }
  }

  // ============================================================
  // ДИНАМИЧЕСКИЕ ПОЛЯ КАТЕГОРИИ
  // ============================================================

  /**
   * Рендерит динамические поля в fieldsContainer
   *
   * @param {Array} fields
   */
  renderFields(fields) {
    if (!this.hasFieldsContainerTarget) return
    this.fieldsContainerTarget.innerHTML = ""

    fields.forEach(field => {
      const wrapper = document.createElement("div")
      wrapper.className = "mb-3"

      const label = document.createElement("label")
      label.className = "block text-sm font-medium text-gray-700 mb-1"
      label.textContent = field.label
      wrapper.appendChild(label)

      switch (field.field_type) {
        case "boolean":
          const cb = document.createElement("input")
          cb.type = "checkbox"
          cb.name = `poi[metadata][${field.field_key}]`
          cb.value = "1"
          cb.className = "rounded border-gray-300 text-emerald-600 focus:ring-emerald-500"
          wrapper.appendChild(cb)
          break

        case "select":
        case "multiselect":
          this.renderSelectField(wrapper, field)
          break

        case "number":
          const num = document.createElement("input")
          num.type = "number"
          num.name = `poi[metadata][${field.field_key}]`
          num.placeholder = field.placeholder || ""
          num.className = "w-full px-3 py-2 border rounded-md text-sm focus:ring-emerald-500 focus:border-emerald-500"
          wrapper.appendChild(num)
          break

        default:
          const txt = document.createElement("input")
          txt.type = "text"
          txt.name = `poi[metadata][${field.field_key}]`
          txt.placeholder = field.placeholder || ""
          txt.className = "w-full px-3 py-2 border rounded-md text-sm focus:ring-emerald-500 focus:border-emerald-500"
          wrapper.appendChild(txt)
      }

      this.fieldsContainerTarget.appendChild(wrapper)
    })
  }

  /**
   * Рендер select/multiselect с локализованными option { key, label }
   *
   * @param {HTMLElement} wrapper
   * @param {Object} field
   */
  renderSelectField(wrapper, field) {
    const select = document.createElement("select")
    select.name = `poi[metadata][${field.field_key}]${field.field_type === "multiselect" ? "[]" : ""}`
    select.className = "w-full px-3 py-2 border rounded-md text-sm focus:ring-emerald-500 focus:border-emerald-500"
    if (field.field_type === "multiselect") select.multiple = true

    const emptyOpt = document.createElement("option")
    emptyOpt.value = ""
    emptyOpt.textContent = field.placeholder || "Select..."
    select.appendChild(emptyOpt)

    const options = field.options || []
    options.forEach(opt => {
      const option = document.createElement("option")
      if (typeof opt === "string") {
        option.value = opt
        option.textContent = opt
      } else {
        option.value = opt.key || opt.value
        option.textContent = opt.label || opt.key
      }
      select.appendChild(option)
    })

    wrapper.appendChild(select)
  }

  // ============================================================
  // ФОТО (галерея)
  // ============================================================

  /**
   * Показывает превью выбранных файлов в контейнере photosPreview.
   * Вызывается при change на file_field :photos.
   *
   * @param {Event} event - событие change
   */
  previewPhotos(event) {
    const files = event.target.files
    if (!files || !files.length) return
    const container = this.photosPreviewTarget

    Array.from(files).forEach((file) => {
      const url = URL.createObjectURL(file)
      const wrapper = document.createElement("div")
      wrapper.className = "relative w-20 h-20 rounded-md overflow-hidden border border-gray-200 group"
      const img = document.createElement("img")
      img.src = url
      img.alt = file.name
      img.className = "w-full h-full object-cover"
      wrapper.appendChild(img)
      container.appendChild(wrapper)
    })
  }

  /**
   * Помечает существующее фото на удаление: добавляет hidden-input
   * poi[remove_photos][] и скрывает его превью.
   * Вызывается по кнопке удаления у существующего фото (edit mode).
   *
   * @param {Event} event - событие click
   */
  removeExistingPhoto(event) {
    const btn = event.currentTarget
    const id = btn.dataset.photoId
    if (!id) return

    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "poi[remove_photos][]"
    input.value = id
    this.removePhotosInputTarget.appendChild(input)

    const wrapper = btn.closest(".group")
    if (wrapper) wrapper.classList.add("hidden")
  }

  /**
   * Отправка формы через fetch (create/edit) — без полной перезагрузки.
   * При 302 (успех) переходим по итоговому URL; при 422 — показываем ошибку
   * в блоке формы модалки (не закрывая её).
   *
   * @param {Event} event - событие submit
   */
  handleSubmit(event) {
    event.preventDefault()
    const form = event.target
    const body = new FormData(form)

    this._clearFormError()

    fetch(form.action, {
      method: form.method,
      body: body,
      headers: { 'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content || '' },
      credentials: 'same-origin'
    })
      .then((response) => {
        if (response.redirected) {
          window.location.href = response.url
          return null
        }
        return response.json().catch(() => ({ error: 'Request failed' }))
      })
      .then((data) => {
        if (data && data.error) {
          this._showFormError(data.error)
        }
      })
      .catch((e) => {
        console.error('[POI FORM] submit error:', e)
        this._showFormError('Network error')
      })
  }

  /**
   * Показывает ошибку валидации как тост (структура Ui::ToastComponent)
   * в контейнере #notifications. Тост авто-скрывается через
   * ui--toast-component (auto-dismiss).
   *
   * @param {string} message - текст ошибки
   */
  _showFormError(message) {
    const container = document.getElementById("notifications")
    if (!container) return

    const toast = document.createElement("div")
    toast.setAttribute("role", "alert")
    toast.setAttribute("data-controller", "ui--toast-component")
    toast.setAttribute("data-ui--toast-component-auto-dismiss-timeout-value", "6000")
    toast.className = "mb-4 p-4 rounded-lg shadow-lg bg-red-600 text-white flex items-center justify-between pointer-events-auto"

    const text = document.createElement("span")
    text.textContent = message
    toast.appendChild(text)

    const dismissBtn = document.createElement("button")
    dismissBtn.setAttribute("type", "button")
    dismissBtn.setAttribute("data-action", "click->ui--toast-component#dismiss")
    dismissBtn.className = "ml-4 text-white hover:text-gray-200"
    const closeIcon = document.createElement("span")
    closeIcon.className = "mdi mdi-close"
    dismissBtn.appendChild(closeIcon)
    toast.appendChild(dismissBtn)

    container.appendChild(toast)
  }

  /**
   * Скрывает блок ошибки формы.
   * Тосты авто-скрываются контроллером ui--toast-component — отдельная
   * очистка не требуется (метод оставлен для обратной совместимости).
   */
  _clearFormError() {
    // no-op: тосты управляют собственным жизненным циклом
  }
}
