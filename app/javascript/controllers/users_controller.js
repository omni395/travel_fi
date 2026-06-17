import { Controller } from "@hotwired/stimulus"

/**
 * Users Controller
 *
 * Управляет формой редактирования пользователя в админке.
 * Используется в Admin::Users::User::EditComponent
 */
export default class extends Controller {
  static targets = ["statusInput", "statusText", "roleInput", "roleText", "nameInput", "avatarInput", "submitButton"]

  /**
   * Выбирает статус пользователя из дропдауна
   * @param {Event} event
   */
  selectStatus(event) {
    const value = event.currentTarget.dataset.value
    if (!value) return
    this.statusInputTarget.value = value
    this.statusTextTarget.textContent = event.currentTarget.textContent.trim()
  }

  /**
   * Выбирает роль пользователя из дропдауна
   * @param {Event} event
   */
  selectRole(event) {
    const value = event.currentTarget.dataset.value
    if (!value) return
    this.roleInputTarget.value = value
    this.roleTextTarget.textContent = event.currentTarget.textContent.trim()
  }

  /**
   * Предпросмотр аватара перед загрузкой
   * @param {Event} event
   */
  previewAvatar(event) {
    const file = event.currentTarget.files[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = (e) => {
      const img = this.element.querySelector("#avatar-preview img")
      if (img) img.src = e.target.result
    }
    reader.readAsDataURL(file)
  }

  /**
   * Обработчик отправки формы
   * @param {Event} event
   */
  handleSubmit(event) {
    event.preventDefault()
    // Форма отправляется стандартно через POST
    // StimulusReflex для формы не используется
  }
}
