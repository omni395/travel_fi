import { Controller } from "@hotwired/stimulus"

// Контроллер для Ui::ClipboardComponent
// Иконка: mdi-content-copy
//
// Предоставляет:
// - Копирование явного текста из textValue
// - ИЛИ считывание текста/значения из стороннего элемента по targetIdValue
// - Визуальную обратную связь (tooltip "Скопировано")
export default class extends Controller {
  static targets = ["text"]
  static values = {
    text: String,
    targetId: String,
    tooltipTarget: String,
    copiedText: String
  }

  /**
   * Копирует текст в буфер обмена
   * Вызывается по клику на элемент
   */
  copy(event) {
    if (event) event.preventDefault()

    let textToCopy = (this.hasTextValue && this.textValue.trim() !== "") ? this.textValue : ""

    if (!textToCopy && this.hasTargetIdValue) {
      const sourceElement = document.getElementById(this.targetIdValue)
      if (sourceElement) {
        textToCopy = sourceElement.value !== undefined && sourceElement.value !== ""
          ? sourceElement.value
          : sourceElement.textContent
      }
    }

    if (!textToCopy) return

    const cleanText = textToCopy.trim()

    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(cleanText)
        .then(() => this._showCopiedFeedback())
        .catch(() => this._fallbackCopy(cleanText))
    } else {
      this._fallbackCopy(cleanText)
    }
  }

  /**
   * Fallback для работы в iframe Lookbook и старых браузерах
   */
  _fallbackCopy(text) {
    try {
      const textarea = document.createElement("textarea")
      textarea.value = text
      textarea.style.position = "fixed"
      textarea.style.left = "-9999px"
      textarea.style.top = "0"
      document.body.appendChild(textarea)
      textarea.focus()
      textarea.select()
      document.execCommand("copy")
      document.body.removeChild(textarea)
    } catch (e) {
      // Игнорируем ограничение безопасности iframe
    }
    this._showCopiedFeedback()
  }

  /**
   * Показывает визуальную обратную связь об успешном копировании
   */
  _showCopiedFeedback() {
    const target = this.hasTooltipTargetValue && this.tooltipTargetValue
      ? document.getElementById(this.tooltipTargetValue)
      : (this.hasTextTarget ? this.textTarget : this.element)

    if (!target) return

    if (this._timeout) clearTimeout(this._timeout)

    const originalText = target.dataset.originalText || target.textContent
    target.dataset.originalText = originalText

    const copiedText = this.hasCopiedTextValue ? this.copiedTextValue : "Copied!"
    target.textContent = copiedText

    this._timeout = setTimeout(() => {
      target.textContent = target.dataset.originalText
      delete target.dataset.originalText
    }, 2000)
  }
}
