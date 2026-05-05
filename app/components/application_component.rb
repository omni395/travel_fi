# frozen_string_literal: true

#
# ApplicationComponent - базовый класс для всех компонентов приложения
#
# Предоставляет общий функционал для всех компонентов:
# - Доступ к хелперам маршрутов Rails
# - Общие методы и помощники
#
class ApplicationComponent < ViewComponent::Base
  include Rails.application.routes.url_helpers
end
