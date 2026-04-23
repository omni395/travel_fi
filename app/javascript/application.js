// Entry point for the build script in your package.json
import "./controllers"
import "./config"
import "./channels"

import { initFlowbite } from 'flowbite'

document.addEventListener('DOMContentLoaded', () => {
  initFlowbite();
});