# frozen_string_literal: true

#
# Rake task: переводит статус OSM-точек с :approved на :imported.
#
# Проблема: OSM-импорт сохранял точки со статусом :approved. Введён отдельный
# статус :imported для точек, загруженных из OpenStreetMap. Видимость на карте
# для :imported — как у :approved (см. Poi.visible).
#
# Используется update! (а НЕ update_all/update_columns): создаётся PaperTrail-версия
# для каждой точки (единый источник правды для аудита), что дополнительно триггерит
# VersionObserverJob → PoiBroadcaster (обновление карты/списка у подписанных).
#
# Запуск: bin/rails pois:backfill_osm_imported_status
#
namespace :pois do
  desc "Переводит статус OSM-точек с approved на imported"
  task backfill_osm_imported_status: :environment do
    puts "=== Backfill POI OSM status: approved → imported ==="

    scope = Poi.where(source: :osm, status: :approved)
    total = scope.count
    updated = 0
    errors = 0

    scope.find_each do |poi|
      poi.update!(status: :imported)
      updated += 1
    rescue StandardError => e
      errors += 1
      Rails.logger.error("Backfill POI #{poi.id}: #{e.message}")
    end

    puts "Всего OSM-точек (approved): #{total}"
    puts "Обновлено: #{updated}"
    puts "Ошибок: #{errors}"
    puts "=== Done ==="
  end
end
