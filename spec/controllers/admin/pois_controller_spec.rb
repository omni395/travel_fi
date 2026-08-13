# frozen_string_literal: true

require 'rails_helper'

#
# Admin::PoisController — request-спек админ-страницы POI (баг 6).
#
# Покрытие:
# 1. show с ?edit=true рендерит форму редактирования (EditComponent)
# 2. Форма использует Ui::DropdownComponent для категории (НЕ <select>)
# 3. Форма использует Ui::DropdownComponent для статуса (НЕ <select>)
# 4. rating — readonly-значение, НЕ редактируемое поле (консолидированное вычисляемое)
# 5. Мини-карта инициализируется собственным контроллером (bag 6)
#
RSpec.describe Admin::PoisController, type: :request do
  let(:admin) { create(:user, :admin) }
  let(:category) { create(:poi_category) }
  let(:poi) { create(:poi, poi_category: category, rating: 4.5) }

  before { sign_in admin }

  describe 'GET /admin-panel/pois/:id?edit=true (форма редактирования, баг 6)' do
    it 'рендерит edit-форму (EditComponent) при ?edit=true' do
      get admin_poi_path(id: poi.id, edit: 'true')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('admin--pois--poi--edit-component')
    end

    it 'использует Ui::DropdownComponent для категории вместо <select>' do
      get admin_poi_path(id: poi.id, edit: 'true')

      # Dropdown рендерит кнопку с data-action, НЕ <select>
      expect(response.body).to include('ui--dropdown-component')
      expect(response.body).not_to include('<select')
    end

    it 'отображает выбранную категорию в тексте дропдауна' do
      get admin_poi_path(id: poi.id, edit: 'true')

      # Имя категории отображается как текст выбранного значения
      expect(response.body).to include(CGI.escapeHTML(category.localized_name))
    end

    it 'показывает rating как readonly-значение (не редактируемое поле)' do
      get admin_poi_path(id: poi.id, edit: 'true')

      body = response.body
      # Значение rating выводится как текст, а не как number_field с name="poi[rating]"
      expect(body).to include('4.5')
      expect(body).not_to include('poi[rating]')
    end

    it 'инициализирует мини-карту собственным контроллером poi--map-component' do
      get admin_poi_path(id: poi.id, edit: 'true')

      # Single-POI режим: корень MapComponent несёт data-controller="poi--map-component"
      # и data-poi-single-* → инициализация карты при загрузке (баг 6).
      expect(response.body).to include('data-controller="poi--map-component"')
      expect(response.body).to include('data-poi-single-lat')
    end
  end

  describe 'GET /admin-panel/pois/:id (show без edit)' do
    it 'рендерит ShowComponent, а не форму' do
      get admin_poi_path(id: poi.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('admin--pois--poi--edit-component')
    end
  end
end
