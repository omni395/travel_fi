# frozen_string_literal: true

#
# VersionObserverJob - асинхронный наблюдатель за изменениями в БД
#
# Ответственность:
# 1. Реагирует на создание новой записи в таблице versions (PaperTrail)
# 2. Анализирует object_changes
# 3. Определяет список получателей
# 4. Вызывает соответствующие Broadcasters
#
class VersionObserverJob < ApplicationJob
  queue_as :default

  # Список audit-событий, которые НЕ требуют обновления UI
  AUDIT_ONLY_EVENTS = %w[
    login logout email_verified email_changed
    wallet_added avatar_uploaded name_changed
    registration user_created_by_admin user_deleted_by_admin
  ].freeze

  #
  # Обработка версии
  #
  # @param version_id [Integer] ID записи из таблицы PaperTrail::Version
  #
  def perform(version_id)
    version = PaperTrail::Version.find_by(id: version_id)
    return unless version

    # Игнорируем audit-only события (логины, логауты и т.д.)
    # Эти версии создаются напрямую через UserAuditLogger, без сохранения модели
    return if AUDIT_ONLY_EVENTS.include?(version.event)

    case version.item_type
    when 'User'
      handle_user_update(version)
    when 'Poi'
      handle_poi_update(version)
    when 'Setting'
      handle_setting_update(version)
    when 'PoiCategory'
      handle_poi_category_update(version)
    when 'PoiCategoryField'
      handle_poi_category_field_update(version)
    end
  end

  private

  #
  # Маршрутизация обновлений модели User
  #
  def handle_user_update(version)
    user = version.item || version.reify
    return unless user || version.event == 'destroy'

    # 1. Административные бродкасты (всегда при изменении пользователя)
    case version.event
    when 'create'
      Admin::DashboardBroadcaster.broadcast_recent_users_update
      Admin::DashboardBroadcaster.broadcast_stats_update
      Admin::UserBroadcaster.broadcast_user_created(user)
    when 'update'
      Admin::DashboardBroadcaster.broadcast_stats_update
      Admin::UserBroadcaster.broadcast_user_update(user)
    when 'destroy'
      Admin::DashboardBroadcaster.broadcast_stats_update
      Admin::UserBroadcaster.broadcast_user_destroy(user) if user
    end

    # 2. Пользовательские бродкасты и уведомления (Live Update для клиента)
    return if version.event == 'destroy' || user.nil?

    # Определяем, инициировано ли изменение администратором.
    # Контекст берём из version.whodunnit: Current.admin_context thread-local
    # не переживает переход в SolidQueue worker и потому здесь недоступен.
    admin_initiated = version.whodunnit.present? &&
                      User.find_by(id: version.whodunnit)&.has_role?(:admin)

    # Живое обновление личного профиля (user_N канал) — только для изменений,
    # инициированных самим пользователем. Админ-правка чужого профиля обновляет
    # строку в админке (AdminChannel, см. Admin::UserBroadcaster выше), а не личный профиль.
    UserBroadcaster.call(user: user) unless admin_initiated

    # 3. Уведомления (Noticed)
    recipients = User.with_role(:admin).to_a
    recipients << user unless recipients.include?(user)

    event_type = if version.event == 'create'
                   'new_registration'
                 elsif admin_initiated
                   'user_updated_by_admin'
                 else
                   'user_updated_by_user'
                 end

    recipients.each do |recipient|
      UserProfileNotification.with(item: user, event_type: event_type).deliver_later(recipient)
    end
  end

  #
  # Маршрутизация обновлений модели POI
  #
  def handle_poi_update(version)
    poi = version.item || version.reify
    return unless poi || version.event == 'destroy'

    # Административные бродкасты
    case version.event
    when 'create', 'update'
      Admin::DashboardBroadcaster.broadcast_stats_update
    end

    # Пользовательские бродкасты
    return if version.event == 'destroy' || poi.nil?

    PoiBroadcaster.call(poi: poi)
  end

  #
  # Маршрутизация обновлений модели Setting
  #
  def handle_setting_update(version)
    setting = version.item || version.reify
    return unless setting

    SettingBroadcaster.call(setting: setting)
  end

  #
  # Маршрутизация обновлений модели PoiCategory
  #
  def handle_poi_category_update(version)
    category = version.item || version.reify
    return unless category

    PoiCategoryBroadcaster.call(category: category)
  end

  #
  # Маршрутизация обновлений модели PoiCategoryField
  #
  def handle_poi_category_field_update(version)
    field = version.item || version.reify
    return unless field

    # Обновляем родительскую категорию, т.к. поле отображается внутри неё
    PoiCategoryBroadcaster.call(category: field.poi_category)
  end
end
