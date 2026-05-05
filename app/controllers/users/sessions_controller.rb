class Users::SessionsController < Devise::SessionsController
  include ActionView::Helpers::DateHelper

  skip_after_action :verify_authorized, raise: false
  skip_after_action :verify_policy_scoped, raise: false
  
  before_action :redirect_if_signed_in, only: [:new]

  def create
    # Pre-check for users that exist but are not yet confirmed / verification expiring
    email = params.dig(:user, :email)&.downcase
    if email.present?
      user = User.find_by(email: email)
      # If user doesn't exist, redirect to sign up with a friendly message
      if user.nil?
        flash[:notice] = I18n.t('devise.failure.account_not_found', email: email)
        return redirect_to(new_user_registration_path(email: email))
      end
      if user.present? && user.pending_verification? && user.confirmed_at.blank?
        # If token already expired
        if user.verification_expired?
          flash[:alert] = I18n.t('devise.failure.email_confirmation_expired')
          return redirect_to(new_user_confirmation_path)
        end

        # If confirmation will expire soon, tell the user how much time is left
        if user.confirmation_sent_at.present?
          confirm_within = Devise.confirm_within || User::VERIFICATION_EXPIRY_DAYS.days
          expiry_time = user.confirmation_sent_at + confirm_within
          time_left = expiry_time - Time.current
          if time_left <= 1.day
            human = distance_of_time_in_words(Time.current, expiry_time, include_seconds: true, highest_measure_only: true)
            flash[:alert] = I18n.t('devise.failure.email_confirmation_expires_soon', time: human)
          else
            flash[:alert] = I18n.t('devise.failure.email_pending_confirmation', email: user.email)
          end
        else
          flash[:alert] = I18n.t('devise.failure.email_pending_confirmation', email: email)
        end

        # Redirect back to sign in page so flash will be rendered by layout's notification controller
        return redirect_to(new_user_session_path)
      end
    end

    super do |resource|
      # Ensure notice is set for successful login
      if resource.present?
        # Clear all default Devise flash messages
        flash.delete(:notice)
        flash.delete(:alert)
        flash[:success] = I18n.t('devise.sessions.signed_in', default: 'Signed in successfully.')
        
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
    flash[:success] = I18n.t('devise.sessions.signed_out', default: 'Signed out successfully.')
  end

  # Ensure redirect with proper locale after successful sign in
  def after_sign_in_path_for(resource)
    root_path(locale: I18n.locale)
  end

  private

  def redirect_if_signed_in
    if user_signed_in?
      flash[:notice] = I18n.t('devise.sessions.already_signed_in', default: 'You are already signed in.')
      redirect_to(root_path(locale: I18n.locale))
    end
  end

end
