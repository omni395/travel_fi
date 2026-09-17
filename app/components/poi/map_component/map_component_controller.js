import ApplicationController from '../../../javascript/controllers/application_controller'
import 'ol/ol.css'
import Map from "ol/Map"
import View from "ol/View"
import TileLayer from "ol/layer/Tile"
import VectorLayer from "ol/layer/Vector"
import Cluster from "ol/source/Cluster"
import VectorSource from "ol/source/Vector"
import OSM from "ol/source/OSM"
import Feature from "ol/Feature"
import Point from "ol/geom/Point"
import { fromLonLat, toLonLat } from "ol/proj"
import { Circle as CircleStyle, Fill, Stroke, Style, Text, Icon } from "ol/style"
import { defaults as defaultControls, Control } from "ol/control"
import { boundingExtent } from "ol/extent"
import Overlay from "ol/Overlay"
/**
 * Poi Map Component Controller
 * Иконка: mdi-map
 *
 * Управляет:
 * - Геолокация пользователя → инициализация карты
 * - OpenLayers 10 карта с кластеризацией POI
 * - Ховер-тултип (UI::TooltipComponent)
 * - Клик по точке → модалка с деталями
 * - Загрузка POI в bounds через StimulusReflex
 * - afterReflex: обновление маркеров после загрузки списка
 *
 * Антифрод-механизм (через poiUserId):
 *   В data-атрибуты POI записывается user_id владельца (data-poi-user-id).
 *   Это НЕ используется для блокировки просмотра/навигации — тултип и детали
 *   доступны ВСЕГДА для любой точки.
 *   poiUserId применяется в Poi::ShowComponent для блокировки действий:
 *   редактирование, лайки, комментарии — если расстояние от пользователя
 *   до точки > 100м, И точка НЕ принадлежит пользователю. Это антифрод:
 *   нельзя написать "я был там" про точку в Китае из Америки.
 *
 * Ссылка: https://openlayers.org/en/latest/examples/
 */
export default class extends ApplicationController {
  static DEFAULT_ZOOM = 17
  // Центр карты по умолчанию (fallback при ошибке геолокации). Согласован с
  // тестовой геолокацией (TestGeolocation::DEFAULT_TEST_LAT/LNG в spec/support)
  // и центром OSM-импорта. Иконка: mdi-map-marker (маркер fallback-координат).
  static DEFAULT_MAP_CENTER = { lat: 52.52, lng: 13.405 }

  /** @returns {HTMLElement} элемент .poi-map внутри компонента */
  get _mapElement() {
    return this.element.querySelector(".poi-map") || this.element
  }

  connect() {
    super.connect()
    console.log("[POI MAP] connect() — element ready")

    // Single POI mode (админка: детали/редактирование)
    const singleLat = parseFloat(this._mapElement.dataset.poiSingleLat)
    const singleLng = parseFloat(this._mapElement.dataset.poiSingleLng)
    const isInteractive = this._mapElement.dataset.poiInteractive === "true"

    if (!isNaN(singleLat) && !isNaN(singleLng)) {
      console.log(`[POI MAP] Single POI mode: ${singleLat}, ${singleLng}, interactive=${isInteractive}`)
      this._map = null
      this._vectorSource = null
      this._userLayer = null
      this._resizeObserver = null
      this._rafPending = false
      this._tooltipOverlay = null
      this._hoveredFeatureId = null
      this._initRetries = 0
      this._currentUserId = parseInt(document.body.dataset.currentUserId) || null
      this._mdiCodepointCache = {}

      // Инициализируем сразу без геолокации
      this._initMapWithLocation(singleLat, singleLng, isInteractive)
      return
    }

    // Стандартный режим (публичная карта с геолокацией)
    this._map = null
    this._vectorSource = null
    this._userLayer = null
    this._userLocation = null
    this._resizeObserver = null
    this._rafPending = false
    this._tooltipOverlay = null
    this._hoveredFeatureId = null
    this._geolocationTimer = null
    this._initRetries = 0
    this._fallbackPoisTimer = null
    this._currentUserId = parseInt(document.body.dataset.currentUserId) || null
    this._mdiCodepointCache = {}
    this._boundOnReloadFeatures = this._onReloadFeatures.bind(this)
    document.addEventListener("poi:reload-features", this._boundOnReloadFeatures)

    // Force init через 10 секунд если геолокация не ответила
    this._forceInitTimer = setTimeout(() => {
      if (!this._map) {
        console.warn("[POI MAP] Force init after 10s timeout — map not initialized")
        this._onGeolocationError({ message: "Force init timeout", code: 3 })
      }
    }, 10000)

    this._locateUser()
  }

  disconnect() {
    super.disconnect()
    document.removeEventListener("poi:reload-features", this._boundOnReloadFeatures)
    clearTimeout(this._geolocationTimer)
    clearTimeout(this._forceInitTimer)
    clearTimeout(this._fallbackPoisTimer)
    if (this._rafPending) {
      cancelAnimationFrame(this._rafPending)
    }
    if (this._map) {
      this._map.setTarget(null)
      this._map = null
    }
    this._userLayer = null
    this._userLocation = null
    if (this._userPinOverlay) {
      this._map?.removeOverlay(this._userPinOverlay)
      this._userPinOverlay = null
    }
    this._resizeObserver?.disconnect()
  }

