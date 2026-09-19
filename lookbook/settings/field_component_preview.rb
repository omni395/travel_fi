# frozen_string_literal: true

class Settings::FieldComponentPreview < Lookbook::Preview
  # @label Default Field (My POI Status)
  def default
    render Settings::FieldComponent.new(setting: mock_setting('my_poi_status'), event_type: 'my_poi_status')
  end

  # @label Reward Locked
  def reward_locked
    render Settings::FieldComponent.new(setting: mock_setting('reward_locked'), event_type: 'reward_locked')
  end

  # @label Recommendations
  def recommendations
    render Settings::FieldComponent.new(setting: mock_setting('recommendations'), event_type: 'recommendations')
  end

  private

  #
  # Мок Setting с требуемыми методами включения/выключения каналов.
  #
  # @return [Object]
  #
  def mock_setting(event_type = 'my_poi_status', channels = {})
    setting = Object.new
    %i[notifications email push].each do |channel|
      field = "#{event_type}_#{channel}_enabled"
      value = channels[field].nil? ? false : channels[field]
      setting.define_singleton_method(field) { value }
    end
    setting
  end
end
