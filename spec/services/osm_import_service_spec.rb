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
    it 'создаёт POI, отдаёт прогресс и статистику' do
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
      expect(Poi.find_by(osm_id: 900_000_001)).to be_present
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
  end
end