  /**
   * StimulusReflex lifecycle — после успешного рефлекса
   * Обновляем маркеры на карте из #poi-map-features
   */
  afterReflex(element, reflex) {
    if (reflex.includes("PoiReflex#load_pois_in_bounds") || reflex.includes("PoiReflex#load_more_pois") || reflex.includes("PoiReflex#apply_filters") || reflex.includes("PoiReflex#reset_filters")) {
      console.log('[POI MAP] afterReflex: reloading POI features')
      this._loadPois()
    }
  }

  /**
   * Обработчик события poi:reload-features (шлёт PoiBroadcaster и OsmImportBroadcaster
   * после создания/обновления/импорта POI).
   * ВАЖНО: вызываем _loadPoisInBounds() (перезапрос с сервера), а не _loadPois() —
   * скрытый контейнер #poi-map-features ещё не содержит новых POI, поэтому
   * перечитывание DOM не покажет свежие маркеры/список.
   *
   * Гео-фильтрация (баг 4): dispatch_event может нести detail с зоной изменения —
   *   { type: "osm", bbox: [south, west, north, east], category_id }
   *   { type: "single", lat, lng }
   * Перезагружаем POI только если видимые границы карты пересекаются с этой зоной.
   * Локальные события (apply/reset фильтров из filters_component) приходят без detail —
   * обрабатываются всегда (это реакция самого пользователя).
   *
   * @param {CustomEvent} event - событие с detail.zone
   */
  _onReloadFeatures(event) {
    if (event && event.detail) {
      const detail = event.detail
      if (!this._detailIntersectsView(detail)) {
        console.log('[POI MAP] _onReloadFeatures: zone outside current view, skipping reload')
        return
      }
    }
    // Сбрасываем кэш bounds-ключа: без этого _loadPoisInBounds() при неизменённых
    // границах карты упирается в страж `_lastBoundsKey === currentBoundsKey` и
    // возвращается, НЕ отправляя серверный запрос. В результате новая одобренная
    // точка (шаг «админ одобрил → пользователь live видит») НЕ появлялась бы ни
    // на карте, ни в сайдбаре без перезагрузки. Сброс форсирует повторный
    // `PoiReflex#load_pois_in_bounds`, который рендерит и маркеры, и список.
    this._lastBoundsKey = null
    console.log('[POI MAP] _onReloadFeatures: reloading POIs in bounds from server')
    this._loadPoisInBounds()
  }

  /**
   * Проверяет, пересекается ли зона изменения (detail события poi:reload-features)
   * с текущими видимыми границами карты.
   *
   * @param {Object} detail - detail события { type, bbox|lat, lng, category_id }
   * @return {boolean} true — зона в пределах видимости (или тип неизвестен → reload)
   */
  _detailIntersectsView(detail) {
    if (!this._map) return true
    const size = this._map.getSize()
    if (!size || size[0] === undefined || size[1] === undefined) return true

    // Текущие видимые границы карты в lon/lat (слегка расширены запасом)
    const extent = this._map.getView().calculateExtent(size)
    const sw = toLonLat([extent[0], extent[1]])
    const ne = toLonLat([extent[2], extent[3]])
    const viewSouth = Math.min(sw[1], ne[1])
    const viewNorth = Math.max(sw[1], ne[1])
    const viewWest = Math.min(sw[0], ne[0])
    const viewEast = Math.max(sw[0], ne[0])

    // Зона по типу события
    let bbox = null
    if (detail.type === "osm" && Array.isArray(detail.bbox) && detail.bbox.length === 4) {
      // bbox: [south, west, north, east]
      bbox = { south: detail.bbox[0], west: detail.bbox[1], north: detail.bbox[2], east: detail.bbox[3] }
    } else if (detail.type === "single" && detail.lat != null && detail.lng != null) {
      bbox = { south: detail.lat, north: detail.lat, west: detail.lng, east: detail.lng }
    }

    // Нет зоны/типа — считаем релевантным (не ограничиваем)
    if (!bbox) return true

    // Запас для одиночных точек: маркер/кластер может быть виден, даже если
    // точка чуть за пределами "строгого" прямоугольника границ. Без запаса
    // одобренная точка на краю видимой области не появится, т.к. _loadPoisInBounds
    // запрашивает усечённые на 0.9×0.9 границы. 0.02° ≈ 2.2 км на экваторе.
    const pad = detail.type === "single" ? 0.02 : 0

    // Пересечение прямоугольников (с запасом pad для одиночных точек)
    return !(
      bbox.north < viewSouth - pad ||
      bbox.south > viewNorth + pad ||
      bbox.east < viewWest - pad ||
      bbox.west > viewEast + pad
    )
  }

  // ============================================================
  // ГЕОЛОКАЦИЯ
  // ============================================================

  _locateUser() {
    if (!navigator.geolocation) {
      this._onGeolocationError({ message: "Geolocation not supported", code: 0 })
      return
    }

    // Таймаут 5с — если браузер завис на попапе, форсируем fallback
    this._geolocationTimer = setTimeout(() => {
      console.warn("[POI MAP] Geolocation timeout — fallback to London")
      this._onGeolocationError({ message: "Geolocation timeout", code: 3 })
    }, 5000)

    navigator.geolocation.getCurrentPosition(
      (pos) => this._onGeolocationSuccess(pos),
      (err) => this._onGeolocationError(err),
      { enableHighAccuracy: true, timeout: 5000, maximumAge: 60000 }
    )
  }

