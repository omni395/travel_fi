// Admin::Users::User::WalletComponent
// Stimulus controller for admin wallet tab (passive — rendering only)
import ApplicationController from '../../../../../javascript/controllers/application_controller'

export default class extends ApplicationController {
  connect() {
    // Passive component — updates come via CableReady inner_html ([data-admin-user-wallet])
  }
}
