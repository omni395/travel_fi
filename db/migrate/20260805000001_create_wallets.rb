# frozen_string_literal: true

#
# Создаёт таблицу wallets — кошельки пользователей.
#
# kind:
#   - 'custodial' — скрытый кошелёк платформы (private key зашифрован у нас)
#   - 'external'  — собственный кошелёк пользователя (private key НЕ хранится)
#
class CreateWallets < ActiveRecord::Migration[8.1]
  def change
    create_table :wallets do |t|
      t.string :address, null: false
      t.string :chain_id, null: false
      t.text :encrypted_private_key
      t.string :kind, null: false, default: 'custodial'
      t.bigint :user_id, null: false

      t.timestamps
    end

    add_index :wallets, :address, unique: true
    add_index :wallets, :user_id
    add_foreign_key :wallets, :users
  end
end
