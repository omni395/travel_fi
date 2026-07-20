import { Controller } from "@hotwired/stimulus"

//
// AdminLayoutController — управление спиннером загрузки админ-лайаута
//
// Показывает спиннер пока `<%= yield %>` не загружен.
// Скрывает спиннер после:
//   1. `DOMContentLoaded` (первая загрузка страницы)
//   2. `cable-ready:after-morph` (обновление через StimulusReflex)
//
export default class extends Controller {
  static targets = ["spinner", "content"]

  connect() {
    // Показываем контент после первой загрузки DOM
    if (document.readyState === 'complete') {
      this.#showContent()
    } else {
      window.addEventListener('load', () => this.#showContent(), { once: true })
    }

    // После каждого morph от StimulusReflex — убираем спиннер
    document.addEventListener('cable-ready:after-morph', () => this.#showContent(), { passive: true })
  }

  disconnect() {
    // Cleanup не требуется, т.к. используем { once: true } и { passive: true }
  }

  //
  // Скрывает спиннер и показывает контент
  //
  #showContent() {
    if (!this.hasSpinnerTarget || !this.hasContentTarget) return

    this.spinnerTarget.classList.add('opacity-0', 'pointer-events-none')
    this.contentTarget.classList.remove('opacity-0')
  }
}
