# frozen_string_literal: true

#
# AdminChannel - канал административной панели
#
# Модель «2 канала с адресными стримами» (см. README «Канальная модель»):
# один класс канала подписывает клиента на НЕСКОЛЬКО стримов, а серверные
# бродкастеры адресуют сообщение по имени стрима.
#
# Подписки (стримы), которые получает администратор/модератор через этот канал:
#   - "admin_#{id}" — ПЕРСОНАЛЬНЫЙ поток админа (результат его собственных
#                     действий: success/error события рефлексов). Разрешает
#                     вопрос «как вычленить отдельного админа из канала».
#   - "admin_feed"  — ОБЩИЙ поток live-изменений админки (POI, users, categories,
#                     настройки, статистика дашборда) для ВСЕХ админов.
#
# Клиент подписан на AdminChannel только на админском лэйауте
# (app/javascript/admin.js → channels/admin_channel.js), поэтому на
# пользовательской части админ не получает админ-поток.
#
class AdminChannel < ApplicationCable::Channel
  #
  # Подписывает администратора/модератора на личный и общий поток админки
  # Проверяет аутентификацию и наличие роли admin/moderator
  #
  def subscribed
    return reject unless current_user
    return reject unless current_user.has_role?(:admin) || current_user.has_role?(:moderator)

    stream_from "admin_#{current_user.id}"
    stream_from "admin_feed"

    Rails.logger.info("AdminChannel: Admin/Moderator #{current_user.id} subscribed to admin_#{current_user.id} + admin_feed")
  rescue StandardError => e
    Rails.logger.error("AdminChannel subscription error: #{e.class} #{e.message}")
    reject
  end

  #
  # Отписывает администратора от потоков
  #
  def unsubscribed
    Rails.logger.info("AdminChannel: Admin #{current_user&.id} unsubscribed")
  end
end
