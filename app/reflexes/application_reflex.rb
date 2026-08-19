# frozen_string_literal: true

class ApplicationReflex < StimulusReflex::Reflex
  include Rails.application.routes.url_helpers
  include Pundit::Authorization
  include Pagy::Method

  # ActionCable connection использует current_user as identified_by
  delegate :current_user, to: :connection

  # Устанавливаем текущего пользователя для Pundit, whodunnit для PaperTrail и локаль из URL
  # PaperTrail.request.whodunnit — иначе все версии, созданные через Reflex
  # (например, изменения PoiCategoryField), попадают в аудит без автора ("System")
  before_reflex do
    Current.user = current_user
    PaperTrail.request.whodunnit = current_user&.id
    I18n.locale = params[:locale]&.to_sym || I18n.default_locale
  end

  # Пробрасываем NotAuthorizedError при ошибке авторизации
  rescue_from Pundit::NotAuthorizedError do |exception|
    Rails.logger.warn("Pundit authorization failed: #{exception.message}")
    morph :nothing
  end

  # Пробрасываем другие ошибки валидации
  rescue_from ActiveRecord::RecordInvalid do |exception|
    Rails.logger.warn("Record validation failed: #{exception.message}")
    morph :nothing
  end

  #
  # Авторизует действие через Pundit
  #
  # @param resource [Object] ресурс для авторизации
  # @param action [Symbol] действие для проверки прав
  # @raise [Pundit::NotAuthorizedError] если нет прав
  #
  def authorize_with_pundit!(resource, action)
    authorize(resource, action)
  end

  #
  # Проверяет расстояние между пользователем и POI (100м лимит)
  # Админы/модераторы — без проверки
  #
  # При нарушении рендерит Ui::ConfirmDialogComponent с предупреждением
  # и возвращает false. Если всё ок — true.
  #
  # @param poi [Poi] POI для проверки
  # @return [Boolean] разрешено ли действие
  #
  def check_proximity!(poi)
    return true if current_user&.has_role?(:admin) || current_user&.has_role?(:moderator)

    user_lat = session[:user_lat]
    user_lng = session[:user_lng]

    unless user_lat && user_lng
      render_proximity_warning(:no_location)
      return false
    end

    unless PoiService.within_range?(
      user_lat: user_lat,
      user_lng: user_lng,
      poi_lat: poi.latitude,
      poi_lng: poi.longitude,
      user: current_user
    )
      render_proximity_warning(:too_far)
      return false
    end

    true
  end

  #
  # Рендерит Ui::ConfirmDialogComponent с предупреждением о расстоянии
  # и вставляет в контейнер #poi-auth-dialog
  #
  # @param reason [Symbol] :too_far или :no_location
  #
  def render_proximity_warning(reason)
    title = I18n.t("poi.details_component.#{reason == :too_far ? 'proximity_warning_title' : 'no_location_title'}")
    message = I18n.t("poi.details_component.#{reason == :too_far ? 'proximity_warning_message' : 'no_location_message'}")

    dialog = ApplicationController.render(Ui::ConfirmDialogComponent.new(
      title: title,
      message: message,
      confirm_text: I18n.t("ui.confirm_dialog_component.confirm"),
      cancel_text: I18n.t("ui.confirm_dialog_component.cancel"),
      confirm_variant: :primary,
      confirm_url: nil,
      confirm_method: :get
    ), layout: false)

    cable_ready.inner_html(selector: "#poi-auth-dialog", html: dialog)
    cable_ready.remove_css_class(selector: "#poi-auth-dialog", name: "hidden")
    cable_ready.remove_css_class(
      selector: "#poi-auth-dialog [data-controller='ui--confirm-dialog-component']",
      name: "hidden"
    )
    cable_ready.broadcast
    morph :nothing
  end

  private

  #
  # Рекурсивно преобразует строковые ключи хэша в символьные.
  # Необходимо для совместимости params из JS (строковые ключи)
  # с сервисным слоем, где используются символьные ключи (slice, dig).
  #
  # @param obj [Hash, Array, Object] данные для нормализации
  # @return [Hash, Array, Object] нормализованные данные
  #
  def deep_symbolize_keys(obj)
    case obj
    when Hash
      obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = deep_symbolize_keys(v) }
    when Array
      obj.map { |v| deep_symbolize_keys(v) }
    else
      obj
    end
  end
end

