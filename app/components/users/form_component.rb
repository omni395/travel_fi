# frozen_string_literal: true

#
# Users::FormComponent - форма для редактирования профиля пользователя
#
# Использует WebSocket-first подход: Stimulus → StimulusReflex → Reflex → Service → Broadcaster
# При submit форма отправляет данные через WebSocket, не через HTTP
#
# @param user [User] пользователь для редактирования
#
class Users::FormComponent < ApplicationComponent
  def initialize(user:)
    @user = user
  end

  #
  # Возвращает CSS классы для инпутов
  #
  def input_classes
    "w-full px-4 py-2 rounded-lg border border-gray-300 focus:border-teal-500 focus:ring-2 focus:ring-teal-200 transition-colors duration-200"
  end

  #
  # Возвращает CSS классы для label
  #
  def label_classes
    "block text-sm font-semibold text-gray-700 mb-2"
  end

  #
  # Возвращает CSS классы для кнопок
  #
  def button_classes
    "px-4 py-2 rounded-lg font-semibold transition-all duration-300"
  end

  #
  # Возвращает CSS классы для primary button (Save)
  #
  def primary_button_classes
    "#{button_classes} bg-gradient-to-r from-teal-600 to-sky-600 text-white hover:from-teal-700 hover:to-sky-700 shadow-md hover:shadow-lg"
  end

  #
  # Возвращает CSS классы для secondary button (Cancel)
  #
  def secondary_button_classes
    "#{button_classes} bg-gray-200 text-gray-700 hover:bg-gray-300"
  end
end
