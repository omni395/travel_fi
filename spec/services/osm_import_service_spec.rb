# frozen_string_literal: true

require 'rails_helper'

#
# OsmImportService — unit-спек на .import: единая точка входа
# (fetch + первичный прогресс + обработка с колбэком).
#
RSpec.describe OsmImportService, type: :service do
  let(:category) { create(:poi_category, :with_osm_tags) }
  let(:user) { create(:user, :admin) }
  let(:location) { { city: 'London', country: 'United Kingdom', bbox: [ 51.3, -0.5, 51.7, 0.3 ] } }

  describe '.import' do
    it 'создаёт POI со статусом imported (загружен из OSM), отдаёт прогресс и статистику' do
      elements = [
        { 'id' => 900_000_001, 'lat' => 51.5, 'lon' => -0.12, 'tags' => { 'name' => 'Fountain' } }
      ]
      allow(described_class).to receive(:fetch_elements).and_return(elements)

      progresses = []
      stats = described_class.import(category: category, location: location, user: user) do |processed, total, already_in_db|
        progresses << [ processed, total, already_in_db ]
      end

      expect(stats[:created]).to eq(1)
      expect(progresses.first).to eq([ 0, 1, 0 ]) # первичный прогресс: found/уже в БД
      expect(progresses.last).to eq([ 1, 1, nil ]) # финальный прогресс обработки
      poi = Poi.find_by(osm_id: 900_000_001)
      expect(poi).to be_present
      # OSM-точки получают статус imported (отображаются на карте как approved)
      expect(poi.status).to eq('imported')
      expect(poi.source).to eq('osm')
      expect(poi).to be_imported
    end

    it 'не дублирует уже существующие POI по osm_id' do
      create(:poi, poi_category: category, osm_id: 900_000_001, status: :approved)
      elements = [
        { 'id' => 900_000_001, 'lat' => 51.5, 'lon' => -0.12, 'tags' => { 'name' => 'Fountain' } }
      ]
      allow(described_class).to receive(:fetch_elements).and_return(elements)

      stats = described_class.import(category: category, location: location, user: user)

      expect(stats[:created]).to eq(0)
      expect(stats[:skipped_duplicate]).to eq(1)
    end

    it 'собирает metadata ТОЛЬКО из полей с OSM-маппингом и типизирует значение' do
      # Поле категории с OSM-маппингом (wheelchair → boolean)
      create(:poi_category_field, :with_osm_mapping,
             poi_category: category, field_key: 'wheelchair_accessible')

      elements = [
        {
          'id' => 900_000_002,
          'lat' => 51.5,
          'lon' => -0.12,
          'tags' => {
            'name' => 'Restroom',
            'wheelchair' => 'yes',
            # мусорные технические теги, которые НЕ должны попасть в metadata
            'survey:date' => '2021-05-01',
            'source' => 'Bing',
            'highway' => 'bus_stop'
          }
        }
      ]
      allow(described_class).to receive(:fetch_elements).and_return(elements)

      described_class.import(category: category, location: location, user: user)

      poi = Poi.find_by(osm_id: 900_000_002)
      expect(poi).to be_present
      # В metadata только зарегистрированное поле, значение типизировано в boolean
      expect(poi.metadata).to eq({ 'wheelchair_accessible' => true })
    end
  end
end
