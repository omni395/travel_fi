# frozen_string_literal: true

require 'rails_helper'

#
# ToastBroadcaster — unit-спек тост-уведомлений в UserChannel.
#
# Покрытие:
# 1. Формирует insert_adjacent_html в стрим user_<id>
# 2. Устойчивость: ошибка рендера не роняет (rescue)
#
RSpec.describe ToastBroadcaster, type: :service do
  let(:user) { create(:user) }

  describe '#broadcast' do
    it 'отправляет insert_adjacent_html в стрим user_<id> (контейнер #notifications)' do
      cable_mock = double('cable_ready')
      allow(cable_mock).to receive(:[]).and_return(cable_mock)
      allow(cable_mock).to receive(:insert_adjacent_html)
      allow(cable_mock).to receive(:broadcast)
      allow(ApplicationController).to receive(:render).and_return('<div data-toast>toast</div>')

      broadcaster = described_class.new(user_id: user.id, message: 'Hello', type: :success)
      allow(broadcaster).to receive(:cable_ready).and_return(cable_mock)

      expect(cable_mock).to receive(:insert_adjacent_html)
        .with(selector: '#notifications', position: 'beforeend', html: a_string_including('toast'))

      broadcaster.broadcast
    end

    it 'устойчив к ошибке рендера (rescue, не падает)' do
      allow(ApplicationController).to receive(:render).and_raise(StandardError, 'render boom')

      expect { described_class.call(user_id: user.id, message: 'X') }.not_to raise_error
    end
  end
end
