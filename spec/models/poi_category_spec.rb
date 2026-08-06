# frozen_string_literal: true

require 'rails_helper'

#
# PoiCategory — unit-тесты модели категории POI.
#
RSpec.describe PoiCategory, type: :model do
  let(:category) { create(:poi_category) }

  describe 'валидации' do
    it 'требует name и slug' do
      expect(build(:poi_category, name: nil)).not_to be_valid
      expect(build(:poi_category, slug: nil)).not_to be_valid
    end

    it 'требует уникальный slug' do
      create(:poi_category)
      expect(build(:poi_category, slug: PoiCategory.last.slug)).not_to be_valid
    end
  end

  describe 'scopes' do
    it 'active и by_position' do
      inactive = create(:poi_category, :inactive)
      active = create(:poi_category)

      expect(PoiCategory.active).to include(active)
      expect(PoiCategory.active).not_to include(inactive)
      expect(PoiCategory.by_position).to eq(PoiCategory.order(position: :asc))
    end
  end

  describe 'локализация' do
    it 'localized_name подхватывает локаль' do
      I18n.with_locale(:ru) do
        expect(category.localized_name).to eq('Категория')
      end
    end

    it 'localized_description по en по умолчанию' do
      expect(category.localized_description).to eq('Description')
    end
  end

  describe 'переводы' do
    it 'missing_translations определяет незаполненные локали' do
      incomplete = create(:poi_category, name: { 'en' => 'Only EN' })

      expect(incomplete.missing_translations).to include(:ru)
      expect(incomplete).to be_missing_translations
    end
  end
end
