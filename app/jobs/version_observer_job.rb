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
    category_icon_uploaded category_icon_removed
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
    when "User"
      handle_user_update(version)
    when "Poi"
      handle_poi_update(version)
    when "PoiComment"
      handle_poi_comment_update(version)
    when "Setting"
      handle_setting_update(version)
    when "PoiCategory"
      handle_poi_category_update(version)
    when "PoiCategoryField"
      handle_poi_category_field_update(version)
    when "TokenTransaction"
      handle_token_transaction_update(version)
    when "Vote"
      handle_vote_update(version)
    end
  end

  private

  #
  # Маршрутизация обновлений модели User
  #
  def handle_user_update(version)
    user = version.item || version.reify
    return unless user || version.event == "destroy"

    # 1. Административные бродкасты (всегда при изменении пользователя).
    # Каждая зона в rescue: сбой одного бродкаста не должен ронять весь job
    # (уведомления/остальные зоны доставляются).
    case version.event
    when "create"
      safe_broadcast { Admin::DashboardBroadcaster.broadcast_recent_users_update }
      safe_broadcast { Admin::DashboardBroadcaster.broadcast_stats_update }
      safe_broadcast { Admin::UserBroadcaster.broadcast_user_created(user) }
    when "update"
      safe_broadcast { Admin::DashboardBroadcaster.broadcast_stats_update }
      safe_broadcast { Admin::UserBroadcaster.broadcast_user_update(user) }
    when "destroy"
      safe_broadcast { Admin::DashboardBroadcaster.broadcast_stats_update }
      safe_broadcast { Admin::UserBroadcaster.broadcast_user_destroy(user) } if user
    end

    # 2. Пользовательские бродкасты и уведомления (Live Update для клиента)
    return if version.event == "destroy" || user.nil?

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

    event_type = if version.event == "create"
                   "new_registration"
    elsif admin_initiated
                   "user_updated_by_admin"
    else
                   "user_updated_by_user"
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
    return unless poi || version.event == "destroy"

    # Административные бродкасты
    case version.event
    when "create", "update"
      Admin::DashboardBroadcaster.broadcast_stats_update
    end

    # Пользовательские бродкасты
    return if version.event == "destroy" || poi.nil?

    # Определяем, был ли это переход статуса (pending→approved и т.п.). При
    # смене статуса PoiBroadcaster дополнительно рисует feature-ноду точки в
    # #poi-map-features — иначе одобренная пользовательская точка не появлялась
    # бы на карте без перезагрузки (маркер рисуется только из этого контейнера).
    change_status = status_change?(version)

    PoiBroadcaster.call(poi: poi, change_status: change_status)
  end

  #
  # Определяет, был ли в версии PaperTrail переход status (колонка status
  # изменилась в object_changes).
  #
  # @param version [PaperTrail::Version] версия изменения
  # @return [Boolean] true, если статус POI изменился
  #
  def status_change?(version)
    # Переход статуса имеет смысл только для UPDATE-версии: при CREATE
    # object_changes — полный снапшот всех полей (в т.ч. status), поэтому проверка
    # по одному только наличию ключа дала бы ложное true для pending-создания.
    return false unless version.event == "update"

    changes = version.object_changes
    # PaperTrail::Serializers::JSON (см. config/initializers/paper_trail.rb) сериализует
    # object_changes в JSON-строку при сохранении в колонку типа text. Поэтому при
    # чтении версии ИЗ БД (SolidQueue worker) changes приходит как String, а не Hash.
    # Парсим строку в Hash, чтобы корректно определить переход статуса. Иначе
    # change_status всегда false → feature-нода не добавляется в #poi-map-features
    # и одобренная точка не появляется на карте у пользователя без перезагрузки.
    changes = JSON.parse(changes) if changes.is_a?(String)
    return false unless changes.is_a?(Hash)
    changes.key?("status") || changes.key?(:status)
  rescue JSON::ParserError
    false
  end

  #
  # Маршрутизация обновлений модели PoiComment (live-комментарии).
  # При create/update — точечный broadcast в общий стрим карты (все зрители
  # карточки POI видят новый комментарий/обновление без перезагрузки).
  # При create ответа на чужой комментарий — уведомление автору ветки (Noticed).
  #
  # @param version [PaperTrail::Version] версия изменения PoiComment
  #
  def handle_poi_comment_update(version)
    comment = version.item || version.reify
    return unless comment

    event = version.event.to_sym rescue :update

    # Точечный broadcast (inner_html/insert_adjacent_html) — live у публичных зрителей.
    safe_broadcast { PoiCommentBroadcaster.call(comment: comment, event: event) }

    # Админ-модерация: при изменении hidden_at (скрытие/показ) обновляем
    # админ-таблицу [data-admin-comments-list] через Admin::CommentAdminBroadcaster.
    # При destroy — удаляем ноду у публичных зрителей (см. broadcast_removal).
    if event == :update && hidden_at_changed?(version)
      safe_broadcast { Admin::CommentAdminBroadcaster.call(comment: comment, event: event) }
    end

    # Уведомление автору родительского комментария при создании ответа.
    return unless event == :create && comment.parent.present?

    notify_comment_parent(comment)
  end

  #
  # Определяет, был ли в версии PaperTrail изменён hidden_at (модерация скрытия).
  #
  # @param version [PaperTrail::Version] версия изменения
  # @return [Boolean] true, если поле hidden_at менялось
  #
  def hidden_at_changed?(version)
    return false unless version.object_changes.present?

    changes = version.object_changes
    changes = JSON.parse(changes) if changes.is_a?(String)
    return false unless changes.is_a?(Hash)

    changes.key?("hidden_at") || changes.key?(:hidden_at)
  rescue JSON::ParserError
    false
  end

  #
  # Отправляет уведомление (Noticed) автору родительского комментария о новом ответе.
  # Инлайн-нотификация через Noticed::Event + Setting-фильтры обрабатывает клиент.
  #
  # @param comment [PoiComment] созданный ответ
  #
  def notify_comment_parent(comment)
    parent_author = comment.parent.user
    return if parent_author.nil? || parent_author.id == comment.user_id

    PoiCommentNotification.with(
      poi: comment.poi,
      comment: comment,
      reply_author_id: comment.user_id
    ).deliver_later(parent_author)
  rescue StandardError => e
    Rails.logger.error("VersionObserverJob notify_comment_parent failed: #{e.class} #{e.message}")
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
  # Игнорирует служебные версии, где изменился только updated_at (пустой audit):
  # ActiveStorage detach/attach при смене картинки-маркера делают touch родителя,
  # создавая версию с одним полем updated_at. Бродкаст такой версии рендерит
  # show-компонент в #poi-category-detail и затирает открытую edit-форму.
  # Настоящий edit (name/position/icon/active и др.) меняет осмысленные поля
  # и продолжает штатно бродкастить.
  #
  def handle_poi_category_update(version)
    category = version.item || version.reify
    return unless category

    changes = version.object_changes.is_a?(Hash) ? version.object_changes : {}
    meaningful = changes.keys.reject { |k| k.to_s == "updated_at" }
    return if meaningful.empty?

    PoiCategoryBroadcaster.call(
      category: category,
      event_type: version.event,
      payload: { initiator_id: version.whodunnit }
    )
  end

  #
  # Маршрутизация обновлений модели PoiCategoryField
  #
  def handle_poi_category_field_update(version)
    field = version.item || version.reify
    return unless field

    # Обновляем родительскую категорию, т.к. поле отображается внутри неё
    PoiCategoryBroadcaster.call(
      category: field.poi_category,
      event_type: "field_#{version.event}",
      payload: { initiator_id: version.whodunnit }
    )
  end

  #
  # Маршрутизация записей журнала токенов (TokenTransaction).
  # Обновляет баланс/историю в профиле юзера и вкладку Wallet в админке.
  #
  def handle_token_transaction_update(version)
    transaction = version.item || version.reify
    return unless transaction

    TokenTransactionBroadcaster.call(token_transaction: transaction)
  end

  #
  # Маршрутизация голосов (Vote) — пороговая авто-модерация + live-счётчик.
  #
  # 1. ModerationService.evaluate! — выставляет бейджи («Одобрено/Отклонено
  #    сообществом») и пересчитывает репутацию автора. Для POI при переходе
  #    бейджа обновляет poi.moderation_source/community_rejected (создаёт версию
  #    PaperTrail → отдельный broadcast через PoiBroadcaster).
  # 2. VoteBroadcaster — live-обновление счётчика голосов на клиенте.
  #
  def handle_vote_update(version)
    vote = version.item || version.reify
    return unless vote

    votable = vote.votable
    return unless votable

    # Бейджи/репутация (создаёт версию POI при смене moderation_source →
    # отдельный handle_poi_update → PoiBroadcaster).
    ModerationService.evaluate!(votable)

    # Live-счётчик голосов.
    safe_broadcast { VoteBroadcaster.call(votable: votable) }
  end

  #
  # Выполняет бродкаст-зону с устойчивостью: сбой одной зоны не роняет job.
  #
  # @yield блок бродкаста
  #
  def safe_broadcast
    yield
  rescue StandardError => e
    Rails.logger.error("VersionObserverJob broadcast error: #{e.class} #{e.message}")
  end
end
