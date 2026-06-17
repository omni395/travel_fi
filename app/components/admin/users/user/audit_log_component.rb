# frozen_string_literal: true

#
# Admin::Users::User::AuditLogComponent - компонент аудит-лога пользователя
#
# Отображает ВСЮ историю изменений пользователя из PaperTrail:
# - логины, логауты, регистрация
# - изменения профиля (email, имя, аватар)
# - админские действия
# - полный diff: старое → новое для каждого поля
#
# @param versions [Array<PaperTrail::Version>] история изменений
# @param pagy [Pagy, nil] объект пагинации (опционально)
#
class Admin::Users::User::AuditLogComponent < ApplicationComponent
  def initialize(versions:, pagy: nil)
    @versions = versions
    @pagy = pagy
  end

  private

  attr_reader :versions, :pagy

  #
  # Возвращает иконку для типа события
  #
  # @param event [String] тип события
  # @return [String] класс иконки MDI
  #
  def event_icon(event)
    case event
    when 'create', 'registration', 'user_created_by_admin'
      'mdi-account-plus text-green-500'
    when 'login'
      'mdi-login text-blue-500'
    when 'logout'
      'mdi-logout text-gray-500'
    when 'update'
      'mdi-pencil-circle text-blue-500'
    when 'destroy', 'user_deleted_by_admin'
      'mdi-delete-circle text-red-500'
    when 'email_changed'
      'mdi-email-sync text-yellow-500'
    when 'email_verified'
      'mdi-email-check text-green-500'
    when 'name_changed'
      'mdi-account-edit text-teal-500'
    when 'avatar_uploaded'
      'mdi-camera text-purple-500'
    when 'wallet_added'
      'mdi-wallet-plus text-indigo-500'
    when 'user_updated_by_user'
      'mdi-account-edit text-teal-500'
    when 'user_updated_by_admin'
      'mdi-shield-edit text-orange-500'
    when 'admin_action'
      'mdi-shield-account text-red-500'
    else
      'mdi-history text-gray-500'
    end
  end

  #
  # Возвращает текст события
  #
  # @param event [String] тип события
  # @return [String] переведенный текст
  #
  def event_text(event)
    t("notifications.#{event}", default: event.humanize)
  end

  #
  # Возвращает имя пользователя, совершившего изменение
  #
  # @param version [PaperTrail::Version] версия
  # @return [String] имя пользователя
  #
  def whodunnit_name(version)
    return t('admin.users.system') unless version.whodunnit.present?

    user = User.find_by(id: version.whodunnit)
    user&.name || t('admin.users.deleted_user')
  end

  #
  # Проверяет, есть ли изменения в версии
  #
  # @param version [PaperTrail::Version] версия
  # @return [Boolean]
  #
  def changes_present?(version)
    version.object_changes.present?
  end

  #
  # Возвращает массив изменений с полями, старыми и новыми значениями
  #
  # @param version [PaperTrail::Version] версия
  # @return [Array<Hash{Symbol => String}>] [{ field:, old:, new: }]
  #
  def changes_diff(version)
    changes = version.object_changes
    return [] unless changes.present?

    # UserAuditLogger сохраняет object_changes как JSON-строку
    changes = JSON.parse(changes) if changes.is_a?(String)

    changes.map do |field, values|
      old_val = values.is_a?(Array) ? values[0] : values['old']
      new_val = values.is_a?(Array) ? values[1] : values['new']

      {
        field: t("activerecord.attributes.user.#{field}", default: field.humanize),
        old: format_value(old_val),
        new: format_value(new_val)
      }
    end
  rescue JSON::ParserError
    []
  end

  #
  # Форматирует значение для отображения
  #
  # @param value [Object] значение
  # @return [String] отформатированное значение
  #
  def format_value(value)
    return t('admin.users.null_value') if value.nil?
    return t('admin.users.boolean_true') if value == true
    return t('admin.users.boolean_false') if value == false

    value.to_s
  end
end
