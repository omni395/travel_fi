// Travel Fi — Service Worker.
// Рендерится через маршрут rails/pwa#service_worker (config/routes.rb), регистрируется из
// app/javascript/application.js по пути /service-worker.
//
// Слои:
//  - push/notificationclick — обработка Web Push-уведомлений (Noticed/WebPush);
//  - install — предзагрузка App Shell (якорные URL + MDI шрифт/иконки);
//  - fetch — стратегии: static = cache-first, navigation = network-first с офлайн-фолбэком.
//  - активная версия кэша инкрементится при правке этого файла (см. CACHE_VERSION ниже).

const CACHE_VERSION = 'travel-fi-v1'
const APP_SHELL_CACHE = `app-shell-${CACHE_VERSION}`
const RUNTIME_CACHE = `runtime-${CACHE_VERSION}`

// Якорные URL App Shell: кэшируются на install, отдаются офлайн.
const APP_SHELL_URLS = [
  '/',
  '/en/pois',
  '/manifest.json',
  '/favicon.svg',
  '/favicon-192.webp',
  '/favicon-256.webp',
  '/favicon-512.webp',
  '/apple-touch-icon.webp'
]

// MDI: веб-шрифт материальных иконок (семейство mdi). Полные своды CDN не кэшируем —
// офлайн-fallback на магнит для отображения иконок-глифов.
const MDI_FONT_URL = 'https://cdn.jsdelivr.net/npm/@mdi/font@7/css/materialdesignicons.min.css'

// Получение кэша по имени.
const openCache = (name) => caches.open(name)

// Удаление устаревших версий кэшей (session cleanup при активации новой версии SW).
const cleanUpCaches = async (keepNames) => {
  const keys = await caches.keys()
  await Promise.all(
    keys.filter((key) => !keepNames.includes(key)).map((key) => caches.delete(key))
  )
}

// Регистрация SW: активируется немедленно на всех вкладках без ручной перезагрузки.
self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await openCache(APP_SHELL_CACHE)
      await cache.addAll(APP_SHELL_URLS)
      // MDI CSS грузим условно (CORS-зависимость желаемая, при ошибке не валим install).
      try {
        await cache.add(MDI_FONT_URL)
      } catch (e) {
        // Font CDN недоступен — продолжаем, иконки-фолбэки в шаблонах остаются.
      }
      await self.skipWaiting()
    })()
  )
})

// Активация: очистка старых кэшей + немедленный захват контроля над страницами.
self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      await cleanUpCaches([APP_SHELL_CACHE, RUNTIME_CACHE])
      await self.clients.claim()
    })()
  )
})

// Обработка сетевых запросов.
self.addEventListener('fetch', (event) => {
  const { request } = event
  if (request.method !== 'GET') return

  const url = new URL(request.url)

  // Не перехватываем WebSocket (ActionCable/SolidCable) и Service Worker API.
  if (url.protocol === 'ws:' || url.protocol === 'wss:') return
  if (request.url.includes('/cable')) return

  // Стратегия для навигационных запросов: network-first с офлайн-фолбэком на App Shell.
  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          const fresh = await fetch(request)
          const cache = await openCache(RUNTIME_CACHE)
          cache.put(request, fresh.clone())
          return fresh
        } catch (e) {
          // Офлайн: отдаём закэшированный App Shell.
          const cache = await openCache(APP_SHELL_CACHE)
          const cached = await cache.match('/')
          return cached || Response.error()
        }
      })()
    )
    return
  }

  // Стратегия для статики (бандлы, MDI, иконки, шрифты): cache-first с фоном в runtime-кэш.
  event.respondWith(
    (async () => {
      const cache = await openCache(RUNTIME_CACHE)
      const cached = await cache.match(request)
      if (cached) return cached

      // Сначала проверяем App Shell (для закэшированных на install ресурсов).
      const shellCache = await openCache(APP_SHELL_CACHE)
      const shellCached = await shellCache.match(request)
      if (shellCached) return shellCached

      try {
        const fresh = await fetch(request)
        cache.put(request, fresh.clone())
        return fresh
      } catch (e) {
        // Офлайн и ресурс не в кэше → пустой ответ (браузер покажет свою заглушку).
        return Response.error()
      }
    })()
  )
})

// --- Web Push (существующие обработчики Noticed/WebPush, сохранены как есть) ---

self.addEventListener('push', async (event) => {
  const { title, options } = await event.data.json()
  event.waitUntil(self.registration.showNotification(title, options))
})

self.addEventListener('notificationclick', function (event) {
  event.notification.close()
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then((clientList) => {
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i]
        let clientPath = new URL(client.url).pathname
        if (clientPath === event.notification.data.path && 'focus' in client) {
          return client.focus()
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(event.notification.data.path)
      }
    })
  )
})
