# frozen_string_literal: true

require 'rails_helper'

#
# User — unit-тесты модели (валидации, роли, статусы, реферальный код,
# токены TFT, бейджи, кошелёк).
#
RSpec.describe User, type: :model do
  describe 'валидации' do
    it 'требует name' do
      expect(build(:user, name: nil)).not_to be_valid
    end

    it 'требует name не короче 2 символов' do
      expect(build(:user, name: 'A')).not_to be_valid
    end

    it 'требует уникальный email' do
      existing = create(:user)
      expect(build(:user, email: existing.email)).not_to be_valid
    end
  end

  describe 'роли' do
    it 'назначает роль :user при создании' do
      expect(create(:user)).to have_role(:user)
    end

    it 'admin?/moderator? для соответствующих ролей' do
      expect(create(:user, :admin)).to be_admin
      expect(create(:user, :moderator)).to be_moderator
    end
  end

  describe 'статусы (scopes)' do
    it 'фильтрует по статусам' do
      create(:user, :active)
      create(:user, :suspended)
      create(:user, :banned)

      expect(User.active.count).to eq(1)
      expect(User.suspended.count).to eq(1)
      expect(User.banned.count).to eq(1)
    end
  end

  describe 'реферальный код' do
    it 'генерирует код при создании' do
      user = create(:user)
      expect(user.referral_code).to be_present
      expect(user.referral_code.length).to eq(8)
    end

    it 'невалиден при несуществующем referral_code_input' do
      user = build(:user, referral_code_input: 'NOPE1234')
      expect(user).not_to be_valid
      expect(user.errors[:referral_code_input]).to be_present
    end
  end

  describe 'токены TFT' do
    it 'token_balance считает начисления' do
      user = create(:user)
      expect(user.token_balance).to eq(0)

      GamificationService.award!(:registration, user)

      expect(user.reload.token_balance).to eq(10)
    end
  end

  describe 'бейджи' do
    it 'выдаёт и проверяет бейджи' do
      user = create(:user)

      GamificationService.grant_badge!(user, 1)

      expect(user).to be_earned_badge(1)
      expect(user.badge_ids).to include(1)
    end
  end

  describe 'кошелёк' do
    it 'возвращает custodial-кошелёк' do
      user = create(:user)
      wallet = WalletService.create_hidden_wallet(user: user)

      expect(user.reload.wallet).to eq(wallet)
    end
  end

  describe 'реферальная связь' do
    it 'сохраняет реферера (referred_by) и считает рефералов' do
      referrer = create(:user)
      referred = create(:user, referred_by: referrer)

      expect(referred.referred_by).to eq(referrer)
      expect(referrer.referrals).to include(referred)
      expect(referrer.referrals_count).to eq(1)
    end
  end

  describe 'friendly_id slug' do
    it 'генерирует slug из имени при создании' do
      user = create(:user, name: 'John Doe')
      expect(user.slug).to eq('john-doe')
    end

    it 'перегенерирует slug при смене имени (should_generate_new_friendly_id?)' do
      user = create(:user, name: 'John Doe')
      user.update!(name: 'Jane Roe')
      expect(user.slug).to eq('jane-roe')
    end

    it 'использует fallback user-<id> для непараметризуемого имени' do
      user = create(:user, name: '!!')
      expect(user.slug).to start_with('user-')
    end

    it 'уникализирует slug при коллизии' do
      user1 = create(:user, name: 'Same Name')
      user2 = create(:user, name: 'Same Name')
      expect(user1.slug).to eq('same-name')
      expect(user2.slug).not_to eq(user1.slug)
    end
  end

  describe '.from_google_oauth' do
    it 'принимает реферальный код (2 аргумента) без ArgumentError' do
      referrer = create(:user)
      auth = OmniAuth::AuthHash.new(
        provider: 'google_oauth2',
        uid: 'google-uid-signature',
        info: { email: 'oauth-sig@example.com', name: 'Sig User', image: nil }
      )

      expect do
        allow(TokenTransactionRelayJob).to receive(:perform_later)
        User.from_google_oauth(auth, referrer.referral_code)
      end.not_to raise_error
    end
  end
end
