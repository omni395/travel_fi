import ApplicationController from '../../../javascript/controllers/application_controller'

// Ui::HamburgerComponent — контроллер выдвижной панели
//
// Управляет:
//   - Открытием/закрытием панели с анимацией
//   - Затемняющим оверлеем
//   - Блокировкой скролла body
//   - Закрытием по Escape и клику на оверлей
//   - Анимацией иконки бургера
//
export default class extends ApplicationController {
  static targets = ["panel", "overlay", "trigger", "burgerIcon"]
  static classes = ["panelTranslate"]

  connect() {
    super.connect()

    // Слушатель клавиатуры
    this._boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener("keydown", this._boundHandleEscape)
  }

  disconnect() {
    super.disconnect()
    document.removeEventListener("keydown", this._boundHandleEscape)
    this._unlockBodyScroll()
  }

  // ============================================================
  // ПУБЛИЧНЫЕ МЕТОДЫ (вызываются из действий)
  // ============================================================

  // Переключение открыто/закрыто
  toggle() {
    if (this._isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  // Открыть панель
  open() {
    this.panelTarget.classList.remove(this.panelTranslateClass)
    this._showOverlay()
    this._lockBodyScroll()
    this._animateBurger()
    this.element.classList.add("ui-hamburger--open")
  }

  // Закрыть панель
  close() {
    this.panelTarget.classList.add(this.panelTranslateClass)
    this._hideOverlay()
    this._unlockBodyScroll()
    this._resetBurger()
    this.element.classList.remove("ui-hamburger--open")
  }

  // Обработка клика на оверлей
  handleBackdrop(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }

  // Обработка клавиши Escape
  handleEscape(event) {
    if (event.key === "Escape" && this._isOpen()) {
      this.close()
    }
  }

  // ============================================================
  // ПРИВАТНЫЕ МЕТОДЫ
  // ============================================================

  // Проверка, открыта ли панель
  _isOpen() {
    return !this.panelTarget.classList.contains(this.panelTranslateClass)
  }

  // Показать оверлей
  _showOverlay() {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.classList.remove("hidden")
    // Задержка для активации transition
    requestAnimationFrame(() => {
      this.overlayTarget.classList.remove("opacity-0")
    })
  }

  // Скрыть оверлей
  _hideOverlay() {
    if (!this.hasOverlayTarget) return
    this.overlayTarget.classList.add("opacity-0")
    // После завершения transition скрыть элемент
    setTimeout(() => {
      this.overlayTarget.classList.add("hidden")
    }, 300)
  }

  // Блокировка скролла body
  _lockBodyScroll() {
    document.body.classList.add("overflow-hidden")
  }

  // Разблокировка скролла body
  _unlockBodyScroll() {
    document.body.classList.remove("overflow-hidden")
  }

  // Анимация бургер-иконки (замена mdi-menu на mdi-close)
  _animateBurger() {
    if (!this.hasBurgerIconTarget) return
    this.burgerIconTarget.className = "mdi mdi-close text-xl text-teal-700"
  }

  // Сброс бургер-иконки
  _resetBurger() {
    if (!this.hasBurgerIconTarget) return
    this.burgerIconTarget.className = "mdi mdi-menu text-xl text-teal-700"
  }
}
