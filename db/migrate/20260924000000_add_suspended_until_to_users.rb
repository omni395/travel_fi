# frozen_string_literal: true

#
# Добавляет точную дату окончания пенализации (suspended_until) к пользователю.
#
# Нужна для плашки «Комментирование недоступно до <дата>» у suspended-юзера:
# дата живёт в БД, а не вычисляется из updated_at + срока — даже если
# UnlockSuspendedUserJob опоздает, guard и плашка читают точное значение.
#
class AddSuspendedUntilToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :suspended_until, :datetime
  end
end
