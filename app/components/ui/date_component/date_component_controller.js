import ApplicationController from '../../../javascript/controllers/application_controller'

/**
 * Ui::DateComponent — контроллер форматирования дат.
 *
 * Компонент не интерактивный (read-only дата), JS-контроллер существует для
 * соблюдения правила полного sidecar. Регистрируется через discover_components.js.
 */
export default class extends ApplicationController {
  connect() {
    // Нет интерактивности — подключение не требуется
  }
}
