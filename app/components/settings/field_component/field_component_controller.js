// Settings::FieldComponent — контроллер для переключения настроек уведомлений
// Иконка: mdi-toggle-switch
//
// Отвечает за:
//   - Отправку StimulusReflex при переключении тумблера
import ApplicationController from '../../../javascript/controllers/application_controller'

export default class extends ApplicationController {
  // Отправить обновление настройки через StimulusReflex.
  // Передаём нэймспейсный args-объект { field: '<имя_колонки>' } —
  // рефлекс читает поле из params[:field], а не из dataset элемента,
  // чтобы инверсию значения брать из актуального состояния БД.
  toggle(event) {
    const button = event.currentTarget
    this.stimulate('SettingsReflex#update', { field: button.dataset.fieldValue })
  }
}
