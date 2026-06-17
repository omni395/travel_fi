source "https://rubygems.org"

ruby "3.4.9"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem "cssbundling-rails"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mswin mingw x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"
gem "mini_magick"         # Обработка изображений с помощью ImageMagick

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mswin mingw x64_mingw ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  gem "foreman"
end

# --- 1. БЕЗОПАСНОСТЬ, АУТЕНТИФИКАЦИЯ И АУДИТ ---
gem "devise"    # Система аутентификации (вход/регистрация)
gem "devise-i18n" # Локализация Devise
gem "bcrypt"              # Хеширование паролей
gem "pundit"              # Авторизация: управление доступом на уровне контроллеров
gem "paper_trail" # Аудит: версионирование и логирование всех изменений в БД
gem "omniauth-rails_csrf_protection" # CSRF protection для OmniAuth
gem "omniauth-google-oauth2" # Google OAuth стратегия
gem "rolify"              # Роли и разрешения для пользователей

# --- 2. ФОНОВЫЕ ЗАДАЧИ, КЭШИРОВАНИЕ И ПОИСК ---
gem "solid_queue"  # Database-backed job queue (default in Rails 8)
gem "solid_cable"  # ActionCable adapter для PostgreSQL (альтернатива Redis)
gem "solid_cache"  # Cache store для Solid Queue
gem "solid_queue_dashboard" # Dashboard для управления фоновыми задачами (сторонний инструмент)
gem "ransack"      # Поиск и фильтрация через Ransack (без внешних сервисов)

# --- 3. ГЕОЛОКАЦИЯ И GIS ---
gem "activerecord-postgis-adapter" # PostGIS adapter для Rails с RGeo (стандартный подход)
gem "geocoder"               # Геокодирование адресов и координат
gem "country_select"         # Виджет выбора страны в формах
gem "rgeo"                   # Геометрические объекты и операции для PostGIS

# --- 4. UI, VIEW И ПРЕЗЕНТАЦИЯ ДАННЫХ ---
gem "view_component"        # Современный компонентный подход для View-файлов
gem "enum_help"             # Помощь с локализацией и отображением Enums
gem "pagy"                  # Быстрая и легкая пагинация
gem "breadcrumbs_on_rails"  # Хлебные крошки для навигации
gem "cable_ready"           # Инструменты для обновления UI через WebSockets + real-time DOM обновления
gem "stimulus_reflex"       # Reactive Rails with real-time client-server interaction
gem "rails-i18n"            # Расширенные файлы локализации для Rails
gem "noticed"               # Централизованная система уведомлений с множественными методами доставки
gem "web-push"

# --- 5. ГЕЙМИФИКАЦИЯ ---
# Собственная система геймификации: баллы, бейджи, уровни, репутация
# Конфиг: config/gamification.yml
# Сервис: GamificationService
# --- 6. SEO И АНАЛИТИКА ---
gem "friendly_id"         # Красивые, читаемые URL-адреса
gem "sitemap_generator"   # Генерация sitemap.xml
gem "json-ld"             # Генерация JSON-LD данных
gem "schema_dot_org"      # Генерация структурированных данных Schema.org
gem "chartkick"           # Удобная визуализация данных (графики)
gem "groupdate"           # Группировка данных по времени (дням, неделям)

gem "twilio-ruby"         # WhatsApp-бот и уведомления
gem "hugging-face"        # Интеграция с Hugging Face API для AI возможностей

gem "dotenv-rails"        # Загрузка переменных окружения из .env файла (для локальной разработки)
