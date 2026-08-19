import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Users::FormComponent Controller
 *
 * Управляет формой редактирования профиля пользователя
 * - Перехватывает submit событие
 * - Показывает preview аватара при выборе файла
 * - Отправляет форму классическим HTTP multipart-запросом (PATCH update_user_path),
 *   т.к. бинарный File (аватар) через StimulusReflex/WebSocket не передаётся.
 *   Серверная обработка (сжатие PhotoService) + live-обновление — в Service/конвейере.
 * - Обрабатывает отмену
 */
export default class extends ApplicationController {
  static targets = ["nameInput", "avatarInput", "submitButton"]

  /**
   * Подключение контроллера - регистрируем слушатели
   */
  connect() {
    super.connect()
    console.log("Users::FormComponent controller connected")
  }

  /**
   * Открыть выбор аватара (системный пикер: галерея + камера на мобильных)
   */
  openAvatar() {
    if (this.hasAvatarInputTarget) {
      this.avatarInputTarget.click()
    }
  }

  /**
   * Обработчик submit события формы.
   * Аватар (бинарный File) через StimulusReflex не передаётся, поэтому форма
   * отправляется классическим HTTP multipart-запросом на update_user_path.
   * Оставляем нативный submit — браузер сам уйдёт на action form и после
   * сохранения сервер сделает редирект на профиль.
   *
   * @param {Event} event - событие submit
   */
  handleSubmit(event) {
    // Валидация типа аватара (если выбран) перед отправкой.
    const file = this.hasAvatarInputTarget ? this.avatarInputTarget.files?.[0] : null
    if (file && !this._isAllowedType(file.type)) {
      event.preventDefault()
      this.showError(["Only JPG, PNG, and WebP images are allowed"])
      this.avatarInputTarget.value = ""
      return
    }
    this.clearErrors()
    // Нативный submit: не вызываем event.preventDefault()
    this.disableSubmitButton()
  }

  /**
   * Проверяет допустимый тип файла аватара.
   *
   * @param {string} type - MIME-тип файла
   * @return {boolean} true если тип допустим
   */
  _isAllowedType(type) {
    return ["image/jpeg", "image/png", "image/webp"].includes(type)
  }

  /**
   * Обработчик выбора аватара - показывает preview
   */
  previewAvatar(event) {
    const file = event.target.files?.[0]
    if (!file) return

    // Только проверка типа. Проверка размера файла намеренно УБРАНА:
    // сжатие до целевого размера выполняет серверный PhotoService
    // (app/services/photo_service.rb), поэтому большие файлы допустимы.
    const allowedTypes = ["image/jpeg", "image/png", "image/webp"]
    if (!allowedTypes.includes(file.type)) {
      this.showError(["Only JPG, PNG, and WebP images are allowed"])
      event.target.value = ""
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      const preview = document.getElementById("avatar-preview")
      if (preview) {
        preview.innerHTML = `
          <div class="w-32 h-32 rounded-full overflow-hidden shadow-md">
            <img src="${e.target.result}" alt="Preview" class="w-full h-full object-cover">
          </div>
        `
      }
    }
    reader.readAsDataURL(file)
  }

  /**
   * Обработчик отмены - закрывает форму
   */
  handleCancel(event) {
    event.preventDefault()
    this.element.dispatchEvent(new CustomEvent("usersCancelled", { bubbles: true }))
  }

  /**
   * Показывает сообщение об ошибках
   */
  showError(errors) {
    const errorsContainer = document.getElementById("edit-form-errors")
    const errorList = document.getElementById("error-list")

    if (errorsContainer && errorList) {
      errorList.innerHTML = errors
        .map(error => `<li>${this.escapeHtml(error)}</li>`)
        .join("")
      errorsContainer.classList.remove("hidden")
    }

    this.enableSubmitButton()
  }

  /**
   * Очищает сообщения об ошибках
   */
  clearErrors() {
    const errorsContainer = document.getElementById("edit-form-errors")
    if (errorsContainer) {
      errorsContainer.classList.add("hidden")
    }
  }

  /**
   * Отключает кнопку submit
   */
  disableSubmitButton() {
    const button = this.submitButtonTarget
    if (button) {
      button.disabled = true
      button.classList.add("opacity-50", "cursor-not-allowed")
    }
  }

  /**
   * Включает кнопку submit
   */
  enableSubmitButton() {
    const button = this.submitButtonTarget
    if (button) {
      button.disabled = false
      button.classList.remove("opacity-50", "cursor-not-allowed")
    }
  }

  /**
   * Утилита для экранирования HTML
   */
  escapeHtml(text) {
    const el = document.createElement("div")
    el.appendChild(document.createTextNode(text))
    return el.innerHTML
  }
}