  _onGeolocationSuccess(pos) {
    clearTimeout(this._geolocationTimer)
    const lat = pos.coords.latitude
    const lng = pos.coords.longitude
    console.log(`[POI MAP] Position: ${lat.toFixed(4)},${lng.toFixed(4)}`)

    // Сохраняем координаты в data-атрибуты для доступа из FormComponent
    this._mapElement.dataset.userLat = lat
    this._mapElement.dataset.userLng = lng

    this._userLocation = { lat, lng }
    this.stimulate("PoiReflex#set_location", { lat, lng })
    this._initWithCenter(lat, lng)
  }

  _onGeolocationError(err) {
    clearTimeout(this._geolocationTimer)
    console.log(`[POI MAP] Geolocation error: ${err.message}`)
    console.log(`[POI MAP] Fallback to map center (${this.constructor.DEFAULT_MAP_CENTER.lat},${this.constructor.DEFAULT_MAP_CENTER.lng})`)
    this.stimulate("PoiReflex#show_geolocation_toast")

    // Fallback-центр (DEFAULT_MAP_CENTER) становится «позицией пользователя» для UI:
    // карта уже центрируется на него, поэтому булавка пользователя обязана
    // присутствовать и при fallback (ранее добавлялась только при _onGeolocationSuccess
    // — баг: при ошибке геолокации .poi-user-pin отсутствовал на карте).
    const { lat, lng } = this.constructor.DEFAULT_MAP_CENTER
    this._userLocation = { lat, lng }

    // СИНХРОНИЗАЦИЯ СЕРВЕРА: пишем fallback-координаты в session[:user_lat/lng] через
    // set_location. Иначе при ошибке геолокации сервер остаётся без координат →
    // check_proximity! (голосование/комментарий/редактирование: 100м лимит) блокирует
    // действие с «нет геолокации», хотя карта визуально центрирована. set_location —
    // идемпотентный, дубликаты safe.
    this.stimulate("PoiReflex#set_location", { lat, lng })

    this._initWithCenter(lat, lng)
  }

  _hideLoader() {
    const el = document.getElementById("poi-loading")
    if (el) el.classList.add("hidden")
  }

  // ============================================================
  // ИНИЦИАЛИЗАЦИЯ КАРТЫ
  // ============================================================

  _initWithCenter(lat, lng) {
    if (this._map) {
      console.log(`[POI MAP] initWithCenter(${lat.toFixed(4)},${lng.toFixed(4)}) — skipped, already init`)
      return
    }

    const el = this._mapElement
    if (!el || !el.isConnected) {
      console.warn("[POI MAP] initWithCenter — map element not in DOM, retrying...")
      if (this._initRetries < 3) {
        this._initRetries++
        setTimeout(() => this._initWithCenter(lat, lng), 500)
      }
      return
    }

    console.log(`[POI MAP] initWithCenter(${lat.toFixed(4)},${lng.toFixed(4)}) — starting init`)

    this._rafPending = requestAnimationFrame(() => {
      this._rafPending = false
      try {
        this._initMap(lat, lng)
        this._loadPois()
        if (this._userLocation) {
          this._addUserLocation(this._userLocation.lat, this._userLocation.lng)
        }
        this._hideLoader()

        // Загружаем POI ТОЛЬКО после того, как карта отрендерилась
        // Используем postrender вместо прямого вызова — гарантирует, что getSize() не undefined
        this._map.once("postrender", () => {
          this._loadPoisInBounds()
        })

        // Fallback-загрузка: если первый кадр карты не отрисовался (headful/headless
        // Chrome с --disable-gpu/SwiftShader, WebGL), событие postrender может не
        // сработать, и _loadPoisInBounds не вызовется → маркеры не загружаются
        // (баг «POI не появляется на карте», ROADMAP 2.2/3.4). Ретраим с паузой,
        // пока карта не получит размер.
        if (!this._fallbackPoisTimer) {
          this._fallbackPoisTimer = setTimeout(() => {
            const attemptLoad = (attempt) => {
              const size = this._map?.getSize()
              if (!size || size[0] === undefined || size[1] === undefined) {
                if (attempt < 5) {
                  setTimeout(() => attemptLoad(attempt + 1), 500)
                }
                return
              }
              this._loadPoisInBounds()
            }
            attemptLoad(0)
          }, 1000)
        }

        console.log("[POI MAP] initialization complete")
      } catch (e) {
        console.error("[POI MAP] Init error:", e)
        if (this._initRetries < 3) {
          this._initRetries++
          setTimeout(() => this._initWithCenter(lat, lng), 500)
        }
      }
    })
  }

