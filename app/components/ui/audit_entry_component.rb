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

    # Отсекаем мусорные изменения "пусто → пусто" (например hint: nil → "",
    # options: {} → {values: []}, placeholder: {} → {en: "", ...}),
    # которые создаёт форма, отправляя все поля, включая пустые.
    parsed.except("id", "created_at", "updated_at").reject do |_field, (old_val, new_val)|
      blank_value?(old_val) && blank_value?(new_val)
    end
  rescue JSON::ParserError
    {}
  end

  #
  # Подпись версии в ленте аудита.
  # Для версий PoiCategoryField возвращает имя поля (field_key), иначе nil.
  # Позволяет отличить изменения полей от изменений самой категории.
  #
  # @return [String, nil]
  #
  def item_label
    return nil unless version.item_type == "PoiCategoryField"

    key = field_key_from_version
    key ? I18n.t("ui.audit_entry_component.field_label", key: key) : I18n.t("ui.audit_entry_component.field")
  end

  #
  # Извлекает field_key версии поля из object/object_changes (JSON в text-колонке).
  # Для create/update — из object_changes (последнее значение),
  # для destroy — из object (снапшот до удаления).
  #
  # @return [String, nil]
  #
  def field_key_from_version
    # Для destroy — из снапшота object (состояние до удаления)
    return parse_object(version.object)&.dig("field_key") if version.event == "destroy"

    # Для create/update — из object_changes (последнее значение).
    # При реордере (изменяется только position) field_key отсутствует в changes,
    # поэтому падаем обратно на снапшот object (состояние ДО изменения),
    # чтобы в ленте аудита было видно, какое поле было передвинуто.
    changes["field_key"]&.last || parse_object(version.object)&.dig("field_key")
  end

  #
  # Парсит JSON в Hash (безопасно).
  # PaperTrail с JSON-сериализатором возвращает object уже десериализованным (Hash),
  # а вручную созданные версии (PaperTrailAuditService) хранят JSON-строку.
  # Поддерживаем оба формата.
  #
  # @param raw [String, Hash, nil] сырые данные версии
  # @return [Hash, nil]
  #
  def parse_object(raw)
    return nil if raw.blank?

    raw.is_a?(String) ? JSON.parse(raw) : raw
  rescue JSON::ParserError
    nil
  end

  #
  # Проверяет, является ли значение "пустым" для целей аудита:
  # nil, пустая строка, пустой массив/хэш, а также JSONB-пустышки вида
  # { values: [] }, { en: "", ru: "", es: "", zh: "" }.
  # Используется для отсечения мусорных изменений "пусто → пусто".
  #
  # @param val [Object] значение
  # @return [Boolean]
  #
  def blank_value?(val)
    case val
    when nil then true
    when String then val.strip.empty?
    when Array then val.empty?
    when Hash
      return true if val.empty?
      return (val["values"] || val[:values] || []).empty? if val.key?("values") || val.key?(:values)

      val.all? { |_, v| blank_value?(v) }
    else
      false
    end
  end

  #
  # Форматирует значение для отображения
  #
  # @param val [Object] значение
  # @return [String]
  #
  def format_value(val)
    case val
    when Hash then format_hash(val)
    when nil then "(nil)"
    when true then "Yes"
    when false then "No"
    when Array then val.map { |v| format_value(v) }.join(", ").presence || "(empty)"
    else val.to_s.presence || "(empty)"
    end
  end

  #
  # Человекочитаемое отображение JSONB-хэша в логе аудита.
  # Для i18n-локалей (label/placeholder/description) — "en: Текст, ru: Текст"
  # (только заполненные локали); для options ({ values: [...] }) — ключи значений.
  #
  # @param val [Hash] значение
  # @return [String]
  #
  def format_hash(val)
    return "(empty)" if val.empty?

    # i18n-хэш локалей: { en: "...", ru: "..." }
    if (val.keys.map(&:to_s) & %w[en ru es zh]).any?
      filled = val.select { |_, v| v.present? }
      return "(empty)" if filled.empty?

      filled.map { |k, v| "#{k}: #{v}" }.join(", ")
    # options: { values: [...] }
    elsif val.key?("values") || val.key?(:values)
      values = val["values"] || val[:values] || []
      keys = values.map { |v| v.is_a?(Hash) ? (v["key"] || v[:key]) : v }.compact
      keys.join(", ").presence || "(empty)"
    else
      val.to_s
    end
  end
end
