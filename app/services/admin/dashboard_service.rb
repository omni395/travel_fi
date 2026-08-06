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
  # Возвращает статистику по пользователям для дашборда.
  #
  # Ключи результата совпадают с типами карточек DashboardComponent
  # (total_users/active_users/suspended_users/new_users_today) — раньше было
  # расхождение (total/active/pending/restricted), из-за чего карточки дашборда
  # рендерились с пустыми label, а new_users_today показывал pending.
  #
  # @return [Hash] { total_users:, active_users:, suspended_users:, new_users_today: }
  #
  def self.stats
    {
      total_users: User.count,
      active_users: User.active.count,
      suspended_users: User.suspended.count + User.banned.count,
      # Зарегистрированные сегодня (не pending — см. ROADMAP 3.1)
      new_users_today: User.where(created_at: Time.current.all_day).count
    }
  end
end
