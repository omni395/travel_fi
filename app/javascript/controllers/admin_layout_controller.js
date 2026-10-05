import ApplicationController from './application_controller'

//
// AdminLayoutController — управление спиннером загрузки админ-лайаута
//
// Показывает спиннер пока `<%= yield %>` не загружен.
// Скрывает спиннер после:
//   1. `DOMContentLoaded` (первая загрузка страницы)
//   2. `cable-ready:after-morph` (обновление через StimulusReflex)
//
// Полноэкранный оверлей (логотип + кольцо + % загрузки) появляется ПЕРВЫМ
// ещё до рендера шапки/контента и закрывается по факту полной загрузки
// страницы (событие window 'load').
//
export default class extends ApplicationController {
  static targets = ["overlay", "progress"]

  connect() {
    // Показываем контент после первой загрузки DOM
    if (document.readyState === 'complete') {
      this.#finishLoad()
    } else {
      // Анимируем прогресс, пока страница не загружена полностью
      this.#startProgress()
      window.addEventListener('load', () => this.#finishLoad(), { once: true })
    }

    // После каждого morph от StimulusReflex — убираем спиннер
    document.addEventListener('cable-ready:after-morph', () => this.#finishLoad(), { passive: true })
  }

  disconnect() {
    if (this._progressTimer) clearInterval(this._progressTimer)
  }

  //
  // Запускает интерполяцию процента загрузки 0 → ~90% до события 'load'.
  // Прогресс эмулируется (нет истинного прогресса SSR), рывком до 90%,
  // затем фиксируется на 100% в #finishLoad и оверлей плавно скрывается.
  //
  #startProgress() {
    if (!this.hasProgressTarget) return

    let value = 0
    this._progressTimer = setInterval(() => {
      // Достигнув ~90%, прекращаем наращивание (ждём реального 'load')
      if (value >= 90) {
        clearInterval(this._progressTimer)
        return
      }
      // Небольшой рывок в начале + плавное замедление к 90%
      const step = value < 40 ? 8 : value < 70 ? 4 : 1.5
      value = Math.min(value + step, 90)
      this.#renderProgress(Math.round(value))
    }, 120)
  }

  //
  // Отображает текущий процент загрузки в DOM
  //
  #renderProgress(value) {
    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `${value}%`
    }
  }

  //
  // Финализация загрузки: стоп прогресса, 100%, плавное скрытие оверлея
  //
  #finishLoad() {
    if (this._progressTimer) {
      clearInterval(this._progressTimer)
      this._progressTimer = null
    }
    this.#renderProgress(100)

    if (!this.hasOverlayTarget) return

    // Немного ждём показа 100% для плавного перехода, затем скрываем оверлей
    window.setTimeout(() => {
      this.overlayTarget.classList.add('opacity-0', 'pointer-events-none')
    }, 300)
  }
}
