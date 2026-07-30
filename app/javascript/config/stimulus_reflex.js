import { application } from "../controllers/application"
import StimulusReflex from "stimulus_reflex"

// Инициализация StimulusReflex — добавляет this.stimulusReflex во все контроллеры
StimulusReflex.initialize(application)

// consider removing these options in production
StimulusReflex.debug = true
// end remove
