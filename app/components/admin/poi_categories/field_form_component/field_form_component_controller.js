import ApplicationController from '../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::FieldFormComponent — диалог создания/редактирования поля
 *
 * Targets:
 *   overlay — затемнённый фон с модалкой
 *   typeInput — скрытое поле для field_type
 *   typeTrigger — текст кнопки-триггера дропдауна
 *
 * Actions:
 *   open — открыть диалог (для создания)
 *   close — закрыть диалог
 *   selectType — выбрать тип поля из дропдауна
 *   handleSubmit — создать или обновить поле через Reflex
 *   handleDelete — удалить поле через Reflex
 */
export default class extends ApplicationController {
  static targets = ["overlay", "typeInput", "typeTrigger"]

  /**
   * Открывает диалог (режим создания)
   */
  open() {
    // Сброс формы до дефолтных значений
    this.overlayTarget.querySelector("form")?.reset()
    this.overlayTarget.classList.remove("hidden")
  }

  /**
   * Открывает диалог для редактирования поля
   */
  openForEdit(fieldData) {
    this.overlayTarget.classList.remove("hidden")
    // Заполняем форму данными поля
    const form = this.overlayTarget.querySelector("form")
    if (!form) return
    form.querySelector("[name='poi_category_field[field_key]']").value = fieldData.field_key || ""
    form.querySelector("[name='_edit_mode']").value = "1"
    form.querySelector("[name='poi_category_field[poi_category_id]']").value = fieldData.poi_category_id

    // Position
    const posInput = form.querySelector("[name='poi_category_field[position]']")
    if (posInput) { posInput.value = fieldData.position; posInput.readOnly = true }

    // ID
    const idEl = form.querySelector("[name='poi_category_field[id]']")
    if (idEl) idEl.value = fieldData.id || ""

    // Type
    if (this.hasTypeInputTarget) this.typeInputTarget.value = fieldData.field_type || ""
    const typeLabel = this.element.querySelector(`[data-field-type="${fieldData.field_type}"]`)?.textContent?.trim()
    if (this.hasTypeTriggerTarget && typeLabel) this.typeTriggerTarget.textContent = typeLabel

    // Required / Active
    form.querySelector("[name='poi_category_field[required]']").checked = fieldData.required || false
    form.querySelector("[name='poi_category_field[active]']").checked = fieldData.active !== false

    // Labels
    const labels = fieldData.label || {}
    ;["en", "ru", "es", "zh"].forEach(locale => {
      const el = form.querySelector(`[name='poi_category_field[label][${locale}]']`)
      if (el) el.value = labels[locale] || ""
    })
  }

  /**
   * Закрывает диалог
   */
  close() {
    this.overlayTarget.classList.add("hidden")
  }

  /**
   * Выбирает тип поля из дропдауна
   */
  selectType(event) {
    const btn = event.currentTarget
    const value = btn.dataset.fieldType
    const label = btn.textContent.trim()
    if (this.hasTypeInputTarget) {
      this.typeInputTarget.value = value
    }
    if (this.hasTypeTriggerTarget) {
      this.typeTriggerTarget.textContent = label
    }
  }

  /**
   * Парсит FormData во вложенный хэш
   */
  _parseFormData(formData) {
    const result = {}
    for (const [key, value] of formData.entries()) {
      const matches = key.match(/(\w+)\[(\w+)\](\[(\w+)\])?/)
      if (matches) {
        const obj = matches[1]
        const prop = matches[2]
        const sub = matches[4]
        if (!result[obj]) result[obj] = {}
        if (sub) {
          if (!result[obj][prop]) result[obj][prop] = {}
          result[obj][prop][sub] = value
        } else {
          result[obj][prop] = value
        }
      } else {
        if (!result._flat) result._flat = {}
        result._flat[key] = value
      }
    }
    return result
  }

  /**
   * Создаёт или обновляет поле через Reflex
   */
  handleSubmit(event) {
    event.preventDefault()
    const formData = new FormData(event.target)
    const parsed = this._parseFormData(formData)
    const params = { ...parsed.poi_category_field }
    const editMode = parsed._flat?._edit_mode === "1"

    // В edit mode добавляем id и вызываем update
    if (editMode) {
      // id берём из скрытого поля или dataset
      const idEl = event.target.querySelector("[name='poi_category_field[id]']")
      if (idEl && idEl.value) {
        this.stimulate("Admin::PoiCategoryFieldsReflex#update", { id: idEl.value, ...params })
      }
    } else {
      this.stimulate("Admin::PoiCategoryFieldsReflex#create", params)
    }

    this.close()
  }

  /**
   * Удаляет поле через Reflex
   */
  handleDelete(event) {
    if (!confirm("Are you sure?")) return
    const form = this.overlayTarget.querySelector("form")
    const idEl = form?.querySelector("[name='poi_category_field[id]']")
    if (idEl && idEl.value) {
      this.stimulate("Admin::PoiCategoryFieldsReflex#destroy", { id: idEl.value })
    }
    this.close()
  }

  connect() {
    super.connect()
    this.#boundOpen = () => this.open()
    document.addEventListener("openFieldForm", this.#boundOpen)
    this.#boundEdit = (e) => this.openForEdit(e.detail)
    document.addEventListener("editFieldForm", this.#boundEdit)
  }

  disconnect() {
    document.removeEventListener("openFieldForm", this.#boundOpen)
    document.removeEventListener("editFieldForm", this.#boundEdit)
  }

  #boundOpen = null
  #boundEdit = null
}
