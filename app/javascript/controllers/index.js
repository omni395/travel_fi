import { application } from "./application"

// Все *_controller.js в этой директории и поддиректориях
// Корневые контроллеры (cable, application)
import controllers from "./*_controller.js"

// Sidecar-контроллеры ViewComponent — EAGER загрузка:
// все контроллеры импортируются при старте и регистрируются как классы.
// Сгенерировано scripts/discover_components.js.
// Примечание: регистрация через класс (не lazy-колбэк), т.к. Stimulus 3.2.2
// не резолвит application.register(name, () => import(...)).
import "./_components_index.js"

controllers.forEach((controller) => {
  // application_controller — базовый класс, не регистрируется
  if (controller.name === 'application') return
  if (!controller.module.default) {
    console.warn(`[CONTROLLER] Skipping ${controller.name}: no default export`)
    return
  }
  application.register(controller.name, controller.module.default)
})
