# frozen_string_literal: true

#
# PoiPolicy - политика доступа к POI
#
# Доступ:
# - index: все аутентифицированные пользователи
# - show: все аутентифицированные пользователи
# - create: все аутентифицированные пользователи
# - update: владелец, admin, moderator
# - destroy: admin
# - moderate: admin и moderator
#
class PoiPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present?
  end

  def update?
    user.has_role?(:admin) || user.has_role?(:moderator) || record.user_id == user.id
  end

  def destroy?
    user.has_role?(:admin)
  end

  def moderate?
    user.has_role?(:admin) || user.has_role?(:moderator)
  end

  #
  # Scope для POI
  #
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Гость (публичная карта) — только approved POI
      return scope.approved unless user

      if user.has_role?(:admin) || user.has_role?(:moderator)
        scope.all
      else
        scope.approved.or(scope.where(user_id: user.id))
      end
    end
  end
end
