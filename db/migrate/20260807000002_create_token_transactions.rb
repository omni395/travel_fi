# frozen_string_literal: true

#
# Создаёт таблицу token_transactions — журнал движения токенов TFT.
#
# Каждое начисление (UserReward, off-chain леджер) порождает запись TokenTransaction
# (direction = credit) в единой транзакции. Поле tx_hash остаётся пустым до on-chain
# отправки через релей (EIP-2771) — после отправки сюда записывается хэш транзакции
# в сети, по которому админка строит ссылку на explorer (выжимка 4+4 символа).
#
# direction: credit (приход) / debit (расход — будущий Token Spend)
# status:    pending (начислено off-chain, on-chain не отправлено)
#            confirmed (tx_hash заполнен, on-chain подтверждено)
#            failed (on-chain отправка упала)
#
class CreateTokenTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :token_transactions do |t|
      t.decimal :amount, precision: 30, scale: 18, null: false
      t.string :direction, null: false, default: 'credit'
      t.string :action_key, null: false
      t.string :tx_hash
      t.string :status, null: false, default: 'pending'
      t.string :chain_id, null: false
      t.jsonb :metadata, default: {}
      t.bigint :user_id, null: false
      t.bigint :wallet_id
      t.bigint :user_reward_id

      t.timestamps
    end

    add_index :token_transactions, :user_id
    add_index :token_transactions, :wallet_id
    add_index :token_transactions, :user_reward_id, unique: true
    add_index :token_transactions, :action_key
    add_index :token_transactions, :status
    add_foreign_key :token_transactions, :users
    add_foreign_key :token_transactions, :wallets
    add_foreign_key :token_transactions, :user_rewards
  end
end
