// Ui::AvatarComponent — пассивный компонент, без интерактива
import ApplicationController from '../../../javascript/controllers/application_controller'

export default class extends ApplicationController {
  connect() {
    // Пассивный компонент — логика не требуется
  }
}
