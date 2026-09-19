// Admin::GamificationSettingsComponent — контроллер формы настройки геймификации.
// Иконка: mdi-trophy-outline
//
// Отвечает за:
//   - Отправку StimulusReflex при изменении числового поля настройки
import ApplicationController from '../../../javascript/controllers/application_controller'

export default class extends ApplicationController {
  // Сохранить значение числового поля через StimulusReflex.
  // Передаём { section, key, value } — рефлекс читает из args-параметров.
  save(event) {
    const input = event.currentTarget
    this.stimulate('Admin::GamificationSettingsReflex#update', {
      section: input.dataset.fieldSection,
      key: input.dataset.fieldKey,
      value: input.value
    })
  }
}
