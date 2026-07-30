# frozen_string_literal: true

#
# Poi::FormComponent — форма создания/редактирования POI
#
# Содержит:
# - Поля: название, категория, динамические поля, координаты (мини-карта),
#   адрес, город, телефон, вебсайт, доступность
# - OpenLayers мини-карту с драггабельным маркером + круг 50м
#
# Режимы:
# - create: новая точка, poi = nil
# - edit: редактирование существующей точки
#
class Poi::FormComponent < ApplicationComponent
  attr_reader :poi, :current_user, :categories, :user_lat, :user_lng

  #
  # @param poi [Poi, nil] объект POI для редактирования
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

  private

  #
  # Начальная широта маркера: из poi (edit) или user_location
  #
  # @return [Float]
  #
  def initial_lat
    (poi&.latitude || user_lat).to_f
  end

  #
  # Начальная долгота маркера
  #
  # @return [Float]
  #
  def initial_lng
    (poi&.longitude || user_lng).to_f
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
    edit_mode? ? poi_path(id: poi) : pois_path
  end

  #
  # HTTP метод
  #
  # @return [Symbol]
  #
  def form_method
    edit_mode? ? :patch : :post
  end
end
