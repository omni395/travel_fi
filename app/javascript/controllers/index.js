import { application } from "./application"

// Все *_controller.js в этой директории и поддиректориях
// Включая сгенерированные stubs в _generated/ (из app/components/)
// Корневые контроллеры (cable, application)
import controllers from "./*_controller.js"

// Сгенерированные stubs из ViewComponent (регистрируются автоматически при импорте)
import "./_generated/_index.js"

controllers.forEach((controller) => {
  // application_controller — базовый класс, не регистрируется
  if (controller.name === 'application') return
  if (!controller.module.default) {
    console.warn(`[CONTROLLER] Skipping ${controller.name}: no default export`)
    return
  }
  application.register(controller.name, controller.module.default)
})
