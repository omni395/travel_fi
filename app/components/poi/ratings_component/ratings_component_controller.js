import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Poi::RatingsComponent Controller
 *
 * Таб «Рейтинги/голосования» карточки POI.
 * Интерактивность голосования (апрув/дизлайк) обрабатывает вложенный
 * контроллер `ui--vote-component` (Ui::VoteComponent). Здесь — только
 * настройка при подключении; живой логики нет.
 */
export default class extends ApplicationController {
  connect() {
    super.connect()
  }
}
