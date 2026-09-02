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

  describe 'картинка-маркер категории (category_icon)' do
    let(:category) { create(:poi_category) }

    it 'загружает картинку через POST /map_icon (update_category_icon)' do
      sign_in admin
      allow(PoiCategoryBroadcaster).to receive(:call)

      # Rack::Test::UploadedFile с явным абсолютным путём — fixture_file_upload
      # резолвится по file_fixture_path, который в этом спеке не гарантирован
      # (падало: нарушенный аргумент копирования/отсутствующий файл).
      icon_file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/photo.png'), 'image/png'
      )

      post update_category_icon_admin_poi_category_path(id: category), params: {
        category: { category_icon: icon_file }
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['attached']).to be true
      expect(body['url']).to be_present
      expect(category.reload.category_icon).to be_attached
    end

    it 'возвращает 422 без файла' do
      sign_in admin

      post update_category_icon_admin_poi_category_path(id: category)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'удаляет картинку через DELETE /map_icon (remove_category_icon)' do
      sign_in admin
      allow(PoiCategoryBroadcaster).to receive(:call)

      category.category_icon.attach(
        io: File.open(Rails.root.join('spec/fixtures/files/photo.png')),
        filename: 'test.png',
        content_type: 'image/png'
      )

      delete remove_category_icon_admin_poi_category_path(id: category)

      expect(response).to have_http_status(:ok)
      expect(category.reload.category_icon).not_to be_attached
    end

    it 'запрещает не-админу менять картинку' do
      user = create(:user)
      sign_in user

      icon_file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/photo.png'), 'image/png'
      )

      post update_category_icon_admin_poi_category_path(id: category), params: {
        category: { category_icon: icon_file }
      }

      # Не-админ отсекается в before_action require_admin_or_moderator!
      # (Admin::BaseController) редиректом на root — 302, а не 403:
      # Pundit-проверка в экшене не достигается.
      expect(response).to have_http_status(:found)
    end
  end

  describe 'POST /import_pbf (загрузка .pbf файла)' do
    let(:category) { create(:poi_category, :with_osm_tags) }

    it 'принимает .pbf, ставит OsmPbfImportJob и возвращает enqueued' do
      sign_in admin
      allow(OsmPbfImportJob).to receive(:perform_later)

      # Аналогично icon: явный абсолютный путь вместо fixture_file_upload.
      pbf_file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/photo.png'),
        'application/octet-stream',
        original_filename: 'test.osm.pbf'
      )

      post import_pbf_admin_poi_category_path(id: category), params: {
        poi_category: { pbf_file: pbf_file }
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['enqueued']).to be true
      expect(OsmPbfImportJob).to have_received(:perform_later)
    end

    it 'возвращает 422, если файл не передан' do
      sign_in admin

      post import_pbf_admin_poi_category_path(id: category)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'запрещает не-админу' do
      user = create(:user)
      sign_in user

      pbf_file = Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/photo.png'),
        'application/octet-stream',
        original_filename: 'test.osm.pbf'
      )

      post import_pbf_admin_poi_category_path(id: category), params: {
        poi_category: { pbf_file: pbf_file }
      }

      # Аналогично картинке: не-админ редиректится на root (302) в
      # require_admin_or_moderator! до Pundit-проверки экшена.
      expect(response).to have_http_status(:found)
    end
  end
end
