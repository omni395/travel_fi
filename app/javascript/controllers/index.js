import { application } from "./application"

import controllers from "./**/*_controller.js"

controllers.forEach((controller) => {
  application.register(controller.name, controller.module.default)
})

// Авто-регистрация sidecar-контроллеров из ViewComponent
// Генерируется автоматически скриптом scripts/discover_components.js

// Статические импорты — ui/* компоненты (всегда в бандле)
import "./_components_index"

// Ленивые импорты — admin/*, poi/*, settings/*, users/* (code-split, chunks/)
// Stimulus загрузит их по требованию при появлении data-controller в DOM
import "./_components_lazy"
