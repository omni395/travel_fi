# frozen_string_literal: true

#
# ContractBalanceNotification — уведомление о низком балансе reward pool-контракта.
#
# Шлётся админам через Noticed (когда ContractBalanceCheckJob обнаруживает баланс
# ниже порога). Каналы фильтруются по личным настройкам админа (Setting).
#
# @param pool [String] адрес pool-контракта
# @param balance [Numeric] текущий баланс в TFT
# @param level [Symbol] :warning или :critical
# @param warning_balance [Integer] порог жёлтой плашки (TFT)
# @param critical_balance [Integer] порог красной плашки (TFT)
#
class ContractBalanceNotification < ApplicationNotification
  # Критичный системный алерт: in-app всегда доставляется админу (не зависит от
  # персональных Setting-фильтров — в схеме нет канала для системных алертов).
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket

  required_param :pool
  required_param :balance
  required_param :level
  required_param :warning_balance
  required_param :critical_balance

  #
  # Текст уведомления (in-app).
  #
  # @return [String]
  #
  def message
    I18n.t("notifications.contract_balance.#{params[:level]}",
           balance: params[:balance],
           warning_balance: params[:warning_balance],
           critical_balance: params[:critical_balance])
  end

  #
  # Сообщение для WebSocket (in-app).
  #
  # @return [Hash]
  #
  def to_websocket
    {
      title: title_text,
      message: message,
      pool: params[:pool],
      level: params[:level].to_s
    }
  end

  #
  # Персональный стрим получателя.
  #
  # @return [String]
  #
  def user_stream
    "user_#{recipient.id}"
  end

  private

  #
  # Заголовок уведомления.
  #
  # @return [String]
  #
  def title_text
    I18n.t("notifications.contract_balance.title_#{params[:level]}", default: I18n.t("notifications.contract_balance.title"))
  end
end
