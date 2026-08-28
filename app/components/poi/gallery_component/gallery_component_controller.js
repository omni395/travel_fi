import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Poi::GalleryComponent Controller
 * Иконка: mdi-image-multiple-outline
 *
 * Управляет галереей фото POI:
 *   - upload: загрузка фото через HTTP/multipart (fetch POST) в Poi::PhotosController
 *   - remove: удаление фото через HTTP DELETE в Poi::PhotosController (fetch)
 *   - open/close/prev/next: lightbox/слайдер по миниатюрам
 *   - closeBackdrop/stopPropagation: закрытие по клику вне окна
 *
 * Live-обновление сетки после добавления/удаления — через Broadcaster
 * (inner_html [data-poi-gallery]), поэтому здесь НЕ перерисовываем вручную.
 */
export default class extends ApplicationController {
  static targets = ["grid", "thumb", "lightbox", "lightboxImage", "counter", "fileInput"]

  connect() {
    super.connect()
    this._currentIndex = 0
    this._onKeydown = this._onKeydown.bind(this)
    document.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    super.disconnect()
    document.removeEventListener("keydown", this._onKeydown)
  }

  /**
   * Загрузка фото через HTTP/multipart (fetch POST). Бинарники не идут
   * через Reflex. После успешного ответа сетка обновится через Broadcaster.
   * @param {Event} event - событие change на input[type=file]
   */
  upload(event) {
    const input = event.target
    const file = input.files && input.files[0]
    if (!file) return

    // data-атрибут с двойным дефисом (data-poi--gallery-component-create-path)
    // НЕ мапится в dataset-[camelCase]; читаем литеральное имя через getAttribute,
    // иначе url = undefined → fetch("/undefined") → RoutingError.
    const url = this.element.getAttribute("data-poi--gallery-component-create-path")
    const formData = new FormData()
    formData.append("photo[image]", file)

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
      .then(() => {
        // live-обновление с current_user (сортировка «свои вначале» + кнопки).
        // Дубликат Broadcaster-зоны безопасен (тот может не достигнуть user-браузера).
        this._refresh()
        input.value = ""
      })
      .catch((err) => {
        window.dispatchEvent(new CustomEvent("toast:error", { detail: { message: err.message } }))
        input.value = ""
      })
  }

  /**
   * Запрашивает актуальную галерею через Reflex (чтение), доставляет
   * селекторным inner_html в [data-poi-gallery].
   */
  _refresh() {
    const poiId = this.element.getAttribute("data-poi--gallery-component-poi-id")
    if (!poiId) return
    this.stimulate("PoiReflex#refresh_gallery", { poi_id: poiId })
  }

  /**
   * Удаление фото через HTTP DELETE (Poi::PhotosController#destroy), как и
   * создание. Бинарники/JSON через fetch — надёжнее, чем Reflex для тестов.
   * После успеха — live-обновление через PoiReflex#refresh_gallery + Broadcaster.
   * @param {Event} event - клик по кнопке удаления
   */
  remove(event) {
    event.stopPropagation()
    const button = event.currentTarget
    const photoId = button.dataset.photoId
    const poiId = this.element.getAttribute("data-poi--gallery-component-poi-id")
    if (!photoId || !poiId) return

    const url = `${this.element.getAttribute("data-poi--gallery-component-create-path")}/${photoId}`
    fetch(url, {
      method: "DELETE",
      headers: { "X-CSRF-Token": this._csrfToken() }
    })
      .then((res) => {
        if (!res.ok) {
          return res.json().then((d) => { throw new Error(d.error || this._i18n("upload_failed")) })
        }
        return res.json()
      })
      .then(() => this._refresh())
      .catch((err) => {
        window.dispatchEvent(new CustomEvent("toast:error", { detail: { message: err.message } }))
      })
  }

  /**
   * Открывает lightbox по клику на миниатюру.
   * @param {Event} event - клик по миниатюре
   */
  open(event) {
    const thumb = event.currentTarget
    const index = Array.from(this.thumbTargets).indexOf(thumb)
    if (index === -1) return
    this._currentIndex = index
    this._render()
    this.lightboxTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  /**
   * Закрывает lightbox.
   */
  close() {
    this.lightboxTarget.classList.add("hidden")
    document.body.style.overflow = ""
  }

  /**
   * Закрывает lightbox по клику на затемнённый фон.
   * @param {Event} event - клик
   */
  closeBackdrop(event) {
    if (event.target === this.lightboxTarget) this.close()
  }

  /**
   * Останавливает всплытие клика (клик внутри окна не закрывает lightbox).
   * @param {Event} event - клик
   */
  stopPropagation(event) {
    event.stopPropagation()
  }

  /**
   * Предыдущая фотография в слайдере.
   */
  prev() {
    if (this.thumbTargets.length === 0) return
    this._currentIndex = (this._currentIndex - 1 + this.thumbTargets.length) % this.thumbTargets.length
    this._render()
  }

  /**
   * Следующая фотография в слайдере.
   */
  next() {
    if (this.thumbTargets.length === 0) return
    this._currentIndex = (this._currentIndex + 1) % this.thumbTargets.length
    this._render()
  }

  /**
   * Обработчик клавиш: Esc — закрыть, стрелки — навигация.
   * @param {KeyboardEvent} event - событие клавиатуры
   */
  _onKeydown(event) {
    if (this.lightboxTarget.classList.contains("hidden")) return
    if (event.key === "Escape") this.close()
    else if (event.key === "ArrowLeft") this.prev()
    else if (event.key === "ArrowRight") this.next()
  }

  /**
   * Рендерит текущее фото в lightbox + счётчик.
   */
  _render() {
    const thumb = this.thumbTargets[this._currentIndex]
    if (!thumb) return
    this.lightboxImageTarget.src = thumb.dataset.fullUrl
    this.lightboxImageTarget.alt = thumb.alt
    this.counterTarget.textContent = this._i18n("counter", {
      current: this._currentIndex + 1,
      total: this.thumbTargets.length
    })
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
   * Подстановка i18n-строки с плейсхолдерами (en fallback).
   * @param {string} key - ключ без префикса
   * @param {Object} vars - плейсхолдеры
   * @returns {string}
   */
  _i18n(key, vars = {}) {
    const base = {
      upload_failed: "Failed to upload photo",
      delete_confirm: "Remove this photo?",
      counter: "{current} / {total}"
    }
    let msg = base[key] || key
    Object.entries(vars).forEach(([k, v]) => {
      msg = msg.replace(`{${k}}`, v)
    })
    return msg
  }
}
