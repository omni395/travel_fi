# frozen_string_literal: true

#
# Добавляет поле claimed (boolean) в token_transactions — маркер лок-модели
# «получено/забрано».
#
# Отвечает за:
# - claimed = false → начисление не забрано (ждёт разблокировки по lock-периоду)
# - claimed = true  → начисление получено (on-chain отправлено через relay)
#
# Лок-период НЕ хранится отдельно: разблокировка определяется вычислением
# по `updated_at` + `lock_days` (см. GamificationService.pool_lock_days).
# Поле lock_until / claimed_at НЕ добавляем — это вычислимая процедура,
# а не данные. При успешном relay `updated_at` обновляется через update!
# (PaperTrail → broadcast), что и фиксирует момент получения.
#
class AddClaimedToTokenTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :token_transactions, :claimed, :boolean, null: false, default: false

    # Индекс для выборки скоупов available/locked (незабранные).
    add_index :token_transactions, [ :user_id, :claimed ]
  end
end
