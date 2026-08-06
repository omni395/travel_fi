class UserMailer < ApplicationMailer
  # Письмо подтверждения email
  def confirmation_instructions(record, token, opts = {})
    @user = record
    # Devise.token_generator.generate returns [raw, encrypted] in some contexts
    @token = token.is_a?(Array) ? token.first : token
    # Devise confirmation is a collection route, don't pass the resource (avoid weird '/confirmation.16')
    @confirmation_url = user_confirmation_url(confirmation_token: @token, locale: I18n.locale)
    # Inline logo for email clients (use app/assets/images/logo-1.png)
    begin
      attachments.inline['logo-1.png'] = File.read(Rails.root.join('app', 'assets', 'images', 'logo-1.png')) if File.exist?(Rails.root.join('app', 'assets', 'images', 'logo-1.png'))
    rescue => e
      Rails.logger.info("Could not attach logo-1.png inline: #{e.class}: #{e.message}") if defined?(Rails)
    end

    mail(to: @user.unconfirmed_email.presence || @user.email, subject: I18n.t("devise.mailer.confirmation_instructions.subject"))
  end

  # Письмо сброса пароля
  def reset_password_instructions(record, token, opts = {})
    @user = record
    # Devise.token_generator.generate returns [raw, encrypted] in some contexts
    @token = token.is_a?(Array) ? token.first : token
    @password_reset_url = edit_user_password_url(reset_password_token: @token, locale: I18n.locale)
    # Inline logo for email clients (use app/assets/images/logo-1.png)
    begin
      attachments.inline['logo-1.png'] = File.read(Rails.root.join('app', 'assets', 'images', 'logo-1.png')) if File.exist?(Rails.root.join('app', 'assets', 'images', 'logo-1.png'))
    rescue => e
      Rails.logger.info("Could not attach logo-1.png inline: #{e.class}: #{e.message}") if defined?(Rails)
    end

    mail(to: @user.email, subject: I18n.t("devise.mailer.reset_password_instructions.subject"))
  end

  # Письмо подтверждения смены email
  def email_changed(record, opts = {})
    @user = record

    mail(to: @user.email, subject: I18n.t("devise.mailer.email_changed.subject"))
  end

  # Письмо разблокировки аккаунта
  def unlock_instructions(record, token, opts = {})
    @user = record
    @token = token
    @unlock_url = user_unlock_url(@user, unlock_token: @token, locale: I18n.locale)

    mail(to: @user.email, subject: I18n.t("devise.mailer.unlock_instructions.subject"))
  end

  # Письмо об удалении аккаунта
  def account_deleted(user)
    @user = user
    mail(to: @user.email, subject: I18n.t("mailer.account_deleted.subject"))
  end

  #
  # Письмо об обновлении профиля пользователя
  # Вызывается из UserProfileNotification через Noticed (deliver_by :email).
  # ВАЖНО: Noticed 3.x вызывает mailer через mailer.with(params) —
  # получатель доступен как params[:recipient] (ActionMailer::Parameterized).
  #
  def profile_updated
    @user = params[:recipient]

    mail(to: @user.email, subject: I18n.t("mailer.profile_updated.subject"))
  end

  #
  # Письмо о завершении OSM-импорта POI
  # Вызывается из PoiCategoryNotification через Noticed (deliver_by :email).
  # Отправляется только если у получателя включена настройка osm_import_email_enabled.
  # Получатель — params[:recipient] (Noticed 3.x, mailer.with(params)).
  #
  def osm_import_complete
    @user = params[:recipient]

    mail(to: @user.email, subject: I18n.t("mailer.osm_import_complete.subject"))
  end
end
