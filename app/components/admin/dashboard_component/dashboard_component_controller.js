import ApplicationController from '../../../javascript/controllers/application_controller'

// Контроллер для Admin::DashboardComponent
// Иконка: mdi-view-dashboard
//
// Отвечает за:
//   - Обновление дашборда через StimulusReflex
export default class extends ApplicationController {
  // Обновляет дашборд через StimulusReflex
  refresh(event) {
    event.preventDefault()
    this.stimulate('Admin::DashboardReflex#refresh')
  }
}
