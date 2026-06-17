# frozen_string_literal: true

#
# PoiCategoryService - сервис для управления категориями POI
#
# Ответственность:
# 1. Создание/обновление категорий
# 2. Управление полями категорий (создание, обновление, удаление)
# 3. Поиск и фильтрация категорий
#
class PoiCategoryService
  #
  # Создаёт новую категорию POI
  #
  # @param params [Hash] параметры категории { name:, slug:, icon:, description:, position:, active: }
  # @param current_user [User] пользователь, выполняющий действие
  # @return [PoiCategory] созданная категория
  # @raise [CreateError] если произойдет ошибка валидации
  #
  def self.create(params:, current_user:)
    category = PoiCategory.new(params.slice(:name, :slug, :icon, :description, :position, :active))
    category.save!
    category
  rescue ActiveRecord::RecordInvalid => e
    raise CreateError, e.message
  end

  #
  # Обновляет категорию POI
  #
  # @param category [PoiCategory] категория для обновления
  # @param params [Hash] параметры для обновления
  # @param current_user [User] пользователь, выполняющий действие
  # @return [PoiCategory] обновленная категория
  # @raise [UpdateError] если произойдет ошибка валидации
  #
  def self.update(category:, params:, current_user:)
    category.update!(params.slice(:name, :slug, :icon, :description, :position, :active))
    category
  rescue ActiveRecord::RecordInvalid => e
    raise UpdateError, e.message
  end

  #
  # Создаёт поле для категории POI
  #
  # @param category [PoiCategory] категория
  # @param params [Hash] параметры поля { field_key:, field_type:, label:, required:, options:, placeholder:, hint:, position:, active: }
  # @param current_user [User] пользователь, выполняющий действие
  # @return [PoiCategoryField] созданное поле
  # @raise [CreateError] если произойдет ошибка валидации
  #
  def self.create_field(category:, params:, current_user:)
    field = category.poi_category_fields.new(
      params.slice(:field_key, :field_type, :label, :required, :options, :placeholder, :hint, :position, :active)
    )
    field.save!
    field
  rescue ActiveRecord::RecordInvalid => e
    raise CreateError, e.message
  end

  #
  # Обновляет поле категории POI
  #
  # @param field [PoiCategoryField] поле для обновления
  # @param params [Hash] параметры для обновления
  # @param current_user [User] пользователь, выполняющий действие
  # @return [PoiCategoryField] обновленное поле
  # @raise [UpdateError] если произойдет ошибка валидации
  #
  def self.update_field(field:, params:, current_user:)
    field.update!(params.slice(:field_key, :field_type, :label, :required, :options, :placeholder, :hint, :position, :active))
    field
  rescue ActiveRecord::RecordInvalid => e
    raise UpdateError, e.message
  end

  #
  # Удаляет поле категории POI
  #
  # @param field [PoiCategoryField] поле для удаления
  # @param current_user [User] пользователь, выполняющий действие
  # @raise [DestroyError] если произойдет ошибка
  #
  def self.destroy_field(field:, current_user:)
    field.destroy!
  rescue ActiveRecord::RecordNotDestroyed => e
    raise DestroyError, e.message
  end

  #
  # Ищет категории по запросу через Ransack
  #
  # @param query [String, nil] поисковый запрос
  # @param active [Boolean, nil] фильтр по активности
  # @return [ActiveRecord::Relation] отфильтрованные категории
  #
  def self.search_categories(query: nil, active: nil)
    categories = PoiCategory.all

    conditions = {}
    conditions[:name_cont] = query if query.present?
    conditions[:active_eq] = active if active.present?

    result = categories.ransack(conditions).result
    result.order(position: :asc)
  end

  # Custom exceptions
  class CreateError < StandardError; end
  class UpdateError < StandardError; end
  class DestroyError < StandardError; end
end
