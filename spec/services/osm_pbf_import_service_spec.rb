# frozen_string_literal: true

require 'rails_helper'

#
# OsmPbfImportService — unit-спек импорта из .pbf файла.
# Парсер (.pbf) мокируется: трансформер по полям категории и логика дедупликации
# тестируются без реального бинарного файла и внешнего CLI.
#
RSpec.describe OsmPbfImportService, type: :service do
  let(:category) { create(:poi_category, :with_osm_tags, osm_tags: [ 'amenity=toilets' ]) }
  let(:user) { create(:user, :admin) }
  let(:file_path) { '/tmp/import.osm.pbf' }

  # Мок парсера: each_record отдаёт записи
  def stub_parser(records)
    parser = instance_double(OsmPbfParser)
    allow(OsmPbfParser).to receive(:new).with(file_path).and_return(parser)
    allow(parser).to receive(:each_record).and_yield(*records)
    parser
  end

  describe '.call' do
    it 'создаёт POI для записей, совпадающих с osm_tags категории' do
      stub_parser([
        { id: 900_001, lat: 50.0, lon: 30.0, tags: { 'amenity' => 'toilets', 'name' => 'WC A' } }
      ])

      stats = described_class.call(category: category, file_path: file_path, user: user)

      expect(stats[:created]).to eq(1)
      poi = Poi.find_by(osm_id: 900_001)
      expect(poi).to be_present
      expect(poi.status).to eq('imported')
      expect(poi.source).to eq('osm')
      expect(poi.name['en']).to eq('WC A')
    end

    it 'пропускает записи, не совпадающие с тегами категории' do
      stub_parser([
        { id: 900_002, lat: 50.0, lon: 30.0, tags: { 'amenity' => 'cafe', 'name' => 'Cafe' } }
      ])

      stats = described_class.call(category: category, file_path: file_path, user: user)

      expect(stats[:created]).to eq(0)
      expect(Poi.find_by(osm_id: 900_002)).to be_nil
    end

    it 'собирает metadata ТОЛЬКО из полей с OSM-маппингом' do
      create(:poi_category_field, :with_osm_mapping,
             poi_category: category, field_key: 'wheelchair_accessible', osm_keys: [ 'wheelchair' ])

      stub_parser([
        {
          id: 900_003,
          lat: 50.0,
          lon: 30.0,
          tags: { 'amenity' => 'toilets', 'name' => 'WC B', 'wheelchair' => 'yes', 'source' => 'Bing' }
        }
      ])

      described_class.call(category: category, file_path: file_path, user: user)

      poi = Poi.find_by(osm_id: 900_003)
      expect(poi.metadata).to eq({ 'wheelchair_accessible' => true })
    end

    it 'не плодит дублей при повторном прогоне с тем же osm_id (обновляет существующую OSM-точку)' do
      stub_parser([
        { id: 900_004, lat: 50.0, lon: 30.0, tags: { 'amenity' => 'toilets', 'name' => 'WC C' } }
      ])
      described_class.call(category: category, file_path: file_path, user: user)

      # Повторный прогон с тем же osm_id: точка уже есть, source=="osm" →
      # update_existing_poi (пересоздание/обновление), а НЕ skipped_duplicate.
      stats = described_class.call(category: category, file_path: file_path, user: user)

      # Точка пересобрана (update_existing_poi), а не пропущена как дубль.
      expect(stats[:created]).to eq(1)
      # Главное: дубль не появился — в БД по-прежнему одна запись.
      expect(Poi.where(osm_id: 900_004).count).to eq(1)
    end
  end
end
