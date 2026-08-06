# frozen_string_literal: true

#
# Admin::DashboardService — статистика для админ-дашборда.
#
# Ответственность: агрегация данных для карточек статистики
# (total/active/pending/restricted).
#
# Отдельный сервис от UserService (профиль юзера) — принцип «одна сущность —
# один сервис»: статистика дашборда — ответственность Admin-секции, а не
# профиля пользователя. Метод UserService.stats удалён (переезд сюда).
#
class Admin::DashboardService
  #
  # Возвращает статистику по пользователям для дашборда
  #
  # @return [Hash] { total:, active:, pending:, restricted: }
  #
  def self.stats
    {
      total: User.count,
      active: User.active.count,
      pending: User.pending.count,
      restricted: User.suspended.count + User.banned.count
    }
  end
end
