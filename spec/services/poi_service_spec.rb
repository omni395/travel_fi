# frozen_string_literal: true

require 'rails_helper'

#
# PoiService — unit-спек полного поведения сервиса POI.
#
# Покрытие:
# 1. CRUD: create / update / change_status / destroy
# 2. Комментарии: create / update / destroy (включая threaded-ответы через parent_id)
# 3. Proximity-проверка 100м (within_range?)
# 4. Поиск и фильтрация (search_pois) + геопоиск (nearby)
# 5. Сериализация: to_geojson / map_feature_data
# 6. Координаты: parse_coordinates
# 7. Заглушки (pending): PoiRating-агрегация (ROADMAP 2.2)
#
RSpec.describe PoiService, type: :service do
  let(:user) { create(:user) }
  let(:category) { create(:poi_category) }

  #
  # Валидные параметры создания POI (name — строка, как шлёт форма; координаты Киева)
  #
  def valid_params(overrides = {})
    {
      poi_category_id: category.id,
      name: "Test POI",
      latitude: 50.4501,
      longitude: 30.5234
    }.merge(overrides)
  end

  describe '.create' do
    it 'создаёт POI со статусом pending по умолчанию и привязкой к current_user' do
      poi = described_class.create(params: valid_params, current_user: user)

      expect(poi).to be_persisted
      expect(poi.status).to eq('pending')
      expect(poi.user).to eq(user)
      expect(poi.poi_category).to eq(category)
    end

    it 'оборачивает строковый name в JSONB текущей локали' do
      poi = described_class.create(params: valid_params, current_user: user)

      expect(poi.name).to eq({ 'en' => 'Test POI' })
    end

    it 'сохраняет Hash-переводы name/description без изменений' do
      poi = described_class.create(
        params: valid_params(
          name: { 'en' => 'Fountain', 'ru' => 'Фонтан' },
          description: { 'en' => 'Nice', 'ru' => 'Красивый' }
        ),
        current_user: user
      )

      expect(poi.name).to eq({ 'en' => 'Fountain', 'ru' => 'Фонтан' })
      expect(poi.description).to eq({ 'en' => 'Nice', 'ru' => 'Красивый' })
    end

    it 'парсит координаты в PostGIS точку (srid 4326)' do
      poi = described_class.create(params: valid_params, current_user: user)

      expect(poi.coordinates).not_to be_nil
      expect(poi.latitude).to be_within(0.0001).of(50.4501)
      expect(poi.longitude).to be_within(0.0001).of(30.5234)
    end

    it 'применяет явный статус, если передан' do
      poi = described_class.create(params: valid_params(status: 'approved'), current_user: user)

      expect(poi).to be_approved
    end

    it 'сохраняет дополнительные поля (address/city/country/phone/website/metadata)' do
      poi = described_class.create(
        params: valid_params(
          address: 'Khreshchatyk 1',
          city: 'Kyiv',
          country: 'UA',
          phone: '+380',
          website: 'https://example.com',
          metadata: { 'operator' => 'Test' }
        ),
        current_user: user
      )

      expect(poi.address).to eq('Khreshchatyk 1')
      expect(poi.city).to eq('Kyiv')
      expect(poi.country).to eq('UA')
      expect(poi.phone).to eq('+380')
      expect(poi.website).to eq('https://example.com')
      expect(poi.metadata).to eq({ 'operator' => 'Test' })
    end

    it 'бросает CreateError при ошибке валидации (нет name)' do
      expect {
        described_class.create(params: valid_params.except(:name), current_user: user)
      }.to raise_error(PoiService::CreateError)
    end

    it 'делегирует прикрепление фото в PhotoService при наличии photos' do
      file = ActionDispatch::Http::UploadedFile.new(
        tempfile: StringIO.new('fake-image'),
        filename: 'photo.png',
        type: 'image/png'
      )
      params = valid_params(photos: [ file ])

      expect(PhotoService).to receive(:attach_photos)
        .with(record: an_instance_of(Poi), files: [ file ], audit_touch: true)

      described_class.create(params: params, current_user: user)
    end
  end

  describe '.update' do
    let(:poi) { create(:poi) }

    it 'обновляет поля и локализованный name' do
      described_class.update(
        poi: poi,
        params: { name: { 'en' => 'Updated', 'ru' => 'Обновлено' }, city: 'Kyiv' },
        current_user: user
      )

      expect(poi.reload.name['en']).to eq('Updated')
      expect(poi.reload.city).to eq('Kyiv')
    end

    it 'обновляет координаты, если переданы latitude/longitude' do
      described_class.update(
        poi: poi,
        params: { latitude: 51.5, longitude: -0.1 },
        current_user: user
      )

      expect(poi.reload.latitude).to be_within(0.0001).of(51.5)
      expect(poi.reload.longitude).to be_within(0.0001).of(-0.1)
    end

    it 'бросает UpdateError при ошибке валидации (name слишком короткое)' do
      expect {
        described_class.update(poi: poi, params: { name: 'X' }, current_user: user)
      }.to raise_error(PoiService::UpdateError)
    end
  end

  describe '.change_status' do
    let(:poi) { create(:poi, :pending) }

    it 'переводит POI в approved' do
      described_class.change_status(poi: poi, status: :approved, current_user: user)

      expect(poi.reload).to be_approved
    end

    it 'переводит POI в rejected и archived' do
      described_class.change_status(poi: poi, status: 'rejected', current_user: user)
      expect(poi.reload).to be_rejected

      described_class.change_status(poi: poi, status: 'archived', current_user: user)
      expect(poi.reload).to be_archived
    end

    it 'создаёт PaperTrail-версию при смене статуса' do
      expect { described_class.change_status(poi: poi, status: :approved, current_user: user) }
        .to change { poi.reload.versions.count }.by(1)
    end

    it 'бросает StatusError при невалидном статусе' do
      expect {
        described_class.change_status(poi: poi, status: :bogus, current_user: user)
      }.to raise_error(PoiService::StatusError)
    end
  end

  describe '.destroy' do
    it 'удаляет POI вместе с комментариями' do
      poi = create(:poi)
      create(:poi_comment, poi: poi)

      described_class.destroy(poi: poi, current_user: user)

      expect(Poi.exists?(poi.id)).to be(false)
      expect(PoiComment.where(poi_id: poi.id).count).to eq(0)
    end
  end

  describe 'комментарии' do
    let(:poi) { create(:poi) }

    describe '.create_comment' do
      it 'создаёт комментарий с автором' do
        comment = described_class.create_comment(poi: poi, user: user, body: 'Nice place')

        expect(comment).to be_persisted
        expect(comment.poi).to eq(poi)
        expect(comment.user).to eq(user)
        expect(comment.body).to eq('Nice place')
      end

      it 'поддерживает threaded-ответы через parent_id' do
        parent = create(:poi_comment, poi: poi)
        reply = described_class.create_comment(poi: poi, user: user, body: 'Reply', parent_id: parent.id)

        expect(reply.parent).to eq(parent)
        expect(poi.poi_comments.roots).to include(parent)
        expect(poi.poi_comments.replies_for(parent.id)).to include(reply)
      end

      it 'бросает CreateError при пустом теле' do
        expect {
          described_class.create_comment(poi: poi, user: user, body: '')
        }.to raise_error(PoiService::CreateError)
      end
    end

    describe '.update_comment' do
      it 'обновляет тело комментария' do
        comment = create(:poi_comment, poi: poi, user: user, body: 'Old')

        described_class.update_comment(comment: comment, body: 'New')

        expect(comment.reload.body).to eq('New')
      end

      it 'бросает UpdateError при невалидном теле' do
        comment = create(:poi_comment, poi: poi, user: user, body: 'Old')

        expect {
          described_class.update_comment(comment: comment, body: '')
        }.to raise_error(PoiService::UpdateError)
      end
    end

    describe '.destroy_comment' do
      it 'удаляет комментарий' do
        comment = create(:poi_comment, poi: poi, user: user)

        described_class.destroy_comment(comment: comment)

        expect(PoiComment.exists?(comment.id)).to be(false)
      end
    end
  end

  describe '.within_range? (proximity 100м)' do
    let(:poi) { create(:poi) } # 50.4501, 30.5234

    it 'всегда true для админа/модератора без координат' do
      admin = create(:user, :admin)

      expect(described_class.within_range?(
        user_lat: nil, user_lng: nil,
        poi_lat: 0, poi_lng: 0, user: admin
      )).to be(true)
    end

    it 'false при отсутствии координат пользователя' do
      expect(described_class.within_range?(
        user_lat: nil, user_lng: nil,
        poi_lat: poi.latitude, poi_lng: poi.longitude, user: user
      )).to be(false)
    end

    it 'true, если пользователь в радиусе 100м' do
      # ~13м от точки
      expect(described_class.within_range?(
        user_lat: 50.4502, user_lng: 30.5235,
        poi_lat: poi.latitude, poi_lng: poi.longitude, user: user
      )).to be(true)
    end

    it 'false, если пользователь дальше 100м' do
      # ~1.1км от точки
      expect(described_class.within_range?(
        user_lat: 50.4600, user_lng: 30.5300,
        poi_lat: poi.latitude, poi_lng: poi.longitude, user: user
      )).to be(false)
    end
  end

  describe '.search_pois' do
    it 'находит POI по query (name_or_description_cont)' do
      target = create(:poi, name: { 'en' => 'Kyiv Fountain', 'ru' => 'Киевский фонтан' })
      create(:poi, name: { 'en' => 'Another Place' })

      result = described_class.search_pois(query: 'Fountain')

      expect(result).to include(target)
      expect(result.count).to eq(1)
    end

    it 'фильтрует по статусу и категории' do
      approved = create(:poi, status: :approved, poi_category: category)
      pending = create(:poi, :pending, poi_category: category)

      result = described_class.search_pois(status: 'pending', category_id: category.id)

      expect(result).to include(pending)
      expect(result).not_to include(approved)
    end

    it 'сортирует по валидной колонке и направлению' do
      create(:poi, name: { 'en' => 'Beta' }, city: 'B')
      create(:poi, name: { 'en' => 'Alpha' }, city: 'A')

      result = described_class.search_pois(sort_column: 'city', sort_direction: 'asc')

      expect(result.first.city).to eq('A')
    end
  end

  describe '.nearby (геопоиск)' do
    it 'возвращает только approved POI в радиусе и фильтрует по категории' do
      inside = create(:poi, coordinates: PoiService.parse_coordinates(50.4501, 30.5234), poi_category: category)
      far = create(:poi, coordinates: PoiService.parse_coordinates(51.0, 30.0))
      outside_category = create(:poi, coordinates: PoiService.parse_coordinates(50.4501, 30.5234))

      result = described_class.nearby(lat: 50.4501, lng: 30.5234, radius_km: 10, category_id: category.id)

      expect(result).to include(inside)
      expect(result).not_to include(far)
      expect(result).not_to include(outside_category)
    end
  end

  describe '.to_geojson' do
    it 'строит FeatureCollection с точкой и свойствами' do
      poi = create(:poi)

      gj = described_class.to_geojson([ poi ])

      expect(gj[:type]).to eq('FeatureCollection')
      feature = gj[:features].first
      expect(feature[:geometry][:type]).to eq('Point')
      expect(feature[:geometry][:coordinates]).to eq([ poi.longitude, poi.latitude ])
      expect(feature[:properties][:id]).to eq(poi.id)
      expect(feature[:properties][:slug]).to eq(poi.slug)
    end
  end

  describe '.map_feature_data' do
    it 'возвращает data-атрибуты фичи карты' do
      poi = create(:poi)

      data = described_class.map_feature_data(poi)

      expect(data[:id]).to eq(poi.id)
      expect(data[:lat]).to eq(poi.latitude)
      expect(data[:lng]).to eq(poi.longitude)
      expect(data[:category_id]).to eq(poi.poi_category_id)
      expect(data[:slug]).to eq(poi.slug)
      expect(data[:photo]).to be_nil
    end

    it 'использует fallback-иконку, если у категории нет иконки' do
      cat = create(:poi_category, icon: nil)
      poi = create(:poi, poi_category: cat)

      expect(described_class.map_feature_data(poi)[:icon]).to eq('mdi-map-marker')
    end
  end

  describe '.parse_coordinates' do
    it 'строит точку srid 4326 с правильными координатами' do
      point = described_class.parse_coordinates(50.45, 30.52)

      expect(point.srid).to eq(4326)
      expect(point.x).to eq(30.52)
      expect(point.y).to eq(50.45)
    end
  end

  describe '.rate (заглушка: PoiRating — фича в планах, ROADMAP 2.2)' do
    it 'создаёт оценку 1..5 и пересчитывает poi.rating' do
      pending 'заглушка: PoiRating не реализован (ROADMAP 2.2)'

      poi = create(:poi, rating: 0.0)

      described_class.rate(poi: poi, user: create(:user), value: 5)

      expect(poi.reload.rating).to eq(5.0)
    end

    it 'усредняет несколько оценок в poi.rating' do
      pending 'заглушка: PoiRating не реализован (ROADMAP 2.2)'

      poi = create(:poi, rating: 0.0)
      other = create(:user)

      described_class.rate(poi: poi, user: user, value: 4)
      described_class.rate(poi: poi, user: other, value: 2)

      expect(poi.reload.rating).to eq(3.0)
    end
  end

  describe 'геймификация (награды TFT из config/gamification.yml)' do
    let(:rewards) { YAML.safe_load_file(Rails.root.join('config/gamification.yml'))['rewards'] }

    describe '.create' do
      it 'НЕ начисляет poi_create при создании pending-точки (БАГ B: награда только после approve)' do
        described_class.create(params: valid_params, current_user: user)

        expect(user.reload.token_balance).to eq(0)
        expect(user.token_transactions).to be_empty
      end

      it 'начисляет poi_create, если точка создана сразу в статусе approved' do
        amount = rewards['poi_create'].to_d

        described_class.create(params: valid_params(status: 'approved'), current_user: user)

        expect(user.reload.token_balance).to eq(amount)
        expect(Poi.last.awarded_for_approval?).to be(true)
      end
    end

    describe '.change_status' do
      let(:pending_poi) { create(:poi, user: user, status: :pending) }

      it 'начисляет награду автору при переводе pending → approved (БАГ B)' do
        amount = rewards['poi_create'].to_d

        described_class.change_status(poi: pending_poi, status: :approved, current_user: user)

        expect(user.reload.token_balance).to eq(amount)
        expect(pending_poi.reload).to be_approved
        expect(pending_poi.awarded_for_approval?).to be(true)
      end

      it 'не начисляет при переводе в rejected/archived' do
        described_class.change_status(poi: pending_poi, status: :rejected, current_user: user)

        expect(user.reload.token_balance).to eq(0)
      end

      it 'начисляет награду ТОЛЬКО один раз (идемпотентность при повторном approve)' do
        amount = rewards['poi_create'].to_d

        described_class.change_status(poi: pending_poi, status: :approved, current_user: user)
        described_class.change_status(poi: pending_poi, status: :rejected, current_user: user)
        described_class.change_status(poi: pending_poi, status: :approved, current_user: user)

        expect(user.reload.token_balance).to eq(amount)
      end
    end

    describe '.create_comment' do
      it 'вызывает GamificationService.award!(:comment_create) для автора комментария' do
        poi = create(:poi)

        expect(GamificationService).to receive(:award!).with(:comment_create, user)

        described_class.create_comment(poi: poi, user: user, body: 'Nice place')
      end
    end
  end
end
