class Users::SessionsController < Devise::SessionsController
  skip_after_action :verify_authorized, raise: false
  skip_after_action :verify_policy_scoped, raise: false

  before_action :redirect_if_signed_in, only: [ :new ]

  def create
    super do |resource|
      # Ensure notice is set for successful login
      if resource.present?
        # Clear all default Devise flash messages
        flash.delete(:notice)
        flash.delete(:alert)
        flash[:success] = I18n.t("devise.sessions.signed_in", default: "Signed in successfully.")

        # Log successful login to audit trail via PaperTrail
        UserAuditLogger.log_login(resource)
      end
    end
  end

  def destroy
    # Log logout BEFORE user is cleared from session via PaperTrail
    UserAuditLogger.log_logout(current_user) if current_user.present?

    super
    # Override Devise's default notice with success flash
    flash.delete(:notice)
    flash[:success] = I18n.t("devise.sessions.signed_out", default: "Signed out successfully.")
  end

  #
  # Возвращает пользователя на страницу, где он был до логина
  # Использует stored_location_for (сохраняется в store_user_location!)
  # Если сохранённого пути нет — редирект на root с текущей локалью
  #
  # @param resource [User] авторизованный пользователь
  # @return [String] путь для редиректа
  #
  def after_sign_in_path_for(resource)
    stored_location = stored_location_for(:user)
    stored_location.presence || root_path(locale: I18n.locale)
  end

  #
  # Возвращает пользователя на страницу, откуда он вышел
  # Использует referrer, если доступен, иначе root с текущей локалью
  #
  # @param resource_or_scope [Object] пользователь или scope
  # @return [String] путь для редиректа
  #
  def after_sign_out_path_for(resource_or_scope)
    request.referrer.presence || root_path(locale: I18n.locale)
  end

  private

  def redirect_if_signed_in
    if user_signed_in?
      flash[:notice] = I18n.t("devise.sessions.already_signed_in", default: "You are already signed in.")
      redirect_to(root_path(locale: I18n.locale))
    end
  end
end
