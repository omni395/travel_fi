# frozen_string_literal: true

require 'rails_helper'

#
# SettingsReflex — unit-спек инверсии переключателя настроек.
#
# Проверяет, что поле читается из args-параметров, значение инвертируется
# из актуального состояния БД (SettingService.toggle) и отправляется тост.
#
RSpec.describe SettingsReflex, type: :reflex do
  let(:user) { create(:user, :with_setting) }
  let(:cable_ready_mock) { build_cable_ready_mock }
  let(:sr_version) { Gem.loaded_specs['stimulus_reflex'].version.to_s }
  let(:session_mock) { {} }

  def build_cable_ready_mock
    cr = double('cable_ready')
    allow(cr).to receive(:set_attribute)
    allow(cr).to receive(:broadcast)
    cr
  end

  #
  # Создаёт экземпляр SettingsReflex с моками connection/reflex_data/session/cable_ready.
  #
  # @param params [Hash] args-параметры рефлекса
  # @return [SettingsReflex]
  #
  def build_reflex(params = {})
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
    allow(channel).to receive(:stream_name).and_return("user_#{user.id}")

    element = instance_double('Element')
    allow(element).to receive(:dataset).and_return({})
    allow(element).to receive(:value).and_return('')

    reflex_data = instance_double('StimulusReflex::ReflexData')
    allow(reflex_data).to receive(:url).and_return('http://test.host/settings')
    allow(reflex_data).to receive(:element).and_return(element)
    allow(reflex_data).to receive(:selectors).and_return([])
    allow(reflex_data).to receive(:method_name).and_return(:update)
    allow(reflex_data).to receive(:id).and_return('reflex-1')
    allow(reflex_data).to receive(:params).and_return(ActionController::Parameters.new(params))
    allow(reflex_data).to receive(:suppress_logging).and_return(true)
    allow(reflex_data).to receive(:version).and_return(sr_version)
    allow(reflex_data).to receive(:npm_version).and_return(sr_version)

    reflex = described_class.new(channel, reflex_data: reflex_data)
    allow(reflex).to receive(:session).and_return(session_mock)
    allow(reflex).to receive(:cable_ready).and_return(cable_ready_mock)
    # Гарантируем args-параметры на самом рефлексе (защита от того, как
    # StimulusReflex экспонирует params в этой версии gem).
    allow(reflex).to receive(:params).and_return(ActionController::Parameters.new(params))
    # Reflex не наследует Rails-хелперы t в unit-тесте — стабим через singleton.
    reflex.define_singleton_method(:t) { |*| 'settings message' }
    allow(reflex).to receive(:authorize).and_return(true)
    reflex
  end

  describe '#update' do
    it 'вызывает SettingService.toggle с полем из args и шлёт тост' do
      user.setting.update!(my_poi_status_email_enabled: false)
      reflex = build_reflex(field: 'my_poi_status_email_enabled')
      allow(ToastBroadcaster).to receive(:call)
      allow(SettingService).to receive(:toggle).and_return(true)

      reflex.update

      expect(SettingService).to have_received(:toggle).with(user.setting, 'my_poi_status_email_enabled')
      expect(ToastBroadcaster).to have_received(:call).with(hash_including(type: :success))
    end

    it 'игнорирует незапрещённое поле без ошибки' do
      reflex = build_reflex(field: 'user_id')
      allow(ToastBroadcaster).to receive(:call)

      expect { reflex.update }.not_to raise_error
      expect(ToastBroadcaster).to have_received(:call).with(hash_including(type: :error))
    end
  end
end
