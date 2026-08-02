# frozen_string_literal: true

#
# Poi::DetailComponent — просмотр детальной информации о POI
#
# Отображается в модалке при клике на маркер карты или элемент списка.
# Содержит табы:
#   - Info: название, категория, рейтинг, адрес, контакты, описание,
#           metadata, мини-карта, автор, дата
#   - Comments: список комментариев (threaded, 1 уровень) + форма добавления
#
# Параметры:
#   poi         [Poi] объект POI
#   current_user [User, nil] текущий пользователь (для кнопки Edit)
#   comments    [ActiveRecord::Relation<PoiComment>, nil] комментарии
#   user_lat    [Float, nil] широта пользователя (для proximity check)
#   user_lng    [Float, nil] долгота пользователя (для proximity check)
#
class Poi::DetailComponent < ApplicationComponent
  attr_reader :poi, :current_user, :comments, :user_lat, :user_lng

  TABS = %w[info comments].freeze

  def initialize(poi:, current_user: nil, comments: nil, user_lat: nil, user_lng: nil)
    @poi = poi
    @current_user = current_user
    @comments = comments || poi&.poi_comments&.includes(:user)&.recent || []
    @user_lat = user_lat
    @user_lng = user_lng
  end

  private

  #
  # Возвращает CSS класс для статуса
  #
  # @return [String]
  #
  def status_badge_class
    return "bg-gray-100 text-gray-800" unless poi

    case poi.status
    when "approved" then "bg-green-100 text-green-800"
    when "pending" then "bg-yellow-100 text-yellow-800"
    when "rejected" then "bg-red-100 text-red-800"
    when "archived" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  #
  # Возвращает массив метаданных с label из PoiCategoryField
  #
  # @return [Array<Hash>] массив { label:, value:, field_type: }
  #
  def metadata_fields
    return [] if poi.metadata.blank?

    field_map = poi.poi_category.poi_category_fields.active.index_by(&:field_key)
    poi.metadata.map do |key, value|
      field = field_map[key]
      {
        label: field&.localized_label || key.humanize,
        value: value,
        field_type: field&.field_type
      }
    end
  end

  #
  # Корневые комментарии (без parent_id)
  #
  # @return [Array<PoiComment>]
  #
  def root_comments
    comments.select { |c| c.parent_id.nil? }
  end

  #
  # Ответы на комментарий
  #
  # @param comment [PoiComment]
  # @return [Array<PoiComment>]
  #
  def replies_for(comment)
    comments.select { |c| c.parent_id == comment.id }
  end

  #
  # URL cover-фото POI (MEDIUM вариант) или fallback no-image.png.
  # Единый источник данных с тултипом карты — PhotoService.
  #
  # @return [String] URL изображения
  #
  def cover_photo_url
    PhotoService.cover_photo_url(poi, variant: PhotoService::MEDIUM) || PhotoService.fallback_url
  end

  #
  # Может ли текущий пользователь редактировать POI?
  #
  # @return [Boolean]
  #
  def can_edit?
    return false if current_user.blank? || poi.blank?

    current_user.has_role?(:admin) || current_user.has_role?(:moderator) || poi.user_id == current_user.id
  end

  #
  # Может ли пользователь комментировать? (в радиусе 50м)
  #
  # @return [Boolean]
  #
  def can_comment?
    return false if current_user.blank?

    PoiService.within_range?(
      user_lat: user_lat,
      user_lng: user_lng,
      poi_lat: poi.latitude,
      poi_lng: poi.longitude,
      user: current_user
    )
  end
end
