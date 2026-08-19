# frozen_string_literal: true

require 'rails_helper'

#
# OsmImportBroadcaster — unit-спек конвейера live-обновлений импорта OSM.
#
# Покрытие:
# 1. progress — dispatch_event("osmImportProgress") с total/processed в user_<id>
# 2. call/broadcast — dispatch_event("osmImportComplete") с деталями импорта
# 3. Гео-фильтрация (баг 4): poi:reload-features несёт bbox импорта в detail,
#    чтобы клиент перезагружал карту только если его видимые границы пересекают зону.
#
RSpec.describe OsmImportBroadcaster, type: :service do
  let(:user) { create(:user) }
  let(:category) { create(:poi_category) }
  let(:broadcaster) { described_class.new(user: user) }
  let(:cable_mock) { double('cable_ready') }

  let(:stats) do
    { created: 3, skipped_duplicate: 1, skipped_modified: 0, errors: 0 }
  end

  before do
    # Мок CableReady: [user_N] / ['pois_map'] возвращают один билдер.
    # osmImportComplete уходит в личный стрим пользователя (["user_#{id}"]),
    # а poi:reload-features — в общий поток карты ["pois_map"] (подписка карты
    # идёт на user_N + pois_map, а не на "UserChannel" — см. osm_import_broadcaster.rb).
    allow(broadcaster).to receive(:cable_ready).and_return(cable_mock)
    allow(cable_mock).to receive(:[]).with("user_#{user.id}").and_return(cable_mock)
    allow(cable_mock).to receive(:[]).with('pois_map').and_return(cable_mock)
    allow(cable_mock).to receive(:dispatch_event)
    allow(cable_mock).to receive(:broadcast)
    # Внутри broadcast вызывается PoiCategoryBroadcaster — изолируем (не тестируем здесь)
    allow(PoiCategoryBroadcaster).to receive(:call)
  end

  describe '#progress' do
    it 'отправляет osmImportProgress в личный стрим пользователя' do
      expect(cable_mock).to receive(:dispatch_event).with(
        name: 'osmImportProgress',
        detail: { total: 10, processed: 5, already_in_db: nil }
      )

      broadcaster.progress(total: 10, processed: 5)
    end

    it 'указывает already_in_db для первого прогресса' do
      expect(cable_mock).to receive(:dispatch_event).with(
        name: 'osmImportProgress',
        detail: { total: 10, processed: 0, already_in_db: 4 }
      )

      broadcaster.progress(total: 10, processed: 0, already_in_db: 4)
    end
  end

  describe '#broadcast' do
    it 'отправляет osmImportComplete с результатами импорта в личный стрим' do
      expect(cable_mock).to receive(:dispatch_event).with(
        name: 'osmImportComplete',
        detail: {
          category_id: category.id,
          category_name: category.localized_name,
          created: 3, skipped_duplicate: 1, skipped_modified: 0, errors: 0
        }
      )

      broadcaster.broadcast(stats: stats, category: category)
    end

    it 'шлёт poi:reload-features с bbox импорта в detail (гео-фильтрация, баг 4)' do
      bbox = [ 52.3, 13.2, 52.7, 13.6 ] # [south, west, north, east] — Берлин
      expect(cable_mock).to receive(:dispatch_event).with(
        name: 'poi:reload-features',
        detail: { type: 'osm', category_id: category.id, bbox: bbox }
      )

      broadcaster.broadcast(stats: stats, category: category, bbox: bbox)
    end

    it 'шлёт poi:reload-features без bbox, если bbox не передан' do
      expect(cable_mock).to receive(:dispatch_event).with(
        name: 'poi:reload-features',
        detail: { type: 'osm', category_id: category.id }
      )

      broadcaster.broadcast(stats: stats, category: category)
    end
  end
end
