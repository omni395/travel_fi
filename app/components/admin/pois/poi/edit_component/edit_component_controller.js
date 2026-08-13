import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::Pois::Poi::EditComponent — форма редактирования POI
 *
 * Действия:
 *   handleSubmit — отправляет форму через StimulusReflex
 */
export default class extends ApplicationController {
  static targets = ["submitButton", "categoryInput", "categoryText", "statusInput", "statusText"]

  /**
   * Собирает вложенный хэш параметров формы из FormData.
   * Ключи вида "poi[name][en]" распаковываются в { poi: { name: { en: value } } },
   * "poi[metadata][key]" — в { poi: { metadata: { key: value } } },
   * "poi[slug]" — в { poi: { slug: value } }.
   * Служебный ключ "poi[id]" попадает в params.poi.id (используется для
   * детекции режима update и поиска записи в Reflex).
   *
   * @param {HTMLFormElement} form - форма
   * @return {Object} вложенный объект параметров { poi: { ... } }
   */
  _collectParams(form) {
    const params = { poi: {} }
    for (const [key, value] of new FormData(form).entries()) {
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
    return params
  }

  /**
   * Отправляет форму через StimulusReflex.
   * Если POI имеет id → Admin::PoisReflex#update, иначе → Admin::PoisReflex#create.
   */
  handleSubmit(event) {
    event.preventDefault()
    const params = this._collectParams(event.target)

    const hasId = Object.prototype.hasOwnProperty.call(params.poi, 'id') && params.poi.id
    if (hasId) {
      this.stimulate("Admin::PoisReflex#update", { poi: params.poi })
    } else {
      this.stimulate("Admin::PoisReflex#create", { poi: params.poi })
    }
  }

  /**
   * Выбор категории из Ui::DropdownComponent.
   * Обновляет скрытый input poi[poi_category_id] и текст кнопки.
   *
   * @param {Event} event - событие click по опции меню
   */
  selectCategory(event) {
    const value = event.currentTarget.dataset.value
    if (this.hasCategoryInputTarget) this.categoryInputTarget.value = value
    if (this.hasCategoryTextTarget) {
      this.categoryTextTarget.textContent = event.currentTarget.textContent.trim()
    }
  }

  /**
   * Выбор статуса из Ui::DropdownComponent.
   * Обновляет скрытый input poi[status] и текст кнопки.
   *
   * @param {Event} event - событие click по опции меню
   */
  selectStatus(event) {
    const value = event.currentTarget.dataset.value
    if (this.hasStatusInputTarget) this.statusInputTarget.value = value
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = event.currentTarget.textContent.trim()
    }
  }
}
