# frozen_string_literal: true

module ApplicationCable
  class Channel < ActionCable::Channel::Base
    # CableReady::Broadcaster больше не нужен, так как каналы наследуются напрямую

    def subscribe_to_channel
      puts "[CHANNEL_BASE] subscribe_to_channel() called on #{self.class.name}"
      Rails.logger.info("[CHANNEL_BASE] subscribe_to_channel() called on #{self.class.name}")
      super
    end

    def subscribed
      puts "[BASE_CHANNEL] subscribed() called on #{self.class.name}"
      Rails.logger.info("[BASE_CHANNEL] subscribed() called on #{self.class.name}")
    end

    def unsubscribed
      puts "[BASE_CHANNEL] unsubscribed() called on #{self.class.name}"
      Rails.logger.info("[BASE_CHANNEL] unsubscribed() called on #{self.class.name}")
    end

    def reject_subscription
      puts "[CHANNEL_BASE] reject_subscription() called on #{self.class.name}"
      Rails.logger.warn("[CHANNEL_BASE] reject_subscription() called on #{self.class.name} - THIS IS WHY SUBSCRIPTIONS ARE BEING REJECTED!")
      super
    end
  end
end
