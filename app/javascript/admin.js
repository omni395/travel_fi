// Entry point for admin build
// CSS обрабатывается отдельным процессом @tailwindcss/cli --watch

// Material Design Icons — локально через npm
import "@mdi/font/css/materialdesignicons.min.css"

import "./controllers"
import "./config"
import "./channels/admin_channel"
