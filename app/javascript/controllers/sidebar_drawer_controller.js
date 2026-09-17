import { Controller } from "@hotwired/stimulus"

//
// SidebarDrawerController - управление мобильным сайдбаром
//
// Функционал:
// - Toggle открытие/закрытие мобильного сайдбара
// - Закрытие при клике вне сайдбара
// - Закрытие при нажатии Escape
//
export default class extends Controller {
  static targets = ["drawer"]

  //
  // Инициализация
  //
  connect() {
    // Слушаем клики на триггер кнопку в navbar
    document.addEventListener("click", (e) => {
      if (e.target.closest('[data-sidebar-mobile-toggle]')) {
        this.toggle()
      }
    })

    // Закрываем сайдбар при клике вне его
    document.addEventListener("click", (e) => {
      const drawer = this.drawerTarget
      if (!drawer.contains(e.target) && !e.target.closest('[data-sidebar-mobile-toggle]')) {
        this.close()
      }
    })

    // Закрываем при Escape
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        this.close()
      }
    })
  }

  //
  // Toggle открытие/закрытие
  //
  toggle() {
    const drawer = this.drawerTarget
    if (drawer.classList.contains("-translate-x-full")) {
      this.open()
    } else {
      this.close()
    }
  }

  //
  // Открыть
  //
  open() {
    this.drawerTarget.classList.remove("-translate-x-full")
  }

  //
  // Закрыть
  //
  close() {
    this.drawerTarget.classList.add("-translate-x-full")
  }
}
