# frozen_string_literal: true

#
# PaperTrail::Version - модель для хранения версий изменений
#
# ВНИМАНИЕ: Этот файл НЕ переопределяет класс PaperTrail::Version,
# а открывает существующий класс из гема для добавления дополнительной логики.
# Явно включаем PaperTrail::VersionConcern, чтобы гарантировать наличие
# всех методов (timestamp_sort_order, object_col_is_json? и др.) независимо
# от порядка загрузки файлов.
#
# Поток: Model.save! → PaperTrail::Version.create! → after_commit → Broadcaster → WebSocket → браузер
#
class PaperTrail::Version < ActiveRecord::Base
  # Явно подключаем модуль VersionConcern, который определяет методы:
  # - timestamp_sort_order — сортировка по created_at
  # - object_col_is_json? — проверка типа колонки object в БД
  include PaperTrail::VersionConcern

  # Связь с пользователем, совершившим изменение
  belongs_to :user, optional: true

  #
  # Вызывает VersionObserverJob после фиксации транзакции
  # Это гарантирует, что данные уже в БД перед бродкастом
  #
  after_commit :broadcast_changes, on: [ :create, :update, :destroy ]

  private

  #
  # Ставит задачу в очередь для обработки изменений
  #
  def broadcast_changes
    VersionObserverJob.perform_later(self.id)
  rescue StandardError => e
    Rails.logger.error("PaperTrail::Version.broadcast_changes error: #{e.class} #{e.message}")
  end
end
