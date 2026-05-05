# frozen_string_literal: true

class Admin::SidebarComponent < ApplicationComponent
  def initialize(current_page:, user: nil, is_mobile: false)
    @current_page = current_page
    @user = user
    @is_mobile = is_mobile
  end

  private

  def is_active?(path)
    request.path == path
  end

  def request
    view_context.request
  end
end