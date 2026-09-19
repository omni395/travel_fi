import ApplicationController from '../../../javascript/controllers/application_controller'

// Users::ProfileComponent — Stimulus controller for user profile display
// Handles CableReady morphing updates and clipboard interactions
export default class extends ApplicationController {
  connect() {
    console.log("Users::ProfileComponent controller connected")
  }
}
