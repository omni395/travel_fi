# frozen_string_literal: true

#
# Admin::DashboardBroadcaster - бродкастер для отправки обновлений статистики
#
# Ответственность:
# 1. Отправляет обновление статистики дашборда
# 2. Отправляет обновление списка последних пользователей
# 3. Отправляет обновление списка последних активностей
#
# Использование:
#   Admin::DashboardBroadcaster.broadcast_stats_update
#   Admin::DashboardBroadcaster.broadcast_recent_users_update
#   Admin::DashboardBroadcaster.broadcast_recent_activities_update
#
class Admin::DashboardBroadcaster
  #
  # Отправляет обновление статистики дашборда
  # Вызывается при изменении данных пользователей
  #
  def self.broadcast_stats_update
    new.send_stats_update
  end

  #
  # Отправляет обновление списка последних пользователей
  # Вызывается при создании нового пользователя
  #
  def self.broadcast_recent_users_update
    new.send_recent_users_update
  end

  #
  # Отправляет обновление списка последних активностей
  # Вызывается при изменении любого объекта с Paper Trail
  #
  def self.broadcast_recent_activities_update
    new.send_recent_activities_update
  end

  #
  # Отправляет полное обновление дашборда
  # Обновляет все секции дашборда
  #
  def self.broadcast_full_update
    new.send_full_update
  end

  #
  # Отправляет обновление статистики дашборда
  # Морфит компоненты статистики
  #
  def send_stats_update
    stats = AdminStatsService.call

    # Обновляем карточки статистики
    cable_ready.morph(
      selector: "[data-admin-stats-total-users]",
      html: stats[:total_users].to_s
    )

    cable_ready.morph(
      selector: "[data-admin-stats-active-users]",
      html: stats[:active_users].to_s
    )

    cable_ready.morph(
      selector: "[data-admin-stats-suspended-users]",
      html: stats[:suspended_users].to_s
    )

    cable_ready.morph(
      selector: "[data-admin-stats-new-users-today]",
      html: stats[:new_users_today].to_s
    )

    # Отправляем в admin_channel вместо общего broadcast
    cable_ready.broadcast_to("AdminChannel")
  end

  #
  # Отправляет обновление списка последних пользователей
  # Морфит таблицу последних пользователей
  #
  def send_recent_users_update
    recent_users = User.order(created_at: :desc).limit(10)

    cable_ready.morph(
      selector: "[data-admin-recent-users]",
      html: render_recent_users_table(recent_users)
    )

    # Отправляем в admin_channel вместо общего broadcast
    cable_ready.broadcast_to("AdminChannel")
  end

  #
  # Отправляет обновление списка последних активностей
  # Морфит список последних активностей
  #
  def send_recent_activities_update
    recent_activities = PaperTrail::Version.order(created_at: :desc).limit(20)

    cable_ready.morph(
      selector: "[data-admin-recent-activities]",
      html: render_recent_activities_list(recent_activities)
    )

    # Отправляем в admin_channel вместо общего broadcast
    cable_ready.broadcast_to("AdminChannel")
  end

  #
  # Отправляет полное обновление дашборда
  # Морфит весь компонент дашборда
  #
  def send_full_update
    stats = AdminStatsService.call
    recent_users = User.order(created_at: :desc).limit(10)
    recent_activities = PaperTrail::Version.order(created_at: :desc).limit(20)

    component = Admin::DashboardComponent.new(
      stats: stats,
      recent_users: recent_users,
      recent_activities: recent_activities
    )

    cable_ready.morph(
      selector: "[data-admin--dashboard]",
      html: ApplicationController.helpers.render_component(component)
    )

    # Отправляем в admin_channel вместо общего broadcast
    cable_ready.broadcast_to("AdminChannel")
  end

  private

  #
  # Рендерит таблицу последних пользователей
  #
  # @param recent_users [Array<User>] последние пользователи
  # @return [String] HTML таблицы
  #
  def render_recent_users_table(recent_users)
    ApplicationController.helpers.content_tag(:table, class: 'min-w-full divide-y divide-gray-200') do
      ApplicationController.helpers.content_tag(:thead, class: 'bg-gray-50') do
        ApplicationController.helpers.content_tag(:tr) do
          [
            ApplicationController.helpers.content_tag(:th, I18n.t('admin.users.name'), class: 'px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider'),
            ApplicationController.helpers.content_tag(:th, I18n.t('admin.users.email'), class: 'px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider'),
            ApplicationController.helpers.content_tag(:th, I18n.t('admin.users.status'), class: 'px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider'),
            ApplicationController.helpers.content_tag(:th, I18n.t('admin.users.created_at'), class: 'px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider')
          ].join.html_safe
        end
      end +
      ApplicationController.helpers.content_tag(:tbody, class: 'bg-white divide-y divide-gray-200') do
        recent_users.map do |user|
          ApplicationController.helpers.content_tag(:tr) do
            [
              ApplicationController.helpers.content_tag(:td, user.name, class: 'px-6 py-4 whitespace-nowrap'),
              ApplicationController.helpers.content_tag(:td, user.email, class: 'px-6 py-4 whitespace-nowrap text-sm text-gray-500'),
              ApplicationController.helpers.content_tag(:td, class: 'px-6 py-4 whitespace-nowrap') do
                status_class = case user.status
                when 'active'
                  'bg-green-100 text-green-800'
                when 'pending_verification'
                  'bg-yellow-100 text-yellow-800'
                when 'suspended'
                  'bg-orange-100 text-orange-800'
                when 'banned'
                  'bg-red-100 text-red-800'
                when 'deleted'
                  'bg-gray-100 text-gray-800'
                else
                  'bg-gray-100 text-gray-800'
                end

                ApplicationController.helpers.tag.span(
                  I18n.t("activerecord.attributes.user.statuses.#{user.status}"),
                  class: "px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{status_class}"
                )
              end,
              ApplicationController.helpers.content_tag(:td, I18n.l(user.created_at, format: :short), class: 'px-6 py-4 whitespace-nowrap text-sm text-gray-500')
            ].join.html_safe
          end
        end.join.html_safe
      end
    end
  end

  #
  # Рендерит список последних активностей
  #
  # @param recent_activities [Array<PaperTrail::Version>] последние активности
  # @return [String] HTML списка
  #
  def render_recent_activities_list(recent_activities)
    ApplicationController.helpers.content_tag(:div, class: 'space-y-4') do
      recent_activities.map do |version|
        ApplicationController.helpers.content_tag(:div, class: 'flex items-start') do
          ApplicationController.helpers.content_tag(:div, class: 'flex-shrink-0') do
            ApplicationController.helpers.content_tag(:i, '', class: 'mdi mdi-history text-teal-500')
          end +
          ApplicationController.helpers.content_tag(:div, class: 'ml-3') do
            [
              ApplicationController.helpers.content_tag(:p, "#{version.item_type}##{version.item_id}", class: 'text-sm text-gray-700'),
              ApplicationController.helpers.content_tag(:p, I18n.t("user_audit.actions.#{version.event}"), class: 'text-xs text-gray-500'),
              ApplicationController.helpers.content_tag(:p, I18n.l(version.created_at, format: :short), class: 'text-xs text-gray-400')
            ].join.html_safe
          end
        end
      end.join.html_safe
    end
  end
end
