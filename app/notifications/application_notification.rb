# frozen_string_literal: true

#
# Базовый класс для всех уведомлений в приложении
#
class ApplicationNotification < Noticed::Event
  #
  # Noticed передаёт запись уведомления аргументом в callback stream.
  #
  # @param notification [Noticed::Notification] уведомление доставки
  # @return [String]
  #
  def user_stream(notification)
    "user_#{notification.recipient_id}"
  end
end
