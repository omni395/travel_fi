# lookbook/ui/audit_entry_component_preview.rb
# frozen_string_literal: true

# @logical_path ui
# @component Ui::AuditEntryComponent
class Ui::AuditEntryComponentPreview < Lookbook::Preview
  # 1. Дефолтное состояние: Изменение записи (Update)
  # @param whodunnit text "Имя или ID пользователя"
  # @param event select [update, create, destroy, category_icon_uploaded] "Тип события"
  def default(whodunnit: "Admin User", event: "update")
    version = MockVersion.new(
      event: event,
      whodunnit: whodunnit,
      created_at: 15.minutes.ago,
      object_changes: {
        "title" => [ "Старое название", "Новое название POI" ],
        "status" => [ "draft", "published" ],
        "i18n_description" => [ { "en" => "Old desc" }, { "en" => "New description", "ru" => "Новое описание" } ]
      }
    )

    render Ui::AuditEntryComponent.new(version: version)
  end

  # 2. Создание записи (Create)
  def created_event
    version = MockVersion.new(
      event: "create",
      whodunnit: "John Doe",
      created_at: 2.hours.ago,
      object_changes: {
        "name" => [ nil, "New Category" ],
        "slug" => [ nil, "new-category" ]
      }
    )

    render Ui::AuditEntryComponent.new(version: version)
  end

  # 3. Изменение отдельного поля PoiCategoryField
  def category_field_change
    version = MockVersion.new(
      event: "update",
      item_type: "PoiCategoryField",
      whodunnit: "System",
      created_at: 1.day.ago,
      object_changes: {
        "position" => [ 1, 2 ]
      },
      object: { "field_key" => "wifi_available" }.to_json
    )

    render Ui::AuditEntryComponent.new(version: version)
  end

  # 4. Пустое состояние (версия не передана)
  def empty_state
    render Ui::AuditEntryComponent.new(version: nil)
  end

  private

  # Фейковый объект версии, чтобы не дёргать БД и PaperTrail
  class MockVersion
    attr_reader :event, :whodunnit, :created_at, :object_changes, :object, :item_type

    def initialize(event:, whodunnit:, created_at:, object_changes:, object: nil, item_type: "Poi")
      @event = event
      @whodunnit = whodunnit
      @created_at = created_at
      @object_changes = object_changes
      @object = object
      @item_type = item_type
    end

    def present?
      true
    end
  end
end
