# frozen_string_literal: true

require 'rails_helper'

#
# OsmValueTransformer — unit-спек маппинга OSM-тегов в значения полей категории.
#
# Поле тестируется как standalone-структура (без БД), т.к. сервис оперирует
# только набором методов поля (osm_keys, osm_value_map, osm_transform, field_type,
# normalized_*). Это делает тест устойчивым к среде выполнения.
#
RSpec.describe OsmValueTransformer, type: :service do
  # Структура, имитирующая PoiCategoryField с OSM-маппингом
  FieldStub = Struct.new(:osm_keys, :osm_value_map, :osm_transform, :field_type, keyword_init: true) do
    def normalized_osm_keys
      Array(osm_keys).map(&:to_s).reject(&:empty?)
    end

    def normalized_osm_value_map
      osm_value_map.is_a?(Hash) ? osm_value_map : {}
    end

    def osm_key
      Array(osm_keys).first
    end
  end

  def field(overrides = {})
    FieldStub.new({ osm_keys: [ 'shower' ], osm_value_map: {}, osm_transform: nil, field_type: 'string' }.merge(overrides))
  end

  describe '.call' do
    it 'возвращает nil, если ни один из osm_keys не найден в тегах' do
      result = described_class.call(field, { 'other' => 'x' })
      expect(result).to be_nil
    end

    it 'берёт значение из первого найденного osm_key' do
      result = described_class.call(field(osm_keys: [ 'shower', 'showers' ]), { 'showers' => 'yes' })
      expect(result).to eq('yes')
    end

    it 'возвращает исходное значение для string-поля без трансформации' do
      result = described_class.call(field, { 'shower' => 'no' })
      expect(result).to eq('no')
    end

    describe 'osm_value_map' do
      it 'маппит значение через карту соответствий' do
        f = field(osm_value_map: { 'no' => true, 'yes' => false })
        expect(described_class.call(f, { 'shower' => 'no' })).to be(true)
        expect(described_class.call(f, { 'shower' => 'yes' })).to be(false)
      end

      it 'при отсутствии ключа в карте применяет трансформацию' do
        f = field(osm_transform: 'boolean', osm_value_map: { 'maybe' => nil })
        expect(described_class.call(f, { 'shower' => 'yes' })).to be(true)
      end
    end

    describe 'boolean' do
      it 'конвертирует yes/true/1/designated в true' do
        f = field(osm_transform: 'boolean')
        %w[yes true 1 designated].each do |v|
          expect(described_class.call(f, { 'shower' => v })).to be(true), "expected #{v} => true"
        end
      end

      it 'конвертирует прочие значения в false' do
        f = field(osm_transform: 'boolean')
        expect(described_class.call(f, { 'shower' => 'no' })).to be(false)
      end
    end

    describe 'extract_number' do
      it 'извлекает первое число из строки "2,5m"' do
        f = field(osm_transform: 'extract_number')
        expect(described_class.call(f, { 'shower' => '2,5m' })).to eq(2.5)
      end

      it 'работает по field_type number' do
        f = field(field_type: 'number')
        expect(described_class.call(f, { 'shower' => '3.5' })).to eq(3.5)
      end

      it 'возвращает nil, если числа нет' do
        f = field(osm_transform: 'extract_number')
        expect(described_class.call(f, { 'shower' => 'free' })).to be_nil
      end
    end

    describe 'split_array' do
      it 'разбивает "USD;EUR" в массив' do
        f = field(osm_transform: 'split_array')
        expect(described_class.call(f, { 'shower' => 'USD;EUR' })).to eq([ 'USD', 'EUR' ])
      end

      it 'работает по field_type multiselect и отбрасывает пустые' do
        f = field(field_type: 'multiselect')
        expect(described_class.call(f, { 'shower' => 'A;; B' })).to eq([ 'A', 'B' ])
      end
    end
  end
end
