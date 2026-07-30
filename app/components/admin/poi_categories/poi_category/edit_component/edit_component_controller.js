import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::PoiCategory::EditComponent — форма создания/редактирования категории
 *
 * Если category.id есть → Admin::PoiCategoriesReflex#update
 * Если нет (новая запись) → Admin::PoiCategoriesReflex#create
 */
export default class extends ApplicationController {
  static targets = ["iconInput", "iconPreview", "submitButton"]

  /**
   * Обновляет превью иконки в реальном времени
   */
  previewIcon() {
    const value = this.iconInputTarget.value.trim()
    this.iconPreviewTarget.className = `mdi ${value || "mdi-map-marker"} text-emerald-500 text-2xl`
  }

  /**
   * Парсит FormData во вложенный хэш
   * "poi_category[slug]" → { poi_category: { slug: "..." } }
   * "poi_category[name][en]" → { poi_category: { name: { en: "..." } } }
   * "category[name][en]" → { category: { name: { en: "..." } } }
   */
  _parseFormData(formData) {
    const result = {}
    for (const [key, value] of formData.entries()) {
      // Разбираем "poi_category[slug]" и "poi_category[name][en]"
      const matches = key.match(/(\w+)\[(\w+)\](\[(\w+)\])?/)
      if (matches) {
        const obj = matches[1]        // poi_category
        const prop = matches[2]       // slug, name
        const sub = matches[4]        // en, ru (optional)
        if (!result[obj]) result[obj] = {}
        if (sub) {
          if (!result[obj][prop]) result[obj][prop] = {}
          result[obj][prop][sub] = value
        } else {
          result[obj][prop] = value
        }
      } else {
        // Плоский ключ (authenticity_token, _method и т.д.)
        if (!result._flat) result._flat = {}
        result._flat[key] = value
      }
    }
    return result
  }

  /**
   * Отправляет форму через StimulusReflex
   *
   * Парсит FormData во вложенный хэш через _parseFormData,
   * объединяет poi_category + category + flat ключи в один объект.
   * Форма имеет data-reflex-serialize-form="false" — StimulusReflex
   * НЕ пытается сериализовать форму самостоятельно.
   */
  handleSubmit(event) {
    event.preventDefault()
    const formData = new FormData(event.target)
    const parsed = this._parseFormData(formData)

    // Объединяем poi_category + category + flat (authenticity_token, _method)
    // в один плоский params-объект с вложенными ключами:
    // { slug: "...", icon: "mdi-playground", name: { en: "..." }, ... }
    const params = { ...parsed.poi_category, ...parsed.category }
    // Удаляем id из params, чтобы избежать конфликта с getReflexOptions() в StimulusReflex 3.5.5:
    // функция ошибочно поглощает объект, содержащий ключ `id`, как объект опций (см. utils.js#getReflexOptions).
    // id передаётся отдельно через data-id на форме и доступен в рефлексе через element.dataset.id.
    delete params.id
    const id = event.target.dataset.id

    console.log("[EDIT] parsed:", JSON.stringify(parsed))
    console.log("[EDIT] params:", JSON.stringify(params))
    console.log("[EDIT] id:", id)

    if (id) {
      this.stimulate("Admin::PoiCategoriesReflex#update", params)
    } else {
      this.stimulate("Admin::PoiCategoriesReflex#create", params)
    }
  }
}
