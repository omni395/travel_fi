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
 * Poi::DetailsComponent Controller
 * Иконка: mdi-information-outline
 *
 * Управляет мини-картой (readonly) на табе «Детали» карточки POI.
 * Координаты берутся из скрытого data-элемента в Poi::ShowComponent.
 */
export default class extends ApplicationController {
  static targets = ["viewMap"]

  connect() {
    super.connect()
    // Задержка нужна, чтобы target получил размеры после вставки через CableReady
    setTimeout(() => this.initViewMap(), 100)
  }

  disconnect() {
    super.disconnect()
    if (this._map) {
      this._map.setTarget(null)
      this._map = null
    }
  }

  /**
   * Инициализирует мини-карту на табе «Детали»
   */
  initViewMap() {
    if (!this.hasViewMapTarget || !this.viewMapTarget.isConnected) return
    if (this._map) {
      this._map.updateSize()
      return
    }

    // Координаты из скрытого data-элемента в ShowComponent
    const poiEl = this.element.closest("[data-controller='poi--show-component']")?.querySelector("[data-poi-id]")
    const lat = parseFloat(poiEl?.dataset?.poiLat) || 51.5074
    const lng = parseFloat(poiEl?.dataset?.poiLng) || -0.1278
    const center = fromLonLat([lng, lat])

    this._map = new Map({
      target: this.viewMapTarget,
      layers: [new TileLayer({ source: new OSM() })],
      view: new View({ center, zoom: 16, maxZoom: 19 }),
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
}
