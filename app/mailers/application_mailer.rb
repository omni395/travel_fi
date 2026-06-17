class ApplicationMailer < ActionMailer::Base
  include Rails.application.routes.url_helpers

  default from: ENV.fetch("MAILER_DEFAULT_FROM", "noreply@travel-fi.com")
  layout "mailer"

  #
  # Возвращает настройки URL по умолчанию для почтовых писем
  # Берёт значения из config.action_mailer.default_url_options
  #
  # @return [Hash] хост и порт для генерации ссылок в письмах
  #
  def default_url_options
    Rails.application.config.action_mailer.default_url_options
  end
end
