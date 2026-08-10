# frozen_string_literal: true

#
# Создаёт таблицу user_rewards — off-chain леджер начислений токенов TFT.
#
# Здесь фиксируется НАЧИСЛЕНИЕ (amount в TFT, decimals 18);
# фактическая on-chain отправка на custodial-кошелёк — через
# TokenTransactionService.relay! — отдельная интеграция.
#
class CreateUserRewards < ActiveRecord::Migration[8.1]
  def change
    create_table :user_rewards do |t|
      t.decimal :amount, precision: 30, scale: 18, null: false
      t.string :action_key, null: false
      t.text :log
      t.bigint :user_id, null: false
      t.bigint :wallet_id

      t.timestamps
    end

    add_index :user_rewards, :user_id
    add_index :user_rewards, :wallet_id
    add_index :user_rewards, :action_key
    add_foreign_key :user_rewards, :users
    add_foreign_key :user_rewards, :wallets
  end
end
