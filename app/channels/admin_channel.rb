# frozen_string_literal: true

#
# AdminChannel - канал для административной панели
#
# Все администраторы подписываются на этот канал для получения:
# - Обновлений статистики (количество пользователей, активность)
# - Списка последних зарегистрированных пользователей
# - Списка последних активностей (audit log)
# - Обновлений данных пользователя (при редактировании админом или пользователем)
#
# Подписка:
#   - Пользователи с ролью :admin или :moderator
#     (moderator имеет право редактировать категории через PoiCategoryPolicy#update?,
#      поэтому должен получать live-обновления админ-панели)
#   - Канал имеет фиксированное имя: "AdminChannel"
#
class AdminChannel < ApplicationCable::Channel
  #
  # Подписывает администратора/модератора на общий канал админки
  # Проверяет аутентификацию и наличие роли admin/moderator
  #
  def subscribed
    return reject unless current_user
    return reject unless current_user.has_role?(:admin) || current_user.has_role?(:moderator)

    stream_from "AdminChannel"

    Rails.logger.info("AdminChannel: Admin/Moderator #{current_user.id} subscribed to AdminChannel")
  rescue StandardError => e
    Rails.logger.error("AdminChannel subscription error: #{e.class} #{e.message}")
    reject
  end

  #
  # Отписывает администратора от канала
  #
  def unsubscribed
    Rails.logger.info("AdminChannel: Admin #{current_user.id} unsubscribed from AdminChannel")
  end
end
