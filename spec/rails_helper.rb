# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# --- System-тесты «браузер А → браузер Б» ---
require 'capybara/rails'
require 'capybara/cuprite'
require 'database_cleaner/active_record'
require 'webmock/rspec'

# Requires supporting ruby files with custom matchers and macros.
# Файлы в spec/support/**/*.rb подключаются автоматически.
Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }

# Ensures that the test database schema matches the current schema file.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# --- Capybara: headless Chrome (Cuprite) ---
Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite
Capybara.server = :puma, { Silent: true }
# SolidCable-клиент опрашивает сервер каждые 5 сек (polling_interval) —
# увеличиваем время ожидания для live-обновлений «браузер А → браузер Б».
Capybara.default_max_wait_time = 15

RSpec.configure do |config|
  # Драйвер system-тестов — cuprite.
  # В rspec-rails 8 driven_by — instance-метод, вызываемый в before (example scope);
  # глобальный before(:each) выполняется раньше group-level дефолта
  # (:selenium_chrome_headless) и успевает установить @driver.
  config.before(:each, type: :system) do
    driven_by :cuprite
  end

  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # Для system-тестов (реальный сервер + WebSocket) транзакционные фикстуры
  # не работают с несколькими сессиями — используем DatabaseCleaner.
  config.use_transactional_fixtures = false

  # FactoryBot синтаксис: create / build / build_stubbed без префикса FactoryBot.
  config.include FactoryBot::Syntax::Methods

  # ActiveJob::TestHelper — perform_enqueued_jobs / assert_enqueued_jobs в спеках.
  config.include ActiveJob::TestHelper

  # Devise test helpers: sign_in / sign_out в request/controller specs.
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request

  # System-хелперы (браузер А/Б, вход через UI, ожидание WebSocket-обновлений).
  config.include SystemHelpers, type: :system

  # PaperTrail: версии создаются в тестах (необходимо для конвейера).
  config.before(:each) do
    PaperTrail.request.enabled = true
  end

  # --- DatabaseCleaner ---
  # :system — truncation (реальный сервер, несколько сессий);
  # остальные типы — транзакции (быстрее).
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do |example|
    DatabaseCleaner.strategy = example.metadata[:type] == :system ? :truncation : :transaction
    DatabaseCleaner.start
  end

  config.append_after(:each) do
    DatabaseCleaner.clean
  end

  # --- WebMock ---
  # Разрешаем только localhost (Capybara-сервер). Внешние вызовы (Overpass,
  # Nominatim) в тестах мокаются (allow(OsmImportService) / WebMock.stub_request).
  WebMock.disable_net_connect!(allow_localhost: true)

  # --- ActiveJob ---
  # В тестах очередь ставится в :test, джобы проигрываются явно
  # (perform_enqueued_jobs) — предсказуемость для Noticed/VersionObserverJob.
  config.before(:each) do
    ActiveJob::Base.queue_adapter = :test
  end

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
