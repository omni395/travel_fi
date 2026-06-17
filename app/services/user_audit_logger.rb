# frozen_string_literal: true

#
# UserAuditLogger Service
#
# Логирует пользовательские действия в таблицу versions через PaperTrail как custom события.
#
# Типы событий:
# - registration: регистрация нового пользователя (со всеми заполненными полями)
# - login: вход пользователя в систему
# - logout: выход пользователя из системы
# - email_verified: подтверждение email адреса
# - email_changed: изменение email (отправлено письмо подтверждения)
# - wallet_added: добавление кошелька
# - avatar_uploaded: загрузка аватара
# - name_changed: изменение имени
# - user_updated_by_user: обновление профиля пользователем (со всеми изменениями в одной записи)
# - user_updated_by_admin: обновление данных пользователя администратором (со всеми изменениями в одной записи)
# - user_created_by_admin: создание пользователя администратором
# - user_deleted_by_admin: удаление пользователя администратором
#
# Пример использования:
#   UserAuditLogger.log_login(user)
#   UserAuditLogger.log_logout(user)
#   UserAuditLogger.log_email_verified(user)
#   UserAuditLogger.log_registration(user, { email: [nil, 'user@example.com'], name: [nil, 'John'] })
#   UserAuditLogger.log_user_updated_by_user(user, { name: ['John', 'Jane'], email: ['john@example.com', 'jane@example.com'] })
#   UserAuditLogger.log_user_updated_by_admin(user, { role: ['user', 'moderator'] })
#
# ВАЖНО: object_changes хранится в PaperTrail-стандарте: { "field_name" => [old_value, new_value] }
# Это гарантирует совместимость с version.changeset и PaperTrail 17.x.
#
class UserAuditLogger
  # Счётчик микросекунд для гарантии разных timestamps
  @@microsecond_offset = 0
  @@last_timestamp = nil

  # --- Audit-события без object_changes ---

  def self.log_login(user)
    log_action(user, 'login')
  end

  def self.log_logout(user)
    log_action(user, 'logout')
  end

  def self.log_email_verified(user)
    log_action(user, 'email_verified')
  end

  # --- Audit-события с метаданными в object_changes ---

  #
  # Логирует смену email (старый → новый)
  #
  # @param user [User] пользователь
  # @param old_email [String, nil] старый email
  #
  def self.log_email_changed(user, old_email = nil)
    if old_email.present?
      changes = { email: [old_email, user.unconfirmed_email || user.email] }
      log_action_with_changes(user, 'email_changed', changes)
    else
      log_action(user, 'email_changed')
    end
  end

  #
  # Логирует привязку кошелька
  #
  # @param user [User] пользователь
  #
  def self.log_wallet_added(user)
    log_action(user, 'wallet_added')
  end

  #
  # Логирует загрузку аватара
  #
  # @param user [User] пользователь
  # @param had_avatar [Boolean] был ли аватар ранее
  #
  def self.log_avatar_uploaded(user, had_avatar = false)
    changes = { avatar: [had_avatar ? 'Attached' : 'None', 'Attached'] }
    log_action_with_changes(user, 'avatar_uploaded', changes)
  end

  #
  # Логирует смену имени
  #
  # @param user [User] пользователь
  # @param old_name [String, nil] старое имя
  #
  def self.log_name_changed(user, old_name = nil)
    if old_name.present?
      changes = { name: [old_name, user.name] }
      log_action_with_changes(user, 'name_changed', changes)
    else
      log_action(user, 'name_changed')
    end
  end

  # --- События с изменениями полей модели ---

  #
  # Логирует регистрацию пользователя с начальными атрибутами
  #
  # @param user [User] созданный пользователь
  # @param attributes [Hash] атрибуты в формате PaperTrail: { field: [old, new] }
  #
  def self.log_registration(user, attributes = {})
    if attributes.any?
      log_action_with_changes(user, 'registration', attributes)
    else
      log_action(user, 'registration')
    end
  end

  #
  # Логирует обновление профиля пользователем
  #
  # @param user [User] пользователь
  # @param changes [Hash] изменения в формате PaperTrail: { field: [old, new] }
  #
  def self.log_user_updated_by_user(user, changes)
    log_action_with_changes(user, 'user_updated_by_user', changes)
  end

  #
  # Логирует обновление профиля пользователя администратором
  #
  # @param user [User] пользователь
  # @param changes [Hash] изменения в формате PaperTrail: { field: [old, new] }
  # @param admin_id [Integer, nil] ID администратора
  #
  def self.log_user_updated_by_admin(user, changes, admin_id: nil)
    log_action_with_changes(user, 'user_updated_by_admin', changes, admin_id: admin_id)
  end

  #
  # Логирует удаление пользователя администратором
  #
  # @param user [User] пользователь
  # @param admin_id [Integer, nil] ID администратора
  #
  def self.log_user_deleted_by_admin(user, admin_id: nil)
    log_action(user, 'user_deleted_by_admin', admin_id: admin_id)
  end

  #
  # Логирует создание пользователя администратором
  #
  # @param user [User] созданный пользователь
  # @param attributes [Hash] атрибуты в формате PaperTrail: { field: [old, new] }
  # @param admin_id [Integer, nil] ID администратора
  #
  def self.log_user_created_by_admin(user, attributes, admin_id: nil)
    log_action_with_changes(user, 'user_created_by_admin', attributes, admin_id: admin_id)
  end

  #
  # Логирует административное действие (без изменения модели)
  #
  # @param user [User] целевой пользователь
  # @param event_name [String] название события
  # @param metadata [Hash] метаданные (admin_email, admin_id)
  #
  def self.log_admin_action(user, event_name, metadata = {})
    return if user.nil?

    timestamp = generate_unique_timestamp

    PaperTrail::Version.create!(
      item_type: user.class.name,
      item_id: user.id,
      event: event_name,
      whodunnit: metadata[:admin_id].to_s,
      object: user.attributes.to_json,
      object_changes: nil,
      created_at: timestamp
    )
  rescue => e
    Rails.logger.error("UserAuditLogger.log_admin_action failed: #{e.class} #{e.message}")
  end

  private

  # Генерирует уникальный timestamp с гарантией разных времён для разных событий
  def self.generate_unique_timestamp
    current_time = Time.current

    # Если это первый вызов или время изменилось - обнуляем счётчик
    if @@last_timestamp.nil? || current_time > @@last_timestamp
      @@last_timestamp = current_time
      @@microsecond_offset = 0
      return current_time
    end

    # Если время не изменилось - добавляем микросекунды
    @@microsecond_offset += 0.001 # +1ms каждый раз
    @@last_timestamp + @@microsecond_offset.seconds
  end

  #
  # Логирует действие через PaperTrail как custom event
  # Создаёт версию БЕЗ object_changes (для простых audit-событий)
  #
  # @param user [User] Объект пользователя
  # @param event_name [String] Название события
  # @param admin_id [Integer, nil] ID админа если действие выполнено админом
  #
  def self.log_action(user, event_name, admin_id: nil)
    return if user.nil?

    timestamp = generate_unique_timestamp

    PaperTrail::Version.create!(
      item_type: user.class.name,
      item_id: user.id,
      event: event_name,
      whodunnit: (admin_id || user.id).to_s,
      object: user.attributes.to_json,
      created_at: timestamp
    )
  rescue => e
    Rails.logger.error("UserAuditLogger.log_action failed: #{e.class} #{e.message}")
  end

  #
  # Логирует действие с изменениями в формате PaperTrail
  #
  # @param user [User] Объект пользователя
  # @param event_name [String] Название события
  # @param changes [Hash] Словарь с изменениями: { field: [old_value, new_value] }
  # @param admin_id [Integer, nil] ID админа если действие выполнено админом
  #
  def self.log_action_with_changes(user, event_name, changes, admin_id: nil)
    return if user.nil?

    # Очищаем File объекты из changes и конвертируем в PaperTrail-формат
    clean_changes = normalize_changes(changes)

    timestamp = generate_unique_timestamp

    PaperTrail::Version.create!(
      item_type: user.class.name,
      item_id: user.id,
      event: event_name,
      whodunnit: (admin_id || user.id).to_s,
      object: user.attributes.to_json,
      object_changes: clean_changes.to_json,
      created_at: timestamp
    )
  rescue => e
    Rails.logger.error("UserAuditLogger.log_action_with_changes failed: #{e.class} #{e.message}")
  end

  #
  # Нормализует формат изменений в PaperTrail-стандарт: { field: [old, new] }
  # Поддерживает оба входных формата:
  #   - { field: [old, new] }  (PaperTrail-стандарт)
  #   - { field: { old: ..., new: ... } }  (старый legacy-формат)
  #
  # Также очищает File объекты и другие несериализуемые значения
  #
  # @param changes [Hash] входные изменения
  # @return [Hash] нормализованные изменения
  #
  def self.normalize_changes(changes)
    return {} if changes.blank?

    changes.each_with_object({}) do |(key, value), result|
      result[key] = case value
                    when Hash
                      if value.key?(:old) || value.key?('old')
                        # Legacy-формат: { old: ..., new: ... }
                        old_val = sanitize_value(value[:old] || value['old'])
                        new_val = sanitize_value(value[:new] || value['new'])
                        [old_val, new_val]
                      else
                        # Обычный Hash — оставляем как есть
                        value.to_json
                      end
                    when Array
                      # PaperTrail-формат: [old, new]
                      [sanitize_value(value[0]), sanitize_value(value[1])]
                    else
                      value
                    end
    end
  end

  #
  # Очищает значение от несериализуемых объектов (File, etc.)
  #
  # @param value [Object] исходное значение
  # @return [Object] очищенное значение
  #
  def self.sanitize_value(value)
    return value unless value.respond_to?(:path) || value.is_a?(File)

    if value.respond_to?(:original_filename)
      "[File: #{value.original_filename}]"
    else
      "[File]"
    end
  end

  # Для обратной совместимости — старый метод cleanup теперь вызывает normalize
  class << self
    alias_method :clean_file_objects, :normalize_changes
  end
end
