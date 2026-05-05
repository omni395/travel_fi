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
#   UserAuditLogger.log_registration(user, { email: {old: nil, new: 'user@example.com'}, name: {old: nil, new: 'John'} })
#   UserAuditLogger.log_user_updated_by_user(user, { name: {old: 'John', new: 'Jane'}, email: {old: 'john@example.com', new: 'jane@example.com'} })
#   UserAuditLogger.log_user_updated_by_admin(user, { role: {old: 'user', new: 'moderator'} })
#
class UserAuditLogger
  # Счётчик микросекунд для гарантии разных timestamps
  @@microsecond_offset = 0
  @@last_timestamp = nil

  def self.log_login(user)
    log_action(user, 'login')
  end

  def self.log_logout(user)
    log_action(user, 'logout')
  end

  def self.log_email_verified(user)
    log_action(user, 'email_verified')
  end

  def self.log_email_changed(user, old_email = nil)
    if old_email.present?
      changes = { email: { old: old_email, new: user.unconfirmed_email || user.email } }
      log_action_with_changes(user, 'email_changed', changes)
    else
      log_action(user, 'email_changed')
    end
  end

  def self.log_wallet_added(user)
    log_action(user, 'wallet_added')
  end

  def self.log_avatar_uploaded(user, had_avatar = false)
    changes = { avatar: { old: had_avatar ? "Attached" : "None", new: "Attached" } }
    log_action_with_changes(user, 'avatar_uploaded', changes)
  end

  def self.log_name_changed(user, old_name = nil)
    if old_name.present?
      changes = { name: { old: old_name, new: user.name } }
      log_action_with_changes(user, 'name_changed', changes)
    else
      log_action(user, 'name_changed')
    end
  end

  def self.log_registration(user, attributes = {})
    if attributes.any?
      log_action_with_changes(user, 'registration', attributes)
    else
      log_action(user, 'registration')
    end
  end

  def self.log_user_updated_by_user(user, changes)
    log_action_with_changes(user, 'user_updated_by_user', changes)
  end

  def self.log_user_updated_by_admin(user, changes, admin_id: nil)
    log_action_with_changes(user, 'user_updated_by_admin', changes, admin_id: admin_id)
  end

  def self.log_user_deleted_by_admin(user, admin_id: nil)
    log_action(user, 'user_deleted_by_admin', admin_id: admin_id)
  end

  def self.log_user_created_by_admin(user, attributes, admin_id: nil)
    log_action_with_changes(user, 'user_created_by_admin', attributes, admin_id: admin_id)
  end

  def self.log_admin_action(user, event_name, metadata = {})
    return if user.nil?

    timestamp = generate_unique_timestamp

    # Формируем object_changes в правильном формате для PaperTrail
    # Сохраняем metadata как change в format: {"admin_action": {"old": null, "new": metadata_string}}
    object_changes = {
      "admin_action" => {
        "old" => nil,
        "new" => "#{metadata[:admin_email]} (ID: #{metadata[:admin_id]})"
      }
    }

    PaperTrail::Version.create!(
      item_type: user.class.name,
      item_id: user.id,
      event: event_name,
      whodunnit: metadata[:admin_id].to_s,
      object: user.attributes.to_json,
      object_changes: object_changes.to_json,
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

  # Логирует действие через PaperTrail как custom event
  # Создаёт версию БЕЗ сохранения модели, чтобы гарантировать разные timestamps
  #
  # @param user [User] Объект пользователя
  # @param event_name [String] Название события (login, logout, email_verified и т.d.)
  # @param admin_id [Integer, nil] ID админа если действие выполнено админом (иначе используется user.id)
  def self.log_action(user, event_name, admin_id: nil)
    return if user.nil?

    # Создаём версию напрямую через PaperTrail::Version.create
    # с явным timestamp чтобы гарантировать разные времена для разных событий
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

  # Логирует действие с деталями изменений (для админских изменений)
  #
  # @param user [User] Объект пользователя
  # @param event_name [String] Название события
  # @param changes [Hash] Словарь с изменениями {field: {old: old_value, new: new_value}}
  def self.log_action_with_changes(user, event_name, changes, admin_id: nil)
    return if user.nil?

    # Очищаем File объекты из changes (они не могут быть сериализованы в JSON)
    clean_changes = clean_file_objects(changes)

    # Создаём версию напрямую с метаданными
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

  # Очищает File объекты и другие неседеризуемые значения из changes
  def self.clean_file_objects(changes)
    return {} if changes.blank?

    changes.each_with_object({}) do |(key, value), result|
      if value.is_a?(Hash) && value.key?(:old) && value.key?(:new)
        old_val = value[:old]
        new_val = value[:new]

        # Если это File объект, заменяем его на строку
        if new_val.is_a?(File) || new_val.respond_to?(:path)
          new_val = "[File: #{new_val.original_filename rescue 'unknown'}]"
        end

        result[key] = { old: old_val, new: new_val }
      else
        result[key] = value
      end
    end
  end
end
