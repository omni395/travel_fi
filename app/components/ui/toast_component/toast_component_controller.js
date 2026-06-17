// Ui::ToastComponent — контроллер для управления тостами
// Иконка: mdi-toast
//
// Отвечает за:
//   - Управление очередью (max 5 тостов одновременно)
//   - Авто-скрытие по таймауту
//   - Анимированное удаление (slideOutRight)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoDismissTimeout: { type: Number, default: 5000 }
  }

  connect() {
    // Управление очередью: не более 5 тостов
    this.manageQueue()

    // Auto-dismiss
    if (this.autoDismissTimeoutValue > 0) {
      this.timeout = setTimeout(() => {
        this.dismiss()
      }, this.autoDismissTimeoutValue)
    }
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  // Управление очередью на уровне контейнера #notifications
  manageQueue() {
    const container = document.getElementById("notifications")
    if (!container) return

    const toasts = container.querySelectorAll('[role="alert"]')
    if (toasts.length > 5) {
      const toRemove = toasts.length - 5
      for (let i = 0; i < toRemove; i++) {
        this.removeToast(toasts[i])
      }
    }
  }

  // Анимированное удаление тоста
  removeToast(toastElement) {
    toastElement.style.animation = 'slideOutRight 0.4s ease-in-out forwards'
    setTimeout(() => {
      toastElement.remove()
    }, 400)
  }

  // Закрыть текущий тост
  dismiss() {
    this.removeToast(this.element)
  }
}
