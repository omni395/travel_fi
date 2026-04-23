require_relative "boot"

require "rails"
require "devise"  # Ensure Devise is loaded before models
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TravelFi
  class Application < Rails::Application
    # Версия приложения для управления кешем Service Worker
    config.app_version = ENV.fetch("APP_VERSION") { Time.now.to_i.to_s }
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # I18n configuration for locale in URL path
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en, :ru, :es, :zh]

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configure Action Mailer to use Solid Queue for async delivery
    config.action_mailer.deliver_later_queue_name = :mailers
    config.action_mailer.delivery_job = "ActionMailer::MailDeliveryJob"

    # Use SQL structure dumps instead of Ruby DSL for PostGIS compatibility
    #config.active_record.schema_format = :sql
    config.active_record.schema_format = :ruby

    ActiveRecord::SchemaDumper.ignore_tables |= %w[
      geometry_columns    # PostGIS system table for geometry column info
      geography_columns   # PostGIS system table for geography column info  
      spatial_ref_sys     # PostGIS coordinate reference system definitions (most important to ignore)
      layer               # postgis_topology extension system table
      topology            # postgis_topology schema marker table
    ]

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
