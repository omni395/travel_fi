Rails.application.routes.draw do
  # PWA маршруты (строго в корне — service worker scope API браузера)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "up" => "rails/health#show", as: :rails_health_check
  get "/.well-known/appspecific/*path", to: ->(env) { [ 204, {}, [ "" ] ] }

  # Favicon — блокируем перехват роутом get ":id" (UsersController)
  get "favicon.ico", to: redirect("/favicon.ico")

  # ActionCable WebSocket маршрут
  mount ActionCable.server => "/cable"

  # SolidQueue Dashboard — мониторинг очередей (без локали)
  authenticate :user, ->(user) { user.has_role?(:admin) } do
    mount SolidQueueDashboard::Engine, at: "/solid-queue", as: :solid_queue_dashboard
  end

  # Devise omniauth БЕЗ локали (колбэки Google OAuth)
  devise_for :users, skip: [ :sessions, :registrations, :confirmations, :passwords, :unlocks ],
            controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  # Locale scope (/:locale/admin, /:locale/)
  scope "(:locale)", constraints: { locale: /(en|ru|es|zh)(-[A-Z]{2})?/i } do
    root "pages#index"

    devise_for :users, skip: :omniauth_callbacks, controllers: {
      sessions: "users/sessions",
      confirmations: "users/confirmations",
      registrations: "users/registrations"
    }

    # Admin namespace - маршруты админ-панели
    # path: "admin-panel" — чтобы избежать коллизии с профилем пользователя с slug "admin"
    # ВАЖНО: namespace ДО get ":id", чтобы /admin-panel не перехватывался профилем
    namespace :admin, path: "admin-panel" do
      # Dashboard - главная страница админки
      root to: "dashboard#index"

      # Настройки уведомлений админа (расширенные, все типы событий)
      resource :settings, only: [:show], controller: "settings"

      # Управление пользователями
      resources :users, only: [:index, :show, :update]

      # Управление категориями POI
      resources :poi_categories, only: [:index, :show, :new, :create, :update]

      # Управление POI
      resources :pois, only: [:index, :show, :new, :create, :update]
    end

    # User-facing POI routes - карта, список и редактирование (PATCH /pois/:id из модалки)
    resources :pois, only: [:index, :show, :new, :create, :update]

    # User profile routes - FriendlyId slug или числовой id
    # ВАЖНО: эти маршруты должны быть ПОСЛЕ devise_for и admin namespace,
    # чтобы Devise-пути (/sign_in, /sign_up) и админка имели приоритет
    # Исключаем зарезервированные slug-и (favicon, robots и т.д.)
    get ":id", to: "users#show", as: :user,
              constraints: ->(req) { req.path_parameters[:id] !~ /\A(favicon|robots|sitemap)\z/ }
    get ":id/edit", to: "users#edit", as: :edit_user
    get ":id/settings", to: "users/settings#show", as: :user_settings
  end
end
