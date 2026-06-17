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
import { getDistance } from "ol/sphere"
import { Circle as CircleStyle, Fill, Stroke, Style } from "ol/style"
import Translate from "ol/interaction/Translate"

/**
 * Poi::DetailComponent Controller
 *
 * Управляет:
 *   - Открытием/закрытием модалки (create/edit + view detail)
 *   - Переключением табов (info/comments/photos)
 *   - OpenLayers мини-картой с драггабельным маркером + круг 50м
 *   - Загрузкой динамических полей категории
 *   - Рендером полей (boolean/select/multiselect/number/text)
 *   - Показом детальной информации о POI в модалке
 */
export default class extends ApplicationController {
  static targets = [
    "overlay", "tab", "panel", "category", "fieldsContainer",
    "latitude", "longitude", "miniMap"
  ]

  static values = { activeTab: { type: String, default: "info" } }

  static MAX_RADIUS_METERS = 50

  connect() {
    super.connect()
    document.addEventListener("poi:open-modal", this.open.bind(this))
    document.addEventListener("poi:show-detail", this.showDetail.bind(this))
  }

  disconnect() {
    document.removeEventListener("poi:open-modal", this.open.bind(this))
    document.removeEventListener("poi:show-detail", this.showDetail.bind(this))
    if (this._map) {
      this._map.setTarget(null)
      this._map = null
    }
  }

  // ============================================================
  // УПРАВЛЕНИЕ МОДАЛКОЙ
  // ============================================================

  /**
   * Показывает детальную информацию о POI в модалке.
   * Вызывается при клике на маркер карты.
   * @param {CustomEvent} event - событие с poiId в event.detail.poiId
   */
  showDetail(event) {
    const poiId = event.detail?.poiId
    if (!poiId) return
    this.stimulate("PoiReflex#show_detail_modal", poiId)
  }

  /**
   * Открыть модалку — инициализировать карту
   */
  open() {
    this.overlayTarget.classList.remove("hidden")

    // Инициализируем карту при первом открытии (только один раз)
    if (!this._map) {
      setTimeout(() => this.initMiniMap(), 100)
    } else {
      this._map.updateSize()
    }
  }

  /**
   * Закрыть модалку.
   * Сбрасывает состояние: скрывает детальный просмотр, показывает форму.
   */
  close() {
    this.overlayTarget.classList.add("hidden")
    // Сброс состояния детального просмотра → форма
    const detailContent = document.getElementById("poi-detail-modal-content")
    const formContent = document.getElementById("poi-form-content")
    if (detailContent) detailContent.classList.add("hidden")
    if (formContent) formContent.classList.remove("hidden")
  }

  // ============================================================
  // ТАБЫ
  // ============================================================

  /**
   * Переключает активный таб
   * @param {Event} event - click событие
   */
  switchTab(event) {
    const tabName = event.currentTarget.dataset.tab
    if (!tabName) return

    this.activeTabValue = tabName

    // Обновляем стили табов
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === tabName
      tab.classList.toggle("border-emerald-500", isActive)
      tab.classList.toggle("text-emerald-600", isActive)
      tab.classList.toggle("border-transparent", !isActive)
      tab.classList.toggle("text-gray-500", !isActive)
      tab.classList.toggle("hover:text-gray-700", !isActive)
    })

    // Показываем/скрываем панели
    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.dataset.tab !== tabName)
    })
  }

  // ============================================================
  // МИНИ-КАРТА (для формы создания/редактирования)
  // ============================================================

  /**
   * Инициализация OL мини-карты с маркером и кругом 50м
   */
  initMiniMap() {
    const lat = parseFloat(this.element.dataset.poiDetailComponentInitialLat) || 51.5074
    const lng = parseFloat(this.element.dataset.poiDetailComponentInitialLng) || -0.1278
    const center = fromLonLat([lng, lat])

    // Слой подложки OSM
    const tileLayer = new TileLayer({
      source: new OSM()
    })

    // Векторный слой с маркером и кругом
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
        maxZoom: 19
      }),
      controls: []
    })

    // Круг 50м
    this._circleFeature = new Feature({
      geometry: new Circle(center, this.constructor.MAX_RADIUS_METERS)
    })
    this._circleFeature.setStyle(
      new Style({
        stroke: new Stroke({ color: "#10b981", width: 2 }),
        fill: new Fill({ color: "#10b981", opacity: 0.1 })
      })
    )
    this._vectorSource.addFeature(this._circleFeature)

    // Маркер (точка)
    this._markerFeature = new Feature({
      geometry: new Point(center)
    })
    this._markerFeature.setStyle(
      new Style({
        image: new CircleStyle({
          radius: 8,
          fill: new Fill({ color: "#10b981" }),
          stroke: new Stroke({ color: "#ffffff", width: 3 })
        })
      })
    )
    this._vectorSource.addFeature(this._markerFeature)

    // Translate interaction для перетаскивания маркера (через слои, без Collection)
    this._translate = new Translate({
      layers: [vectorLayer]
    })
    this._map.addInteraction(this._translate)

    this._translate.on("translating", (e) => this.onMarkerDrag(e))
    this._translate.on("translateend", () => this.onMarkerDragEnd())

    // Обновить скрытые поля начальными координатами
    this.updateCoords(lat, lng)

    this._map.updateSize()
  }

  /**
   * При перетаскивании маркера — проверяем расстояние и ограничиваем кругом
   */
  onMarkerDrag(e) {
    const centerCoord = this._circleFeature.getGeometry().getCenter()
    const markerCoord = this._markerFeature.getGeometry().getCoordinates()

    const distance = getDistance(
      toLonLat(centerCoord),
      toLonLat(markerCoord)
    )

    // Если маркер вышел за круг — возвращаем на границу круга
    if (distance > this.constructor.MAX_RADIUS_METERS) {
      const ratio = this.constructor.MAX_RADIUS_METERS / distance
      const dx = markerCoord[0] - centerCoord[0]
      const dy = markerCoord[1] - centerCoord[1]
      this._markerFeature.getGeometry().setCoordinates([
        centerCoord[0] + dx * ratio,
        centerCoord[1] + dy * ratio
      ])
    }
  }

  /**
   * После перетаскивания — обновляем скрытые поля
   */
  onMarkerDragEnd() {
    const coords = this._markerFeature.getGeometry().getCoordinates()
    const lonLat = toLonLat(coords)
    this.updateCoords(lonLat[1], lonLat[0])
  }

  /**
   * Обновляет hidden поля latitude/longitude
   */
  updateCoords(lat, lng) {
    this.latitudeTarget.value = lat.toFixed(6)
    this.longitudeTarget.value = lng.toFixed(6)
  }

  // ============================================================
  // ДИНАМИЧЕСКИЕ ПОЛЯ КАТЕГОРИИ
  // ============================================================

  loadFields() {
    const categoryId = this.categoryTarget.value
    if (!categoryId) return

    fetch(`/poi_categories/${categoryId}/fields.json`)
      .then(r => r.json())
      .then(data => this.renderFields(data))
      .catch(e => console.error("Fields load error:", e))
  }

  renderFields(fields) {
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

  /**
   * Открывает форму редактирования POI (с проверкой расстояния через Reflex)
   */
  editPoi() {
    const poiElement = document.querySelector("#poi-detail-modal-body [data-poi-id]")
    if (!poiElement) return
    const poiId = parseInt(poiElement.dataset.poiId)
    if (!poiId) return
    this.stimulate("PoiReflex#edit_poi", poiId)
  }
}
