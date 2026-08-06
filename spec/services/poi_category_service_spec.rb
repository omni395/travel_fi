# frozen_string_literal: true

require 'rails_helper'

#
# PoiCategoryService — unit-тесты сервиса категорий POI.
#
RSpec.describe PoiCategoryService, type: :service do
  let(:admin) { create(:user, :admin) }
  let(:params) do
    {
      name: { 'en' => 'Toilets', 'ru' => 'Туалеты' },
      slug: 'toilets',
      icon: 'mdi-toilet',
      active: true
    }
  end

  describe '.create' do
    it 'создаёт категорию' do
      category = described_class.create(params: params, current_user: admin)

      expect(category).to be_persisted
      expect(category.slug).to eq('toilets')
    end

    it 'бросает CreateError при невалидных данных' do
      expect { described_class.create(params: { name: nil }, current_user: admin) }
        .to raise_error(PoiCategoryService::CreateError)
    end
  end

  describe '.update' do
    it 'обновляет категорию' do
      category = create(:poi_category)

      described_class.update(category: category, params: { icon: 'mdi-new' }, current_user: admin)

      expect(category.reload.icon).to eq('mdi-new')
    end
  end

  describe 'поля категории' do
    it 'create_field → update_field → destroy_field' do
      category = create(:poi_category)

      field = described_class.create_field(
        category: category,
        params: { field_key: 'phone', field_type: 'string', label: { 'en' => 'Phone' } },
        current_user: admin
      )
      expect(field).to be_persisted

      described_class.update_field(field: field, params: { required: true }, current_user: admin)
      expect(field.reload.required).to be true

      described_class.destroy_field(field: field, current_user: admin)
      expect(PoiCategoryField.exists?(field.id)).to be false
    end

    it 'reorder_field меняет позиции через update!' do
      category = create(:poi_category)
      first = create(:poi_category_field, poi_category: category, position: 1)
      second = create(:poi_category_field, poi_category: category, position: 2)

      described_class.reorder_field(field: second, direction: 'up')

      expect(first.reload.position).to eq(2)
      expect(second.reload.position).to eq(1)
    end
  end

  describe '.search_categories' do
    it 'фильтрует по active' do
      create(:poi_category, :inactive)
      active = create(:poi_category)

      expect(described_class.search_categories(active: true)).to include(active)
    end
  end
end
