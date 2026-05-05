class ApplicationController < ActionController::Base
  include Pagy::Method
  include CableReady::Broadcaster
  include Pundit::Authorization

  # CSRF protection (prepend: true ensures it runs BEFORE auth filters)
  protect_from_forgery prepend: true

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  #allow_browser versions: :modern
  allow_browser versions: { safari: 16.4, chrome: 119, firefox: 121 }

  # Set locale from URL params
  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_current_request

  # Authenticate user for most actions (skip for Devise controllers and home page)
  before_action :authenticate_user!, unless: -> { devise_controller? || home_controller? }

  # Сохраняем текущую локацию перед перенаправлением на страницу авторизации
  before_action :store_user_location!, unless: -> { devise_controller? || home_controller? }

  before_action :skip_pundit_checks, if: :devise_controller?
  before_action :skip_pundit_checks, if: :home_controller?

  # Pundit authorization
  after_action :verify_authorized, unless: :skip_pundit?
  after_action :verify_policy_scoped, unless: :skip_pundit?

  # Capture Devise flash messages to ensure they appear as toasts
  after_action :set_devise_flash, if: :devise_controller?

  # Pundit error handling
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Current user for Pundit
  def pundit_user
    current_user
  end

  private

  def set_locale
    locale = params[:locale]&.to_sym || I18n.default_locale
    I18n.locale = locale if I18n.available_locales.include?(locale)
  end

  def set_current_request
    Current.request = request
    Current.user = current_user
  end

  def skip_pundit_checks
    skip_authorization
    skip_policy_scope
    true
  end

  def skip_pundit?
    devise_controller? || is_a?(Devise::OmniauthCallbacksController) || action_name.in?(%w[index show])
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end

  def add_breadcrumb(name, url = nil)
    @breadcrumbs ||= []
    @breadcrumbs << BreadcrumbItem.new(name, url)
  end

  # Simple breadcrumb item struct
  class BreadcrumbItem
    attr_reader :name, :url

    def initialize(name, url = nil)
      @name = name
      @url = url
    end
  end

  def home_controller?
    controller_name == 'home' || controller_name == 'pages'
  end

  def devise_controller_or_engine?
    devise_controller? || is_a?(Devise::OmniauthCallbacksController)
  end

  # Ensure Devise flash messages are properly set for toasts
  def set_devise_flash
    # Devise uses different flash keys for different scenarios
    # We capture all possible Devise flash messages and ensure they're set
    devise_flash_keys = [:notice, :alert]

    devise_flash_keys.each do |key|
      if flash[key].present?
        # Message is already set, keep it
      end
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :avatar])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :avatar])
  end

  #
  # Сохраняет текущую локацию пользователя перед перенаправлением на страницу авторизации
  # Используется для возврата пользователя на страницу, где он был до авторизации
  #
  def store_user_location!
    return if user_signed_in?

    # Сохраняем текущий путь для последующего перенаправления после авторизации
    store_location_for(:user, request.fullpath)
  end
end