  /**
   * Инициализация карты для одиночной POI (админка)
   * Не использует геолокацию и кластеризацию.
   * В interactive-режиме добавляет обработчики для обновления полей координат.
   *
   * @param {number} lat - широта
   * @param {number} lng - долгота
   * @param {boolean} interactive - режим редактирования
   */
  _initMapWithLocation(lat, lng, interactive = false) {
    this._initMap(lat, lng)
    this._loadPois()
    // Маркер редактируемой/просматриваемой точки на мини-карте edit-show.
    // В single-режиме (админка) карта центрируется на POI, но кластер/features
    // отсутствуют (compact-режим не рендерит #poi-map-features) — потому точка
    // не отображалась. Добавляем маркер-точку напрямую в vector source (аналог
    // Poi::FormComponent#initMiniMap). Антифрод-круг для админа не нужен.
    this._addSinglePoiMarker(lat, lng)
    this._hideLoader()

    if (interactive) {
      // Передаём координаты точки: интер. режим сразу запускает обратный геокодинг
      this._setupInteractiveMode(lat, lng)
    }
  }

  /**
   * Добавляет маркер-точку (CircleStyle Feature) для одиночного POI.
   * Используется в single-режиме мини-карты (админка: show-детали/edit-форма),
   * где кластерные фичи не загружаются (compact → нет #poi-map-features).
   *
   * @param {number} lat - широта
   * @param {number} lng - долгота
   */
  _addSinglePoiMarker(lat, lng) {
    if (!this._vectorSource) return
    const projected = fromLonLat([lng, lat])
    this._singleMarkerFeature = new Feature({
      geometry: new Point(projected)
    })
    this._singleMarkerFeature.setStyle(
      new Style({
        image: new CircleStyle({
          radius: 8,
          fill: new Fill({ color: "#10b981" }),
          stroke: new Stroke({ color: "#ffffff", width: 2 })
        })
      })
    )
    this._vectorSource.addFeature(this._singleMarkerFeature)
    console.log(`[POI MAP] single POI marker added at ${lat}, ${lng}`)
  }

  /**
   * Перемещает маркер одиночного POI на новые координаты (клик/панорамирование).
   *
   * @param {number} lat - широта
   * @param {number} lng - долгота
   */
  _moveSinglePoiMarker(lat, lng) {
    if (!this._singleMarkerFeature) return
    this._singleMarkerFeature.getGeometry().setCoordinates(fromLonLat([lng, lat]))
  }

  /**
   * Возвращает фактический глиф (codepoint) MDI-иконки по её class-имени.
   *
   * Так как иконки MDI — это icon-font (подключён через CDN), в canvas OL
   * нельзя подставить <i class="mdi">. Вместо этого извлекаем реальный символ
   * глифа из уже загруженного CSS: создаём временный <i>, читаем
   * getComputedStyle(el, "::before").content и парсим "\FXXXX".
   *
   * Результат кэшируется в this._mdiCodepointCache (обычный object-хэш: в этом
   * модуле идентификатор Map затенён импортом OpenLayers, поэтому нативный Map
   * тут недоступен), чтобы не дёргать getComputedStyle на каждую фичу/кадр.
   * При сбое — fallback на mdi-map-marker.
   *
   * @param {string} className - имя класса иконки без префикса mdi (напр. "mdi-toilet")
   * @returns {string} символ-глиф для использования в OL Text style
   */
  _mdiCodepoint(className) {
    const safe = className || "mdi-map-marker"
    if (this._mdiCodepointCache[safe]) return this._mdiCodepointCache[safe]

    let glyph = this._mdiCodepointCache["mdi-map-marker"]
    if (!glyph) {
      glyph = this._mdiProbe("mdi-map-marker")
      this._mdiCodepointCache["mdi-map-marker"] = glyph
    }

    if (safe !== "mdi-map-marker") {
      const probed = this._mdiProbe(safe)
      this._mdiCodepointCache[safe] = probed
      glyph = probed
    }
    return glyph
  }

  /**
   * Единичный запрос codepoint глифа через временный DOM-элемент.
   * При недоступности CSS или невалидном content — возвращает fallback-глиф.
   *
   * @param {string} className - имя класса иконки MDI
   * @returns {string} символ-глиф
   */
  _mdiProbe(className) {
    const el = document.createElement("i")
    el.className = `mdi ${className}`
    el.style.position = "absolute"
    el.style.visibility = "hidden"
    document.body.appendChild(el)
    try {
      const content = getComputedStyle(el, "::before").content || ""
      const match = content.match(/"(.*)"/)
      if (match && match[1]) return match[1]
    } finally {
      document.body.removeChild(el)
    }
    return this._mdiCodepointCache["mdi-map-marker"] || ""
  }

  /**
   * Настраивает интерактивный режим (для формы редактирования):
   * - Клик по карте → центрирование + обновление полей
   * - Перемещение карты (moveend) → обновление полей lat/lng
   * - Обратный геокодинг по координатам (автозаполнение address/city/country/zip)
   *   при инициализации и каждом перемещении/клике (с debounce).
   */
  _setupInteractiveMode(singleLat, singleLng) {
    if (!this._map) return

    // При каждом перемещении карты обновляем поля координат, маркер и адрес
    this._map.on("moveend", () => {
      const center = toLonLat(this._map.getView().getCenter())
      this._updateCoordFields(center[1], center[0])
      this._moveSinglePoiMarker(center[1], center[0])
      this._debouncedReverseGeocode(center[1], center[0])
    })

    // Клик по карте → центрирование + обновление координат, маркера и адреса
    this._map.on("click", (evt) => {
      const coords = toLonLat(evt.coordinate)
      this._map.getView().setCenter(fromLonLat([coords[0], coords[1]]))
      this._updateCoordFields(coords[1], coords[0])
      this._moveSinglePoiMarker(coords[1], coords[0])
      this._debouncedReverseGeocode(coords[1], coords[0])
    })

    // Обратный геокодинг сразу при открытии формы (если координаты валидны) — по
    // аналогии с Poi::FormComponent#initMiniMap (заполнение адресных полей).
    if (!isNaN(singleLat) && !isNaN(singleLng) && singleLat !== 0 && singleLng !== 0) {
      this._debouncedReverseGeocode(singleLat, singleLng)
    }
  }

