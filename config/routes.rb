Rails.application.routes.draw do
  root "pages#index"
  devise_for :users
  
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  
  get "up" => "rails/health#show", as: :rails_health_check
  get "/.well-known/appspecific/*path", to: ->(env) { [204, {}, [""]] }
end
