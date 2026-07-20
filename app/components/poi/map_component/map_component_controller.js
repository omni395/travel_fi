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
import Circle from "ol/geom/Circle"
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
 *   poiUserId применяется в Poi::DetailComponent для блокировки действий:
 *   редактирование, лайки, комментарии — если расстояние от пользователя
 *   до точки > 100м, И точка НЕ принадлежит пользователю. Это антифрод:
 *   нельзя написать "я был там" про точку в Китае из Америки.
 *
 * Ссылка: https://openlayers.org/en/latest/examples/
 */
export default class extends ApplicationController {
  static DEFAULT_ZOOM = 17
  static LONDON_FALLBACK = { lat: 51.5074, lng: -0.1278 }

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
    this._currentUserId = parseInt(document.body.dataset.currentUserId) || null
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
   * Обработчик события poi:reload-features от Poi::FiltersComponent
   * Перезагружает маркеры после apply_filters / reset_filters
   */
  _onReloadFeatures() {
    console.log('[POI MAP] _onReloadFeatures: reloading POI features')
    this._loadPois()
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

    this._userLocation = { lat, lng }
    this.stimulate("PoiReflex#set_location", { lat, lng })
    this._initWithCenter(lat, lng)
  }

  _onGeolocationError(err) {
    clearTimeout(this._geolocationTimer)
    console.log(`[POI MAP] Geolocation error: ${err.message}`)
    console.log(`[POI MAP] Fallback to London (${this.constructor.LONDON_FALLBACK.lat},${this.constructor.LONDON_FALLBACK.lng})`)
    this.stimulate("PoiReflex#show_geolocation_toast")
    this._initWithCenter(
      this.constructor.LONDON_FALLBACK.lat,
      this.constructor.LONDON_FALLBACK.lng
    )
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
        this._loadPoisInBounds()
        if (this._userLocation) {
          this._addUserLocation(this._userLocation.lat, this._userLocation.lng)
        }
        this._hideLoader()
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
    this._hideLoader()

    if (interactive) {
      this._setupInteractiveMode()
    }
  }

