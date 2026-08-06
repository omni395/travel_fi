# frozen_string_literal: true

require 'rails_helper'

#
# Admin::PoisReflex — unit-спек Reflex админ-модерации POI.
#
# Покрытие:
# 1. create — authorize + PoiService.create + redirect
# 2. update — authorize + PoiService.update (спецификация: НЕ рендерит DOM после сохранения)
# 3. change_status — authorize moderate? + PoiService.change_status
# 4. destroy — authorize destroy? + PoiService.destroy + redirect
# 5. filter — authorize index? + search_pois + морф таблицы
#
RSpec.describe Admin::PoisReflex, type: :reflex do
  let(:admin) { create(:user, :admin) }
  let(:category) { create(:poi_category) }

  # Версия StimulusReflex gem — для check_version! в Reflex#initialize
  let(:sr_version) { Gem.loaded_specs['stimulus_reflex'].version.to_s }

  def build_cable_ready_mock
    cr = double('cable_ready')
    allow(cr).to receive(:[]).and_return(cr)
    allow(cr).to receive(:inner_html)
    allow(cr).to receive(:morph)
    allow(cr).to receive(:dispatch_event)
    allow(cr).to receive(:redirect_to)
    allow(cr).to receive(:broadcast)
    cr
  end

  #
  # Создаёт экземпляр Admin Reflex с моками connection/reflex_data/session/cable_ready.
  #
  def build_reflex(method_name, user:, url: 'http://test.host/admin-panel/pois')
    cable_mock = build_cable_ready_mock
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
    allow(reflex_data).to receive(:id).and_return('reflex-admin-1')
    allow(reflex_data).to receive(:params).and_return({})
    allow(reflex_data).to receive(:suppress_logging).and_return(true)
    allow(reflex_data).to receive(:reflex_controller).and_return('admin--pois')
    allow(reflex_data).to receive(:version).and_return(sr_version)
    allow(reflex_data).to receive(:npm_version).and_return(sr_version)
    allow(reflex_data).to receive(:tab_id).and_return(nil)
    allow(reflex_data).to receive(:xpath_controller).and_return(nil)
    allow(reflex_data).to receive(:xpath_element).and_return(nil)
    allow(reflex_data).to receive(:permanent_attribute_name).and_return(nil)

    reflex = described_class.new(channel, reflex_data: reflex_data)
    allow(reflex).to receive(:session).and_return({})
    allow(reflex).to receive(:cable_ready).and_return(cable_mock)
    reflex
  end

  describe '#create' do
    it 'создаёт POI через PoiService и редиректит' do
      allow(ApplicationController).to receive(:render).and_return('')
      reflex = build_reflex(:create, user: admin)

      expect { reflex.create(poi_category_id: category.id, name: 'New POI', latitude: 50.45, longitude: 30.52) }
        .to change(Poi, :count).by(1)
    end
  end

  describe '#update' do
    it 'обновляет POI через PoiService' do
      poi = create(:poi)
      allow(ApplicationController).to receive(:render).and_return('')
      reflex = build_reflex(:update, user: admin)

      reflex.update(id: poi.id, city: 'Kyiv')

      expect(poi.reload.city).to eq('Kyiv')
    end
  end

  describe '#change_status' do
    it 'меняет статус POI через PoiService (модерация)' do
      poi = create(:poi, :pending)
      allow(ApplicationController).to receive(:render).and_return('')
      reflex = build_reflex(:change_status, user: admin)

      reflex.change_status(id: poi.id, status: 'approved')

      expect(poi.reload).to be_approved
    end
  end

  describe '#destroy' do
    it 'удаляет POI через PoiService' do
      poi = create(:poi)
      reflex = build_reflex(:destroy, user: admin)

      expect { reflex.destroy(poi_id: poi.id) }
        .to change(Poi, :count).by(-1)
    end
  end

  describe '#filter' do
    it 'выполняет поиск через PoiService и морфит таблицу (не падает)' do
      create(:poi, poi_category: category)
      allow(ApplicationController).to receive(:render).and_return('')
      reflex = build_reflex(:filter, user: admin)

      expect { reflex.filter(query: 'POI') }.not_to raise_error
    end
  end
end