  /**
   * Debounced reverse geocoding через PoiReflex#reverse_geocode.
   * Заполняет поля city/country/address/zip_code в форме редактирования POI.
   *
   * @param {number} lat - широта
   * @param {number} lng - долгота
   */
  _debouncedReverseGeocode(lat, lng) {
    clearTimeout(this._reverseGeocodeTimer)
    this._reverseGeocodeTimer = setTimeout(() => {
      if (!lat || !lng || (lat === 0 && lng === 0)) return
      this.stimulate("PoiReflex#reverse_geocode", { lat, lng })
    }, 400)
  }

  /**
   * Обновляет поля lat/lng в форме редактирования
   * @param {number} lat
   * @param {number} lng
   */
  _updateCoordFields(lat, lng) {
    const latField = document.getElementById("poi_latitude") || document.querySelector("[name='poi[latitude]']")
    const lngField = document.getElementById("poi_longitude") || document.querySelector("[name='poi[longitude]']")
    if (latField) latField.value = lat.toFixed(6)
    if (lngField) lngField.value = lng.toFixed(6)
  }

  _initMap(lat, lng) {
    const el = this._mapElement
    const rect = el.getBoundingClientRect()
    console.log(`[POI MAP] _initMap() element rect: ${rect.width.toFixed(0)}x${rect.height.toFixed(0)}`)

    const center = fromLonLat([lng, lat])
    console.log(`[POI MAP] _initMap() center (EPSG:3857): ${center[0].toFixed(2)},${center[1].toFixed(2)}, zoom: ${this.constructor.DEFAULT_ZOOM}`)

    this._vectorSource = new VectorSource({ features: [] })

    const clusterSource = new Cluster({
      source: this._vectorSource,
      distance: 50,
      minDistance: 20
    })

    const clusterStyle = (feature) => {
      const size = feature.get("features")?.length || 1
      const radius = size > 100 ? 28 : size > 10 ? 22 : 16
      return new Style({
        image: new CircleStyle({
          radius,
          fill: new Fill({ color: "#059669" }),
          stroke: new Stroke({ color: "#ffffff", width: 2 })
        }),
        text: new Text({
          text: size > 1 ? size.toString() : "",
          fill: new Fill({ color: "#ffffff" }),
          font: "bold 12px sans-serif"
        })
      })
    }

    // Стиль одиночного POI. Приоритет — картинка-маркер категории
    // (poiCategoryImage): если она есть — рендерим ol/style Icon (img с белой
    // подложкой для читаемости). Иначе — чистый MDI-глиф категории (poiIcon),
    // fallback mdi-map-marker. Иконка: mdi-map-marker (fallback категории)
    const iconStyle = (feature) => {
      const img = feature.get("poiCategoryImage")
      if (img) {
        // Картинка-маркер: исходник variant — 96×96. scale 0.5 → ~48 css-px.
        // Круглая подложка цвета primary (emerald-600, как у кластера) с белым
        // strok'ом для читаемости поверх базовой карты. Массив стилей: сначала
        // подложка (CircleStyle), затем иконка поверх. Без crossOrigin:
        // ActiveStorage representation same-origin, рендер OL без чтения canvas.
        return [
          new Style({
            // 1. Белая круглая подложка с темной обводкой для контраста
            image: new CircleStyle({
              radius: 17, // Диаметр 34px
              fill: new Fill({ color: '#ffffff' }),
              stroke: new Stroke({ color: '#64748b', width: 2 }) // тёмно-серый/синий контур
            })
          }),
          new Style({
            // 2. Иконка с ручной компенсацией смещения
            image: new Icon({
              src: img,
              scale: 0.22, // Слегка уменьшим (карта будет смотреться аккуратнее)
              
              // Смещение цента: [X, Y]
              // Если картинка съехала влево, сдвигаем анкер чуть-чуть вправо (например, 0.54 по X)
              anchor: [0.54, 0.5], 
              anchorXUnits: 'fraction',
              anchorYUnits: 'fraction'
            })
          })
        ]
      }
      return new Style({
        text: new Text({
          text: this._mdiCodepoint(feature.get("poiIcon") || "mdi-map-marker"),
          font: '22px "Material Design Icons"',
          fill: new Fill({ color: "#059669" }),
          stroke: new Stroke({ color: "#ffffff", width: 3 }),
          offsetY: -2
        })
      })
    }

    this._map = new Map({
      target: el,
      layers: [
        new TileLayer({ source: new OSM() }),
        new VectorLayer({
          source: clusterSource,
          style: (feature) => {
            // Cluster-источник оборачивает КАЖДУЮ фичу в обёртку с массивом
            // "features". Свойства (poiIcon и др.) лежат на оригинальной фиче
            // внутри features[0], а не на обёртке. Берём оригинал для иконки.
            const features = feature.get("features")
            if (features && features.length > 1) return clusterStyle(feature)
            const sourceFeature = (features && features.length === 1) ? features[0] : feature
            return iconStyle(sourceFeature)
          }
        })
      ],
      view: new View({
        center,
        zoom: this.constructor.DEFAULT_ZOOM,
        maxZoom: 19,
        minZoom: 2
      }),
      controls: defaultControls({ zoom: true, attribution: { collapsible: true } }),
      willReadFrequently: true
    })

    console.log(`[POI MAP] map created, size: ${this._map.getSize()[0]}x${this._map.getSize()[1]}`)

    // MDI-шрифт (CDN) загружается асинхронно — если маркеры-иконки уже
    // отрисованы до его готовности, глифы отображаются как .notdef.
    // После полной загрузки шрифта пересчитываем стили вектор-источника.
    document.fonts?.ready?.then(() => {
      this._vectorSource?.changed()
      console.log("[POI MAP] MDI font loaded — vector source re-rendered")
    })

    // Tooltip Overlay
    const tooltipEl = document.getElementById("ui-tooltip")
    if (tooltipEl) {
      this._tooltipOverlay = new Overlay({
        element: tooltipEl,
        offset: [0, -15],
        positioning: "bottom-center",
        stopEvent: false
      })
      this._map.addOverlay(this._tooltipOverlay)
    }

    this._map.on("moveend", () => { this._loadPoisInBounds() })
    this._map.on("pointermove", (e) => { this._handleMapHover(e) })
    this._map.on("click", (e) => { this._handleMapClick(e) })

    // GPS кнопка (mdi-crosshairs-gps) в блоке zoom +/-
    const zoomControls = el.querySelector(".ol-zoom") || document.querySelector(".ol-zoom")
    if (zoomControls) {
      const gpsBtn = document.createElement("button")
      gpsBtn.type = "button"
      gpsBtn.className = "ol-zoom-gps"
      gpsBtn.title = "My location"
      gpsBtn.innerHTML = '<span class="mdi mdi-crosshairs-gps text-[#0288D1]"></span>'
      // mdi: crosshairs-gps
      gpsBtn.addEventListener("click", () => {
        if (this._userLocation) {
          this._map.getView().animate({
            center: fromLonLat([this._userLocation.lng, this._userLocation.lat]),
            zoom: 17,
            duration: 500
          })
        }
      })
      zoomControls.appendChild(gpsBtn)
    }

    // При изменении размера (скрытие/показ сайдбара, ресайз окна) — обновляем размер
    // и пересчитываем POI в уменьшенных bounds (90% видимой части)
    this._resizeObserver = new ResizeObserver(() => {
      this._map?.updateSize()
      // this._loadPoisInBounds() - не дергаем лишний раз, т.к. moveend сработает после ресайза и вызовет _loadPoisInBounds
    })
    this._resizeObserver.observe(el)
  }

