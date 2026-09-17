# frozen_string_literal: true

# @logical_path ui
# @component Ui::NavbarComponent
class Ui::NavbarComponentPreview < Lookbook::Preview
  # 1. Незарегистрированный пользователь (Гость)
  def guest
    setup_preview_context
    render_with_template(locals: { user: nil })
  end

  # 2. Авторизованный обычный пользователь
  def authenticated_user
    setup_preview_context
    user = User.new(id: 1, name: "Александр")
    render_with_template(locals: { user: user })
  end

  private

  #
  # Задает базовые параметры запроса для коректной работы helpers.url_for в контексте Lookbook
  #
  def setup_preview_context
    return unless respond_to?(:request) && request.present?

    request.params[:controller] ||= "application"
    request.params[:action] ||= "index"
  end
end
