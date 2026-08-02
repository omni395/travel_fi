# frozen_string_literal: true

#
# Admin::PoiCategories::PoiCategory::AuditLogComponent — панель ленты аудита категории POI
#
# Вкладка "Audit Log" детальной страницы категории. Инкапсулирует список
# Ui::AuditEntryComponent и пагинацию Ui::PaginationComponent.
#
# Собственный Stimulus-контроллер (goToPage) на корне гарантирует, что кнопки
# пагинации имеют контроллер-предок (аналогично PoisListComponent во вкладке POIs),
# — иначе data-action не резолвится и пагинация не работает.
#
# @param category [PoiCategory] категория POI
# @param versions [Array<PaperTrail::Version>] версии для текущей страницы
# @param pagy [Pagy] объект пагинации
#
class Admin::PoiCategories::PoiCategory::AuditLogComponent < ApplicationComponent
  def initialize(category:, versions:, pagy:)
    @category = category
    @versions = versions
    @pagy = pagy
  end

  private

  attr_reader :category, :versions, :pagy

  #
  # Есть ли записи для отображения
  #
  # @return [Boolean]
  #
  def versions_present?
    versions.any?
  end

  #
  # Нужно ли показывать пагинацию
  #
  # @return [Boolean]
  #
  def pagination_present?
    pagy.pages > 1
  end

  #
  # Рендерит все записи аудита через Ui::AuditEntryComponent.
  # Per-entry защита: битая версия не роняет рендер всей ленты.
  #
  # ВАЖНО: рендер через helpers.render (view_context, как вложенные компоненты
  # FieldsListComponent/FieldFormComponent), а НЕ через ApplicationController.render —
  # вложенный ApplicationController.render внутри job (SolidQueue worker) падал,
  # из-за чего лента аудита не отправлялась в broadcast (поля/POIs — работали).
  #
  # @return [String] HTML всех записей ленты
  #
  def render_entries_html
    html = +""
    versions.each do |v|
      begin
        html << helpers.render(Ui::AuditEntryComponent.new(version: v))
      rescue StandardError => e
        Rails.logger.error("AuditLogComponent: entry render failed: #{e.class} #{e.message}")
      end
    end
    html.html_safe
  end
end
