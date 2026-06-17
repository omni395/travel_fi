import { Controller } from "@hotwired/stimulus"

// Контроллер для Ui::ClipboardComponent
// Иконка: mdi-content-copy
//
// Предоставляет:
// - Копирование текста из data-clipboard-text-value в буфер обмена
// - Визуальную обратную связь (tooltip "Скопировано")
export default class extends Controller {
  static targets = ["text"]
  static values = {
    text: String,
    tooltipTarget: String
  }

  /**
   * Копирует текст в буфер обмена
   * Вызывается по клику на элемент
   */
  copy(event) {
    const text = this.textValue || this.element.dataset.clipboardTextValue
    if (!text) return

    navigator.clipboard.writeText(text).then(() => {
      this._showCopiedFeedback()
    }).catch(() => {
      // Fallback для старых браузеров
      const textarea = document.createElement("textarea")
      textarea.value = text
      textarea.style.position = "fixed"
      textarea.style.opacity = "0"
      document.body.appendChild(textarea)
      textarea.select()
      document.execCommand("copy")
      document.body.removeChild(textarea)
      this._showCopiedFeedback()
    })
  }

  /**
   * Показывает визуальную обратную связь об успешном копировании
   */
  _showCopiedFeedback() {
    const target = this.tooltipTargetValue
      ? document.getElementById(this.tooltipTargetValue)
      : this.textTarget

    if (!target) {
      this.textTarget.textContent = "Copied!"
      setTimeout(() => { this.textTarget.textContent = "" }, 2000)
      return
    }

    const original = target.innerHTML
    const copiedText = document.documentElement.lang === "ru"
      ? "Скопировано"
      : "Copied"

    target.innerHTML = `<span>${copiedText}</span>`
    setTimeout(() => { target.innerHTML = original }, 2000)
  }
}
