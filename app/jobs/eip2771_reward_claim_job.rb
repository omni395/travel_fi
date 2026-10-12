# frozen_string_literal: true

class Eip2771RewardClaimJob < ApplicationJob
  queue_as :default

  def perform(user_id, transaction_ids, request, signature)
    Eip2771RewardClaimService.relay!(
      user_id: user_id,
      transaction_ids: transaction_ids,
      request: request,
      signature: signature
    )
  end
end
