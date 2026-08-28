# frozen_string_literal: true

#
# PhotoPolicy - политика доступа к фотографиям галереи POI
#
# Доступ:
# - create: аутентифицированный пользователь (антифрод 100м проверяется отдельно в Service)
# - destroy: автор фото, admin, moderator
#
class PhotoPolicy < ApplicationPolicy
  def create?
    user.present?
  end

  def destroy?
    user.has_role?(:admin) || user.has_role?(:moderator) || record.user_id == user.id
  end
end
