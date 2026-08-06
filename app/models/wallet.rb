# frozen_string_literal: true

#
# Wallet — кошелёк пользователя.
#
# kind:
#   - 'custodial' — скрытый кошелёк платформы (private key зашифрован у нас)
#   - 'external'  — собственный кошелёк пользователя (private key НЕ хранится)
#
class Wallet < ApplicationRecord
  # Аудит всех изменений кошелька.
  has_paper_trail

  belongs_to :user

  enum :kind, {
    custodial: 'custodial',
    external: 'external'
  }, validate: true

  validates :address, presence: true, uniqueness: true
  validates :chain_id, presence: true
  # Приватный ключ храним зашифрованным ТОЛЬКО для custodial-кошельков платформы.
  validates :encrypted_private_key, presence: true, if: :custodial?

  #
  # Возвращает расшифрованный приватный ключ (32 байта) для custodial-кошелька.
  # Для external-кошелька приватного ключа нет.
  #
  # @return [String, nil] приватный ключ
  #
  def private_key
    return nil unless custodial?

    WalletService.decrypt_private_key(self)
  end
end
