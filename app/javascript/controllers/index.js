import { application } from "./application"

// Все *_controller.js в этой директории и поддиректориях
// Корневые контроллеры (cable, application)
import controllers from "./*_controller.js"

// Sidecar-контроллеры ViewComponent — ЛЕНИВАЯ загрузка (code-split):
// каждый контроллер подгружается только если встречается data-controller="..."
// в DOM текущей страницы. Сгенерировано scripts/discover_components.js.
// Это оптимизация под Lighthouse: не тянем все контроллеры приложения на каждой странице.
import "./_components_lazy.js"

controllers.forEach((controller) => {
  // application_controller — базовый класс, не регистрируется
  if (controller.name === 'application') return
  if (!controller.module.default) {
    console.warn(`[CONTROLLER] Skipping ${controller.name}: no default export`)
    return
  }
  application.register(controller.name, controller.module.default)
})
