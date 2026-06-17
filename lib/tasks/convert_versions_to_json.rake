# frozen_string_literal: true

#
# Конвертирует данные в колонках object и object_changes таблицы versions
# из YAML/JSON/невалидного формата в JSON.
#
# PaperTrail по умолчанию использует YAML-сериализатор для text-колонок,
# но UserAuditLogger пишет JSON. Перед конвертацией колонок в jsonb
# нужно унифицировать формат данных.
#
# Запуск:
#   bin/rails versions:convert_to_json
#
namespace :versions do
  desc "Convert object and object_changes from mixed YAML/JSON to pure JSON"
  task convert_to_json: :environment do
    total = PaperTrail::Version.count
    puts "Converting #{total} versions..."
    updated = 0
    errors = 0

    PaperTrail::Version.find_each do |version|
      changed = false

      # Конвертируем object
      if version.object.present?
        parsed = safe_parse(version.object)
        if parsed != version.object
          version.object = parsed
          changed = true
        end
      end

      # Конвертируем object_changes
      if version.object_changes.present?
        parsed = safe_parse(version.object_changes)
        if parsed != version.object_changes
          version.object_changes = parsed
          changed = true
        end
      end

      if changed
        version.save!(touch: false)
        updated += 1
      end
    rescue => e
      errors += 1
      $stderr.puts "Error converting version #{version.id}: #{e.class} #{e.message}"
    end

    puts "Done. Updated: #{updated}, Errors: #{errors}, Total: #{total}"

    if errors > 0
      puts "WARNING: #{errors} versions could not be converted. Check logs above."
    end
  end

  private

  #
  # Безопасно парсит строку как JSON, с fallback на YAML и пустой объект
  #
  # @param value [String] исходная строка
  # @return [String] JSON-строка или пустой JSON объект
  #
  def safe_parse(value)
    return nil if value.blank?

    stripped = value.strip

    # Пробуем JSON
    JSON.parse(stripped)
    return stripped # уже валидный JSON, возвращаем как есть
  rescue JSON::ParserError
    # Пробуем YAML
    begin
      yaml_data = YAML.safe_load(stripped, permitted_classes: [Symbol, Date, Time, ActiveSupport::TimeWithZone, ActiveSupport::TimeZone])
      if yaml_data.is_a?(Hash) || yaml_data.is_a?(Array)
        return yaml_data.to_json
      end
    rescue => e
      Rails.logger.debug("YAML parse failed: #{e.message}")
    end

    # Ничего не сработало — возвращаем пустой JSON объект
    "{}"
  end
end
