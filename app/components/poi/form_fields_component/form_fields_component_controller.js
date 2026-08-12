import { Controller } from "@hotwired/stimulus"

/**
 * Poi::FormFieldsComponent - динамические поля выбранной категории POI
 *
 * Чисто презентационный компонент: инпуты динамических полей рендерятся
 * сервером (PoiReflex#load_category_fields) и доставляются через CableReady.
 * Интерактивной логики на этом контроллере нет — она в родительском
 * poi--form-component (выбор категории, сабмит).
 */
export default class extends Controller {}
