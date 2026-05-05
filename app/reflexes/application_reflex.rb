# frozen_string_literal: true

class ApplicationReflex < StimulusReflex::Reflex
  include Pundit::Authorization
  
  # ActionCable connection использует current_user as identified_by
  delegate :current_user, to: :connection
  
  # Устанавливаем текущего пользователя для Pundit
  before_reflex do
    Current.user = current_user
  end

  # Пробрасываем NotAuthorizedError при ошибке авторизации
  rescue_from Pundit::NotAuthorizedError do |exception|
    Rails.logger.warn("Pundit authorization failed: #{exception.message}")
    morph :nothing
  end

  # Пробрасываем другие ошибки валидации
  rescue_from ActiveRecord::RecordInvalid do |exception|
    Rails.logger.warn("Record validation failed: #{exception.message}")
    morph :nothing
  end

  #
  # Авторизует действие через Pundit
  #
  # @param resource [Object] ресурс для авторизации
  # @param action [Symbol] действие для проверки прав
  # @raise [Pundit::NotAuthorizedError] если нет прав
  #
  def authorize_with_pundit!(resource, action)
    authorize(resource, action)
  end
end

