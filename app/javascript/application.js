// Entry point for the build script in your package.json
// CSS (Tailwind, MDI, Components) грузится асинхронно через <link> в layout
// чтобы не раздувать JS-бандл

import "./controllers"
import "./config"

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker')
      .then(reg => console.log('Сервис-воркер успешно зарегистрирован!', reg))
      .catch(err => console.error('Ошибка регистрации сервис-воркера:', err));
  });
}