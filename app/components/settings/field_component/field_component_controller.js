// Settings::FieldComponent — контроллер для переключения настроек уведомлений
// Иконка: mdi-toggle-switch
//
// Отвечает за:
//   - Отправку StimulusReflex при переключении тумблера
import { Controller } from "@hotwired/stimulus"
import StimulusReflex from 'stimulus_reflex'

export default class extends Controller {
  connect() {
    StimulusReflex.register(this)
  }

  // Отправить обновление настройки через StimulusReflex.
  // Передаём нэймспейсный args-объект { field: '<имя_колонки>' } —
  // рефлекс читает поле из params[:field], а не из dataset элемента,
  // чтобы инверсию значения брать из актуального состояния БД.
  toggle(event) {
    const button = event.currentTarget
    this.stimulate('SettingsReflex#update', { field: button.dataset.fieldValue })
  }
}
