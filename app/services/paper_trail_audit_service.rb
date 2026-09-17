# frozen_string_literal: true

#
# PaperTrailAuditService
#
# Сервис для централизованного логирования действий пользователей через PaperTrail
# Используется для логирования: вход, выход, регистрация, подтверждение email, изменения профиля
#
# ВАЖНО: Для audit-событий (login, logout, registration и т.д.) object_changes НЕ передаётся,
# т.к. эти события не являются изменениями модели в терминах PaperTrail.
# Для profile_update object_changes передаётся в формате PaperTrail: { field: [old, new] }.
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
        event: "login",
        whodunnit: user.id.to_s
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
        event: "logout",
        whodunnit: user.id.to_s
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

      # Для регистрации object_changes не передаётся — это audit-событие
      user.versions.create!(
        event: "registration",
        whodunnit: user.id.to_s,
        object: user.attributes.to_json
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

      # Для email_confirmation object_changes не передаётся
      user.versions.create!(
        event: "email_confirmed",
        whodunnit: user.id.to_s
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log email confirmation: #{e.class} #{e.message}")
    end

    #
    # Логирует изменение профиля пользователя
    #
    # @param user [User] пользователь
    # @param changes [Hash] изменения в формате PaperTrail: { field: [old_value, new_value] }
    #
    def log_profile_update(user, changes)
      return unless user&.persisted? && changes.present?

      # Нормализуем изменения в PaperTrail-формат (поддержка legacy { old:, new: })
      normalized = normalize_changes(changes)

      user.versions.create!(
        event: "profile_update",
        whodunnit: user.id.to_s,
        object_changes: normalized.to_json
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
        event: "password_changed",
        whodunnit: user.id.to_s
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
        event: "oauth_login",
        whodunnit: user.id.to_s
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log OAuth login: #{e.class} #{e.message}")
    end

    #
    # Логирует загрузку картинки-маркера категории (category_icon).
    # Событие audit-only (не триггерит broadcast show-компонента, не затирает
    # открытую форму редактирования — см. VersionObserverJob::AUDIT_ONLY_EVENTS).
    #
    # @param category [PoiCategory] категория POI
    # @param admin [User] администратор, загрузивший картинку
    #
    def log_category_icon_uploaded(category, admin)
      return unless category&.persisted?

      category.versions.create!(
        event: "category_icon_uploaded",
        whodunnit: admin&.id&.to_s
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log category icon upload: #{e.class} #{e.message}")
    end

    #
    # Логирует удаление картинки-маркера категории (category_icon).
    # Событие audit-only (см. log_category_icon_uploaded).
    #
    # @param category [PoiCategory] категория POI
    # @param admin [User] администратор, удаливший картинку
    #
    def log_category_icon_removed(category, admin)
      return unless category&.persisted?

      category.versions.create!(
        event: "category_icon_removed",
        whodunnit: admin&.id&.to_s
      )
    rescue StandardError => e
      Rails.logger.error("Failed to log category icon removal: #{e.class} #{e.message}")
    end

    private

    #
    # Нормализует формат изменений в PaperTrail-стандарт: { field: [old, new] }
    # Поддерживает оба входных формата:
    #   - { field: [old, new] }           (PaperTrail-стандарт)
    #   - { field: { old: ..., new: ... } } (legacy-формат)
    #
    # @param changes [Hash] входные изменения
    # @return [Hash] нормализованные изменения
    #
    def normalize_changes(changes)
      return {} if changes.blank?

      changes.each_with_object({}) do |(key, value), result|
        result[key] = case value
        when Hash
                        if value.key?(:old) || value.key?("old")
                          # Конвертируем legacy { old:, new: } → [old, new]
                          [ value[:old] || value["old"], value[:new] || value["new"] ]
                        else
                          value.to_json
                        end
        when Array
                        # Уже PaperTrail-формат
                        value
        else
                        value
        end
      end
    end
  end
end
