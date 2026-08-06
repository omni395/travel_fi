# frozen_string_literal: true

require 'rails_helper'

#
# PoisController — request-спек пользовательской карты/создания POI.
#
# Покрытие:
# 1. index — доступен гостю, загружает активные категории
# 2. create — требует аутентификации; создаёт POI через PoiService (redirect)
# 3. create — рендер new при ошибке валидации (CreateError)
# 4. update — обновляет POI (redirect)
#
RSpec.describe PoisController, type: :request do
  let(:user) { create(:user) }
  let(:category) { create(:poi_category) }

  def valid_poi_params(overrides = {})
    {
      name: 'Test POI',
      poi_category_id: category.id,
      latitude: 50.4501,
      longitude: 30.5234
    }.merge(overrides)
  end

  describe 'GET /pois (index)' do
    it 'доступен гостю без редиректа на логин' do
      get pois_path

      expect(response).to have_http_status(:ok)
    end

    it 'доступен аутентифицированному' do
      sign_in user

      get pois_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /pois (create)' do
    it 'редиректит гостя на логин' do
      post pois_path, params: { poi: valid_poi_params }

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'создаёт POI через PoiService и редиректит на карту' do
      sign_in user

      expect { post pois_path, params: { poi: valid_poi_params } }
        .to change(Poi, :count).by(1)
      expect(response).to redirect_to(pois_path)
    end

    it 'возвращает JSON 422 с ошибкой при ошибке валидации (для модалки)' do
      sign_in user

      post pois_path, params: { poi: valid_poi_params(name: '') }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']).to be_present
    end
  end

  describe 'PATCH /pois/:id (update)' do
    it 'обновляет POI и редиректит на карту' do
      poi = create(:poi, user: user)
      sign_in user

      patch poi_path(id: poi.id, locale: :en), params: { poi: { city: 'Kyiv' } }

      expect(poi.reload.city).to eq('Kyiv')
      expect(response).to redirect_to(pois_path)
    end
  end
end
