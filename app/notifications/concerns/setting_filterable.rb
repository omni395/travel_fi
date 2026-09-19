# frozen_string_literal: true

#
# SettingFilterable — общий concern для фильтрации каналов уведомления
# по личным настройкам получателя (Setting).
#
# Логика (AND):
#   канал включён = мастер-флаг "#{type}_enabled" И колонка события
#                   "#{event_setting_key}_#{type}_enabled"
#
# - Мастер-флаг (#{type}_enabled) — глобальный выключатель канала; если колонки
#   нет — считается true (игнорируется).
# - Колонка события: ключ берётся из `event_setting_key` (instance-метод).
#   По умолчанию — self.class.setting_event_key (class_attribute). Подкласс
#   может переопределить event_setting_key для динамического ключа из params.
#   Если колонки события нет — событие считается включённым (fallback true).
#
# Использование:
#   include SettingFilterable
#   self.setting_event_key = "my_poi_comment"
#
module SettingFilterable
  extend ActiveSupport::Concern

  included do
    class_attribute :setting_event_key, instance_accessor: false, default: nil
  end

  #
  # Включён ли in-app (action_cable) канал для получателя.
  #
  # @param recipient [User, nil] получатель
  # @return [Boolean]
  #
  def notifications_enabled?(recipient = nil)
    setting_channel_enabled?(:notifications, recipient)
  end

  #
  # Включён ли email-канал для получателя.
  #
  # @param recipient [User, nil] получатель
  # @return [Boolean]
  #
  def email_enabled?(recipient = nil)
    setting_channel_enabled?(:email, recipient)
  end

  #
  # Включён ли push-канал для получателя.
  #
  # @param recipient [User, nil] получатель
  # @return [Boolean]
  #
  def push_enabled?(recipient = nil)
    setting_channel_enabled?(:push, recipient)
  end

  private

  #
  # Ключ события для фильтра (по умолчанию — class_attribute setting_event_key).
  # Может быть переопределён подклассом (например, из event_type в params).
  #
  # @return [String, nil]
  #
  def event_setting_key
    self.class.setting_event_key
  end

  #
  # Проверяет канал канала для получателя (мастер-флаг AND событие-флаг).
  #
  # @param type [Symbol] :notifications / :email / :push
  # @param recipient [User, nil] получатель
  # @return [Boolean]
  #
  def setting_channel_enabled?(type, recipient)
    recipient ||= self.recipient
    return false unless recipient&.setting

    setting = recipient.setting

    # Мастер-флаг канала (глобальный выключатель). Если колонки нет — считаем true.
    master = setting.respond_to?("#{type}_enabled") ? setting.public_send("#{type}_enabled") : true
    return false unless master

    # Флаг конкретного события. Ключа нет или колонки нет — fallback true.
    key = event_setting_key.to_s
    return true if key.blank?

    event_method = "#{key}_#{type}_enabled?"
    return true unless setting.respond_to?(event_method)

    setting.public_send(event_method)
  rescue StandardError => e
    Rails.logger.error("#{self.class.name} setting check error: #{e.message}")
    true
  end
end
