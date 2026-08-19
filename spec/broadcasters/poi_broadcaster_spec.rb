# frozen_string_literal: true

require 'rails_helper'

#
# PoiBroadcaster — unit-спек конвейера live-обновлений POI.
#
# Покрытие:
# 1. Рендер зоны элемента списка (ListItemComponent) в HTML с data-poi-id
# 2. Формирование CableReady-инструкций и broadcast в UserChannel/AdminChannel
# 3. Спецификация: для списка используется inner_html (НЕ morph) — сейчас морф (баг)
# 4. dispatch_event("poi:reload-features") — обновление карты
# 5. Устойчивость: сбой рендера одной зоны не роняет broadcast (rescue)
#
RSpec.describe PoiBroadcaster, type: :service do
  let(:poi) { create(:poi) }
  let(:broadcaster) { described_class.new(poi: poi) }
  let(:cable_mock) { double('cable_ready') }

  before do
    # Изолируем рендер зон (не зависят от worker-контекста)
    allow(broadcaster).to receive(:render_poi_list_item_component).and_return(%(<div data-poi-id="#{poi.id}">Test</div>))
    allow(broadcaster).to receive(:render_toast).and_return('')
    allow(broadcaster).to receive(:render_audit_component).and_return('')
    allow(broadcaster).to receive(:render_poi_header_component).and_return(%(<div>Header POI</div>))
    allow(broadcaster).to receive(:render_poi_show_component).and_return(%(<div>Show POI</div>))

    # Мок CableReady: [pois_map] / [admin_feed] / [admin_#id] возвращают один билдер
    allow(broadcaster).to receive(:cable_ready).and_return(cable_mock)
    allow(cable_mock).to receive(:[]).with('pois_map').and_return(cable_mock)
    allow(cable_mock).to receive(:[]).with('admin_feed').and_return(cable_mock)
    allow(cable_mock).to receive(:[]).with('user_#{poi.user_id}').and_return(cable_mock)
    allow(cable_mock).to receive(:morph)
    allow(cable_mock).to receive(:inner_html)
    allow(cable_mock).to receive(:insert_adjacent_html)
    allow(cable_mock).to receive(:dispatch_event)
    allow(cable_mock).to receive(:broadcast)
  end

  describe '#render_poi_list_item_component' do
    it 'рендерит HTML элемента списка с data-poi-id' do
      html = broadcaster.send(:render_poi_list_item_component)

      expect(html).to include("data-poi-id=\"#{poi.id}\"")
    end
  end

  describe '#broadcast' do
    it 'отправляет poi:reload-features в pois_map с detail (single, координаты POI)' do
      # Модель каналов: общий стрим карты "pois_map" (UserChannel подписан на него);
      # клиент перезагружает карту только если его видимые границы содержат точку.
      poi = broadcaster.send(:poi)
      expect(cable_mock).to receive(:dispatch_event).with(
        name: 'poi:reload-features',
        detail: { type: 'single', lat: poi.latitude, lng: poi.longitude }
      )

      broadcaster.broadcast
    end

    it 'бродкастит в pois_map и admin_feed' do
      expect(cable_mock).to receive(:broadcast).at_least(:once)

      broadcaster.broadcast
    end

    it 'обновляет шапку POI (#poi-detail) для admin_feed' do
      # Эталон: Reflex НЕ рендерит DOM после сохранения — зону рендерит Broadcaster
      # для ВСЕХ подписанных админов (общий стрим админки "admin_feed").
      expect(cable_mock).to receive(:inner_html).with(selector: '#poi-detail', html: '<div>Header POI</div>')

      broadcaster.broadcast
    end

    it 'обновляет содержимое таба Details ([data-poi-detail-body]) для admin_feed' do
      # Содержимое таба Details (ShowComponent) обновляется отдельным inner_html
      # на обёртку [data-poi-detail-body] (догма: селекторы-цели не вложены).
      expect(cable_mock).to receive(:inner_html).with(selector: '[data-poi-detail-body]', html: '<div>Show POI</div>')

      broadcaster.broadcast
    end

    it 'использует inner_html (НЕ morph) для обновления элемента списка' do
      # Спецификация: Broadcaster — только inner_html (README: morph падает
      # на undefined.dispatchEvent). Сейчас код использует morph — тест падает (A-баг).
      broadcaster.broadcast

      expect(cable_mock).not_to have_received(:morph)
    end
  end

  describe 'устойчивость зон (rescue)' do
    it 'не роняет broadcast при сбое рендера одной зоны' do
      allow(broadcaster).to receive(:render_poi_list_item_component).and_raise(StandardError, 'boom')
      allow(broadcaster).to receive(:render_audit_component).and_raise(StandardError, 'audit boom')

      expect { broadcaster.broadcast }.not_to raise_error
    end
  end
end
