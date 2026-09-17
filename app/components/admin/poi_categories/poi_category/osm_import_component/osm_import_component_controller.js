import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::PoiCategories::PoiCategory::OsmImportComponent — управление диалогом импорта из OSM
 *
 * Targets:
 * - overlay: затемнённый фон с модалкой
 * - locationPanel: блок выбора локации (скрывается после старта импорта)
 * - progressPanel: блок прогресса импорта
 * - cityTriggerText: текст внутри триггера дропдауна
 * - validationError: текст ошибки валидации
 * - customFields: блок ручного ввода bbox
 * - customCity, customCountry, customSouth, customWest, customNorth, customEast: поля ручного ввода
 * - importBtn: кнопка импорта
 * - progressBar: элемент прогресс-бара
 * - progressStatusText: текст статуса импорта
 * - progressProcessed, progressTotal: счётчики обработано/всего
 * - closeBtn: кнопка закрытия (после завершения)
 *
 * Actions:
 * - open: открыть диалог
 * - close: закрыть диалог
 * - selectCity: выбрать город из дропдауна
 * - toggleCustom: показать/скрыть ручной ввод
 * - startImport: запустить импорт через Reflex
 */
export default class extends ApplicationController {
  static targets = [
    "overlay", "locationPanel", "progressPanel",
    "cityTriggerText", "validationError",
    "customFields", "customCity", "customCountry",
    "customSouth", "customWest", "customNorth", "customEast",
    "importBtn", "progressBar", "progressStatusText",
    "progressCounter", "progressSpinner", "closeBtn",
    "pbfFileInput", "pbfImportBtn", "pbfStatus"
  ]