  /**
   * Настраивает интерактивный режим (для формы редактирования):
   * - Клик по карте → центрирование + обновление полей
   * - Перемещение карты (moveend) → обновление полей lat/lng
   */
  _setupInteractiveMode() {
    if (!this._map) return

    // При каждом перемещении карты обновляем поля координат
    this._map.on("moveend", () => {
      const center = toLonLat(this._map.getView().getCenter())
      this._updateCoordFields(center[1], center[0])
    })

    // Клик по карте → центрирование
    this._map.on("click", (evt) => {
      const coords = toLonLat(evt.coordinate)
      this._map.getView().setCenter(fromLonLat([coords[0], coords[1]]))
      this._updateCoordFields(coords[1], coords[0])
    })
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

    const singleStyle = new Style({
      image: new CircleStyle({
        radius: 10,
        fill: new Fill({ color: "#059669" }),
        stroke: new Stroke({ color: "#ffffff", width: 2 })
      })
    })

    this._map = new Map({
      target: el,
      layers: [
        new TileLayer({ source: new OSM() }),
        new VectorLayer({
          source: clusterSource,
          style: (feature) => {
            const features = feature.get("features")
            return features && features.length > 1 ? clusterStyle(feature) : singleStyle
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

    this._resizeObserver = new ResizeObserver(() => { this._map?.updateSize() })
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

    const poiId = feature.get("poiId")
    if (poiId === this._hoveredFeatureId && !el.classList.contains("hidden")) {
      this._map.getTargetElement().style.cursor = "pointer"
      return
    }
    this._hoveredFeatureId = poiId

    const iconEl = el.querySelector(".tooltip-category-icon")
    const categoryEl = el.querySelector(".tooltip-category-name")
    const nameEl = el.querySelector(".tooltip-name")
    const ratingEl = el.querySelector(".tooltip-rating")
    const ratingValEl = el.querySelector(".tooltip-rating-value")
    const addressEl = el.querySelector(".tooltip-address")

    const poiIcon = feature.get("poiIcon") || "mdi-map-marker"
    const poiName = feature.get("poiName") || ""
    const poiCategory = feature.get("poiCategory") || ""
    const poiRating = feature.get("poiRating") || 0
    const poiAddress = feature.get("poiAddress") || ""

    if (iconEl) iconEl.className = `tooltip-category-icon mdi ${poiIcon} text-emerald-500`
    if (categoryEl) categoryEl.textContent = poiCategory
    if (nameEl) nameEl.textContent = poiName
    if (ratingValEl) ratingValEl.textContent = poiRating > 0 ? poiRating.toFixed(1) : ""
    if (ratingEl) ratingEl.classList.toggle("hidden", poiRating <= 0)
    if (addressEl) { addressEl.textContent = poiAddress; addressEl.classList.toggle("hidden", !poiAddress) }

    const geometry = feature.getGeometry()
    if (geometry) this._tooltipOverlay.setPosition(geometry.getCoordinates())
    el.classList.remove("hidden")
    this._map.getTargetElement().style.cursor = "pointer"
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
    const modalOverlay = document.querySelector("[data-poi--detail-component-target='overlay']")
    if (!modalOverlay || modalOverlay.classList.contains("hidden")) return
    const detailContent = document.getElementById("poi-detail-modal-content")
    const formContent = document.getElementById("poi-form-content")
    if (detailContent) detailContent.classList.add("hidden")
    if (formContent) formContent.classList.remove("hidden")
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
      feature.set("poiCategory", item.dataset.poiCategory || "")
      feature.set("poiCategoryId", parseInt(item.dataset.poiCategoryId) || null)
      feature.set("poiRating", parseFloat(item.dataset.poiRating) || 0)
      feature.set("poiAddress", item.dataset.poiAddress || "")
      feature.set("poiUserId", parseInt(item.dataset.poiUserId) || null)
      features.push(feature)
    })

    this._vectorSource.clear()
    this._vectorSource.addFeatures(features)
    console.log(`[POI MAP] _loadPois() — ${features.length} features added to vector source`)
  }

  _loadPoisInBounds() {
    if (!this._map) return
    const extent = this._map.getView().calculateExtent(this._map.getSize())
    const sw = toLonLat([extent[0], extent[1]])
    const ne = toLonLat([extent[2], extent[3]])
    console.log(`[POI MAP] bounds: SW(${sw[1].toFixed(4)},${sw[0].toFixed(4)}) NE(${ne[1].toFixed(4)},${ne[0].toFixed(4)})`)

    // Читаем текущее состояние фильтров из DOM (не из session)
    const filtersEl = document.querySelector('[data-controller="poi--filters-component"]')
    const categoryIds = filtersEl
      ? Array.from(filtersEl.querySelectorAll('input[type="checkbox"][value]:checked')).map((cb) => parseInt(cb.value))
      : []
    const query = filtersEl?.querySelector('[data-poi--filters-component-target="searchInput"]')?.value?.trim() || ""
    console.log(`[POI MAP] _loadPoisInBounds — filters:`, { categoryIds, query })

    // Шлём bounds + фильтры одним рефлексом
    this.stimulate("PoiReflex#load_pois_in_bounds", {
      sw_lat: sw[1],
      sw_lng: sw[0],
      ne_lat: ne[1],
      ne_lng: ne[0],
      category_ids: categoryIds,
      query
    })

    // Сохраняем bounds в data-атрибуты для poi--filters-component (для Apply/Reset)
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

    // Булавка пользователя (HTML overlay с mdi-pin, primary blue #0288D1)
    const pinEl = document.createElement("div")
    pinEl.className = "flex items-center justify-center"
    pinEl.innerHTML = '<span class="mdi mdi-pin text-[#0288D1] text-3xl leading-none"></span>'
    // mdi: pin
    this._userPinOverlay = new Overlay({
      element: pinEl,
      positioning: "bottom-center",
      offset: [0, 0],
      stopEvent: false
    })
    this._userPinOverlay.setPosition(center)
    this._map.addOverlay(this._userPinOverlay)

    console.log(`[POI MAP] User pin added at ${lat.toFixed(4)},${lng.toFixed(4)}`)
  }

  sidebarPanOffset() {
    const s = document.querySelector('[data-poi--sidebar-component-target="sidebar"]')
    return (!s || s.classList.contains("poi-sidebar--hidden")) ? 0 : s.offsetWidth / 2
  }
}
