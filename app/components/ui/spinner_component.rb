# frozen_string_literal: true

#
# Ui::SpinnerComponent — полноэкранный оверлей загрузки страницы
#
# Отображается ПЕРВЫМ на странице (логотип + вращающееся кольцо + процент
# загрузки) и скрывается после полной загрузки.
#
# Используется на обоих лайаутах (application и admin):
#   <%= render Ui::SpinnerComponent.new %>
#
class Ui::SpinnerComponent < ApplicationComponent
end
