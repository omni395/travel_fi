# frozen_string_literal: true

# @logical_path ui
# @component Ui::PaginationComponent
class Ui::PaginationComponentPreview < Lookbook::Preview
  # Базовая пагинация (активная 3 страница из 10)
  def default
    pagy = Struct.new(:page, :pages, :previous, :next).new(3, 10, 2, 4)
    render Ui::PaginationComponent.new(pagy: pagy)
  end

  # Первичная страница (без кнопки "Назад")
  def first_page
    pagy = Struct.new(:page, :pages, :previous, :next).new(1, 10, nil, 2)
    render Ui::PaginationComponent.new(pagy: pagy)
  end
end
