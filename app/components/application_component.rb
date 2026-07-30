# frozen_string_literal: true

#
# ApplicationComponent - базовый класс для всех компонентов приложения
#
# Предоставляет общий функционал для всех компонентов:
# - Доступ к хелперам маршрутов Rails
# - Универсальные методы для работы с PaperTrail аудитом
#
class ApplicationComponent < ViewComponent::Base
  include Rails.application.routes.url_helpers

  class << self
    #
    # Возвращает последнюю версию события определённого типа для модели
    # Заменяет прямые вызовы .versions.where(...) в шаблонах
    #
    # @param item [ActiveRecord::Base] модель с has_paper_trail
    # @param event_type [String, Symbol] тип события (login, registration, update и т.д.)
    # @return [PaperTrail::Version, nil]
    #
    # @example
    #   AuditLogComponent.last_event(user, 'login')
    #
    def last_event(item, event_type)
      item.versions.where(event: event_type).last
    end

    #
    # Возвращает дату последнего события определённого типа
    #
    # @param item [ActiveRecord::Base] модель с has_paper_trail
    # @param event_type [String, Symbol] тип события
    # @return [DateTime, nil]
    #
    # @example
    #   AuditLogComponent.last_event_date(user, 'login')
    #
    def last_event_date(item, event_type)
      last_event(item, event_type)&.created_at
    end
  end
end
