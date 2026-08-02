import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::PoiCategory::FieldsListComponent — список полей категории
 *
 * Действия:
 *   openForm — открывает диалог создания поля
 *   moveUp — переместить поле вверх (уменьшить position)
 *   moveDown — переместить поле вниз (увеличить position)
 */
export default class extends ApplicationController {
  openForm() {
    document.dispatchEvent(new CustomEvent("openFieldForm"))
  }

  /**
   * Перемещает поле вверх (уменьшает position)
   */
  moveUp(event) {
    const btn = event.currentTarget
    const fieldId = btn.dataset.fieldId || btn.closest("[data-field-id]")?.dataset.fieldId
    if (fieldId) {
      this.stimulate("Admin::PoiCategoryFieldsReflex#reorder", fieldId, "up")
    }
  }

  /**
   * Перемещает поле вниз (увеличивает position)
   */
  moveDown(event) {
    const btn = event.currentTarget
    const fieldId = btn.dataset.fieldId || btn.closest("[data-field-id]")?.dataset.fieldId
    if (fieldId) {
      this.stimulate("Admin::PoiCategoryFieldsReflex#reorder", fieldId, "down")
    }
  }

  /**
   * Открывает диалог редактирования поля
   */
  editField(event) {
    // Игнорируем клики по кнопкам реордера
    if (event.target.closest("button")) return
    const row = event.currentTarget
    const json = row.dataset.fieldJson
    if (json) {
      try {
        const data = JSON.parse(json)
        document.dispatchEvent(new CustomEvent("editFieldForm", { detail: data }))
      } catch(e) {
        console.error("[FIELDS] failed to parse field data", e)
      }
    }
  }
}
