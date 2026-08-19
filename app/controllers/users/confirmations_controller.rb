class Users::ConfirmationsController < Devise::ConfirmationsController
  # ZABRANENO: require_no_authentication блокировал бы уже залогиненного юзера.
  # reconfirmable требует подтверждения НОВОГО email через ссылку из письма даже
  # в активной сессии; блокировка приводила к тому, что смена email никогда не
  # применялась (оставалась в unconfirmed_email). Поэтому здесь его нет.
  skip_after_action :verify_authorized, raise: false
  skip_after_action :verify_policy_scoped, raise: false

  # GET  /resource/confirmation/new
  def new
    super
  end

  # POST /resource/confirmation
  def create
    super
  end

  # GET  /resource/confirmation?confirmation_token=abcdef
  def show
    self.resource = resource_class.confirm_by_token(params[:confirmation_token])

    if resource.errors.empty?
      set_flash_message(:notice, :confirmed)
      # Обновляем статус пользователя после подтверждения
      # UserService.confirm_email — мутация в Service слое (не в модели), всегда active
      UserService.confirm_email(resource)
      # Скрытый custodial-кошелёк создаётся после подтверждения (для email-регистрации).
      # Порядок важен: начисление идёт ПОСЛЕ кошелька, чтобы начисление сразу
      # получило on-chain адрес (без backfill-ветки).
      WalletService.create_hidden_wallet(user: resource)
      # Точка начисления = статус active: welcome-токены и реферальные бонусы
      # начисляются ТОЛЬКО после активации аккаунта (не в registrations#create).
      # Реферальная связь уже персистится при регистрации (save_referral!) —
      # метод принимает один аргумент (user).
      UserService.award_registration_bonus!(resource)
      # Логируем подтверждение email
      UserAuditLogger.log_email_verified(resource) if defined?(UserAuditLogger)
      # Логируем вход при подтверждении email (timestamps будут разные благодаря счётчику)
      sign_in(resource)
      UserAuditLogger.log_login(resource) if defined?(UserAuditLogger)
      redirect_to after_confirmation_path_for(resource)
    else
      Rails.logger.warn("ConfirmationsController#show: token confirmation failed for token=#{params[:confirmation_token]} errors=#{resource.errors.full_messages.join(', ')}") if defined?(Rails) && Rails.respond_to?(:logger)
      redirect_to new_user_session_path, notice: resource.errors.full_messages.join(", ")
    end
  end

  protected

  # The path used after confirmation.
  def after_confirmation_path_for(resource_name)
    after_sign_in_path_for(resource_name)
  end

  def after_resend_email_path_for(resource_name)
    super(resource_name)
  end
end
