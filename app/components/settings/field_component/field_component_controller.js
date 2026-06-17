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

  // Отправить обновление настройки через StimulusReflex
  toggle(event) {
    this.stimulate('SettingsReflex#update', event.target)
  }
}
