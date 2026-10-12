# frozen_string_literal: true

class Eip2771CashierJob < ApplicationJob
  queue_as :default

  def perform(user_id, request, signature)
    Eip2771RewardClaimService.relay_cashier!(
      user_id:,
      request:,
      signature:
    )
  end
end
