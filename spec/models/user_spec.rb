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
end
