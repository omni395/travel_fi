# frozen_string_literal: true

#
# PaperTrailAuditService
#
# Сервис для централизованного логирования действий пользователей через PaperTrail
# Используется для логирования: вход, выход, регистрация, подтверждение email, изменения профиля
#
class PaperTrailAuditService
  class << self
    #
    # Логирует вход пользователя в систему
    #
    # @param user [User] пользователь, который вошел в систему
    # @param request [ActionDispatch::Request] объект запроса (опционально)
    #
    def log_login(user, request = nil)
      return unless user&.persisted?

      user.versions.create!(
        event: 'login',
        whodunnit: user.id.to_s,
        object_changes: build_changes('login', nil, {
          email: user.email,
          ip: request&.remote_ip,
          user_agent: request&.user_agent,
          timestamp: Time.current
        })
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log login: #{e.class} #{e.message}")
    end

    #
    # Логирует выход пользователя из системы
    #
    # @param user [User] пользователь, который вышел из системы
    # @param request [ActionDispatch::Request] объект запроса (опционально)
    #
    def log_logout(user, request = nil)
      return unless user&.persisted?

      user.versions.create!(
        event: 'logout',
        whodunnit: user.id.to_s,
        object_changes: build_changes('logout', {
          email: user.email,
          ip: request&.remote_ip,
          user_agent: request&.user_agent,
          timestamp: Time.current
        }, nil)
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log logout: #{e.class} #{e.message}")
    end

    #
    # Логирует регистрацию нового пользователя
    #
    # @param user [User] зарегистрированный пользователь
    # @param request [ActionDispatch::Request] объект запроса (опционально)
    #
    def log_registration(user, request = nil)
      return unless user&.persisted?

      user.versions.create!(
        event: 'registration',
        whodunnit: user.id.to_s,
        object_changes: build_changes('registration', nil, {
          email: user.email,
          name: user.name,
          provider: user.provider,
          uid: user.uid,
          ip: request&.remote_ip,
          user_agent: request&.user_agent,
          timestamp: Time.current
        })
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log registration: #{e.class} #{e.message}")
    end

    #
    # Логирует подтверждение email
    #
    # @param user [User] пользователь с подтвержденным email
    #
    def log_email_confirmation(user)
      return unless user&.persisted?

      user.versions.create!(
        event: 'email_confirmed',
        whodunnit: user.id.to_s,
        object_changes: build_changes('email_confirmed', nil, {
          email: user.email,
          confirmed_at: user.confirmed_at,
          timestamp: Time.current
        })
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log email confirmation: #{e.class} #{e.message}")
    end

    #
    # Логирует изменение профиля пользователя
    #
    # @param user [User] пользователь
    # @param changes [Hash] хеш изменений (старые и новые значения)
    #
    def log_profile_update(user, changes)
      return unless user&.persisted? && changes.present?

      user.versions.create!(
        event: 'profile_update',
        whodunnit: user.id.to_s,
        object_changes: build_changes('profile_update', changes[:old], changes[:new])
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log profile update: #{e.class} #{e.message}")
    end

    #
    # Логирует изменение пароля
    #
    # @param user [User] пользователь
    # @param request [ActionDispatch::Request] объект запроса (опционально)
    #
    def log_password_change(user, request = nil)
      return unless user&.persisted?

      user.versions.create!(
        event: 'password_changed',
        whodunnit: user.id.to_s,
        object_changes: build_changes('password_changed', nil, {
          email: user.email,
          ip: request&.remote_ip,
          user_agent: request&.user_agent,
          timestamp: Time.current
        })
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log password change: #{e.class} #{e.message}")
    end

    #
    # Логирует вход через OAuth
    #
    # @param user [User] пользователь
    # @param provider [String] провайдер OAuth (google_oauth2, github и т.д.)
    # @param request [ActionDispatch::Request] объект запроса (опционально)
    #
    def log_oauth_login(user, provider, request = nil)
      return unless user&.persisted?

      user.versions.create!(
        event: 'oauth_login',
        whodunnit: user.id.to_s,
        object_changes: build_changes('oauth_login', nil, {
          email: user.email,
          provider: provider,
          uid: user.uid,
          ip: request&.remote_ip,
          user_agent: request&.user_agent,
          timestamp: Time.current
        })
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log OAuth login: #{e.class} #{e.message}")
    end

    private

    #
    # Строит JSON для object_changes
    #
    # @param action [String] тип действия
    # @param old_value [Hash, nil] старое значение
    # @param new_value [Hash, nil] новое значение
    # @return [String] JSON строка
    #
    def build_changes(action, old_value, new_value)
      {
        action => {
          'old' => old_value,
          'new' => new_value
        }
      }.to_json
    end
  end
end
