class AddUserProfileFields < ActiveRecord::Migration[8.1]
  def change
    # User profile основные поля
    add_column :users, :name, :string, null: false, default: "User"
    
    # Статус пользователя (enum)
    add_column :users, :status, :string, default: "registered"
    
    # OAuth поля
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    
    # Devise Confirmable модуль - для подтверждения email
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string
    
    # Referral code
    add_column :users, :referral_code, :string
    
    # Web3 / Wallet
    add_column :users, :wallet_address, :string
    add_column :users, :wallet_provider, :string
    add_column :users, :wallet_provider_id, :string
    
    # Indices для оптимизации
    add_index :users, :name
    add_index :users, :status
    add_index :users, [:provider, :uid], unique: true, where: "provider IS NOT NULL"
    add_index :users, :confirmation_token, unique: true
    add_index :users, :referral_code, unique: true, where: "referral_code IS NOT NULL"
    add_index :users, :wallet_address, unique: true, where: "wallet_address IS NOT NULL"
  end
end
