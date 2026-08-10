# frozen_string_literal: true

#
# Добавляет реферальную связь users.referred_by_id (self-join).
#
# Поле хранит пользователя, чей реферальный код был использован при регистрации.
# Служит для:
#   - начисления реферальных бонусов (15 — рефереру, 5 — новому)
#   - бейджа recruiter (user.referrals_count >= 5)
#   - отображения реферера/рефералов в админке
#
class AddReferredByToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :referred_by_id, :bigint
    add_index :users, :referred_by_id
    add_foreign_key :users, :users, column: :referred_by_id
  end
end
