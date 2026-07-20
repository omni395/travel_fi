import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::Pois::Poi::EditComponent — форма редактирования POI
 *
 * Targets:
 *   submitButton — кнопка сохранения
 *
 * Действия:
 *   handleSubmit — отправляет форму через Reflex
 */
export default class extends ApplicationController {
  static targets = ["submitButton"]

  /**
   * Отправляет форму через StimulusReflex
   */
  handleSubmit(event) {
    event.preventDefault()
    const formData = new FormData(event.target)
    const params = Object.fromEntries(formData.entries())

    this.stimulusReflex("Admin::PoisReflex#update", params)
  }
}
