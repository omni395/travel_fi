# frozen_string_literal: true

#
# Rake task для исправления name у POI
#
# Проблема: колонка name в БД — varchar (не jsonb как в миграции).
# Данные: или plain string "Trafalgar Square", или Ruby hash '{"en" => "..."}'.
#
# Исправление через raw SQL:
# 1. Ruby hash → JSON: '{"en" => "..."}' → '{"en":"..."}'
# 2. Plain string → JSON: "Trafalgar Square" → '{"en":"Trafalgar Square"}'
#
# Для полного исправления запусти: rails db:migrate
# (миграция 20260605000000_change_poi_name_to_jsonb.rb сделает всё + изменит тип колонки)
#
namespace :pois do
  desc "Конвертирует name из varchar в JSON-формат (подготовка к jsonb миграции)"
  task fix_names: :environment do
    puts "=== Fix POI names (varchar → json format) ==="

    # Шаг 1: Конвертируем Ruby hash format в JSON
    result1 = Poi.connection.execute(<<~SQL.squish)
      UPDATE pois
      SET name = regexp_replace(name, '("[a-z_]+") => ', E'\\1: ', 'g')
      WHERE name ~ '=>'
    SQL
    puts "Шаг 1 (Ruby hash → JSON): #{result1.cmd_tuples} строк"

    # Шаг 2: Оборачиваем plain строки в JSON объект
    result2 = Poi.connection.execute(<<~SQL.squish)
      UPDATE pois
      SET name = format('{"en":"%s"}', replace(name, '"', E'\\"'))
      WHERE name !~ '^\{' AND name IS NOT NULL AND name != ''
    SQL
    puts "Шаг 2 (plain → JSON): #{result2.cmd_tuples} строк"

    # Проверка
    remaining = Poi.connection.execute("SELECT count(*) FROM pois WHERE name !~ '^\{'").first
    puts "Осталось не-JSON: #{remaining['count']}"

    puts "=== Done ==="
    puts "Теперь запусти: rails db:migrate"
  end
end
