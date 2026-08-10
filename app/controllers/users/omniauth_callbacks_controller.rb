class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController

  #
  # Обработчик Google OAuth2 callback
  # Вызывается когда пользователь возвращается с Google аутентификации
  #
  def google_oauth2
    # Рефкод берём из query (?ref=) либо из session (если был передан до старта OAuth).
    @user = User.from_google_oauth(request.env['omniauth.auth'], referral_code_input)

    if @user.persisted?
      # Рефкод истрачен после обработки — не размазываем по сессии.
      session.delete(:referral_code) if session[:referral_code]
      sign_in @user, event: :authentication
      UserAuditLogger.log_login(@user) if defined?(UserAuditLogger)

      # Устанавливаем flash-сообщение через штатный ключ devise.omniauth_callbacks.success
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?

      # Перенаправляем на главную со сбережением локали
      redirect_to after_sign_in_path_for(@user), allow_other_host: false
    else
      session['devise.google_data'] = request.env['omniauth.auth'].except(:extra)
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  private

  #
  # Реферальный код для OAuth: из query-параметра ?ref= или session[:referral_code].
  #
  # @return [String, nil]
  #
  def referral_code_input
    params[:ref].presence || session[:referral_code].presence
  end
  
  #
  # Обработчик ошибок при OAuth2 аутентификации
  # Вызывается если пользователь отклонил доступ или произошла ошибка
  #
  def failure
    redirect_to root_path, alert: 'Authentication failed'
  end

  protected

  def after_sign_in_path_for(resource)
    # Возвращаем пользователя на страницу, где он был до авторизации
    # Если сохраненной локации нет, перенаправляем на главную
    stored_location_for(resource) || root_path(locale: I18n.locale)
  end
end
