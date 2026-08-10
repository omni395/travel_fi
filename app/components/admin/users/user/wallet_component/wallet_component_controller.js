// Admin::Users::User::WalletComponent
// Stimulus controller for admin wallet tab (passive — rendering only)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Passive component — updates come via CableReady inner_html ([data-admin-user-wallet])
  }
}
