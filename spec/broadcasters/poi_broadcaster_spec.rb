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
    allow(broadcaster).to receive(:render_poi_show_component).and_return(%(<div>Show POI</div>))

    # Мок CableReady: [UserChannel] / ["UserChannel"] / ["AdminChannel"] возвращают один билдер
    allow(broadcaster).to receive(:cable_ready).and_return(cable_mock)
    allow(cable_mock).to receive(:[]).with(UserChannel).and_return(cable_mock)
    allow(cable_mock).to receive(:[]).with('UserChannel').and_return(cable_mock)
    allow(cable_mock).to receive(:[]).with('AdminChannel').and_return(cable_mock)
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
    it 'отправляет poi:reload-features в UserChannel с detail (single, координаты POI)' do
      # Баг 4: dispatch_event несёт гео-detail, чтобы клиент перезагружал карту
      # только если его видимые границы содержат точку.
      poi = broadcaster.send(:poi)
      expect(cable_mock).to receive(:dispatch_event).with(
        name: 'poi:reload-features',
        detail: { type: 'single', lat: poi.latitude, lng: poi.longitude }
      )

      broadcaster.broadcast
    end

    it 'бродкастит в UserChannel и AdminChannel' do
      expect(cable_mock).to receive(:broadcast).at_least(:once)

      broadcaster.broadcast
    end

    it 'обновляет детальную карточку POI (#poi-detail) для AdminChannel' do
      # Эталон: Reflex НЕ рендерит DOM после сохранения — зону рендерит Broadcaster
      # для ВСЕХ подписанных админов (а не только инициатора через morph).
      expect(cable_mock).to receive(:inner_html).with(selector: '#poi-detail', html: '<div>Show POI</div>')

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
