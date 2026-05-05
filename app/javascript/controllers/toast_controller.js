import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoDismissTimeout: Number
  }

  connect() {
    console.log(`[toast] connect: autoDismissTimeoutValue=${this.autoDismissTimeoutValue} ms`)
    
    // Управление очередью: max 5 toast'ов одновременно
    this.manageQueue()
    
    // Auto-dismiss для этого toast'а
    if (this.autoDismissTimeoutValue && this.autoDismissTimeoutValue > 0) {
      console.log(`[toast] Setting auto-dismiss timeout: ${this.autoDismissTimeoutValue}ms`)
      this.timeoutId = setTimeout(() => {
        console.log(`[toast] Auto-dismiss triggered after ${this.autoDismissTimeoutValue}ms`)
        this.dismiss()
      }, this.autoDismissTimeoutValue)
    } else {
      console.warn(`[toast] No auto-dismiss: value=${this.autoDismissTimeoutValue}`)
    }
  }

  disconnect() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
  }

  // Управление очередью на уровне контейнера #notifications
  manageQueue() {
    const notificationsContainer = document.getElementById("notifications")
    if (!notificationsContainer) return

    // Получить все видимые toast'ы (role="alert")
    const toasts = notificationsContainer.querySelectorAll('[role="alert"]')
    
    // Если больше 5 - удалить самые старые (те которые в начале)
    if (toasts.length > 5) {
      const toRemove = toasts.length - 5
      for (let i = 0; i < toRemove; i++) {
        if (toasts[i]) {
          this.removeToast(toasts[i])
        }
      }
    }
  }

  dismiss() {
    this.removeToast(this.element)
  }

  removeToast(toastElement) {
    // Slide-out + fade animation
    toastElement.style.animation = 'slideOutRight 0.4s ease-in-out forwards'
    
    setTimeout(() => {
      toastElement.remove()
    }, 400)
  }
}

