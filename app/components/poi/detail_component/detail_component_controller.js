import ApplicationController from '../../../javascript/controllers/application_controller'
import Map from "ol/Map"
import View from "ol/View"
import TileLayer from "ol/layer/Tile"
import VectorLayer from "ol/layer/Vector"
import VectorSource from "ol/source/Vector"
import OSM from "ol/source/OSM"
import Feature from "ol/Feature"
import Point from "ol/geom/Point"
import { fromLonLat } from "ol/proj"
import { Circle as CircleStyle, Fill, Stroke, Style } from "ol/style"

/**
 * Poi::DetailComponent Controller
 * Иконка: mdi-information-outline
 *
 * Управляет:
 *   - Закрытием модалки просмотра
 *   - Кнопкой Edit (открывает форму редактирования)
 *   - Отправкой комментария через StimulusReflex
 *   - Инициализацией мини-карты на вкладке Info
 */
export default class extends ApplicationController {
  static targets = ["viewMap", "commentsList", "commentInput"]

  connect() {
    super.connect()
    document.addEventListener("poi:show-detail", this.showDetail.bind(this))
  }

  disconnect() {
    super.disconnect()
    document.removeEventListener("poi:show-detail", this.showDetail.bind(this))
    if (this._map) {
      this._map.setTarget(null)
      this._map = null
    }
  }

  // ============================================================
  // ПОКАЗ ДЕТАЛЕЙ
  // ============================================================

  /**
   * Показывает детальную информацию о POI в модалке.
   * Вызывается при клике на маркер карты или элемент списка.
   * @param {CustomEvent} event - событие с poiId в event.detail.poiId
   */
  showDetail(event) {
    const poiId = event.detail?.poiId
    if (!poiId) return
    this.stimulate("PoiReflex#show_detail_modal", poiId)
  }

  /**
   * Закрыть модалку просмотра
   */
  close() {
    const overlay = this.element.closest("[data-poi--detail-component-target='overlay']")
    if (overlay) overlay.classList.add("hidden")
  }

  /**
   * Открыть форму редактирования POI
   */
  editPoi() {
    const poiId = parseInt(this.element.dataset.poiDetailComponentPoiId)
    if (!poiId) return
    this.stimulate("PoiReflex#edit_poi", poiId)
  }

  // ============================================================
  // МИНИ-КАРТА (readonly, вкладка Info)
  // ============================================================

  /**
   * Инициализирует мини-карту на вкладке Info
   * Вызывается из afterReflex после рендера компонента
   */
  initViewMap() {
    if (!this.hasViewMapTarget || !this.viewMapTarget.isConnected) return
    if (this._map) {
      this._map.updateSize()
      return
    }

    // Ищем координаты из data-атрибутов POI в компоненте
    const poiEl = this.element.querySelector("[data-poi-id]")
    const lat = parseFloat(poiEl?.dataset?.poiLat) || 51.5074
    const lng = parseFloat(poiEl?.dataset?.poiLng) || -0.1278
    const center = fromLonLat([lng, lat])

    this._map = new Map({
      target: this.viewMapTarget,
      layers: [
        new TileLayer({ source: new OSM() })
      ],
      view: new View({
        center,
        zoom: 16,
        maxZoom: 19
      }),
      controls: []
    })

    // Маркер
    const markerFeature = new Feature({ geometry: new Point(center) })
    markerFeature.setStyle(
      new Style({
        image: new CircleStyle({
          radius: 8,
          fill: new Fill({ color: "#059669" }),
          stroke: new Stroke({ color: "#ffffff", width: 3 })
        })
      })
    )

    const vectorSource = new VectorSource({ features: [markerFeature] })
    this._map.addLayer(new VectorLayer({ source: vectorSource }))

    this._map.updateSize()
  }

  // ============================================================
  // КОММЕНТАРИИ
  // ============================================================

  /**
   * Отправляет комментарий через StimulusReflex
   * @param {Event} event - submit событие формы
   */
  submitComment(event) {
    event.preventDefault()
    const body = this.commentInputTarget?.value?.trim()
    if (!body) return

    // Ищем poiId из data-атрибута компонента
    const poiId = parseInt(this.element.dataset.poiDetailComponentPoiId)
    if (!poiId) return

    this.stimulate("PoiReflex#create_comment", { poi_id: poiId, body })
  }

  /**
   * StimulusReflex lifecycle — после успешного рефлекса
   * Обновляем мини-карту и очищаем поле комментария
   */
  afterReflex(element, reflex) {
    if (reflex.includes("PoiReflex#show_detail_modal")) {
      setTimeout(() => this.initViewMap(), 100)
    }
    if (reflex.includes("PoiReflex#create_comment")) {
      if (this.hasCommentInputTarget) {
        this.commentInputTarget.value = ""
      }
    }
  }
}
