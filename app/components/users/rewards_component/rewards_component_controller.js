// Users::RewardsComponent
// Stimulus controller for rewards history + claim button.
import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Users::RewardsComponent — история начислений TFT + кнопка «Забрать награды».
 *
 * Действия:
 *   claim — ставит relay-джобы для разблокированных наград через StimulusReflex
 */
export default class extends ApplicationController {
  connect () {
    // Рендер приходит через CableReady inner_html ([data-user-rewards])
  }

  /**
   * Отправляет запрос на получение разблокированных наград.
   * @param {Event} event
   */
  claim (event) {
    event.preventDefault()
    this.stimulate('UserReflex#claim_rewards')
  }
}
