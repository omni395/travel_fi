import { Controller } from "@hotwired/stimulus"

/**
 * Ui Confirm Dialog Component Controller
 *
 * Управляет модальным окном подтверждения.
 * - Показывает/скрывает оверлей
 * - При подтверждении: redirect или Turbo-визит по confirmUrl
 * - При отмене: скрывает диалог
 * - Закрытие по Escape и клику вне диалога
 *
 * Использование:
 *   <button data-action="click->ui--confirm-dialog-component#show"
 *           data-ui--confirm-dialog-component-target="some-id">
 *     Delete
 *   </button>
 */
export default class extends Controller {
  static values = {
    confirmUrl: String,
    confirmMethod: { type: String, default: "get" }
  }

  connect() {
    // Слушаем кастомные события для открытия диалога
    this.boundKeyHandler = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeyHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeyHandler)
  }

  /**
   * Показывает диалог подтверждения
   * Вызывается через data-action="click->ui--confirm-dialog-component#show"
   */
  show(event) {
    event?.preventDefault()
    this.element.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
  }

  /**
   * Скрывает диалог без подтверждения
   */
  cancel(event) {
    event?.preventDefault()
    this.hide()
  }

  /**
   * Подтверждает действие
   * Выполняет переход по confirmUrl с confirmMethod
   */
  confirm(event) {
    event?.preventDefault()

    const url = this.confirmUrlValue
    if (!url) return

    const method = this.confirmMethodValue.toUpperCase()

    if (method === "GET") {
      window.location.href = url
    } else {
      // Для не-GET методов создаём форму и сабмитим
      const form = document.createElement("form")
      form.method = "POST"
      form.action = url
      form.style.display = "none"

      const csrfToken = document.querySelector("[name='csrf-token']")?.content
      if (csrfToken) {
        const csrfInput = document.createElement("input")
        csrfInput.type = "hidden"
        csrfInput.name = "_csrf_token"
        csrfInput.value = csrfToken
        form.appendChild(csrfInput)
      }

      const methodInput = document.createElement("input")
      methodInput.type = "hidden"
      methodInput.name = "_method"
      methodInput.value = method
      form.appendChild(methodInput)

      document.body.appendChild(form)
      form.submit()
    }

    this.hide()
  }

  /**
   * Закрытие по Escape
   */
  handleKeydown(event) {
    if (event.key === "Escape" && !this.element.classList.contains("hidden")) {
      this.hide()
    }
  }

  hide() {
    this.element.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }
}
