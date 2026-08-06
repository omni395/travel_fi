# frozen_string_literal: true

#
# User Broadcaster - отправляет обновления профиля пользователя через WebSocket
# 
# Ответственность:
# 1. Получает обновленного пользователя
# 2. Рендерит актуальный компонент интерфейса
# 3. Формирует CableReady команды для обновления DOM
# 4. Отправляет команды в канал конкретного пользователя
#
class UserBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет обновление профиля пользователя через WebSocket
  #
  # @param user [User] пользователь с обновленными данными
  #
  def self.call(user:)
    new(user: user).broadcast
  end

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  #
  # Выполняет broadcast обновления
  #
  def broadcast
    # Рендерим обновленный компонент
    updated_component_html = render_user_profile_component

    # Получаем канал для пользователя
    channel = "user_#{user.id}"

    # 1. Живое обновление профиля (inner_html, НЕ morph — morph падает на клиенте)
    cable_ready[channel].inner_html(
      selector: "[data-user-profile-id='#{user.id}']",
      html: updated_component_html
    )

    # 2. Живое обновление уведомления (toast)
    toast_html = ApplicationController.renderer.render(Ui::ToastComponent.new(
      message: I18n.t('notifications.user_updated', name: user.name)
    ))

    cable_ready[channel].insert_adjacent_html(
      selector: "#notifications",
      position: "beforeend",
      html: toast_html
    )

    # Применяем изменения
    cable_ready[channel].broadcast

    Rails.logger.info("UserBroadcaster: Sent profile update for user #{user.id}")
  rescue StandardError => e
    Rails.logger.error("UserBroadcaster error: #{e.class} #{e.message}")
  end

  private

  #
  # Рендерит компонент Users::ProfileComponent для текущего пользователя
  #
  # @return [String] HTML строка компонента
  #
  def render_user_profile_component
    component = Users::ProfileComponent.new(user: user)

    # ApplicationController.render (НЕ renderer): renderer не знает route helpers/locale
    # и падает "No route matches {locale: :en}" при рендере вложенных ссылок.
    # В SolidQueue worker I18n.locale = nil → route helper с locale: nil не матчит scope
    # "(:locale)". Фиксируем дефолтную локаль на время рендера (как в PoiCategoryBroadcaster).
    I18n.with_locale(I18n.default_locale) do
      ApplicationController.render(component, layout: false)
    end
  rescue StandardError => e
    Rails.logger.error("Failed to render Users::ProfileComponent: #{e.class} #{e.message}")
    ""
  end
end
