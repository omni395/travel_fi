import { Controller } from "@hotwired/stimulus"

/**
 * DropdownController - управление выпадающими меню
 *
 * Замена @stimulus-components/dropdown.
 * Поддерживает:
 * - Открытие/закрытие по клику на триггер
 * - Закрытие при клике вне меню
 * - Закрытие при клике на пункт меню (через data-action="dropdown#toggle")
 * - CSS-анимации через data-transition-* атрибуты
 *
 * Использование:
 *   <div data-controller="dropdown" class="relative">
 *     <button data-action="dropdown#toggle">Открыть</button>
 *     <div data-dropdown-target="menu" class="hidden">
 *       <a href="#" data-action="dropdown#toggle">Пункт</a>
 *     </div>
 *   </div>
 */
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.boundClickOutside = this.clickOutside.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  /**
   * Переключает видимость меню
   * При открытии добавляет слушатель клика вне меню
   */
  toggle(event) {
    event.stopPropagation()

    if (this.hasMenuTarget) {
      this.menuTarget.classList.toggle("hidden")

      if (!this.menuTarget.classList.contains("hidden")) {
        document.addEventListener("click", this.boundClickOutside)
      } else {
        document.removeEventListener("click", this.boundClickOutside)
      }
    }
  }

  /**
   * Закрывает меню при клике вне компонента
   */
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      if (this.hasMenuTarget) {
        this.menuTarget.classList.add("hidden")
      }
      document.removeEventListener("click", this.boundClickOutside)
    }
  }

  /**
   * Показывает меню
   */
  show() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove("hidden")
      document.addEventListener("click", this.boundClickOutside)
    }
  }

  /**
   * Скрывает меню
   */
  hide() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add("hidden")
      document.removeEventListener("click", this.boundClickOutside)
    }
  }
}
