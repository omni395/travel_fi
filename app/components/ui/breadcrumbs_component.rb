# frozen_string_literal: true

#
# Ui::BreadcrumbsComponent - компонент хлебных крошек
#
# Отображает навигационную цепочку на основе breadcrumbs_on_rails.
# Последний элемент отображается как активный (без ссылки).
#
# @example
#   <%= render Ui::BreadcrumbsComponent.new(breadcrumbs: [
#     { name: t("admin.dashboard.title"), path: admin_root_path },
#     { name: t("admin.users.index.title"), path: admin_users_path },
#     { name: @user.name }
#   ]) %>
#
class Ui::BreadcrumbsComponent < ApplicationComponent
  def initialize(breadcrumbs:)
    @breadcrumbs = breadcrumbs
  end

  private

  attr_reader :breadcrumbs
end
