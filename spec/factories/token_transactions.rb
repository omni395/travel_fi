# frozen_string_literal: true

#
# Фабрика TokenTransaction — запись журнала движения токенов TFT.
#
FactoryBot.define do
  factory :token_transaction do
    user
    amount { 10 }
    direction { :credit }
    action_key { 'registration' }
    status { :pending }
    chain_id { (ENV['CHAIN_ID'] || '0x14a34').to_i(16).to_s }
  end
end
