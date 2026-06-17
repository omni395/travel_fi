# frozen_string_literal: true

#
# PoiCategoryPolicy - политика доступа к категориям POI
#
# Доступ:
# - index: все аутентифицированные пользователи
# - show: все аутентифицированные пользователи
# - create: только admin
# - update: admin и moderator
# - destroy: только admin
#
class PoiCategoryPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    user.has_role?(:admin)
  end

  def update?
    user.has_role?(:admin) || user.has_role?(:moderator)
  end

  def destroy?
    user.has_role?(:admin)
  end

  #
  # Scope для категорий POI
  #
  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.has_role?(:admin) || user.has_role?(:moderator)
        scope.all
      else
        scope.active
      end
    end
  end
end
