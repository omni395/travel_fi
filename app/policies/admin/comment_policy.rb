# frozen_string_literal: true

#
# Admin::CommentPolicy — политика модерации комментариев POI в админ-панели.
#
# Доступ (согласовано с Admin::BaseController#require_admin_or_moderator!,
# который уже пускает модераторов в админку):
#   - index / show — администраторы и модераторы (просмотр/модерация);
#   - hide / unhide — администраторы и модераторы (скрытие/показ).
#
class Admin::CommentPolicy < ApplicationPolicy
  #
  # Список комментариев: администраторы и модераторы.
  #
  # @return [Boolean]
  #
  def index?
    user.admin? || user.moderator?
  end

  #
  # Детальная страница комментария: администраторы и модераторы.
  #
  # @return [Boolean]
  #
  def show?
    user.admin? || user.moderator?
  end

  #
  # Скрытие комментария (модерация): администраторы и модераторы.
  #
  # @return [Boolean]
  #
  def hide?
    user.admin? || user.moderator?
  end

  #
  # Показ ранее скрытого комментария: администраторы и модераторы.
  #
  # @return [Boolean]
  #
  def unhide?
    user.admin? || user.moderator?
  end
end
