# frozen_string_literal: true

require 'rails_helper'

#
# Poi::PhotosController — HTTP/multipart цепочка галереи POI (create/destroy).
# Бинарники идут через fetch (не Reflex). Backend-логика проверяется здесь
# независимо от браузерного флака system-тестов (upload/delete).
#
RSpec.describe Poi::PhotosController, type: :request do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:category) { create(:poi_category) }
  let(:poi) { create(:poi, poi_category: category, user: user) }
  let(:image) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/photo.png'), 'image/png') }

  #
  # Фото создаётся через PhotoService.add_photo (как в контроллере create).
  #
  let!(:photo) do
    PoiService.add_photo(poi: poi, file: image, current_user: user)
  end

  describe 'POST /pois/:poi_id/photos' do
    context 'админ (вне proximity всегда)' do
      before { sign_in admin }

      it 'создаёт фото и возвращает JSON' do
        expect {
          post poi_photos_path(poi_id: poi.id), params: { photo: { image: image } }
        }.to change(Photo, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to have_key('photo')
      end
    end

    context 'обычный пользователь' do
      before { sign_in user }

      it 'создаёт фото в пределах proximity (координаты пользователя близко)' do
        # proximity 100м: задаём координаты пользователя рядом с POI
        allow(PoiService).to receive(:within_range?).and_return(true)
        expect {
          post poi_photos_path(poi_id: poi.id), params: { photo: { image: image } }
        }.to change(Photo, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it 'отклоняет без proximity (антифрод 100м)' do
        allow(PoiService).to receive(:within_range?).and_return(false)
        expect {
          post poi_photos_path(poi_id: poi.id), params: { photo: { image: image } }
        }.not_to change(Photo, :count)
        expect(response).to have_http_status(:forbidden)
      end

      it 'отклоняет без файла' do
        post poi_photos_path(poi_id: poi.id), params: { photo: {} }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE /pois/:poi_id/photos/:id' do
    context 'админ удаляет чужое фото (PhotoPolicy.destroy для admin)' do
      before { sign_in admin }

      it 'удаляет фото' do
        expect {
          delete poi_photo_path(poi_id: poi.id, id: photo.id)
        }.to change(Photo, :count).by(-1)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'ok' => true })
      end
    end

    context 'автор фото удаляет своё (PhotoPolicy.destroy для автора)' do
      before { sign_in user }

      it 'удаляет фото' do
        expect {
          delete poi_photo_path(poi_id: poi.id, id: photo.id)
        }.to change(Photo, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'посторонний пользователь не удаляет чужое' do
      let(:stranger) { create(:user) }

      it 'отклоняет удаление (Pundit NotAuthorized)' do
        sign_in stranger
        expect {
          delete poi_photo_path(poi_id: poi.id, id: photo.id)
        }.not_to change(Photo, :count)
        expect(response).to have_http_status(:redirect).or have_http_status(:forbidden)
      end
    end
  end
end
