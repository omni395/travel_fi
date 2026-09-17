import { Controller } from "@hotwired/stimulus"

/**
 * DropdownController - управление выпадающими меню
 *
 * Поддерживает:
 * - Открытие/закрытие по клику на триггер
 * - Закрытие при клике вне меню
 * - Закрытие всех остальных открытых дропдаунов при открытии текущего
 * - Закрытие при клике на пункт меню
 */
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.boundClickOutside = this.clickOutside.bind(this)
    this.boundCloseOther = this.closeOther.bind(this)
    window.addEventListener("dropdown:opened", this.boundCloseOther)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
    window.removeEventListener("dropdown:opened", this.boundCloseOther)
  }

  /**
   * Переключает видимость меню
   */
  toggle(event) {
    if (!this.hasMenuTarget) return

    const isHidden = this.menuTarget.classList.contains("hidden")

    if (isHidden) {
      this.show()
    } else {
      this.hide()
    }
  }

  /**
   * Показывает меню и отправляет событие для закрытия других дропдаунов
   */
  show() {
    if (!this.hasMenuTarget) return

    // Оповещаем другие дропдауны о том, что нужно закрыться
    window.dispatchEvent(
      new CustomEvent("dropdown:opened", {
        detail: { opener: this }
      })
    )

    this.menuTarget.classList.remove("hidden")

    // Навешиваем клик снаружи в следующем цикле событий,
    // чтобы текущий клик не заблокировался и всплыл
    setTimeout(() => {
      document.addEventListener("click", this.boundClickOutside)
    }, 0)
  }

  /**
   * Скрывает текущее меню
   */
  hide() {
    if (!this.hasMenuTarget) return

    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.boundClickOutside)
  }

  /**
   * Закрывает меню, если открылся другой дропдаун
   */
  closeOther(event) {
    if (event.detail && event.detail.opener !== this) {
      this.hide()
    }
  }

  /**
   * Закрывает меню при клике вне компонента
   */
  clickOutside(event) {
    if (this.element.contains(event.target)) return

    this.hide()
  }
}