  _handleMapHover(e) {
    if (!this._map || !this._tooltipOverlay) return
    const feature = this._map.forEachFeatureAtPixel(e.pixel, (f) => f)
    const el = this._tooltipOverlay.getElement()

    if (!feature) {
      this._hoveredFeatureId = null
      if (!el.classList.contains("hidden")) {
        el.classList.add("hidden")
        this._tooltipOverlay.setPosition(undefined)
      }
      this._map.getTargetElement().style.cursor = ""
      return
    }

    const features = feature.get("features")
    if (features && features.length > 1) {
      this._hoveredFeatureId = null
      if (!el.classList.contains("hidden")) {
        el.classList.add("hidden")
        this._tooltipOverlay.setPosition(undefined)
      }
      this._map.getTargetElement().style.cursor = "pointer"
      return
    }

    // Cluster-обёртка не хранит properties — берём оригинальную фичу (как в _handleMapClick)
    const sourceFeature = (features && features.length === 1) ? features[0] : feature

    const poiId = sourceFeature.get("poiId")
    if (poiId === this._hoveredFeatureId && !el.classList.contains("hidden")) {
      this._map.getTargetElement().style.cursor = "pointer"
      return
    }
    this._hoveredFeatureId = poiId

    const imgEl = el.querySelector(".ui-tooltip__img")
    const iconEl = el.querySelector(".ui-tooltip__category-icon")
    const categoryImageEl = el.querySelector(".ui-tooltip__category-image")
    const categoryEl = el.querySelector(".ui-tooltip__category-name")
    const nameEl = el.querySelector(".ui-tooltip__name")
    const ratingEl = el.querySelector(".ui-tooltip__rating")
    const ratingValEl = el.querySelector(".ui-tooltip__rating-value")
    const addressEl = el.querySelector(".ui-tooltip__address")

    const poiIcon = sourceFeature.get("poiIcon") || "mdi-map-marker"
    const poiCategoryImage = sourceFeature.get("poiCategoryImage") || ""
    const poiName = sourceFeature.get("poiName") || ""
    const poiCategory = sourceFeature.get("poiCategory") || ""
    const poiRating = sourceFeature.get("poiRating") || 0
    const poiAddress = sourceFeature.get("poiAddress") || ""
    const poiPhoto = sourceFeature.get("poiPhoto") || ""

    // Фото: если есть cover — подставляем URL, иначе оставляем fallback no-image.png
    if (imgEl) imgEl.src = poiPhoto || imgEl.dataset.fallback
    // Картинка категории приоритетнее MDI-иконки (паттерн list_item_component):
    // при наличии poiCategoryImage показываем <img> и прячем <i>, иначе наоборот.
    if (poiCategoryImage && categoryImageEl) {
      categoryImageEl.src = poiCategoryImage
      categoryImageEl.classList.remove("hidden")
      if (iconEl) iconEl.classList.add("hidden")
    } else {
      if (categoryImageEl) { categoryImageEl.src = ""; categoryImageEl.classList.add("hidden") }
      if (iconEl) {
        iconEl.classList.remove("hidden")
        iconEl.className = `ui-tooltip__category-icon mdi ${poiIcon} text-emerald-500 text-sm`
      }
    }
    if (categoryEl) categoryEl.textContent = poiCategory
    if (nameEl) nameEl.textContent = poiName
    if (ratingValEl) ratingValEl.textContent = poiRating > 0 ? poiRating.toFixed(1) : ""
    if (ratingEl) ratingEl.classList.toggle("hidden", poiRating <= 0)
    if (addressEl) { addressEl.textContent = poiAddress; addressEl.classList.toggle("hidden", !poiAddress) }

    const geometry = sourceFeature.getGeometry()
    if (geometry) this._positionTooltip(el, geometry.getCoordinates())
    this._map.getTargetElement().style.cursor = "pointer"
  }

