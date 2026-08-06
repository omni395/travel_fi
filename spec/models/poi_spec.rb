# frozen_string_literal: true

require 'rails_helper'

#
# Poi — unit-спек модели POI.
#
# Покрытие:
# 1. Валидации: name/coordinates/slug/rating/osm_id, длина name (Hash и String)
# 2. Enum: status / source
# 3. FriendlyId: генерация slug
# 4. PaperTrail: версии create/update
# 5. Скоупы: visible / within_meters / within_bounds / by_category / verified / recent
# 6. Локализация: localized_name / localized_description / missing_translations
# 7. Динамические поля: field_value / set_field_value
# 8. Координаты: latitude / longitude
# 9. Галерея: photos (ActiveStorage)
#
RSpec.describe Poi, type: :model do
  describe 'валидации' do
    it 'валиден с фабрикой' do
      expect(build(:poi)).to be_valid
    end

    it 'требует name' do
      expect(build(:poi, name: nil)).not_to be_valid
    end

    it 'требует coordinates' do
      expect(build(:poi, coordinates: nil)).not_to be_valid
    end

    it 'FriendlyId автогенерирует slug, если он не задан' do
      poi = build(:poi, slug: nil)

      expect(poi).to be_valid
      expect(poi.slug).to be_present
    end

    it 'уникальность slug' do
      create(:poi, slug: 'poi-slug')

      expect(build(:poi, slug: 'poi-slug')).not_to be_valid
    end

    it 'уникальность osm_id (allow_nil)' do
      create(:poi, :from_osm, osm_id: 123_456)

      expect(build(:poi, :from_osm, osm_id: 123_456)).not_to be_valid
      expect(build(:poi, osm_id: nil)).to be_valid
    end

    it 'rating в диапазоне 0..5' do
      expect(build(:poi, rating: -1)).not_to be_valid
      expect(build(:poi, rating: 5.1)).not_to be_valid
      expect(build(:poi, rating: 3.5)).to be_valid
    end
  end

  describe 'валидация длины name (JSONB)' do
    it 'отклоняет короткое значение в Hash' do
      poi = build(:poi, name: { 'en' => 'A' })

      expect(poi).not_to be_valid
      expect(poi.errors[:name]).to include(I18n.t('errors.messages.too_short', count: 2))
    end

    it 'отклоняет слишком длинное значение в Hash' do
      long = 'x' * 201
      poi = build(:poi, name: { 'en' => long })

      expect(poi).not_to be_valid
      expect(poi.errors[:name]).to include(I18n.t('errors.messages.too_long', count: 200))
    end

    it 'валидирует строковый name по длине' do
      expect(build(:poi, name: 'OK')).to be_valid
      expect(build(:poi, name: 'O')).not_to be_valid
    end
  end

  describe 'enum' do
    it 'status: pending/approved/rejected/archived' do
      expect(described_class.statuses.keys).to match_array(%w[pending approved rejected archived])
      expect(create(:poi, :pending)).to be_pending
      expect(create(:poi)).to be_approved
    end

    it 'source: manual/osm' do
      expect(described_class.sources.keys).to match_array(%w[manual osm])
      expect(create(:poi, :from_osm)).to be_osm
    end
  end

  describe 'FriendlyId (slug)' do
    it 'генерирует читаемый slug из названия' do
      poi = create(:poi, slug: nil, name: { 'en' => 'Kyiv Fountain' })

      expect(poi.slug).to be_present
      # slug не должен содержать спецсимволов JSONB-сериализации Hash-имени
      expect(poi.slug).not_to match(/[{}"]/)
    end

    it 'сохраняет уникальность slug при повторных созданиях' do
      first = create(:poi, slug: nil, name: { 'en' => 'Same Name' })
      second = create(:poi, slug: nil, name: { 'en' => 'Same Name' })

      expect(first.slug).not_to eq(second.slug)
    end
  end

  describe 'PaperTrail' do
    it 'создаёт версию при создании и обновлении' do
      poi = create(:poi)

      expect { poi.update!(city: 'Kyiv') }
        .to change { poi.versions.count }.by(1)
    end
  end

  describe 'скоупы' do
    describe '.visible' do
      it 'включает approved POI только из активных категорий' do
        active_cat = create(:poi_category)
        inactive_cat = create(:poi_category, :inactive)

        visible_poi = create(:poi, status: :approved, poi_category: active_cat)
        create(:poi, :pending, poi_category: active_cat)
        create(:poi, status: :approved, poi_category: inactive_cat)

        expect(described_class.visible).to contain_exactly(visible_poi)
      end
    end

    describe '.within_meters' do
      it 'возвращает POI в радиусе N метров от точки' do
        near = create(:poi, coordinates: PoiService.parse_coordinates(50.4501, 30.5234))
        far = create(:poi, coordinates: PoiService.parse_coordinates(50.4600, 30.5300))

        result = described_class.within_meters(50.4501, 30.5234, 1000)

        expect(result).to include(near)
        expect(result).not_to include(far)
      end
    end

    describe '.within_bounds' do
      it 'возвращает POI в пределах прямоугольника' do
        inside = create(:poi, coordinates: PoiService.parse_coordinates(50.45, 30.52))
        outside = create(:poi, coordinates: PoiService.parse_coordinates(51.5, 31.5))

        result = described_class.within_bounds(50.0, 30.0, 51.0, 31.0)

        expect(result).to include(inside)
        expect(result).not_to include(outside)
      end
    end

    describe '.by_category' do
      it 'фильтрует по категории' do
        cat_a = create(:poi_category)
        cat_b = create(:poi_category)

        poi_a = create(:poi, poi_category: cat_a)
        create(:poi, poi_category: cat_b)

        expect(described_class.by_category(cat_a.id)).to contain_exactly(poi_a)
      end
    end

    describe '.verified' do
      it 'возвращает только POI с verification_count > 0' do
        verified = create(:poi, :verified)
        create(:poi)

        expect(described_class.verified).to contain_exactly(verified)
      end
    end

    describe '.recent' do
      it 'сортирует по created_at desc' do
        older = create(:poi, created_at: 2.days.ago)
        newer = create(:poi, created_at: 1.day.ago)

        expect(described_class.recent.to_a).to eq([ newer, older ])
      end
    end
  end

  describe 'локализация' do
    let(:poi) { create(:poi) }

    it 'localized_name возвращает имя на текущей локали' do
      expect(I18n.with_locale(:ru) { poi.localized_name }).to eq('Тестовая точка')
      expect(I18n.with_locale(:en) { poi.localized_name }).to eq('Test POI')
    end

    it 'localized_name возвращает как есть для строкового name' do
      poi.update!(name: 'Plain Name')

      expect(poi.localized_name).to eq('Plain Name')
    end

    it 'localized_description возвращает описание на текущей локали' do
      expect(I18n.with_locale(:ru) { poi.localized_description }).to eq('Описание')
    end

    it 'missing_translations перечисляет незаполненные локали' do
      poi.update!(name: { 'en' => 'Only EN' }, description: { 'en' => 'Desc' })

      expect(poi.missing_translations).to include(:ru, :es, :zh)
      expect(poi.missing_translations?).to be(true)
    end
  end

  describe 'динамические поля' do
    let(:poi) { create(:poi) }

    it 'field_value возвращает значение из metadata' do
      poi.update!(metadata: { 'operator' => 'Kyivstar' })

      expect(poi.field_value('operator')).to eq('Kyivstar')
    end

    it 'set_field_value сохраняет значение в metadata' do
      poi.set_field_value('operator', 'Vodafone')

      expect(poi.field_value('operator')).to eq('Vodafone')
    end
  end

  describe 'координаты' do
    it 'latitude/longitude извлекаются из PostGIS-точки' do
      poi = create(:poi, coordinates: PoiService.parse_coordinates(50.4501, 30.5234))

      expect(poi.latitude).to be_within(0.0001).of(50.4501)
      expect(poi.longitude).to be_within(0.0001).of(30.5234)
    end
  end

  describe 'галерея photos (ActiveStorage)' do
    it 'позволяет прикреплять фото' do
      poi = create(:poi)

      poi.photos.attach(io: StringIO.new('fake-image'), filename: 'photo.png', content_type: 'image/png')

      expect(poi.photos).to be_attached
    end
  end
end
