// Users::RewardsComponent
// Stimulus controller for rewards history.
import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Users::RewardsComponent — история начислений.
 *
 * Действия:
 *   goToPage   — переключить страницу истории (Ui::PaginationComponent, StimulusReflex)
 *   openSource — открыть POI-модалку на источнике начисления (poi:show-detail)
 */
export default class extends ApplicationController {
  connect () {
    // super.connect() вызывает StimulusReflex.register(this) → крепит this.stimulate.
    // Без него бросок: "this.stimulate is not a function" при вызове goToPage.
    super.connect()
  }

  /**
   * Переключает страницу истории начислений (read-пагинация).
   * Вызывается кнопками Ui::PaginationComponent (data-action=...#goToPage, data-page).
   * @param {Event} event - click событие по кнопке с data-page
   */
  goToPage (event) {
    event.preventDefault()
    const page = event.currentTarget.dataset.page
    if (page) {
      // Страницу передаём в объекте params — согласовано с эталоном админки
      // (Admin::UsersReflex#filter), где page идёт внутри объекта. Примитив в
      // StimulusReflex 3.x может интерпретироваться иначе → риск «пустых args».
      this.stimulate('UserReflex#rewards_page', { page })
    }
  }

  /**
   * Открывает POI-модалку на источнике начисления и запрашивает подсветку.
   * Параметры источника (poi_id/tab/selector) лежат в data-reward-source="JSON".
   * @param {Event} event - click событие по кнопке с data-reward-source
   */
  openSource (event) {
    event.preventDefault()
    const source = event.currentTarget.dataset.rewardSource
    if (!source) return
    let parsed
    try {
      parsed = JSON.parse(source)
    } catch (e) {
      return
    }
    if (!parsed.poi_id) return

    // Детали + данные о подсветке (tab/selector) — слушает Poi::ShowComponent
    document.dispatchEvent(new CustomEvent('poi:show-detail', {
      detail: { poiId: parsed.poi_id, highlight: { tab: parsed.tab, selector: parsed.selector } }
    }))
  }
}
