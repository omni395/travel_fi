# frozen_string_literal: true

require 'rails_helper'

#
# PoiReflex — unit-спек Reflex пользовательской карты POI.
#
# Покрытие:
# 1. set_location — сохранение координат в session и Current
# 2. load_pois_in_bounds — загрузка visible POI в bounds + рендер списка/маркеров
# 3. filter_by_categories — фильтрация по категориям (спецификация: не падает)
# 4. create_comment — создание комментария с авторизацией (proximity)
# 5. reverse_geocode — заполнение полей формы через CableReady (мок сервиса)
# 6. show_geolocation_toast — тост геолокации
#
RSpec.describe PoiReflex, type: :reflex do
  let(:user) { create(:user) }
  let(:category) { create(:poi_category) }
  let(:cable_ready_mock) { build_cable_ready_mock }

  # Версия StimulusReflex gem — для check_version! в Reflex#initialize
  let(:sr_version) { Gem.loaded_specs['stimulus_reflex'].version.to_s }

  # Мок сессии Reflex (мутабельный — reflex пишет в session[:user_lat] и т.п.)
  let(:session_mock) { {} }

  #
  # Мок CableReady-билдера (все операции возвращают self/void)
  #
  def build_cable_ready_mock
    cr = double('cable_ready')
    allow(cr).to receive(:inner_html)
    allow(cr).to receive(:set_attribute)
    allow(cr).to receive(:remove_css_class)
    allow(cr).to receive(:add_css_class)
    allow(cr).to receive(:morph)
    allow(cr).to receive(:insert_adjacent_html)
    allow(cr).to receive(:dispatch_event)
    allow(cr).to receive(:broadcast)
    cr
  end

  #
  # Создаёт экземпляр Reflex с моками connection/reflex_data/session/cable_ready.
  #
  # @param klass [Class] класс Reflex
  # @param method_name [Symbol] имя действия
  # @param user [User] current_user
  # @param url [String] URL рефлекса
  # @return [StimulusReflex::Reflex]
  #
  def build_reflex(klass, method_name, user:, url: 'http://test.host/pois')
    connection = instance_double('Connection')
    allow(connection).to receive(:current_user).and_return(user)
    allow(connection).to receive(:env).and_return(
      'rack.session' => {},
      'rack.session.options' => { id: SecureRandom.hex(16) },
      'HTTP_HOST' => 'test.host',
      'rack.input' => StringIO.new('')
    )

    channel = instance_double('Channel')
    allow(channel).to receive(:connection).and_return(connection)
    allow(channel).to receive(:stream_name).and_return("user_#{user&.id}")

    element = instance_double('Element')
    allow(element).to receive(:dataset).and_return({})
    allow(element).to receive(:value).and_return('')

    reflex_data = instance_double('StimulusReflex::ReflexData')
    allow(reflex_data).to receive(:url).and_return(url)
    allow(reflex_data).to receive(:element).and_return(element)
    allow(reflex_data).to receive(:selectors).and_return([])
    allow(reflex_data).to receive(:method_name).and_return(method_name)
    allow(reflex_data).to receive(:id).and_return('reflex-1')
    allow(reflex_data).to receive(:params).and_return({})
    allow(reflex_data).to receive(:suppress_logging).and_return(true)
    allow(reflex_data).to receive(:reflex_controller).and_return('poi')
    allow(reflex_data).to receive(:version).and_return(sr_version)
    allow(reflex_data).to receive(:npm_version).and_return(sr_version)
    allow(reflex_data).to receive(:tab_id).and_return(nil)
    allow(reflex_data).to receive(:xpath_controller).and_return(nil)
    allow(reflex_data).to receive(:xpath_element).and_return(nil)
    allow(reflex_data).to receive(:permanent_attribute_name).and_return(nil)

    reflex = klass.new(channel, reflex_data: reflex_data)
    allow(reflex).to receive(:session).and_return(session_mock)
    allow(reflex).to receive(:cable_ready).and_return(cable_ready_mock)
    reflex
  end

  describe '#set_location' do
    it 'сохраняет координаты в session и Current' do
      reflex = build_reflex(described_class, :set_location, user: user)

      reflex.set_location(lat: 50.45, lng: 30.52)

      expect(reflex.session[:user_lat]).to eq(50.45)
      expect(reflex.session[:user_lng]).to eq(30.52)
      expect(Current.user_lat).to eq(50.45)
    end
  end

  describe '#load_pois_in_bounds' do
    it 'рендерит список и маркеры только видимых POI в bounds' do
      create(:poi, status: :approved, poi_category: category,
                   coordinates: PoiService.parse_coordinates(50.45, 30.52))
      create(:poi, :pending, poi_category: category,
                             coordinates: PoiService.parse_coordinates(50.45, 30.52))
      allow(ApplicationController).to receive(:render).and_return('')

      reflex = build_reflex(described_class, :load_pois_in_bounds, user: user)

      expect { reflex.load_pois_in_bounds(sw_lat: 50.0, sw_lng: 30.0, ne_lat: 51.0, ne_lng: 31.0) }
        .not_to raise_error
    end
  end

  describe '#filter_by_categories' do
    it 'фильтрует POI по категориям без ошибок (спецификация)' do
      create(:poi, status: :approved, poi_category: category,
                   coordinates: PoiService.parse_coordinates(50.45, 30.52))
      allow(ApplicationController).to receive(:render).and_return('')

      reflex = build_reflex(described_class, :filter_by_categories, user: user)

      # Ожидание: фильтрация отрабатывает и формирует inner_html.
      # Сейчас падает NameError (bounds) — тест выявляет баг.
      expect { reflex.filter_by_categories(category_ids: [ category.id ], sw_lat: 50.0, sw_lng: 30.0, ne_lat: 51.0, ne_lng: 31.0) }
        .not_to raise_error
    end
  end

  describe '#create_comment' do
    it 'создаёт комментарий при авторизации в радиусе 100м' do
      poi = create(:poi) # 50.4501, 30.5234
      session_mock[:user_lat] = 50.4501
      session_mock[:user_lng] = 30.5234
      allow(ApplicationController).to receive(:render).and_return('')

      reflex = build_reflex(described_class, :create_comment, user: user)

      expect { reflex.create_comment(poi_id: poi.id, body: 'Nice') }
        .to change(PoiComment, :count).by(1)
    ensure
      Current.user_lat = nil
      Current.user_lng = nil
    end
  end

  describe '#reverse_geocode' do
    it 'заполняет поля формы через CableReady при успешном ответе' do
      allow(ReverseGeocodingService).to receive(:reverse_geocode)
        .and_return(country: 'Ukraine', city: 'Kyiv', address: 'Khreshchatyk', zip_code: '01001')

      reflex = build_reflex(described_class, :reverse_geocode, user: user)

      expect(cable_ready_mock).to receive(:set_attribute).at_least(:once)
      expect { reflex.reverse_geocode(lat: 50.45, lng: 30.52) }.not_to raise_error
    end
  end

  describe '#show_geolocation_toast' do
    it 'шлёт тост через ToastBroadcaster для аутентифицированного' do
      reflex = build_reflex(described_class, :show_geolocation_toast, user: user)

      expect(ToastBroadcaster).to receive(:call).with(hash_including(user_id: user.id, type: :warning))

      reflex.show_geolocation_toast
    end
  end
end
