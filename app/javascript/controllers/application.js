import { Application } from "@hotwired/stimulus"
import consumer from "../channels/consumer"
// Stimulus components https://www.stimulus-components.com/docs/
import Dropdown from '@stimulus-components/dropdown'
import RevealController from '@stimulus-components/reveal'
import Popover from '@stimulus-components/popover'

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
application.consumer = consumer
window.Stimulus   = application

// Register Stimulus components
application.register('dropdown', Dropdown)
application.register('reveal', RevealController)
application.register('popover', Popover)

export { application }
