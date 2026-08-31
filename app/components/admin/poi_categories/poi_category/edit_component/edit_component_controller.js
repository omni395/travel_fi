import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::PoiCategory::EditComponent — форма создания/редактирования категории
 *
 * Если category.id есть → Admin::PoiCategoriesReflex#update
 * Если нет (новая запись) → Admin::PoiCategoriesReflex#create
 */
export default class extends ApplicationController {
  static targets = ["iconInput", "iconPreview", "submitButton", "iconImage", "iconPlaceholder", "iconStatus"]

  /**
   * Обновляет превью иконки в реальном времени
   */
  previewIcon() {
    const value = this.iconInputTarget.value.trim()
    this.iconPreviewTarget.className = `mdi ${value || "mdi-map-marker"} text-emerald-500 text-2xl`
  }

  /**
   * Реактивное превью выбранной картинки-маркера (FileReader).
   * Показывает выбранный файл мгновенно, до загрузки на сервер.
   * @param {Event} event - событие change на input[type=file]
   */
  previewCategoryIcon(event) {
    const file = event.target.files && event.target.files[0]
    if (!file) return

    const reader = new FileReader()
    reader.onload = (e) => {
      this._renderCategoryIconImage(e.target.result, true)
    }
    reader.readAsDataURL(file)
  }

  /**
   * Загрузка картинки-маркера через HTTP/multipart (fetch POST).
   * Бинарники не идут через Reflex. После успеха live-обновление карточки и
   * маркеров — через PoiCategoryBroadcaster (PaperTrail → VersionObserverJob).
   */
  uploadCategoryIcon() {
    const input = this._iconFileInput()
    const file = input && input.files && input.files[0]
    if (!file) return

    // data-атрибут с двойным дефисом НЕ мапится в dataset-[camelCase] — читаем
    // литеральное имя через getAttribute (как gallery_component_controller).
    const url = this.element.getAttribute("data-admin--poi-categories--poi-category--edit-component-upload-category-icon-path")
    if (!url) return

    const formData = new FormData()
    formData.append("category[category_icon]", file)

    this._setIconStatus(this._i18n("uploading"))
    fetch(url, {
      method: "POST",
      body: formData,
      headers: { "X-CSRF-Token": this._csrfToken() }
    })
      .then((res) => {
        if (!res.ok) {
          return res.json().then((data) => {
            const msg = data && data.error ? data.error : this._i18n("upload_failed")
            throw new Error(msg)
          })
        }
        return res.json()
      })
      .then((data) => {
        if (data && data.url) this._renderCategoryIconImage(data.url, false)
        this._setIconStatus(this._i18n("uploaded"))
        input.value = ""
      })
      .catch((err) => {
        this._setIconStatus(err.message)
        window.dispatchEvent(new CustomEvent("toast:error", { detail: { message: err.message } }))
        input.value = ""
      })
  }

  /**
   * Удаление картинки-маркера через HTTP DELETE (fetch).
   * После успеха показывается MDI-иконка (fallback).
   */
  removeCategoryIcon() {
    const url = this.element.getAttribute("data-admin--poi-categories--poi-category--edit-component-remove-category-icon-path")
    if (!url) return

    this._setIconStatus(this._i18n("removing"))
    fetch(url, {
      method: "DELETE",
      headers: { "X-CSRF-Token": this._csrfToken() }
    })
      .then((res) => {
        if (!res.ok) {
          return res.json().then((data) => {
            const msg = data && data.error ? data.error : this._i18n("remove_failed")
            throw new Error(msg)
          })
        }
        return res.json()
      })
      .then(() => {
        this._resetCategoryIcon()
        this._setIconStatus(this._i18n("removed"))
      })
      .catch((err) => {
        this._setIconStatus(err.message)
        window.dispatchEvent(new CustomEvent("toast:error", { detail: { message: err.message } }))
      })
  }

  /**
   * Рендерит картинку-маркер в превью-блоке, пряча placeholder (MDI).
   * @param {string} src - URL или data-URL картинки
   * @param {boolean} asPreview - распознан ли src как data-URL превью
   */
  _renderCategoryIconImage(src, asPreview) {
    let img = this.hasIconImageTarget ? this.iconImageTarget : null
    if (!img) {
      img = document.createElement("img")
      img.setAttribute("data-admin--poi-categories--poi-category--edit-component-target", "iconImage")
      img.className = "w-full h-full object-cover"
      this._iconPreviewContainer().appendChild(img)
    }
    img.src = src
    img.alt = asPreview ? "preview" : this._i18n("map_icon_alt")
    const ph = this.hasIconPlaceholderTarget ? this.iconPlaceholderTarget : null
    if (ph) ph.style.display = "none"
  }

  /**
   * Сбрасывает превью к placeholder (MDI-иконка) после удаления.
   */
  _resetCategoryIcon() {
    if (this.hasIconImageTarget) this.iconImageTarget.remove()
    const ph = this.hasIconPlaceholderTarget ? this.iconPlaceholderTarget : null
    if (ph) ph.style.display = ""
  }

  /**
   * Контейнер превью картинки-маркера (родитель img/placeholder).
   * @returns {Element}
   */
  _iconPreviewContainer() {
    return this.element.querySelector(".flex-shrink-0.w-16.h-16")
  }

  /**
   * Возвращает input[type=file] картинки-маркера.
   * @returns {HTMLInputElement|null}
   */
  _iconFileInput() {
    return this.element.querySelector('input[type="file"][accept="image/jpeg,image/png,image/webp"]')
  }

  /**
   * Устанавливает текст статуса под кнопками.
   * @param {string} text
   */
  _setIconStatus(text) {
    if (this.hasIconStatusTarget) this.iconStatusTarget.textContent = text
  }

  /**
   * Возвращает CSRF-токен из meta-тега.
   * @returns {string}
   */
  _csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.getAttribute("content") : ""
  }

  /**
   * Подстановка i18n-строки (en fallback, как gallery_component).
   * @param {string} key
   * @param {Object} vars - плейсхолдеры
   * @returns {string}
   */
  _i18n(key, vars = {}) {
    const base = {
      uploading: "Uploading...",
      uploaded: "Uploaded",
      removing: "Removing...",
      removed: "Removed",
      upload_failed: "Failed to upload category icon",
      remove_failed: "Failed to remove category icon",
      map_icon_alt: "Category icon"
    }
    let msg = base[key] || key
    Object.entries(vars).forEach(([k, v]) => {
      msg = msg.replace(`{${k}}`, v)
    })
    return msg
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
