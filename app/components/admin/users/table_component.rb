# frozen_string_literal: true

#
# Admin::Users::TableComponent - таблица пользователей с пагинацией
#
# Отображает:
# - Таблицу пользователей
# - Пагинацию (pagy)
# Используется для CableReady morph в Admin::UsersReflex
#
class Admin::Users::TableComponent < ApplicationComponent
  #
  # @param users [ActiveRecord::Relation] коллекция пользователей
  # @param pagy [Pagy, nil] объект пагинации
  #
  def initialize(users:, pagy: nil)
    @users = users
    @pagy = pagy
  end

  private

  attr_reader :users, :pagy
end
