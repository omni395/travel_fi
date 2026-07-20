import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::PoiCategory::EditComponent — форма редактирования категории POI
 *
 * Targets:
 *   iconInput    — текстовое поле для MDI-класса иконки
 *   iconPreview  — элемент превью иконки
 *   submitButton — кнопка сохранения
 *
 * Действия:
 *   previewIcon  — обновляет превью при вводе текста
 *   handleSubmit — отправляет форму через Reflex
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
   * Отправляет форму через StimulusReflex
   */
  handleSubmit(event) {
    event.preventDefault()
    const formData = new FormData(event.target)
    const params = Object.fromEntries(formData.entries())

    this.stimulusReflex("Admin::PoiCategoriesReflex#update", params)
  }
}
