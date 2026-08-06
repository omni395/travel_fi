# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

# --- System-тесты «браузер А → браузер Б» ---
require 'capybara/rails'
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

# --- Capybara: Selenium Chrome (видимое окно) ---
# Драйвер регистрируется в spec/support/cuprite.rb (selenium_chrome_visible):
# локально — headful (видимое окно Chrome, наблюдать процесс), в CI — headless.
Capybara.default_driver = :selenium_chrome_visible
Capybara.javascript_driver = :selenium_chrome_visible
Capybara.server = :puma, { Silent: true }
# SolidCable-клиент опрашивает сервер каждые 5 сек (polling_interval) —
# увеличиваем время ожидания для live-обновлений «браузер А → браузер Б».
Capybara.default_max_wait_time = 15

RSpec.configure do |config|
  # Драйвер system-тестов — selenium_chrome_visible (headful Chrome локально).
  # В rspec-rails 8 driven_by — instance-метод, вызываемый в before (example scope);
  # глобальный before(:each) выполняется раньше group-level дефолта
  # (:selenium_chrome_headless) и успевает установить @driver.
  config.before(:each, type: :system) do
    driven_by :selenium_chrome_visible
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

    # PostGIS: гарантируем SRID 4326 в spatial_ref_sys для geography-кастов
    # (ST_MakePoint(...)::geography, ST_DWithin). schema.rb не содержит данных
    # spatial_ref_sys — при пересоздании тестовой БД (schema:load) строка
    # отсутствует, и каст падает с `Cannot find SRID (4326) in spatial_ref_sys`.
    # Вставка идемпотентна; выполняется до DatabaseCleaner-очисток каждого примера.
    ActiveRecord::Base.connection.execute(<<~SQL)
      INSERT INTO spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text)
      SELECT 4326, 'EPSG', 4326,
             'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]',
             '+proj=longlat +datum=WGS84 +no_defs'
      WHERE NOT EXISTS (SELECT 1 FROM spatial_ref_sys WHERE srid = 4326);
    SQL
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
