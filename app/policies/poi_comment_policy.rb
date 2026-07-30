# frozen_string_literal: true

#
# PoiCommentPolicy — политика доступа к комментариям POI
#
# Доступ:
#   - index/show: все (включая гостей)
#   - create: аутентифицированные пользователи в радиусе 100м от POI
#   - update: автор комментария или admin (в радиусе 100м)
#   - destroy: автор комментария или admin
#
# Координаты пользователя для proximity check берутся из Current.user_lat/lng
# (устанавливаются в Reflex/Controller перед авторизацией)
#
class PoiCommentPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  #
  # Создание комментария: только аутентифицированные в радиусе 100м
  #
  def create?
    return false unless user.present?
    return true if user.has_role?(:admin) || user.has_role?(:moderator)

    within_proximity?
  end

  #
  # Редактирование: автор или admin (с проверкой расстояния 100м)
  #
  def update?
    return false unless user.present?
    return true if user.has_role?(:admin)

    record.user_id == user.id && within_proximity?
  end

  #
  # Удаление: автор или admin (без проверки расстояния)
  #
  def destroy?
    return false unless user.present?

    user.has_role?(:admin) || record.user_id == user.id
  end

  private

  #
  # Проверка расстояния до POI (антифрод)
  # Использует координаты из Current (устанавливаются в Reflex)
  #
  # @return [Boolean]
  #
  def within_proximity?
    poi = record.is_a?(PoiComment) ? record.poi : record
    return false unless poi
    return false if Current.user_lat.nil? || Current.user_lng.nil?

    PoiService.within_range?(
      user_lat: Current.user_lat,
      user_lng: Current.user_lng,
      poi_lat: poi.latitude,
      poi_lng: poi.longitude,
      user: user
    )
  end
end
