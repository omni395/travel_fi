# frozen_string_literal: true

#
# UnlockSuspendedUserJob — автоматическая разблокировка временно замороженного
# пользователя.
#
# При модерации комментария (admin удаляет / скрывает нарушение) автору может
# быть выставлен статус :suspended на фиксированный срок (по умолчанию 3 дня).
# Этот джоб планируется с задержкой (SolidQueue, set(wait:)) и по истечении
# срока возвращает пользователя в статус :active. Логика перевода статуса — в
# UserService.reactivate! (PaperTrail-версия → VersionObserverJob → broadcaster).
#
class UnlockSuspendedUserJob < ApplicationJob
  queue_as :default

  #
  # Возвращает пользователя из статуса :suspended в :active.
  #
  # @param user_id [Integer] идентификатор пользователя
  #
  def perform(user_id)
    user = User.find_by(id: user_id)
    return Rails.logger.warn("UnlockSuspendedUserJob: user ##{user_id} not found") unless user
    return Rails.logger.info("UnlockSuspendedUserJob: user ##{user_id} not suspended (status=#{user.status})") unless user.status == "suspended"

    UserService.reactivate!(user: user)
    Rails.logger.info("UnlockSuspendedUserJob: user ##{user_id} reactivated to :active")
  end
end
