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

    it 'статус рендерится как скрытый input name="poi[status]" внутри Dropdown (не <select>, не radio)' do
      get admin_poi_path(id: poi.id, edit: 'true')

      body = response.body
      # Статус — DropdownComponent с hidden input name="poi[status]" (обновляется
      # через selectStatus в edit_component_controller.js) и пунктами меню с
      # data-action="click->admin--pois--poi--edit-component#selectStatus".
      # НЕ radio-кнопки и НЕ <select>.
      expect(body).to include('name="poi[status]"')
      expect(body).to include('type="hidden"')
      expect(body).to include('data-admin--pois--poi--edit-component-target="statusInput"')
      expect(body).to include('selectStatus')
      expect(body).not_to include('type="radio"')
      expect(body).not_to include('<select')
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

    it 'не дублирует секцию деталей: шапка отдельно (HeaderComponent), детали — в табе (ShowComponent)' do
      get admin_poi_path(id: poi.id)

      body = response.body
      # Шапка рендерится ОДИН раз через HeaderComponent
      expect(body).to include('admin--pois--poi--header-component').once
      # Содержимое таба Details — через ShowComponent в обёртке [data-poi-detail-body]
      expect(body).to include('data-poi-detail-body').once
    end
  end
end
