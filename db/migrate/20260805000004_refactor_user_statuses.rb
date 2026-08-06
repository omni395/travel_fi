# frozen_string_literal: true

#
# Переработка статусов пользователей (чистая модель):
#   registered + pending_verification → pending (зарегистрирован, email не подтверждён)
#   default статуса: registered → pending
#   inactive — добавляется в enum модели (без миграции данных).
#
class RefactorUserStatuses < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE users SET status = 'pending'
      WHERE status IN ('registered', 'pending_verification')
    SQL

    change_column_default :users, :status, 'pending'
  end

  def down
    change_column_default :users, :status, 'registered'
  end
end
