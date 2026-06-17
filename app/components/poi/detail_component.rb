# frozen_string_literal: true

#
# Poi::DetailComponent - модалка детального просмотра/создания/редактирования POI
#
# Содержит:
# - Оверлей с центрированной карточкой
# - Табы: информация, комментарии, фото (просмотр)
# - Форму создания/редактирования POI (с мини-картой и кругом 50м)
# - Показ деталей точки через StimulusReflex
#
# Режимы:
# - create: новая точка на user_location
# - edit: редактирование существующей точки (только автор или админ)
# - view: просмотр деталей (табы)
#
class Poi::DetailComponent < ApplicationComponent
  attr_reader :poi, :current_user, :categories, :user_lat, :user_lng

  TABS = %w[info comments photos].freeze

  #
  # @param poi [Poi, nil] объект POI для редактирования/просмотра
  # @param current_user [User, nil] текущий пользователь
  # @param categories [ActiveRecord::Relation, nil] список активных категорий
  # @param user_lat [Float, nil] широта пользователя
  # @param user_lng [Float, nil] долгота пользователя
  #
  def initialize(poi: nil, current_user: nil, categories: nil, user_lat: nil, user_lng: nil)
    @poi = poi
    @current_user = current_user
    @categories = categories
    @user_lat = user_lat
    @user_lng = user_lng
  end

  #
  # Начальная широта маркера: из poi (edit) или user_location
  #
  # @return [Float]
  #
  def initial_lat
    (poi&.latitude || user_lat || 55.751244).to_f
  end

  #
  # Начальная долгота маркера
  #
  # @return [Float]
  #
  def initial_lng
    (poi&.longitude || user_lng || 37.618423).to_f
  end

  #
  # Режим редактирования?
  #
  # @return [Boolean]
  #
  def edit_mode?
    poi.present?
  end

  #
  # URL формы
  #
  # @return [String]
  #
  def form_url
    edit_mode? ? poi_path(poi) : pois_path
  end

  #
  # HTTP метод
  #
  # @return [Symbol]
  #
  def form_method
    edit_mode? ? :patch : :post
  end

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
  # Возвращает массив пар [ключ, значение] для отображения metadata
  #
  # @return [Array<Array(String, Object)>]
  #
  def metadata_fields
    return [] if poi.blank? || poi.metadata.blank?

    poi.metadata.select { |_k, v| v.present? }
  end

  #
  # Форматирует значение для отображения
  #
  # @param value [Object] значение поля
  # @return [String]
  #
  def format_value(value)
    case value
    when true then "✓"
    when false then "✗"
    when Array then value.join(", ")
    else value.to_s
    end
  end

  #
  # Имеет ли текущий пользователь право редактировать POI?
  #
  # @return [Boolean]
  #
  def can_edit?
    return false if current_user.blank? || poi.blank?

    current_user.has_role?(:admin) || current_user.has_role?(:moderator) || poi.user_id == current_user.id
  end
end
