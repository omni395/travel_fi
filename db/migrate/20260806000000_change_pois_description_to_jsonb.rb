# frozen_string_literal: true

#
# Миграция: перевод поля pois.description из text в jsonb.
#
# Описание POI мультиязычное (аналогично name): PoiService.assign_localized_fields
# сохраняет Hash переводов, Poi#localized_description / missing_translations ожидают
# JSONB. Текущий тип text сериализует Hash в строку — i18n-описания не работают
# (localized_description возвращает nil).
#
# Существующие строковые значения оборачиваются в JSON-строку (to_jsonb).
# Для БД с данными, где description содержит Ruby-представление хэша, требуется
# отдельная конвертация (бэклог).
#
class ChangePoisDescriptionToJsonb < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE pois
        ALTER COLUMN description TYPE jsonb
        USING CASE
          WHEN description IS NULL OR btrim(description::text) = '' THEN '{}'::jsonb
          ELSE to_jsonb(description::text)
        END;
      ALTER TABLE pois
        ALTER COLUMN description SET DEFAULT '{}'::jsonb;
      ALTER TABLE pois
        ALTER COLUMN description SET NOT NULL;
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE pois
        ALTER COLUMN description TYPE text USING description::text;
      ALTER TABLE pois
        ALTER COLUMN description DROP NOT NULL;
      ALTER TABLE pois
        ALTER COLUMN description DROP DEFAULT;
    SQL
  end
end
