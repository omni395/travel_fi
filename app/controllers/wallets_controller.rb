# frozen_string_literal: true

class WalletsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_wallet_management!
  before_action :skip_policy_scope

  #
  # Issues a one-time signature challenge for connecting an external wallet.
  #
  def challenge
    result = WalletService.build_external_wallet_challenge(
      address: params[:address],
      base_url: request.base_url
    )
    session[challenge_session_key] = result.fetch(:challenge)
    render json: result.slice(:message, :chain_id)
  rescue ArgumentError
    render json: { error: I18n.t("wallets.invalid_address") }, status: :unprocessable_entity
  end

  #
  # Verifies the wallet's challenge signature and links the external wallet.
  #
  def connect
    challenge = session.delete(challenge_session_key)
    wallet = WalletService.connect_external!(
      user: current_user,
      challenge: challenge,
      signature: params.require(:signature)
    )
    render json: {
      address: wallet.address,
      message: I18n.t("wallets.connected")
    }
  rescue WalletService::ChallengeExpired
    render json: { error: I18n.t("wallets.challenge_expired") }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing, ArgumentError
    render json: { error: I18n.t("wallets.signature_invalid") }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    render json: { error: I18n.t("wallets.address_in_use") }, status: :conflict
  end

  #
  # Disconnects the user's external wallet without touching the custodial wallet.
  #
  def disconnect
    WalletService.disconnect_external!(user: current_user)
    render json: { message: I18n.t("wallets.disconnected") }
  end

  #
  # Creates the signed EIP-712 payload for claiming available rewards.
  #
  def claim_request
    prepared = Eip2771RewardClaimService.prepare_for_user!(user: current_user)
    session[claim_session_key] = {
      "user_id" => current_user.id,
      **prepared.fetch(:state)
    }
    render json: { typed_data: prepared.fetch(:typed_data) }
  rescue ArgumentError, KeyError => e
    Rails.logger.error("WalletsController#claim_request failed: #{e.class} #{e.message}")
    render json: { error: I18n.t("wallets.claim_unavailable") }, status: :unprocessable_entity
  end

  #
  # Validates the signed reward request and queues its on-chain relay.
  #
  def claim
    state = session[claim_session_key]
    Eip2771RewardClaimService.enqueue_claim!(
      user: current_user,
      state: state,
      signature: params.require(:signature)
    )
    session.delete(claim_session_key)
    render json: { accepted: true }, status: :accepted
  rescue Eip2771RewardClaimService::RequestExpired
    render json: { error: I18n.t("wallets.challenge_expired") }, status: :unprocessable_entity
  rescue ActionController::ParameterMissing, ArgumentError, KeyError => e
    Rails.logger.error("WalletsController#claim failed: #{e.class} #{e.message}")
    render json: { error: I18n.t("wallets.signature_invalid") }, status: :unprocessable_entity
  end

  #
  # Creates the signed EIP-712 payload for an allowed cashier operation.
  #
  def cashier_request
    prepared = Eip2771RewardClaimService.prepare_cashier_request!(
      user: current_user,
      data: params.require(:data),
      gas_limit: params.require(:gas).to_i
    )
    session[cashier_session_key] = {
      "user_id" => current_user.id,
      **prepared.fetch(:state)
    }
    render json: { typed_data: prepared.fetch(:typed_data) }
  rescue ArgumentError, KeyError, ActionController::ParameterMissing => e
    Rails.logger.error("WalletsController#cashier_request failed: #{e.class} #{e.message}")
    render json: { error: I18n.t("wallets.cashier_unavailable") }, status: :unprocessable_entity
  end

  #
  # Validates the signed cashier request and queues its on-chain relay.
  #
  def cashier
    state = session[cashier_session_key]
    Eip2771RewardClaimService.enqueue_cashier!(
      user: current_user,
      state: state,
      signature: params.require(:signature)
    )
    session.delete(cashier_session_key)
    render json: { accepted: true }, status: :accepted
  rescue Eip2771RewardClaimService::RequestExpired
    render json: { error: I18n.t("wallets.challenge_expired") }, status: :unprocessable_entity
  rescue ArgumentError, KeyError, ActionController::ParameterMissing => e
    Rails.logger.error("WalletsController#cashier failed: #{e.class} #{e.message}")
    render json: { error: I18n.t("wallets.signature_invalid") }, status: :unprocessable_entity
  end

  private

  #
  # Authorizes management of the authenticated user's wallets.
  #
  def authorize_wallet_management!
    authorize current_user, :update?
  end

  #
  # Returns the per-user session key for wallet ownership challenges.
  #
  def challenge_session_key
    "wallet_connect_challenge_#{current_user.id}"
  end

  #
  # Returns the per-user session key for reward claim requests.
  #
  def claim_session_key
    "eip2771_reward_claim_#{current_user.id}"
  end

  #
  # Returns the per-user session key for cashier requests.
  #
  def cashier_session_key
    "eip2771_cashier_#{current_user.id}"
  end
end
