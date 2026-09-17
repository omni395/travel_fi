import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::PoiCategory::FieldFormComponent — диалог создания/редактирования поля
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
 *   requestDelete — открыть диалог подтверждения удаления (Ui::ConfirmDialogComponent)
 *   handleDialogConfirmed — удалить поле через Reflex после подтверждения
 */
export default class extends ApplicationController {
  static targets = [
    "overlay",
    "typeInput",
    "typeTrigger",
    "titleEl",
    "titleIcon",
    "titleText",
    "submitBtn",
    "submitText",
    "deleteBtn",
    "optionsSection",
    "transformInput",
    "transformTrigger"
  ]

  /**
   * Открывает диалог (режим создания)
   */
  open() {
    // Сброс формы до дефолтных значений
    this.overlayTarget.querySelector("form")?.reset()
    this.overlayTarget.classList.remove("hidden")
    this._setMode("create")
    // В режиме создания options-секция скрыта до выбора select/multiselect
    if (this.hasOptionsSectionTarget) this.optionsSectionTarget.classList.add("hidden")
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

    // Required / Active.
    // Rails check_box генерирует ПАРУ инпутов с одним name: скрытый (value=0) и checkbox (value=1).
    // querySelector по name возвращает ПЕРВЫЙ = скрытый (checked у него всегда false),
    // поэтому выбираем именно input[type='checkbox'], иначе чекбокс не заполнится.
    const requiredBox = form.querySelector("[name='poi_category_field[required]'][type='checkbox']")
    if (requiredBox) requiredBox.checked = fieldData.required || false
    const activeBox = form.querySelector("[name='poi_category_field[active]'][type='checkbox']")
    if (activeBox) activeBox.checked = fieldData.active !== false

    // Labels
    const labels = fieldData.label || {}
    ;["en", "ru", "es", "zh"].forEach(locale => {
      const el = form.querySelector(`[name='poi_category_field[label][${locale}]']`)
      if (el) el.value = labels[locale] || ""
    })

    // Placeholders
    const placeholders = fieldData.placeholder || {}
    ;["en", "ru", "es", "zh"].forEach(locale => {
      const el = form.querySelector(`[name='poi_category_field[placeholder][${locale}]']`)
      if (el) el.value = placeholders[locale] || ""
    })

    // Hint
    const hintEl = form.querySelector("[name='poi_category_field[hint]']")
    if (hintEl) hintEl.value = fieldData.hint || ""

    // Options (только для select/multiselect)
    const optionsRawEl = form.querySelector("[name='poi_category_field[options_raw]']")
    if (optionsRawEl) optionsRawEl.value = this._serializeOptions(fieldData.options)
    if (this.hasOptionsSectionTarget) {
      const isSelect = ["select", "multiselect"].includes(fieldData.field_type)
      this.optionsSectionTarget.classList.toggle("hidden", !isSelect)
    }

    // OSM Mapping
    const osmKeysEl = form.querySelector("[name='poi_category_field[osm_keys]']")
    if (osmKeysEl) osmKeysEl.value = (fieldData.osm_keys || []).join(", ")
    const osmValueMapEl = form.querySelector("[name='poi_category_field[osm_value_map]']")
    if (osmValueMapEl) osmValueMapEl.value = this._serializeValueMap(fieldData.osm_value_map)
    if (this.hasTransformInputTarget) this.transformInputTarget.value = fieldData.osm_transform || ""
    const transformLabel = this.element.querySelector(`[data-osm-transform="${fieldData.osm_transform || ""}"]`)?.textContent?.trim()
    if (this.hasTransformTriggerTarget && transformLabel) this.transformTriggerTarget.textContent = transformLabel

    this._setMode("edit")
  }

  /**
   * Переключает UI диалога между режимами создания и редактирования
   *
   * @param mode {String} "create" | "edit"
   */
  _setMode(mode) {
    const isEdit = mode === "edit"
    const icon = this.titleIconTarget
    this.titleTextTarget.textContent = isEdit ? this.element.dataset.editTitle : this.element.dataset.title
    icon.classList.toggle("mdi-plus-circle", !isEdit)
    icon.classList.toggle("mdi-pencil", isEdit)
    this.submitTextTarget.textContent = isEdit ? this.element.dataset.save : this.element.dataset.create
    this.deleteBtnTarget.classList.toggle("hidden", !isEdit)
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
    // Показываем options-секцию только для select/multiselect
    if (this.hasOptionsSectionTarget) {
      this.optionsSectionTarget.classList.toggle("hidden", !["select", "multiselect"].includes(value))
    }
  }

