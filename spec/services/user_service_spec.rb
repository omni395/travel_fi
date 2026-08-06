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
  end
end
