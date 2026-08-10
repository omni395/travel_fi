# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  skip_after_action :verify_authorized, raise: false
  skip_after_action :verify_policy_scoped, raise: false

  # POST /resource
  def create
    # Обработаем аватар ДО того как сохранится пользователь
    process_avatar_before_save

    self.resource = build_resource(sign_up_params)
    resource.save

    if resource.persisted?
      # Служебные данные + начисления (бизнес-логика в Service).
      setup_new_user(resource)

      if resource.confirmed?
        # Подтверждённый аккаунт (напр. OAuth) — стандартный вход.
        set_flash_message!(:notice, :signed_up)
        sign_up(resource_name, resource)
      else
        # Email не подтверждён: НЕ логиним — уводим на страницу входа
        # с сообщением о необходимости подтверждения почты.
        set_flash_message!(:notice, :signed_up_but_unconfirmed)
        expire_data_after_sign_in!
        redirect_to after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords(resource)
      set_minimum_password_length
      respond_with resource
    end
  end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  def update
    # Обработаем аватар перед обновлением
    process_avatar_before_update

    # ПЕРЕД обновлением - сохраняем ТОЧНЫЕ старые значения для логирования
    old_values = {
      name: resource.name,
      email: resource.email,
      avatar_present: resource.avatar.attached?
    }

    # Если пароль пустой, исключаем его из параметров для обновления
    # Это позволит пользователю обновлять профиль без изменения пароля
    account_update_params = update_params
    if account_update_params[:password].blank? && account_update_params[:password_confirmation].blank?
      account_update_params = account_update_params.except(:password, :password_confirmation)
    end

    # Вызываем стандартный Devise update с уже обработанными параметрами
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
    prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

    # Проверяем, меняется ли email (для unconfirmed_email)
    email_changed = account_update_params[:email].present? && resource.email != account_update_params[:email]
    if email_changed
      resource.unconfirmed_email = account_update_params[:email]
    end

    # Проверяем, меняется ли пароль
    password_changed = account_update_params[:password].present? && account_update_params[:password_confirmation].present?
    avatar_changed = account_update_params[:avatar].present?

    resource_updated = resource.update(account_update_params)

    yield resource if block_given?

    if resource_updated
      yield resource if block_given?

      # Собираем ВСЕ изменения в один объект changes (аналогично админке)
      changes = {}

      # Имя
      if old_values[:name] != resource.name
        changes[:name] = { old: old_values[:name], new: resource.name }
      end

      # Email
      if email_changed
        changes[:email] = { old: old_values[:email], new: account_update_params[:email] }
      end

      # Аватар
      if avatar_changed
        changes[:avatar] = { old: old_values[:avatar_present] ? "Attached" : "None", new: "Attached" }
      end

      # Пароль - логируем как защищённое поле
      if password_changed
        changes[:password] = { old: "[Protected]", new: "[Changed]" }
      end

      # Логируем ОДНО действие со ВСЕМИ изменениями
      if changes.any?
        UserAuditLogger.log_user_updated_by_user(resource, changes) if defined?(UserAuditLogger)
      end

      if is_navigational_format?
        flash_message = update_needs_confirmation?(resource, prev_unconfirmed_email) ?
          :update_needs_confirmation : :updated
        set_flash_message :notice, flash_message
      end
      sign_in resource, bypass: true
      respond_with resource, location: after_update_path_for(resource)
    else
      clean_up_passwords resource
      set_flash_message :alert, :update_unsuccessful
      respond_with resource
    end
  end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process, removing all OAuth session data.
  # def cancel
  #   super
  # end

  protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # После регистрации неподтверждённого юзера ведём на страницу входа
  # (сообщение о подтверждении почты — в flash :signed_up_but_unconfirmed).
  def after_inactive_sign_up_path_for(_resource)
    new_user_session_path
  end

  private

  # Создаёт служебные данные для нового пользователя: настройки уведомлений,
  # скрытый custodial-кошелёк, реферальную связь (в БД, до подтверждения) и
  # аудит-записи.
  #
  # ВАЖНО: начисления TFT (welcome + реферальные) здесь НЕ производятся.
  # Точка начисления — достижение статуса active:
  #   - email-регистрация: удостоверение в ConfirmationsController#show
  #   - OAuth: сразу в UserService.handle_google_oauth (юзер активен сразу)
  # Реферальная связь фиксируется СЕЙЧАС (persisted), чтобы пережить
  # подтверждение почты (там виртуальный атрибут недоступен).
  #
  # @param resource [User] только что созданный пользователь
  #
  def setup_new_user(resource)
    UserService.create_default_settings(resource)
    WalletService.create_hidden_wallet(user: resource)
    UserService.save_referral!(resource, resource.referral_code_input)

    registration_changes = {
      email: { old: nil, new: resource.email },
      name: { old: nil, new: resource.name }
    }
    registration_changes[:avatar] = { old: nil, new: "Attached" } if resource.avatar.attached?
    UserAuditLogger.log_registration(resource, registration_changes) if defined?(UserAuditLogger)
    UserAuditLogger.log_login(resource) if defined?(UserAuditLogger)
  end

  def update_params
    devise_parameter_sanitizer.sanitize(:account_update)
  end

  def process_avatar_before_update
    # Если в параметрах есть аватар, обработаем его через PhotoService
    return unless update_params[:avatar].present?

    avatar_file = update_params[:avatar]

    begin
      # Обработаем изображение: конвертируем в webp и сжимаем до 100 KB
      processed = PhotoService.process(
        avatar_file,
        filename: "avatar_#{current_user.id}",
        format: 'webp'
      )

      if processed.respond_to?(:path)
        # Заменяем аватар на обработанный файл
        params[:user][:avatar] = File.open(processed.path)
        # Очищаем старый файл после использования
        processed.unlink if processed.respond_to?(:unlink)
      end
    rescue => e
      Rails.logger.warn("Failed to process avatar during profile update: #{e.class} #{e.message}")
      # Если обработка не удалась, используем оригинальный файл
      # (валидация потом проверит размер)
    end
  end

  def process_avatar_before_save
    # Если в параметрах есть аватар, обработаем его через PhotoService
    return unless sign_up_params[:avatar].present?

    avatar_file = sign_up_params[:avatar]

    begin
      # Обработаем изображение: конвертируем в webp и сжимаем до 100 KB
      processed = PhotoService.process(
        avatar_file,
        filename: "avatar_#{sign_up_params[:email].split('@').first}",
        format: "webp"
      )

      if processed.respond_to?(:path)
        # Заменяем аватар на обработанный файл
        params[:user][:avatar] = File.open(processed.path)
        # Очищаем старый файл после использования
        processed.unlink if processed.respond_to?(:unlink)
      end
    rescue => e
      Rails.logger.warn("Failed to process avatar during registration: #{e.class} #{e.message}")
      # Если обработка не удалась, используем оригинальный файл
      # (валидация потом проверит размер)
    end
  end

  def sign_up_params
    params.require(:user).permit(:email, :name, :password, :password_confirmation, :avatar, :referral_code_input)
  end
end
