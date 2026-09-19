# frozen_string_literal: true

#
# CommentModerationService — модерация комментариев POI (скрытие/показ).
#
# Отвечает за изменение видимости комментария модераторами/админами
# (поле hidden_at) и автоматическим порогом голосов сообщества:
#   - hide!(comment:)   — скрыть: hidden_at = Time.current;
#   - unhide!(comment:) — показать: hidden_at = nil.
#
# Используется ТОЛЬКО `update!` (НЕ `update_all`) — создаёт PaperTrail-версию
# → VersionObserverJob → broadcaster (публичный PoiCommentBroadcaster +
# админский Admin::CommentAdminBroadcaster). Методы идемпотентны: повторный
# вызов с уже достигнутым состоянием НЕ создаёт лишней версии.
#
class CommentModerationService
  #
  # Скрывает комментарий (модерация). Идемпотентно.
  #
  # @param comment [PoiComment] комментарий
  # @return [PoiComment]
  # @raise [ActiveRecord::RecordInvalid] при ошибке валидации
  #
  def self.hide!(comment:)
    comment.update!(hidden_at: Time.current) unless comment.hidden?
    comment
  end

  #
  # Показывает ранее скрытый комментарий. Идемпотентно.
  #
  # @param comment [PoiComment] комментарий
  # @return [PoiComment]
  # @raise [ActiveRecord::RecordInvalid] при ошибке валидации
  #
  def self.unhide!(comment:)
    comment.update!(hidden_at: nil) if comment.hidden?
    comment
  end
end
