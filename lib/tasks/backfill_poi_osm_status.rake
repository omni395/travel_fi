# frozen_string_literal: true

#
# Rake task: приводит статус OSM-точек к :imported и проставляет source=:osm.
#
# Проблема: OSM-импорт сохранял точки со статусом :approved и (из-за потери
# :source в PoiService.create) источником "manual" — мы не могли отличить их
# от ручных. Введён отдельный статус :imported для точек, загруженных из
# OpenStreetMap. Видимость на карте для :imported — как у :approved (см. Poi.visible).
#
# Критерий «это OSM-точка» — наличие osm_id (NOT NULL). Таск:
#   1. approved + osm_id → status=:imported, source=:osm
#   2. imported + osm_id + source="manual" → source=:osm
#
# Используется update! (а НЕ update_all/update_columns): создаётся PaperTrail-версия
# для каждой точки (единый источник правды для аудита), что дополнительно триггерит
# VersionObserverJob → PoiBroadcaster (обновление карты/списка у подписанных).
#
# Запуск: bin/rails pois:backfill_osm_imported_status
#
namespace :pois do
  desc "Приводит OSM-точки к статусу imported и источнику osm"
  task backfill_osm_imported_status: :environment do
    puts "=== Backfill POI OSM status: approved → imported, source → osm ==="

    # 1. OSM-точки со статусом approved (старый импорт) → imported + source=:osm
    approved_scope = Poi.where.not(osm_id: nil).where(status: :approved)
    approved_total = approved_scope.count
    approved_updated = 0
    approved_errors = 0

    approved_scope.find_each do |poi|
      poi.update!(status: :imported, source: :osm)
      approved_updated += 1
    rescue StandardError => e
      approved_errors += 1
      Rails.logger.error("Backfill POI #{poi.id}: #{e.message}")
    end

    puts "Approved (osm_id NOT NULL): #{approved_total}, обновлено: #{approved_updated}, ошибок: #{approved_errors}"

    # 2. Уже-imported OSM-точки с ошибочным источником manual → source=:osm
    imported_scope = Poi.where.not(osm_id: nil).where(status: :imported, source: :manual)
    imported_total = imported_scope.count
    imported_updated = 0
    imported_errors = 0

    imported_scope.find_each do |poi|
      poi.update!(source: :osm)
      imported_updated += 1
    rescue StandardError => e
      imported_errors += 1
      Rails.logger.error("Backfill POI #{poi.id}: #{e.message}")
    end

    puts "Imported + source=manual (osm_id NOT NULL): #{imported_total}, обновлено: #{imported_updated}, ошибок: #{imported_errors}"
    puts "=== Done ==="
  end
end
