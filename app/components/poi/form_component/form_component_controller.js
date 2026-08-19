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
 *   - Маркером: установка кликом (ограничен кругом)
 *   - Выбором категории через Ui::DropdownComponent
 *   - Загрузкой динамических полей категории
 *   - Рендером полей (boolean/select/multiselect/number/text)
 *   - Отображением координат под картой
 *   - Reverse geocoding через Nominatim (по клику/перемещению маркера)
 */
export default class extends ApplicationController {
  static targets = [
    "categoryDropdown", "categoryName", "categoryId",
    "latitude", "longitude", "miniMap",
    "coordDisplayLat", "coordDisplayLng",
    "photosInput", "photosPreview", "removePhotosInput"
  ]

  static MAX_RADIUS_METERS = 100
  static REVERSE_GEOCODE_DEBOUNCE_MS = 800

  connect() {
    super.connect()
    document.addEventListener("poi:open-modal", this.open.bind(this))

    // Форма вставлена через inner_html (PoiReflex#edit_poi) без события
    // poi:open-modal. CableReady применяет операции по порядку: inner_html
    // (connect срабатывает, пока overlay ещё hidden) → remove_css_class(hidden).
    // Поэтому инициализируем карту ТОЛЬКО когда overlay стал видимым:
    // иначе мини-карта не создаётся и reverse geocoding/адрес не заполняются
    // (баг «редактирование POI — карта не инициализируется», ROADMAP 2.2).
    const overlay = this.element.closest("[data-poi--show-component-target='overlay']")
    if (this._map) return

    if (overlay && overlay.classList.contains("hidden")) {
      this._observeOverlay(overlay)
    } else {
      setTimeout(() => this.initMiniMap(), 100)
    }
  }

  disconnect() {
    super.disconnect()
    document.removeEventListener("poi:open-modal", this.open.bind(this))
    if (this._overlayObserver) {
      this._overlayObserver.disconnect()
      this._overlayObserver = null
    }
    // Мини-карта переиспользуется между экземплярами контроллера через
    // глобальный реестр (__poiFormMapRegistry): при inner_html-пересборке формы
    // новый контроллер перепривязывает target (_adoptExistingMap). Поэтому здесь
    // карту НЕ уничтожаем (setTarget(null)) — иначе повторная вставка получит
    // отвязанную мёртвую карту и маркер перестанет обновляться.
    clearTimeout(this._reverseGeocodeTimer)
  }

