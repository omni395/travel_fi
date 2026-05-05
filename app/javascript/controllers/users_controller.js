import { Controller } from "@hotwired/stimulus"

/**
 * Users Stimulus Controller
 *
 * Управляет формой редактирования профиля пользователя
 * - Перехватывает submit событие
 * - Показывает preview аватара при выборе файла
 * - Отправляет данные через WebSocket (StimulusReflex)
 * - Обрабатывает ошибки и успех
 */
export default class extends Controller {
  static targets = ["form", "nameInput", "avatarInput", "submitButton"]

  /**
   * Подключение контроллера - регистрируем слушатели
   */
  connect() {
    // Слушаем события ошибки от Reflex
    this.element.addEventListener("usersError", (event) => {
      this.showError([event.detail.message])
    })

    // Слушаем события успеха (после CableReady морфинга)
    this.element.addEventListener("usersSuccess", (event) => {
      this.hideLoading()
      this.enableSubmitButton()
      // Показываем уведомление об успехе
      this.showSuccess(event.detail?.message || "Profile updated successfully!")

      // Закрываем форму через 2 секунды после успеха
      setTimeout(() => {
        this.handleCancel({ preventDefault: () => {} })
      }, 2000)
    })
  }

  /**
   * Обработчик submit события формы
   * Отправляет данные через WebSocket (StimulusReflex)
   * Отправляем только name - аватар обрабатывается через element в Reflex
   */
  handleSubmit(event) {
    event.preventDefault()
    this.clearErrors()
    this.showLoading()
    this.disableSubmitButton()

    // Собираем данные формы
    const name = this.nameInputTarget.value

    // Вызываем StimulusReflex для отправки через WebSocket
    // Параметры передаются как именованные параметры в Ruby методе
    this.stimulusReflex("updateProfile", name)
  }

  /**
   * Обработчик выбора аватара - показывает preview
   */
  previewAvatar(event) {
    const file = event.target.files?.[0]
    if (!file) return

    // Валидация размера файла (макс 5MB)
    const maxSize = 5 * 1024 * 1024 // 5MB
    if (file.size > maxSize) {
      this.showError(["File size must be less than 5MB"])
      event.target.value = ""
      return
    }

    // Валидация типа файла
    const allowedTypes = ["image/jpeg", "image/png", "image/webp"]
    if (!allowedTypes.includes(file.type)) {
      this.showError(["Only JPG, PNG, and WebP images are allowed"])
      event.target.value = ""
      return
    }

    // Показываем preview изображения
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
    // Отправляем пользовательское событие для закрытия модала/редиректа
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

    this.hideLoading()
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
   * Показывает индикатор загрузки
   */
  showLoading() {
    const loading = document.getElementById("edit-form-loading")
    if (loading) {
      loading.classList.remove("hidden")
    }
  }

  /**
   * Скрывает индикатор загрузки
   */
  hideLoading() {
    const loading = document.getElementById("edit-form-loading")
    if (loading) {
      loading.classList.add("hidden")
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
   * Показывает сообщение об успехе (временное уведомление)
   */
  showSuccess(message) {
    // Создаем временное уведомление об успехе
    const successEl = document.createElement("div")
    successEl.className = "fixed top-4 right-4 px-4 py-3 rounded-lg bg-green-100 border border-green-300 text-green-700 text-sm font-medium shadow-lg z-50"
    successEl.textContent = message
    document.body.appendChild(successEl)

    // Автоматически удаляем через 4 секунды
    setTimeout(() => {
      successEl.remove()
    }, 4000)
  }

  /**
   * Утилита для экранирования HTML
   */
  escapeHtml(text) {
    const map = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#039;"
    }
    return text.replace(/[&<>"']/g, m => map[m])
  }
}
