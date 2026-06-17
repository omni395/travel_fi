# frozen_string_literal: true

#
# Ui::CardComponent - переиспользуемая карточка
#
# Содержит три опциональных слота: header, body, footer
#
# @example
#   <%= render Ui::CardComponent.new do |c| %>
#     <% c.with_header do %>
#       <h2 class="text-xl font-bold text-gray-900"><%= t('admin.users.profile') %></h2>
#     <% end %>
#     <% c.with_body do %>
#       <p>Content</p>
#     <% end %>
#     <% c.with_footer do %>
#       <%= render Ui::BtnComponent.new(color: :primary) { t('common.save') } %>
#     <% end %>
#   <% end %>
#
class Ui::CardComponent < ApplicationComponent
  renders_one :header
  renders_one :body
  renders_one :footer
end
