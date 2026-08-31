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

  describe 'картинка-маркер категории (category_icon)' do
    before do
      allow(PoiCategoryBroadcaster).to receive(:call)
      allow(PhotoService).to receive(:process) do |file, **|
        File.open(file.respond_to?(:path) ? file.path : file)
      end
    end

    it 'attach_category_icon прикрепляет картинку и шлёт broadcast (category_icon)' do
      category = create(:poi_category)
      file = fixture_file_upload('files/photo.png', 'image/png')

      described_class.attach_category_icon(category: category, file: file, current_user: admin)

      expect(category.reload.category_icon).to be_attached
      expect(PoiCategoryBroadcaster).to have_received(:call).with(
        category: category, event_type: 'category_icon'
      )
    end

    it 'бросает UpdateError при невалидном типе файла' do
      category = create(:poi_category)
      file = fixture_file_upload('files/photo.png', 'text/plain')

      expect { described_class.attach_category_icon(category: category, file: file, current_user: admin) }
        .to raise_error(PoiCategoryService::UpdateError)
    end

    it 'remove_category_icon удаляет картинку и шлёт broadcast (category_icon)' do
      category = create(:poi_category)
      category.category_icon.attach(
        io: File.open(Rails.root.join('spec/fixtures/files/photo.png')),
        filename: 'test.png',
        content_type: 'image/png'
      )

      described_class.remove_category_icon(category: category, current_user: admin)

      expect(category.reload.category_icon).not_to be_attached
      expect(PoiCategoryBroadcaster).to have_received(:call).with(
        category: category, event_type: 'category_icon'
      )
    end
  end
end
