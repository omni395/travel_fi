# frozen_string_literal: true

#
# Ui::TabsComponent - универсальный компонент для вкладок (табов)
#
# @example
#   <%= render Ui::TabsComponent.new(
#     tabs: [
#       { id: "activity",  name: t("admin.users.tabs.activity"),  icon: "mdi-history" },
#       { id: "wallet",    name: t("admin.users.tabs.wallet"),    icon: "mdi-wallet" },
#       { id: "audit_log", name: t("admin.users.tabs.audit_log"), icon: "mdi-clipboard-text-search" }
#     ],
#     active_tab: "activity",
#     panels: {
#       activity:  render(ActivityComponent.new(user: user)),
#       wallet:    render(WalletComponent.new(user: user)),
#       audit_log: render(AuditLogComponent.new(versions: versions, pagy: pagy))
#     }
#   ) %>
#
class Ui::TabsComponent < ApplicationComponent
  attr_reader :tabs, :active_tab, :panels

  #
  # @param tabs [Array<Hash>] массив вкладок [{ id:, name:, icon: }]
  # @param active_tab [String, Symbol] идентификатор активной вкладки
  # @param panels [Hash] хэш { id: content_html }
  #
  def initialize(tabs:, active_tab: nil, panels: {})
    @tabs = tabs
    @active_tab = active_tab || tabs.first&.dig(:id)
    @panels = panels
  end

  #
  # Возвращает контент панели для указанного таба
  #
  # @param id [String, Symbol] идентификатор таба
  # @return [String, nil] HTML контент
  #
  def panel_content(id)
    panels[id.to_s] || panels[id.to_sym]
  end
end
