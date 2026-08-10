# frozen_string_literal: true

require 'rails_helper'

#
# TokenTransactionBroadcaster — unit-спек live-обновлений при создании
# записи журнала токенов (TokenTransaction).
#
# Покрытие:
# 1. inner_html в AdminChannel ([data-admin-user-wallet]) — вкладка Wallet в админке
# 2. inner_html в user_N ([data-user-rewards], [data-user-profile-id]) — профиль юзера
# 3. Устойчивость: ошибка рендера не роняет (rescue)
#
RSpec.describe TokenTransactionBroadcaster, type: :service do
  let(:user) { create(:user) }
  let(:tx) { create(:token_transaction, user: user) }

  describe '#broadcast' do
    it 'отправляет inner_html в AdminChannel и user_N' do
      cable_mock = double('cable_ready')
      allow(cable_mock).to receive(:[]).and_return(cable_mock)
      allow(cable_mock).to receive(:inner_html)
      allow(cable_mock).to receive(:broadcast)
      allow(ApplicationController).to receive(:render).and_return('<div>html</div>')

      broadcaster = described_class.new(token_transaction: tx)
      allow(broadcaster).to receive(:cable_ready).and_return(cable_mock)

      expect(cable_mock).to receive(:inner_html)
        .with(selector: '[data-admin-user-wallet]', html: a_string_including('html'))
      expect(cable_mock).to receive(:inner_html)
        .with(selector: '[data-user-rewards]', html: a_string_including('html'))
      expect(cable_mock).to receive(:inner_html)
        .with(selector: "[data-user-profile-id='#{user.id}']", html: a_string_including('html'))

      broadcaster.broadcast
    end

    it 'устойчив к ошибке рендера (rescue, не падает)' do
      allow(ApplicationController).to receive(:render).and_raise(StandardError, 'render boom')

      expect { described_class.call(token_transaction: tx) }.not_to raise_error
    end
  end
end
