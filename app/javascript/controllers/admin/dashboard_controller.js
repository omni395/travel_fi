import { Controller } from '@hotwired/stimulus'
//
// AdminDashboardController - контроллер для админского дашборда
//
// Отвечает за:
// - Обновление статистики через StimulusReflex
// - Обновление списка последних пользователей
// - Обновление списка последних активностей
//
export default class extends Controller {
  //
  // Обновляет дашборд через StimulusReflex
  // Вызывается при нажатии кнопки обновления
  //
  refresh(event) {
    event.preventDefault()
    this.stimulate('Admin::DashboardReflex#refresh')
  }
}
