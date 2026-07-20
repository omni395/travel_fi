# frozen_string_literal: true

#
# Admin::Pois::Poi::AuditLogComponent - журнал аудита для POI
#
# Отображает историю изменений POI (PaperTrail versions)
# Аналог Admin::Users::User::AuditLogComponent
#
# @param versions [ActiveRecord::Relation<PaperTrail::Version>] версии
# @param pagy [Pagy, nil] объект пагинации
#
class Admin::Pois::Poi::AuditLogComponent < ApplicationComponent
  def initialize(versions:, pagy: nil)
    @versions = versions
    @pagy = pagy
  end

  private

  attr_reader :versions, :pagy
end
