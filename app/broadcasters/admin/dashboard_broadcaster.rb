# frozen_string_literal: true

class Admin::DashboardBroadcaster
  include CableReady::Broadcaster

  def self.broadcast_stats_update
    new.send_stats_update
  end

  def self.broadcast_recent_users_update
    new.send_recent_users_update
  end

  def self.broadcast_recent_activities_update
    new.send_recent_activities_update
  end

  def self.broadcast_full_update
    new.send_full_update
  end

  def send_stats_update
    stats = Admin::DashboardService.stats

    # Обновляем карточки статистики. inner_html (НЕ morph) — эталон Broadcaster:
    # morph падает на undefined.dispatchEvent, а также логирует ложные skip
    # на страницах, где карточки дашборда отсутствуют.
    # Общий поток админки "admin_feed".
    cable_ready["admin_feed"].inner_html(
      selector: "[data-admin-stats-total-users]",
      html: stats[:total_users].to_s
    )

    cable_ready["admin_feed"].inner_html(
      selector: "[data-admin-stats-active-users]",
      html: stats[:active_users].to_s
    )

    cable_ready["admin_feed"].inner_html(
      selector: "[data-admin-stats-suspended-users]",
      html: stats[:suspended_users].to_s
    )

    cable_ready["admin_feed"].inner_html(
      selector: "[data-admin-stats-new-users-today]",
      html: stats[:new_users_today].to_s
    )

    cable_ready["admin_feed"].broadcast
  end

  def send_recent_users_update
    recent_users = User.order(created_at: :desc).limit(10)

    cable_ready["admin_feed"].inner_html(
      selector: "[data-admin-recent-users]",
      html: render_recent_users_table(recent_users)
    )

    cable_ready["admin_feed"].broadcast
  end

  def send_recent_activities_update
    recent_activities = PaperTrail::Version.order(created_at: :desc).limit(20)

    cable_ready["admin_feed"].inner_html(
      selector: "[data-admin-recent-activities]",
      html: render_recent_activities_list(recent_activities)
    )

    cable_ready["admin_feed"].broadcast
  end

  def send_full_update
    stats = Admin::DashboardService.stats
    recent_users = User.order(created_at: :desc).limit(10)
    recent_activities = PaperTrail::Version.order(created_at: :desc).limit(20)

    component = Admin::DashboardComponent.new(
      stats: stats,
      recent_users: recent_users,
      recent_activities: recent_activities
    )

    cable_ready["admin_feed"].inner_html(
      selector: "[data-admin--dashboard]",
      html: ApplicationController.render(component, layout: false)
    )

    cable_ready["admin_feed"].broadcast
  end

  private

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
