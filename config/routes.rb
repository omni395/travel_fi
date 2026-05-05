Rails.application.routes.draw do
  # ActionCable WebSocket маршрут
  mount ActionCable.server => '/cable'

  # Locale scope (/:locale/admin, /:locale/)
  # Matches: en, ru, es, zh or en-US, ru-RU, es-ES, zh-CN
  devise_for :users, skip: [:sessions, :registrations, :confirmations, :passwords, :unlocks], 
            controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  scope '(:locale)', constraints: { locale: /(en|ru|es|zh)(-[A-Z]{2})?/i } do
    root "pages#index"
    
    devise_for :users, skip: :omniauth_callbacks, controllers: {
      sessions: "users/sessions",
      confirmations: "users/confirmations",
      registrations: "users/registrations"
    }

    # User profile routes - только числовые id, чтобы не конфликтовать с Devise
    resources :users, only: [:show, :edit], constraints: { id: /\d+/ }

    # Admin namespace - маршруты админ-панели
    namespace :admin do
      # Dashboard - главная страница админки
      root to: 'dashboard#index'

      # Управление пользователями - все операции через StimulusReflex
      resources :users, only: [:index, :edit] do
        # Дополнительные действия для морфинга компонента
        member do
          get :select_user
          get :start_edit
          get :cancel_edit
        end
      end
    end
  end

  # PWA маршруты без локали
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  
  get "up" => "rails/health#show", as: :rails_health_check
  get "/.well-known/appspecific/*path", to: ->(env) { [204, {}, [""]] }
end
