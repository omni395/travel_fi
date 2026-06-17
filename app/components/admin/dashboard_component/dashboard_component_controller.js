import { Controller } from "@hotwired/stimulus"
import StimulusReflex from 'stimulus_reflex'

// Контроллер для Admin::DashboardComponent
// Иконка: mdi-view-dashboard
//
// Отвечает за:
//   - Обновление дашборда через StimulusReflex
export default class extends Controller {
  connect() {
    StimulusReflex.register(this)
  }

  // Обновляет дашборд через StimulusReflex
  refresh(event) {
    event.preventDefault()
    this.stimulate('Admin::DashboardReflex#refresh')
  }
}
