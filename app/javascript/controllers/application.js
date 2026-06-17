import { Application } from "@hotwired/stimulus"
import consumer from "../channels/consumer"
import StimulusReflex from 'stimulus_reflex'

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
application.consumer = consumer
window.Stimulus   = application

// Initialize StimulusReflex
StimulusReflex.initialize(application, consumer, {})

// Все контроллеры регистрируются автоматически через:
// 1. index.js — glob всех *_controller.js в app/javascript/controllers/
// 2. _components_index.js — sidecar-контроллеры из ViewComponent
// См. index.js и _components_index.js

export { application }
