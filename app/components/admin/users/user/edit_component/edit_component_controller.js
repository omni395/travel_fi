// Admin::Users::User::EditComponent
// Stimulus controller for admin user edit form
// Handles form submission, status/role selection, avatar preview
import ApplicationController from '../../../../../javascript/controllers/application_controller'

export default class extends ApplicationController {
  static targets = ["nameInput", "statusInput", "roleInput", "statusText", "roleText", "avatarInput", "submitButton"]

  /**
   * Обработчик submit — собирает данные и отправляет через Reflex
   */
  handleSubmit(event) {
    event.preventDefault()
    const formData = new FormData(event.target)
    const params = {
      id: formData.get('user[id]') || this.element.querySelector('[data-admin-user-id]')?.dataset.adminUserId,
      name: formData.get('user[name]'),
      email: formData.get('user[email]'),
      status: formData.get('user[status]'),
      role_id: formData.get('user[role_id]')
    }

    this.stimulusReflex("Admin::UsersReflex#update", params)
  }

  /**
   * Выбор статуса из DropdownComponent
   */
  selectStatus(event) {
    const value = event.currentTarget.dataset.value
    this.statusInputTarget.value = value
    this.statusTextTarget.textContent = event.currentTarget.textContent.trim()
  }

  /**
   * Выбор роли из DropdownComponent
   */
  selectRole(event) {
    const value = event.currentTarget.dataset.value
    this.roleInputTarget.value = value
    this.roleTextTarget.textContent = event.currentTarget.textContent.trim()
  }

  /**
   * Превью аватара при выборе файла
   */
  previewAvatar(event) {
    const file = event.target.files?.[0]
    if (!file) return

    const maxSize = 5 * 1024 * 1024
    if (file.size > maxSize) {
      alert("File size must be less than 5MB")
      event.target.value = ""
      return
    }

    const allowedTypes = ["image/jpeg", "image/png", "image/webp"]
    if (!allowedTypes.includes(file.type)) {
      alert("Only JPG, PNG, and WebP images are allowed")
      event.target.value = ""
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      const preview = document.getElementById("avatar-preview")
      if (preview) {
        preview.innerHTML = `
          <div class="w-32 h-32 rounded-full overflow-hidden shadow-md">
            <img src="${e.target.result}" alt="Avatar preview" class="w-full h-full object-cover">
          </div>
        `
      }
    }
    reader.readAsDataURL(file)
  }
}
