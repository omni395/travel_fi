// Entry point for the build script in your package.json
// OpenLayers CSS подключается через @import в app/assets/tailwind/application.css

// ViewComponent sidecar CSS подключается отдельно (components.css) в лэйауте
// для правильного приоритета над Tailwind

// Material Design Icons — локально через npm вместо CDN
// esbuild включит в бандл (или создаст отдельный CSS-чанк при splitting:true)
import "@mdi/font/css/materialdesignicons.min.css"

import "./controllers"
import "./config"
