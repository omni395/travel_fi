# frozen_string_literal: true

#
# Admin::PoiCategories::PoiCategory::FieldsListComponent - список полей категории POI в админке
#
# Используется в двух режимах:
# 1. Вкладка "Fields" детальной страницы (show-режим): только таблица строк + reorder
#    (add_button: false, with_form: false).
# 2. Внутри формы редактирования категории (EditComponent, под блоком OSM Import):
#    таблица + кнопка "Add Field" + модалка FieldFormComponent (add_button: true, with_form: true).
#
# В обоих случаях список оборачивается в общий контейнер [data-poi-category-fields],
# который перерисовывает PoiCategoryBroadcaster (inner_html) — без дублирования, т.к.
# на странице присутствует ровно один такой контейнер (либо во вкладке, либо в форме).
#
# @param category [PoiCategory] категория POI
# @param add_button [Boolean] показывать ли кнопку "Add Field"
# @param with_form [Boolean] рендерить ли диалог FieldFormComponent
#
class Admin::PoiCategories::PoiCategory::FieldsListComponent < ApplicationComponent
  attr_reader :category

  #
  # @param category [PoiCategory] категория POI
  # @param add_button [Boolean] показывать ли кнопку "Add Field"
  # @param with_form [Boolean] рендерить ли диалог FieldFormComponent
  #
  def initialize(category:, add_button: true, with_form: true)
    @category = category
    @add_button = add_button
    @with_form = with_form
  end

  #
  # Показывать ли кнопку добавления поля
  #
  # @return [Boolean]
  #
  def add_button?
    @add_button
  end

  #
  # Рендерить ли диалог создания/редактирования поля
  #
  # @return [Boolean]
  #
  def with_form?
    @with_form
  end

  #
  # Возвращает поля категории, отсортированные по позиции
  #
  # @return [ActiveRecord::Relation<PoiCategoryField>]
  #
  def fields
    category.poi_category_fields.by_position
  end

  #
  # Является ли переданное поле последним в списке?
  # Используется в шаблоне для определения кнопки реордера (Herb: не вызывать fields в `<% %>`)
  #
  # @param field [PoiCategoryField] поле
  # @return [Boolean]
  #
  def last_field?(field)
    field == fields.last
  end
end
