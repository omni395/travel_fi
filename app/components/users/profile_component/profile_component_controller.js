import ApplicationController from '../../../javascript/controllers/application_controller'

// Users::ProfileComponent — Stimulus controller for user profile display
// Handles TFT balance claim and clipboard interactions
export default class extends ApplicationController {
  connect() {
    // super.connect() вызывает StimulusReflex.register(this) → крепит this.stimulate.
    // Без него бросок: "this.stimulate is not a function" при вызове claim.
    super.connect()
  }

  /**
   * Забирает разблокированные награды (claim).
   * @param {Event} event - click событие
   */
  claim(event) {
    event.preventDefault()
    this.stimulate('UserReflex#claim_rewards')
  }
}