  /**
   * Позиционирует тултип над точкой, не давая ему выйти за пределы карты/экрана.
   * Если карточка не влезает вверх — открывается вниз (top-center);
   * по горизонтали — прижимается к границам с отступом PADDING.
   *
   * @param {HTMLElement} el - элемент тултипа (#ui-tooltip)
   * @param {Array<number>} coords - координаты точки (EPSG:3857)
   */
  _positionTooltip(el, coords) {
    const PADDING = 12
    const mapEl = this._map.getTargetElement()
    const mapW = mapEl.clientWidth

    // Показываем для измерения реальных размеров (visibility:hidden — без мигания)
    el.classList.remove("hidden")
    el.style.visibility = "hidden"
    const tw = el.offsetWidth || 300
    const th = el.offsetHeight || 120
    el.style.visibility = ""

    const px = this._map.getPixelFromCoordinate(coords)
    if (!px) return

    // Вертикаль: по умолчанию вверх (bottom-center); если не влезает — вниз (top-center)
    let positioning = "bottom-center"
    let dy = -15
    if (px[1] - th - 15 < PADDING) {
      positioning = "top-center"
      dy = 15
    }

    // Горизонталь: кламп центрированного тултипа к границам карты
    const left = px[0] - tw / 2
    let dx = 0
    if (left < PADDING) dx = PADDING - left
    else if (left + tw > mapW - PADDING) dx = (mapW - PADDING) - (left + tw)

    this._tooltipOverlay.setPositioning(positioning)
    this._tooltipOverlay.setOffset([dx, dy])
    this._tooltipOverlay.setPosition(coords)
  }

  _handleMapClick(e) {
    if (!this._map) return
    const feature = this._map.forEachFeatureAtPixel(e.pixel, (f) => f)
    if (!feature) { this._closeDetailModal(); return }

    const features = feature.get("features")
    if (features && features.length > 1) {
      console.log(`[POI MAP] cluster click — ${features.length} features, zooming in`)
      const extent = boundingExtent(features.map((f) => f.getGeometry().getCoordinates()))
      this._map.getView().fit(extent, { duration: 200, padding: [50, 50, 50, 50] })
    } else {
      // Берем poiId с оригинальной фичи (Cluster source возвращает обёртку, у которой нет poiId)
      const sourceFeature = (features && features.length === 1) ? features[0] : feature
      const poiId = parseInt(sourceFeature.get("poiId"))

      console.log(`[POI MAP] poi click — ${poiId}`)
      document.dispatchEvent(new CustomEvent("poi:show-detail", { detail: { poiId } }))
    }
  }

  _closeDetailModal() {
    const modalOverlay = document.querySelector("[data-poi--show-component-target='overlay']")
    if (!modalOverlay || modalOverlay.classList.contains("hidden")) return
    // Делегируем закрытие контроллеру диалога (poi--show-component), который
    // корректно скрывает оверлей. Fallback — скрыть напрямую.
    document.dispatchEvent(new CustomEvent("poi:close-detail"))
    modalOverlay.classList.add("hidden")
  }

