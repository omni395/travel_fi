# lookbook/ui/breadcrumbs_component_preview.rb
# frozen_string_literal: true

# @logical_path ui
# @component Ui::BreadcrumbsComponent
class Ui::BreadcrumbsComponentPreview < Lookbook::Preview
  # Default Breadcrumbs
  #
  # @param items_count select [1, 2, 3, 4] "Количество крошек"
  def default(items_count: 3)
    breadcrumbs = [
      { name: "Главная", path: "#" },
      { name: "Раздел", path: "#" },
      { name: "Подраздел", path: "#" },
      { name: "Текущая страница", path: nil }
    ].take(items_count.to_i)

    render Ui::BreadcrumbsComponent.new(breadcrumbs: breadcrumbs)
  end

  # Только первый уровень (без вложенности)
  def single_level
    render Ui::BreadcrumbsComponent.new(breadcrumbs: [
      { name: "Единственная страница", path: nil }
    ])
  end
end
