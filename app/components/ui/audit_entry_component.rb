# frozen_string_literal: true

#
# Ui::AuditEntryComponent — универсальный компонент аудита
#
# Отображает одну запись PaperTrail Version.
# Если version = nil — показывает пустой state (нет записей).
#
# @param version [PaperTrail::Version, nil] запись версии или nil
#
class Ui::AuditEntryComponent < ApplicationComponent
  def initialize(version:)
    @version = version
  end

  private

  attr_reader :version

  #
  # Есть ли версия для отображения
  #
  def version_present?
    version.present?
  end

  #
  # Имя пользователя, совершившего изменение
  #
  # @return [String]
  #
  def whodunnit_name
    User.find_by(id: version.whodunnit)&.name || version.whodunnit || "System"
  end

  #
  # Тип события с цветом
  #
  # @return [Hash] { label:, color: }
  #
  def event_info
    case version.event
    when "create"  then { label: "Created", color: "text-green-600 bg-green-50" }
    when "update"  then { label: "Updated", color: "text-amber-600 bg-amber-50" }
    when "destroy" then { label: "Deleted", color: "text-red-600 bg-red-50" }
    else { label: version.event.humanize, color: "text-gray-600 bg-gray-50" }
    end
  end

  #
  # Изменения полей (object_changes)
  #
  # PaperTrail хранит object_changes как Hash, но UserAuditLogger/PaperTrailAuditService
  # могут сохранять как JSON-строку. Поддерживаем оба формата.
  #
  # @return [Hash] { field_name => [old_value, new_value] }
  #
  def changes
    raw = version.object_changes
    return {} if raw.blank?

    parsed = raw.is_a?(String) ? JSON.parse(raw) : raw
    return {} unless parsed.is_a?(Hash)

    parsed.except("id", "created_at", "updated_at")
  rescue JSON::ParserError
    {}
  end

  #
  # Форматирует значение для отображения
  #
  # @param val [Object] значение
  # @return [String]
  #
  def format_value(val)
    case val
    when Hash then val.values.first&.to_s.presence || "(empty)"
    when nil then "(nil)"
    when true then "Yes"
    when false then "No"
    else val.to_s.presence || "(empty)"
    end
  end
end
