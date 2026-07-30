import ApplicationController from '../../../../../javascript/controllers/application_controller'

/**
 * Admin::Pois::Poi::EditComponent — форма редактирования POI
 *
 * Действия:
 *   handleSubmit — отправляет форму через StimulusReflex
 */
export default class extends ApplicationController {
  static targets = ["submitButton"]

  /**
   * Отправляет форму через StimulusReflex
   * Если POI имеет id → update, иначе → create
   */
  handleSubmit(event) {
    event.preventDefault()
    const formData = new FormData(event.target)
    const params = Object.fromEntries(formData.entries())

    // Удаляем id из params, чтобы избежать конфликта с getReflexOptions() в StimulusReflex 3.5.5:
    // функция ошибочно поглощает объект, содержащий ключ `id`, как объект опций (см. utils.js#getReflexOptions).
    // id доступен в рефлексе через element.dataset.id или formSelector.
    delete params.id

    const idInput = event.target.querySelector("[name='poi[id]']")
    if (idInput && idInput.value) {
      this.stimulate("Admin::PoisReflex#update", params)
    } else {
      this.stimulate("Admin::PoisReflex#create", params)
    }
  }
}