  /**
   * Безопасно обновляет текст progressCounter.
   * Если target отсутствует (старый кэш шаблона) — не падает, пишет в консоль.
   */
  #setProgressText(text) {
    if (this.hasProgressCounterTarget) {
      this.progressCounterTarget.textContent = text
    }
  }

  static values = {
    cities: { type: Object, default: {} }
  }

  #selectedCity = null
  #selectedBbox = null
  #selectedCountry = ""
  #currentProgress = 0
  #isImporting = false
  #boundStarted = null
  #boundProgress = null
  #boundComplete = null
  #boundPbfProgress = null
  #boundFailed = null

  /**
   * Открывает диалог импорта
   */
  open() {
    this.overlayTarget.classList.remove("hidden")
    this.#resetState()
  }

  /**
   * Закрывает диалог и сбрасывает все панели
   * Заблокировано пока идёт импорт (#isImporting === true)
   */
  close() {
    if (this.#isImporting) return
    this.overlayTarget.classList.add("hidden")
    this.#resetState()
  }

  /**
   * Выбирает город из дропдауна
   * Дропдаун управляется Ui::DropdownComponent (ui--dropdown-component#toggle)
   */
  selectCity(event) {
    const btn = event.currentTarget
    this.#selectedCity = btn.dataset.city
    this.#selectedBbox = JSON.parse(btn.dataset.bbox)
    this.#selectedCountry = btn.dataset.country

    // Обновляем текст кнопки-триггера
    this.cityTriggerTextTarget.textContent = `${btn.dataset.city}, ${btn.dataset.country}`

    // Прячем ошибку валидации
    this.validationErrorTarget.classList.add("hidden")

    // Скрываем ручной ввод (если был открыт)
    this.customFieldsTarget.classList.add("hidden")

    // Разблокируем кнопку импорта
    this.importBtnTarget.disabled = false
  }

  /**
   * Показать/скрыть поля ручного ввода
   */
  toggleCustom() {
    this.customFieldsTarget.classList.toggle("hidden")
    if (!this.customFieldsTarget.classList.contains("hidden")) {
      this.#selectedCity = null
      this.#selectedBbox = null
      this.#selectedCountry = ""
      this.cityTriggerTextTarget.textContent = this.cityTriggerTextTarget.dataset.placeholder || "Choose a city"
    }
    this.#updateImportBtnState()
  }

  /**
   * Проверяет заполненность кастомных полей bbox
   */
  #checkCustomFieldsReady() {
    if (this.customFieldsTarget.classList.contains("hidden")) return false
    const s = parseFloat(this.customSouthTarget.value)
    const w = parseFloat(this.customWestTarget.value)
    const n = parseFloat(this.customNorthTarget.value)
    const e = parseFloat(this.customEastTarget.value)
    return !isNaN(s) && !isNaN(w) && !isNaN(n) && !isNaN(e)
  }

  /**
   * Обновляет состояние кнопки импорта
   */
  #updateImportBtnState() {
    const cityReady = this.#selectedCity !== null && this.#selectedBbox !== null
    const customReady = this.#checkCustomFieldsReady()
    this.importBtnTarget.disabled = !(cityReady || customReady)
  }

  /**
   * Запускает импорт через StimulusReflex
   * Reflex выполняет синхронный импорт (OsmImportService напрямую).
   * Прогресс приходит через dispatch_event от OsmImportBroadcaster.
   * Кнопка Close блокируется до завершения.
   */
  startImport() {
    const { city, country, bbox } = this.#getLocation()

    if (!this.#selectedCity && (!bbox || bbox.length !== 4 || bbox.some(v => isNaN(v)))) {
      this.validationErrorTarget.textContent = "Please select a city or fill in all bounding box coordinates"
      this.validationErrorTarget.classList.remove("hidden")
      return
    }

    // Блокируем кнопку Close до завершения импорта
    this.closeBtnTarget.disabled = true
    this.closeBtnTarget.title = "Wait for import to complete"

    // Переключаем UI на панель прогресса (спиннер)
    this.locationPanelTarget.classList.add("hidden")
    this.progressPanelTarget.classList.remove("hidden")
    this.progressStatusTextTarget.textContent = this.progressStatusTextTarget.dataset.fetchingText || "Fetching data from OpenStreetMap..."
    this.progressBarTarget.style.width = "0%"
    this.#setProgressText("0 of 0 (0%)")

    // Блокируем все кнопки закрытия до завершения импорта
    this.#currentProgress = 0
    this.#isImporting = true

    const element = this.overlayTarget
    const categoryId = element.closest("[data-admin-poi-category-id]")?.dataset.adminPoiCategoryId

    this.stimulate(
      "Admin::PoiCategoriesReflex#import_from_osm",
      { category_id: categoryId, location: { city, country, bbox } }
    )
  }

  /**
   * Загружает .pbf файл через HTTP/multipart и запускает фоновый OsmPbfImportJob.
   * Бинарник через Reflex не передаётся — используем fetch (как картинку категории).
   * После успешного enqueue переключаем UI на панель прогресса.
   */
  startPbfImport() {
    const input = this.hasPbfFileInputTarget ? this.pbfFileInputTarget : null
    const file = input && input.files && input.files[0]
    if (!file) { this.#setPbfStatus(this.element.dataset.pbfFileRequired || "Select a .pbf file", true); return }

    const path = this.element.getAttribute("data-admin--poi-categories--poi-category--osm-import-component-pbf-import-path")
    if (!path) { this.#setPbfStatus(this.element.dataset.pbfNoRoute || "Import route unavailable", true); return }

    // Блокируем UI
    this.#setPbfStatus("", false)
    if (this.hasPbfImportBtnTarget) this.pbfImportBtnTarget.disabled = true

    const formData = new FormData()
    formData.append("poi_category[pbf_file]", file, file.name)

    fetch(path, {
      method: "POST",
      body: formData,
      headers: { "X-CSRF-Token": this._csrfToken() }
    })
      .then((res) => {
        if (!res.ok) {
          return res.json().then((data) => {
            const msg = (data && data.error) || this.element.dataset.pbfUploadFailed || "Upload failed"
            throw new Error(msg)
          })
        }
        return res.json()
      })
      .then(() => {
        // Файл принят → переходим к панели прогресса (как при старте импорта)
        this.closeBtnTarget.disabled = true
        this.closeBtnTarget.title = "Wait for import to complete"
        this.locationPanelTarget.classList.add("hidden")
        this.progressPanelTarget.classList.remove("hidden")
        this.progressStatusTextTarget.textContent =
          this.progressStatusTextTarget.dataset.importingText || "Importing..."
        this.progressBarTarget.style.width = "0%"
        this.#setProgressText("0 (0%)")
        this.#currentProgress = 0
        this.#isImporting = true
      })
      .catch((err) => {
        this.#setPbfStatus(err.message, true)
        if (this.hasPbfImportBtnTarget) this.pbfImportBtnTarget.disabled = false
      })
  }

  /**
   * Обработчик промежуточного прогресса импорта из .pbf (osmPbfProgress).
   * Передаётся только счётчик обработанных записей (CableReady: snake_case → camelCase).
   */
  osmPbfProgress(event) {
    const processed = event.detail?.processed
    if (processed === undefined) return
    this.#currentProgress = processed
    this.#setProgressText(`${processed} processed`)
  }

  /**
   * Обработчик ошибки импорта (osmImportFailed)
   */
  osmImportFailed(event) {
    const msg = event.detail?.message || this.element.dataset.pbfImportFailed || "Import failed"
    this.progressStatusTextTarget.textContent = `\u274C ${msg}`
    this.progressStatusTextTarget.classList.remove("text-emerald-600", "text-emerald-700")
    this.progressStatusTextTarget.classList.add("text-red-600")
    this.#isImporting = false
    this.closeBtnTarget.disabled = false
    this.closeBtnTarget.title = ""
  }

  /**
   * Устанавливает текст статуса PBF (ошибка/успех)
   */
  #setPbfStatus(message, isError) {
    if (!this.hasPbfStatusTarget) return
    this.pbfStatusTarget.textContent = message
    this.pbfStatusTarget.classList.remove("text-emerald-600", "text-red-600")
    this.pbfStatusTarget.classList.add(isError ? "text-red-600" : "text-emerald-600")
    this.pbfStatusTarget.classList.toggle("hidden", !message)
  }

  /**
   * Обработчик события osmImportStarted
   */
  osmImportStarted(event) {
    console.log('[OSM IMPORT] ⏳ osmImportStarted received', event.detail)
    this.#currentProgress = 0
    this.progressStatusTextTarget.textContent =
      this.progressStatusTextTarget.dataset.fetchingText || "Fetching data from OpenStreetMap..."
    this.progressBarTarget.style.width = "0%"
    this.#setProgressText("0 of 0 (0%)")
  }

  /**
   * Обработчик события osmImportProgress
   * Обновляет UI только если новое processed БОЛЬШЕ предыдущего.
   * SolidCable может доставлять события вразнобой (polling 5s),
   * поэтому старые события не должны перезатирать новые.
   * ВНИМАНИЕ: CableReady конвертирует snake_case в camelCase в detail
   */
  osmImportProgress(event) {
    const detail = event.detail
    const total = detail.total
    const processed = detail.processed
    const alreadyInDb = detail.alreadyInDb  // CableReady: already_in_db → alreadyInDb
    const percent = total > 0 ? Math.min(Math.round((processed / total) * 100), 100) : 0
    console.log(`[OSM IMPORT] 📊 progress: ${processed}/${total} (${percent}%), alreadyInDb: ${alreadyInDb}`)

    // Игнорируем строго старые события (<, не <=, чтобы обработать повторы)
    if (this.#currentProgress !== undefined && processed < this.#currentProgress) {
      console.log(`[OSM IMPORT] ⏭️ skip stale progress: ${processed} < ${this.#currentProgress}`)
      return
    }
    this.#currentProgress = processed

    this.#setProgressText(`${processed} of ${total} (${percent}%)`)
    this.progressBarTarget.style.width = `${percent}%`

    if (processed === 0 && alreadyInDb !== null && alreadyInDb !== undefined) {
      const toImport = total - alreadyInDb
      this.progressStatusTextTarget.textContent =
        `OSM returned ${total} elements, ${alreadyInDb} already in DB, ${toImport} will be imported`
    } else {
      this.progressStatusTextTarget.textContent =
        this.progressStatusTextTarget.dataset.importingText || "Importing..."
    }
  }

  /**
   * Обработчик события osmImportComplete
   */
  osmImportComplete(event) {
    const detail = event.detail  // CableReady: snake_case → camelCase
    const total = detail.created + (detail.skippedDuplicate || 0) + (detail.skippedModified || 0) + detail.errors
    console.log(`[OSM IMPORT] ✅ osmImportComplete received`, detail)

    this.progressBarTarget.style.width = "100%"
    this.#setProgressText(`${total} of ${total} (100%)`)
    this.progressStatusTextTarget.textContent =
      `\u2705 Created: ${detail.created}, Skipped: ${(detail.skippedDuplicate || 0) + (detail.skippedModified || 0)}, Errors: ${detail.errors}`
    this.progressStatusTextTarget.classList.remove("text-emerald-600")
    this.progressStatusTextTarget.classList.add("text-emerald-700")

    // Прячем спиннер, показываем зелёную галочку (в статусе)
    if (this.hasProgressSpinnerTarget) {
      this.progressSpinnerTarget.classList.add("hidden")
    }

    this.#isImporting = false
    this.closeBtnTarget.disabled = false
    this.closeBtnTarget.title = ""
  }

  /**
   * Возвращает CSRF-токен из meta-тега (для fetch-загрузки .pbf)
   * @returns {string}
   */
  _csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.getAttribute("content") : ""
  }

  /**
   * Собирает данные локации из формы
   */
  #getLocation() {
    // Если город выбран из дропдауна
    if (this.#selectedCity && this.#selectedBbox) {
      return {
        city: this.#selectedCity,
        country: this.#selectedCountry,
        bbox: this.#selectedBbox
      }
    }

    // Если ручной ввод
    return {
      city: this.customCityTarget.value || "Custom",
      country: this.customCountryTarget.value || "",
      bbox: [
        parseFloat(this.customSouthTarget.value),
        parseFloat(this.customWestTarget.value),
        parseFloat(this.customNorthTarget.value),
        parseFloat(this.customEastTarget.value)
      ]
    }
  }

  /**
   * Сбрасывает состояние диалога
   */
  #resetState() {
    this.#selectedCity = null
    this.#selectedBbox = null
    this.#selectedCountry = ""
    this.cityTriggerTextTarget.textContent = this.cityTriggerTextTarget.dataset.placeholder || "Choose a city"
    this.validationErrorTarget.classList.add("hidden")
    this.customFieldsTarget.classList.add("hidden")
    this.progressPanelTarget.classList.add("hidden")
    this.locationPanelTarget.classList.remove("hidden")
    this.progressBarTarget.style.width = "0%"
    this.progressStatusTextTarget.classList.remove("text-red-600", "text-emerald-700")
    this.progressStatusTextTarget.classList.add("text-emerald-600")
    this.progressStatusTextTarget.textContent = this.progressStatusTextTarget.dataset.fetchingText || "Fetching data from OpenStreetMap..."
    if (this.hasProgressSpinnerTarget) this.progressSpinnerTarget.classList.remove("hidden")
    this.closeBtnTarget.classList.add("hidden")
    this.importBtnTarget.disabled = true
    // Сброс PBF-секции (файл, кнопка, статус)
    if (this.hasPbfFileInputTarget) this.pbfFileInputTarget.value = ""
    if (this.hasPbfImportBtnTarget) this.pbfImportBtnTarget.disabled = false
    this.#setPbfStatus("", false)
    // Сброс полей ручного ввода
    ;["customCity", "customCountry", "customSouth", "customWest", "customNorth", "customEast"].forEach(t => {
      if (this[`${t}Target`]) this[`${t}Target`].value = ""
    })
  }

  connect() {
    super.connect()
    this.importBtnTarget.disabled = true
    this.#boundProgress = this.osmImportProgress.bind(this)
    this.#boundComplete = this.osmImportComplete.bind(this)
    this.#boundStarted = this.osmImportStarted.bind(this)
    document.addEventListener("osmImportStarted", this.#boundStarted)
    document.addEventListener("osmImportProgress", this.#boundProgress)
    document.addEventListener("osmImportComplete", this.#boundComplete)
    this.#boundPbfProgress = this.osmPbfProgress.bind(this)
    this.#boundFailed = this.osmImportFailed.bind(this)
    document.addEventListener("osmPbfProgress", this.#boundPbfProgress)
    document.addEventListener("osmImportFailed", this.#boundFailed)

    // Слушаем изменения кастомных полей для обновления кнопки
    ;["customCity", "customCountry", "customSouth", "customWest", "customNorth", "customEast"].forEach(t => {
      const el = this[`${t}Target`]
      if (el) el.addEventListener("input", () => this.#updateImportBtnState())
    })
  }

  disconnect() {
    document.removeEventListener("osmImportStarted", this.#boundStarted)
    document.removeEventListener("osmImportProgress", this.#boundProgress)
    document.removeEventListener("osmImportComplete", this.#boundComplete)
    document.removeEventListener("osmPbfProgress", this.#boundPbfProgress)
    document.removeEventListener("osmImportFailed", this.#boundFailed)
  }
}
