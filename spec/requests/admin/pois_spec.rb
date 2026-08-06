# frozen_string_literal: true

require 'rails_helper'

#
# Admin::PoisController — request-спек админ-страниц POI.
#
# Покрытие:
# 1. GET /admin-panel/pois/new — рендер формы (регрессия ActionNotFound
#    verify_policy_scoped: раньше маршрут :create указывал на несуществующий
#    action, и Rails 7.1+ падал AbstractController::ActionNotFound).
# 2. POST /admin-panel/pois (create) — создание через PoiService + redirect.
# 3. POST /admin-panel/pois — рендер :new с 422 при ошибке валидации.
# 4. POST /admin-panel/pois — редирект гостя на логин.
#
RSpec.describe Admin::PoisController, type: :request do
  let(:admin) { create(:user, :admin) }
  let(:category) { create(:poi_category) }

  #
  # Параметры создания POI (мультиязычный name — как шлёт форма EditComponent)
  #
  def poi_params(overrides = {})
    {
      poi: {
        name: { 'en' => 'New POI', 'ru' => 'Новая точка' },
        poi_category_id: category.id,
        latitude: 50.4501,
        longitude: 30.5234
      }.merge(overrides)
    }
  end

  describe 'GET /admin-panel/pois/new' do
    it 'рендерит форму создания (не падает ActionNotFound verify_policy_scoped)' do
      sign_in admin

      get new_admin_poi_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /admin-panel/pois (create)' do
    it 'создаёт POI через PoiService и редиректит на show' do
      sign_in admin

      expect { post admin_pois_path, params: poi_params }
        .to change(Poi, :count).by(1)

      expect(response).to redirect_to(admin_poi_path(id: Poi.last))
    end

    it 'рендерит :new с 422 при ошибке валидации (пустой name)' do
      sign_in admin

      post admin_pois_path, params: poi_params(name: { 'en' => '' })

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'редиректит гостя на логин' do
      post admin_pois_path, params: poi_params

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
