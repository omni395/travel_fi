# frozen_string_literal: true

#
# Admin::PoiCategories::PoiCategory::AuditLogComponent - журнал аудита категории POI
#
# Аналог Admin::Users::User::AuditLogComponent
#
# @param versions [ActiveRecord::Relation<PaperTrail::Version>] версии
# @param pagy [Pagy, nil] объект пагинации
#
class Admin::PoiCategories::PoiCategory::AuditLogComponent < ApplicationComponent
  def initialize(versions:, pagy: nil)
    @versions = versions
    @pagy = pagy
  end

  private

  attr_reader :versions, :pagy
end