  /**
   * Выбирает OSM-трансформер из дропдауна
   */
  selectTransform(event) {
    const btn = event.currentTarget
    const value = btn.dataset.osmTransform
    const label = btn.textContent.trim()
    if (this.hasTransformInputTarget) {
      this.transformInputTarget.value = value
    }
    if (this.hasTransformTriggerTarget) {
      this.transformTriggerTarget.textContent = label
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
   * Сериализует options (массив {key, label}) в текст для textarea:
   * каждая строка "key;en;ru;es;zh" (пустые локали пропускаются).
   * Формат симметричен серверному options_editor_text.
   *
   * @param options {Object|null} options поля { values: [...] }
   * @return {String} текст для textarea
   */
  _serializeOptions(options) {
    const values = (options && options.values) || []
    return values.map(v => {
      const key = (v && v.key) || String(v)
      const label = (v && v.label) || {}
      const parts = [String(key)]
      ;["en", "ru", "es", "zh"].forEach(locale => {
        if (label[locale]) parts.push(String(label[locale]))
      })
      return parts.join(";")
    }).join("\n")
  }

  /**
   * Парсит текст textarea options в структуру { values: [{ key, label }] }
   *
   * @param text {String} строки вида "key;en;ru;es;zh"
   * @return {Object} { values: [...] }
   */
  _parseOptions(text) {
    const values = []
    String(text || "").split("\n").map(l => l.trim()).filter(Boolean).forEach(line => {
      const [key, en, ru, es, zh] = line.split(";").map(s => (s || "").trim())
      if (!key) return
      const label = {}
      if (en) label.en = en
      if (ru) label.ru = ru
      if (es) label.es = es
      if (zh) label.zh = zh
      values.push({ key, label })
    })
    return { values }
  }

  /**
   * Сериализует osm_value_map (объект) в JSON-строку для textarea
   *
   * @param map {Object|null} карта соответствий { "yes": true }
   * @return {String} JSON-строка или пустая строка
   */
  _serializeValueMap(map) {
    if (!map || typeof map !== "object" || Object.keys(map).length === 0) return ""
    return JSON.stringify(map, null, 2)
  }

  /**
   * Парсит текст textarea osm_value_map в объект
   *
   * @param text {String} JSON-строка
   * @return {Object} распарсенный объект или {}
   */
  _parseValueMap(text) {
    if (!String(text || "").trim()) return {}
    try {
      const parsed = JSON.parse(text)
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {}
    } catch (e) {
      return {}
    }
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

    // "id" — зарезервированная опция StimulusReflex (идентификатор рефлекса).
    // Убираем её из данных, чтобы объект стал аргументом, а не опциями.
    delete params.id

    // Unchecked-чекбоксы отсутствуют в FormData — явно выставляем оба флага.
    // ВАЖНО: querySelector по name возвращает ПЕРВЫЙ инпут = скрытый компаньон Rails check_box
    // (value=0, checked всегда false) → если брать его, required/active всегда сохранялись бы "0".
    // Выбираем именно input[type='checkbox'].
    const requiredBox = event.target.querySelector("[name='poi_category_field[required]'][type='checkbox']")
    const activeBox = event.target.querySelector("[name='poi_category_field[active]'][type='checkbox']")
    params.required = requiredBox?.checked ? "1" : "0"
    params.active = activeBox?.checked ? "1" : "0"

    // Options: textarea → структура { values: [{ key, label }] }, сырой текст не передаём
    const optionsRaw = event.target.querySelector("[name='poi_category_field[options_raw]']")
    if (optionsRaw) params.options = this._parseOptions(optionsRaw.value)
    delete params.options_raw

    // OSM Mapping: CSV-строка → массив; JSON-строка → объект; transform — из скрытого инпута.
    const osmKeysEl = event.target.querySelector("[name='poi_category_field[osm_keys]']")
    if (osmKeysEl) {
      params.osm_keys = String(osmKeysEl.value).split(",").map(s => s.trim()).filter(Boolean)
      if (params.osm_keys.length === 0) delete params.osm_keys
    }
    const osmValueMapEl = event.target.querySelector("[name='poi_category_field[osm_value_map]']")
    if (osmValueMapEl) {
      const map = this._parseValueMap(osmValueMapEl.value)
      if (Object.keys(map).length > 0) params.osm_value_map = map
    }
    // osm_transform берётся из FormData через скрытый инпут (transformInput)
    if (!params.osm_transform) delete params.osm_transform

    // В edit mode добавляем field_id и вызываем update
    if (editMode) {
      // id берём из скрытого поля или dataset
      const idEl = event.target.querySelector("[name='poi_category_field[id]']")
      if (idEl && idEl.value) {
        this.stimulate("Admin::PoiCategoryFieldsReflex#update", { field_id: idEl.value, ...params })
      }
    } else {
      this.stimulate("Admin::PoiCategoryFieldsReflex#create", params)
    }

    this.close()
  }

  /**
   * Открывает диалог подтверждения удаления поля (Ui::ConfirmDialogComponent)
   */
  requestDelete(event) {
    event.preventDefault()
    const dialog = this.overlayTarget.querySelector("[data-controller='ui--confirm-dialog-component']")
    if (dialog) {
      dialog.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  /**
   * Обрабатывает подтверждение из Ui::ConfirmDialogComponent и удаляет поле через Reflex
   */
  handleDialogConfirmed(event) {
    // Откликаемся только на событие диалога внутри этого оверлея
    if (!this.overlayTarget.contains(event.target)) return
    const form = this.overlayTarget.querySelector("form")
    const idEl = form?.querySelector("[name='poi_category_field[id]']")
    if (idEl && idEl.value) {
      this.stimulate("Admin::PoiCategoryFieldsReflex#destroy", { field_id: idEl.value })
    }
    this.close()
  }

  connect() {
    super.connect()
    this.#boundOpen = () => this.open()
    document.addEventListener("openFieldForm", this.#boundOpen)
    this.#boundEdit = (e) => this.openForEdit(e.detail)
    document.addEventListener("editFieldForm", this.#boundEdit)
    this.#boundConfirm = (e) => this.handleDialogConfirmed(e)
    document.addEventListener("confirmDialogConfirmed", this.#boundConfirm)
  }

  disconnect() {
    document.removeEventListener("openFieldForm", this.#boundOpen)
    document.removeEventListener("editFieldForm", this.#boundEdit)
    document.removeEventListener("confirmDialogConfirmed", this.#boundConfirm)
  }

  #boundOpen = null
  #boundEdit = null
  #boundConfirm = null
}
