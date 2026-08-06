# frozen_string_literal: true

require 'rails_helper'

#
# Admin::PoiCategoriesController — request-спек админ-страниц категорий POI.
#
# Покрытие:
# 1. GET /admin-panel/poi_categories/new — рендер формы.
# 2. POST /admin-panel/poi_categories (create) — создание через
#    PoiCategoryService + redirect (форма шлёт префикс poi_category[...]).
# 3. POST /admin-panel/poi_categories — рендер :new с 422 при ошибке валидации.
#
RSpec.describe Admin::PoiCategoriesController, type: :request do
  let(:admin) { create(:user, :admin) }

  def category_params(overrides = {})
    {
      poi_category: {
        name: { 'en' => 'Toilets', 'ru' => 'Туалеты' },
        slug: 'toilets',
        icon: 'mdi-toilet',
        active: true
      }.merge(overrides)
    }
  end

  describe 'GET /admin-panel/poi_categories/new' do
    it 'рендерит форму создания' do
      sign_in admin

      get new_admin_poi_category_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /admin-panel/poi_categories (create)' do
    it 'создаёт категорию через PoiCategoryService и редиректит на show' do
      sign_in admin

      expect { post admin_poi_categories_path, params: category_params }
        .to change(PoiCategory, :count).by(1)

      expect(response).to redirect_to(admin_poi_category_path(id: PoiCategory.last))
      expect(PoiCategory.last.name).to eq({ 'en' => 'Toilets', 'ru' => 'Туалеты' })
    end

    it 'рендерит :new с 422 при ошибке валидации (отсутствует name)' do
      sign_in admin

      post admin_poi_categories_path, params: category_params(name: nil)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'редиректит гостя на логин' do
      post admin_poi_categories_path, params: category_params

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