  _loadPois() {
    if (!this._vectorSource) return
    const container = document.getElementById("poi-map-features")
    if (!container) return
    const items = container.querySelectorAll("[data-poi-id]")
    console.log(`[POI MAP] _loadPois() — found ${items.length} POI elements in #poi-map-features`)
    if (!items.length) return

    const features = []
    items.forEach((item) => {
      const lat = parseFloat(item.dataset.poiLat)
      const lng = parseFloat(item.dataset.poiLng)
      if (!lat || !lng) return
      const feature = new Feature({ geometry: new Point(fromLonLat([lng, lat])) })
      feature.set("poiId", parseInt(item.dataset.poiId))
      feature.set("poiName", item.dataset.poiName || "")
      feature.set("poiIcon", item.dataset.poiIcon || "mdi-map-marker")
      feature.set("poiCategoryImage", item.dataset.poiCategoryImage || "")
      feature.set("poiCategory", item.dataset.poiCategory || "")
      feature.set("poiCategoryId", parseInt(item.dataset.poiCategoryId) || null)
      feature.set("poiRating", parseFloat(item.dataset.poiRating) || 0)
      feature.set("poiAddress", item.dataset.poiAddress || "")
      feature.set("poiUserId", parseInt(item.dataset.poiUserId) || null)
      feature.set("poiSlug", item.dataset.poiSlug || "")
      feature.set("poiPhoto", item.dataset.poiPhoto || "")
      features.push(feature)
    })

    this._vectorSource.clear()
    this._vectorSource.addFeatures(features)
    console.log(`[POI MAP] _loadPois() — ${features.length} features added to vector source`)
  }

  _loadPoisInBounds() {
    if (!this._map) return
    const size = this._map.getSize()
    if (!size || size[0] === undefined || size[1] === undefined) return

    const extent = this._map.getView().calculateExtent(size)
    const cx = (extent[0] + extent[2]) / 2
    const cy = (extent[1] + extent[3]) / 2
    const w = (extent[2] - extent[0]) * 0.9
    const h = (extent[3] - extent[1]) * 0.9
    const shrunk = [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2]
    const sw = toLonLat([shrunk[0], shrunk[1]])
    const ne = toLonLat([shrunk[2], shrunk[3]])

    // --- ДОБАВЛЯЕМ ПРОВЕРКУ ---
    // Округляем до 4 знаков, чтобы мелкие погрешности пикселей не считались сдвигом карты
    const currentBoundsKey = `${sw[1].toFixed(4)},${sw[0].toFixed(4)},${ne[1].toFixed(4)},${ne[0].toFixed(4)}`
    
    if (this._lastBoundsKey === currentBoundsKey) {
      // Координаты те же самые! Сбрасываем вызов, рефлекс НЕ летит
      return 
    }
    this._lastBoundsKey = currentBoundsKey
    // ---------------------------

    const filtersEl = document.querySelector('[data-controller="poi--filters-component"]')
    const categoryIds = filtersEl
      ? Array.from(filtersEl.querySelectorAll('input[type="checkbox"][value]:checked')).map((cb) => parseInt(cb.value))
      : []
    const query = filtersEl?.querySelector('[data-poi--filters-component-target="searchInput"]')?.value?.trim() || ""

    this.stimulate("PoiReflex#load_pois_in_bounds", {
      sw_lat: sw[1],
      sw_lng: sw[0],
      ne_lat: ne[1],
      ne_lng: ne[0],
      category_ids: categoryIds,
      query
    })

    this.element.dataset.swLat = sw[1]
    this.element.dataset.swLng = sw[0]
    this.element.dataset.neLat = ne[1]
    this.element.dataset.neLng = ne[0]
  }

  /**
   * Добавляет булавку пользователя на карту (mdi-pin, primary цвет #0288D1)
   *
   * Вызывается из _initWithCenter после инициализации карты
   *
   * @param {number} lat - широта
   * @param {number} lng - долгота
   */
  _addUserLocation(lat, lng) {
    if (!this._map) return

    // Удаляем старую булавку (если была)
    if (this._userPinOverlay) {
      this._map.removeOverlay(this._userPinOverlay)
    }

    const center = fromLonLat([lng, lat])

    // Маркер пользователя — стилизованная булавка с MDI-иконкой (mdi-navigation)
    // и пульсирующим кольцом. Зелено-голубая гамма (sky-600), белая обводка.
    // Иконка: mdi-navigation
    const wrapperEl = document.createElement("div")
    wrapperEl.className = "poi-user-pin"
    wrapperEl.innerHTML = `
      <span class="poi-user-pin__ping"></span>
      <span class="poi-user-pin__body">
        <span class="mdi mdi-navigation poi-user-pin__icon"></span>
      </span>
    `
    this._userPinOverlay = new Overlay({
      element: wrapperEl,
      positioning: "center-center",
      offset: [0, 0],
      stopEvent: false
    })
    this._userPinOverlay.setPosition(center)
    this._map.addOverlay(this._userPinOverlay)

    console.log(`[POI MAP] User pin added at ${lat.toFixed(4)},${lng.toFixed(4)}`)
  }

  /**
   * Открывает форму добавления нового POI
   * Диспатчит событие poi:open-modal, которое слушает Poi::FormComponent
   */
  openAddPoi() {
    document.dispatchEvent(new CustomEvent("poi:open-modal"))
  }

  sidebarPanOffset() {
    const s = document.querySelector('[data-poi--sidebar-component-target="sidebar"]')
    return (!s || s.classList.contains("poi-sidebar--hidden")) ? 0 : s.offsetWidth / 2
  }
}