  /**
   * Следит за overlay: как только снят класс hidden (CableReady remove_css_class),
   * инициализирует мини-карту. Используется при inner_html-вставке формы,
   * когда connect срабатывает раньше снятия hidden.
   *
   * @param {HTMLElement} overlay контейнер модалки (data-poi--show-component-target="overlay")
   */
  _observeOverlay(overlay) {
    if (this._overlayObserver) this._overlayObserver.disconnect()
    this._overlayObserver = new MutationObserver(() => {
      if (overlay.classList.contains("hidden") || this._map) return
      this._overlayObserver.disconnect()
      this._overlayObserver = null
      setTimeout(() => this.initMiniMap(), 100)
    })
    this._overlayObserver.observe(overlay, { attributes: true, attributeFilter: ["class"] })
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

    // Загружаем динамические поля выбранной категории через WebSocket (StimulusReflex)
    // Сервер рендерит Poi::FormFieldsComponent и доставляет HTML в [data-poi-form-fields]
    if (id) {
      this.stimulate("PoiReflex#load_category_fields", { category_id: id })
    }
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
    // Защита от повторной инициализации OpenLayers на одном target.
    // Без этого connect()/open()/MutationObserver/повторная inner_html-вставка
    // могут создать ДВА Map на одном элементе: клик двигает маркер первой
    // (невидимой) карты, а видимая (вторая) остаётся в центре — «координаты и
    // адрес (Nominatim) меняются, маркер нет».
    if (this._map) return

    // Глобальная защита между ЭКЗЕМПЛЯРАМИ контроллера. Комментарий выше
    // защищает только внутри одного экземпляра; при повторной inner_html-вставке
    // формы (PoiReflex#edit_poi) на тот же элемент подключается второй
    // контроллер и молча создаёт вторую карту на том же target. Реестр
    // (target DOM-элемент → метаданные карты) не даёт этого: повторная
    // инициализация переиспользует существующую карту.
    const registry = (window.__poiFormMapRegistry ||= new WeakMap())
    if (registry.has(this.miniMapTarget)) {
      this._adoptExistingMap(registry.get(this.miniMapTarget))
      return
    }

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

      // Диагностика для system-теста: текущие lon/lat маркера (WGS84).
      // Раньше экспорт отдельной функции toLonLat был ненадёжен из-за повторной
      // инициализации карты; здесь значения пишутся в момент клика напрямую.
      window.__poiFormLastLonLat = coords

      // Reverse geocoding
      this._debouncedReverseGeocode(coords[1], coords[0])
    })

    // Регистрируем карту в глобальном реестре для предотвращения дубликатов
    registry.set(this.miniMapTarget, {
      map: this._map,
      source: this._vectorSource,
      marker: this._markerFeature,
      circle: this._circleFeature,
      userCenter: this._userCenter
    })

    // Диагностическая экспозиция карты/маркера (для system-теста: маркер — это
    // OL-feature, а не DOM-элемент, проверить его положение через DOM нельзя).
    // Фактические lon/lat маркера пишутся в __poiFormLastLonLat внутри клика.
    window.__poiFormMiniMap = this._map
    window.__poiFormMarker = this._markerFeature

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
   * Переиспользует уже созданную карту на том же target-элементе (защита от
   * дубликатов между экземплярами контроллера при inner_html-вставке формы).
   * Привязывает target заново (предыдущий контроллер мог отвязать карту при
   * disconnect) и связывает текущий экземпляр с общей картой/маркером.
   *
   * Клик навешивается на объект карты один раз первым контроллером и остаётся
   * активным при повторной вставке.
   *
   * @param {Object} meta { map, source, marker, circle, userCenter }
   */
  _adoptExistingMap(meta) {
    this._map = meta.map
    this._vectorSource = meta.source
    this._markerFeature = meta.marker
    this._circleFeature = meta.circle
    this._userCenter = meta.userCenter

    // Перепривязываем target на случай, если старый контроллер отвязал карту
    this._map.setTarget(this.miniMapTarget)
    this._map.updateSize()
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
  // REVERSE GEOCODING (Nominatim)
  // ============================================================

  /**
   * Debounced reverse geocoding через StimulusReflex.
   * Debounce защищает от спама вызовов при серии кликов/перемещений маркера.
   *
   * @param {number} lat - широта
   * @param {number} lng - долгота
   */
  _debouncedReverseGeocode(lat, lng) {
    clearTimeout(this._reverseGeocodeTimer)
    this._reverseGeocodeTimer = setTimeout(() => {
      this._reverseGeocode(lat, lng)
    }, this.constructor.REVERSE_GEOCODE_DEBOUNCE_MS)
  }

  /**
   * Выполняет reverse geocoding (PoiReflex → ReverseGeocodingService/Nominatim).
   * Сервер через CableReady заполняет поля city/country/address формы.
   *
   * @param {number} lat - широта
   * @param {number} lng - долгота
   */
  _reverseGeocode(lat, lng) {
    this.stimulate("PoiReflex#reverse_geocode", { lat, lng })
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
   * Отправка формы через StimulusReflex (create/edit) — Websocket-first,
   * без полной перезагрузки страницы. DOM после сохранения не рендерится:
   * обновление списка/карты выполняет PoiBroadcaster (по версии PaperTrail),
   * пользователю приходит тост через ToastBroadcaster (WebSocket).
   *
   * Валидация координат: без широты/долготы форму не отправляем.
   *
   * Формат: for edit mode FormData содержит poi[id] (persisted model); удаляем
   * его из params, чтобы не конфликтовать с getReflexOptions() в StimulusReflex
   * (ключ `id` верхнего уровня поглощается как опции). id уходит только внутри
   * вложенного `poi.id`, который использует PoiReflex#update.
   *
   * Примечание: бинарники фото (File) через StimulusReflex не передаются —
   * загрузка фото вынесена в отдельную задачу (ROADMAP: «фото → HTTP/multipart»),
   * поэтому элементы File пропускаются.
   *
   * @param {Event} event - событие submit
   */
  handleSubmit(event) {
    event.preventDefault()
    const form = event.target

    // Валидация координат: без широты/долготы форму не отправляем.
    const lat = parseFloat(this.hasLatitudeTarget ? this.latitudeTarget.value : 0)
    const lng = parseFloat(this.hasLongitudeTarget ? this.longitudeTarget.value : 0)
    if (!lat || !lng) {
      this._showFormError(this.element.dataset.poiFormComponentMissingCoords || 'Coordinates are required')
      return
    }

    this._clearFormError()

    const params = this._collectPoiParams(form)

    const hasId = Object.prototype.hasOwnProperty.call(params.poi, 'id') && params.poi.id
    if (hasId) {
      this.stimulate("PoiReflex#update", { poi: params.poi })
    } else {
      this.stimulate("PoiReflex#create", { poi: params.poi })
    }
  }

  /**
   * Собирает вложенный хэш пар цифровых полей формы POI из FormData.
   * Ключи вида "poi[name]" распаковываются в { poi: { name: value } };
   * "poi[metadata][key]" — в { poi: { metadata: { key: value } } }.
   * Библиотечные File (фото) пропускаются.
   *
   * @param {HTMLFormElement} form - форма
   * @return {Object} вложенный объект параметров { poi: { ... } }
   */
  _collectPoiParams(form) {
    const params = { poi: {} }
    for (const [key, value] of new FormData(form).entries()) {
      if (value instanceof File) continue // фото — отдельная задача (HTTP upload)
      const match = key.match(/^poi\[([^\]]+)\](?:\[([^\]]+)\])?$/)
      if (!match) continue
      const [, field, subfield] = match
      if (subfield !== undefined) {
        if (typeof params.poi[field] !== 'object' || params.poi[field] === null) {
          params.poi[field] = {}
        }
        params.poi[field][subfield] = value
      } else {
        params.poi[field] = value
      }
    }
    // NOTE: ключ poi[id] остаётся — он вложен, НЕ является top-level опцией
    // StimulusReflex (конфликтуют только зарезервированные верхнеуровневые ключи:
    // id, params, selectors...). PoiReflex#update использует poi_params[:id].
    return params
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
