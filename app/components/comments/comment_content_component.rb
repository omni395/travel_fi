# frozen_string_literal: true

#
# Comments::CommentContentComponent — контент отдельной записи комментария.
#
# Выносится из Comments::CommentComponent для точечного live-обновления тела
# при правке (:update) БЕЗ пересоздания обёртки/детей. Причина: inner_html на
# [data-comment-id] самовкладывает полную обёртку (дубль ноды); inner_html на
# контейнере [data-comment-content] меняет только контент, не трогая
# [data-comment-children].
#
# Отображает:
#   - шапку (автор · дата · @предок при флоттенинге · «изменено»);
#   - тело (или заглушку «скрыт модерацией»);
#   - плашку «Одобрено сообществом»;
#   - панель действий (голоса Ui::VoteComponent, ответ, edited, staff-удаление
#     + пенал. с диалогами);
#   - формы ответа/редактирования (скрытые);
#   - кнопку «Показать N ответов» при свёрнутой ветке.
#
# Никакой бизнес-логики: только презентация. Интерактивность — через
# Comments::CommentComponent (родительская обёртка) → PoiReflex → CommentService.
#
# @param comment [PoiComment] комментарий
# @param current_user [User, nil] текущий пользователь (персональные кнопки)
# @param moderation [Boolean] режим админ-модерации
# @param sort [Symbol] сортировка (пробрасывается в формы)
# @param user_lat [Float, nil] широта юзера (для формы ответа)
# @param user_lng [Float, nil] долгота юзера
#
class Comments::CommentContentComponent < ApplicationComponent
  attr_reader :comment, :current_user, :moderation, :sort, :user_lat, :user_lng

  def initialize(comment:, current_user: nil, moderation: false, sort: :new, user_lat: nil, user_lng: nil)
    @comment = comment
    @current_user = current_user
    @moderation = moderation
    @sort = sort
    @user_lat = user_lat
    @user_lng = user_lng
  end

  private

  #
  # Пометка @предка для флоттенед ответа (ответ на ответ → ответ на корень).
  # Если у комментария задан parent, отличный от корня — это флоттенинг.
  #
  # @return [User, nil]
  #
  def reply_target_name
    return nil if comment.parent.nil?
    return nil if comment.root_id == comment.parent_id

    comment.parent.user.name
  end

  #
  # Был ли комментарий отредактирован (метка «(изменено)» в шапке).
  # Опирается на наличие UPDATE-версии PaperTrail, менявшей body.
  #
  # @return [Boolean]
  #
  def edited?
    edited_version.present?
  end

  #
  # Имя редактора последней правки — из whodunnit последней UPDATE-версии body.
  # Позволяет показать «(изменено {кем} {время})», а не анонимную метку.
  #
  # @return [String, nil]
  #
  def edited_by_name
    edited_version&.whodunnit.present? ? User.find_by(id: edited_version.whodunnit)&.name : nil
  end

  #
  # Момент последней правки (created_at последней UPDATE-версии body).
  #
  # @return [ActiveSupport::TimeWithZone, nil]
  #
  def edited_at
    edited_version&.created_at
  end

  #
  # Комментарий-версия последней правки body (для метки «изменено кем/когда»).
  # Поиск в обратном порядке: последняя UPDATE-версия, менявшая body, первая.
  #
  # @return [PaperTrail::Version, nil]
  #
  def edited_version
    @edited_version ||= comment.versions.reverse.find do |v|
      v.event == "update" && v.object_changes&.key?("body")
    end
  end

  #
  # Одобрен ли комментарий сообществом (ups >= порога при стабильном перевесе).
  #
  # @return [Boolean]
  #
  def community_approved?
    ModerationService.badge_state(comment) == :approved
  end

  #
  # Скрыт ли комментарий модерацией (порог дизлайков).
  #
  # @return [Boolean]
  #
  def hidden?
    comment.hidden?
  end

  #
  # Ответил ли текущий пользователь уже на этот комментарий (анти-флуд UX).
  #
  # @return [Boolean]
  #
  def i_replied?
    return false if current_user.nil?
    return false if comment.parent.present?

    current_user.poi_comments.where(parent_id: comment.id).exists?
  end

  #
  # Свёрнута ли ветка ответов (кнопка «Показать N» вместо детей).
  # Логика дублирует COLLAPSE_THRESHOLD из CommentComponent.
  #
  # @return [Boolean]
  #
  def collapsed?
    comment.children_count.to_i >= 4
  end

  #
  # Число ответов (для кнопки «Показать N ответов»).
  #
  # @return [Integer]
  #
  def children_count
    comment.children_count.to_i
  end
end
