# frozen_string_literal: true

require 'rails_helper'

#
# UserService — unit-спеки на новые фиксы: confirm_email (мутация вынесена из
# модели), mark_inactive_old_users (recurring-джоб), handle_google_oauth (OAuth).
#
RSpec.describe UserService, type: :service do
  describe '.confirm_email' do
    it 'переводит юзера из pending в active' do
      user = create(:user, :pending, :unconfirmed)

      expect { described_class.confirm_email(user) }
        .to change { user.reload.status }.from('pending').to('active')
    end
  end

  describe '.mark_inactive_old_users' do
    it 'переводит active юзера без активности за 6 месяцев в inactive' do
      user = create(:user, :active)
      # Эмулируем старую активность: последняя PaperTrail-версия — 7 месяцев назад
      user.versions.update_all(created_at: 7.months.ago)

      expect { described_class.mark_inactive_old_users }
        .to change { user.reload.status }.from('active').to('inactive')
    end

    it 'не трогает активного юзера с недавней активностью' do
      user = create(:user, :active)

      expect { described_class.mark_inactive_old_users }
        .not_to change { user.reload.status }
    end

    it 'не трогает юзера без версий (вне аудита)' do
      user = create(:user, :active)
      # Прямой delete (минуя ассоциацию): user.versions.delete_all триггерит
      # PaperTrail и пытается создать версию с item_id: nil (NotNullViolation).
      PaperTrail::Version.where(item_type: 'User', item_id: user.id).delete_all

      expect { described_class.mark_inactive_old_users }
        .not_to change { user.reload.status }
    end
  end

  describe '.handle_google_oauth' do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: 'google_oauth2',
        uid: 'google-uid-123',
        info: { email: 'oauth@example.com', name: 'Google User', image: nil }
      )
    end

    it 'создаёт юзера: роль, статус active, настройки, кошелёк, welcome-токены' do
      user = described_class.handle_google_oauth(auth)

      expect(user).to be_persisted
      expect(user).to have_role(:user)
      expect(user.status).to eq('active')
      expect(user.setting).to be_present
      expect(user.wallet).to be_present
      expect(user.token_balance).to be > 0
    end

    it 'идемпотентен: повторный вход находит существующего по uid' do
      described_class.handle_google_oauth(auth)

      expect { described_class.handle_google_oauth(auth) }.not_to change(User, :count)
    end

    it 'с рефкодом фиксирует реферальную связь и начисляет бонус обоим' do
      referrer = create(:user)

      user = described_class.handle_google_oauth(auth, referrer.referral_code)

      expect(user.referred_by).to eq(referrer)
      # Новый юзер: welcome 10 + referral_bonus_new_user 5
      expect(user.token_balance).to eq(15)
      # Реферер: referral_bonus_referrer 15
      expect(referrer.reload.token_balance).to eq(15)
      # Каждое начисление — отдельный TokenTransaction (welcome, new_user_bonus, referrer_bonus)
      expect(user.token_transactions.count).to eq(2)
      expect(referrer.token_transactions.count).to eq(1)
    end

    it 'с рефкодом ставит on-chain relay в очередь (SolidQueue)' do
      referrer = create(:user)

      # Отключаем реальный RPC: relay-job не должен падать в тесте.
      allow(TokenTransactionRelayJob).to receive(:perform_later)
      described_class.handle_google_oauth(auth, referrer.referral_code)

      expect(TokenTransactionRelayJob).to have_received(:perform_later).at_least(:once)
    end
  end

  describe '.award_registration_bonus!' do
    it 'без рефкода начисляет только welcome-токены (10)' do
      user = create(:user)

      expect { described_class.award_registration_bonus!(user) }
        .to change { user.reload.token_balance }.by(10)

      expect(user.referred_by).to be_nil
    end

    it 'с рефкодом начисляет обоим согласно плана и сохраняет referred_by' do
      referrer = create(:user)
      new_user = create(:user, referral_code_input: referrer.referral_code)

      # Реферальная связь персистится при регистрации отдельным шагом (save_referral!),
      # начисление (award_registration_bonus!) принимает один аргумент (user).
      described_class.save_referral!(new_user, referrer.referral_code)
      described_class.award_registration_bonus!(new_user)

      # Новому: welcome (10) + реферальный бонус новому (5) = 15
      expect(new_user.reload.token_balance).to eq(15)
      # Рефереру: реферальный бонус рефереру (15)
      expect(referrer.reload.token_balance).to eq(15)
      # Реферальная связь сохранена
      expect(new_user.referred_by).to eq(referrer)
      expect(referrer.referrals_count).to eq(1)
      # Журнал транзакций создан для обоих
      expect(new_user.token_transactions.count).to eq(2)
      expect(referrer.token_transactions.count).to eq(1)
    end
  end

  describe '.claim_rewards!' do
    it 'ставит relay-джоб только для разблокированных available-начислений' do
      user = create(:user)
      available_tx = create(:token_transaction, user: user, status: :pending, claimed: false,
                                                action_key: 'poi_create', created_at: 10.days.ago)
      locked_tx = create(:token_transaction, user: user, status: :pending, claimed: false,
                                             action_key: 'poi_create', created_at: Time.current)

      expect(TokenTransactionRelayJob).to receive(:perform_later).with(available_tx.id).once
      expect(TokenTransactionRelayJob).not_to receive(:perform_later).with(locked_tx.id)

      count = described_class.claim_rewards!(user)
      expect(count).to eq(1)
    end

    it 'возвращает 0, если нет разблокированных начислений' do
      user = create(:user)
      create(:token_transaction, user: user, status: :pending, claimed: false,
                                 action_key: 'poi_create', created_at: Time.current)

      count = described_class.claim_rewards!(user)
      expect(count).to eq(0)
    end
  end
end
