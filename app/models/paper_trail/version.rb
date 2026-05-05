# frozen_string_literal: true

#
# PaperTrail::Version - модель для хранения версий изменений
#
# Эта модель расширяет стандартную модель PaperTrail::Version
# Добавляет after_commit callback для вызова соответствующих Broadcaster
#
# Поток: Model.save! → PaperTrail::Version.create! → after_commit → Broadcaster → WebSocket → браузер
#
class PaperTrail::Version < ActiveRecord::Base
  #
  # Вызывает соответствующий Broadcaster после создания/обновления версии
  # Определяет тип модели и событие, затем вызывает нужный Broadcaster
  #
  after_commit :broadcast_changes, on: [:create, :update, :destroy]

  private

  #
  # Определяет какой Broadcaster вызвать на основе типа модели и события
  #
  def broadcast_changes
    case item_type
    when 'User'
      case event
      when 'create', 'registration'
        Admin::DashboardBroadcaster.broadcast_recent_users_update
        Admin::DashboardBroadcaster.broadcast_stats_update
      when 'update'
        Admin::DashboardBroadcaster.broadcast_stats_update
        Admin::UserBroadcaster.broadcast_user_update(item)
      when 'destroy'
        Admin::DashboardBroadcaster.broadcast_stats_update
        Admin::UserBroadcaster.broadcast_user_destroy(item)
      end
    end
  rescue StandardError => e
    Rails.logger.error("PaperTrail::Version.broadcast_changes error: #{e.class} #{e.message}")
  end
end
