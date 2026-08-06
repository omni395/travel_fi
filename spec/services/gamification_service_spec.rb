# frozen_string_literal: true

require 'rails_helper'

#
# GamificationService — unit-спек наград токенами TFT.
#
# Покрытие:
# 1. award! начисляет сумму из config/gamification.yml в user_rewards
# 2. Нет начисления для отсутствующего ключа
# 3. Бейджи: first_poi (badge_id 2) при условии user.pois.count == 1
#
RSpec.describe GamificationService, type: :service do
  let(:rewards) { YAML.safe_load_file(Rails.root.join('config/gamification.yml'))['rewards'] }
  let(:user) { create(:user) }

  describe '.award!' do
    it 'начисляет токены TFT из конфига в user_rewards (poi_create)' do
      amount = rewards['poi_create'].to_d

      expect { described_class.award!(:poi_create, user) }
        .to change { user.reload.token_balance }.by(amount)

      reward = user.user_rewards.last
      expect(reward.action_key).to eq('poi_create')
      expect(reward.amount).to eq(amount)
    end

    it 'начисляет comment_create из конфига' do
      amount = rewards['comment_create'].to_d

      expect { described_class.award!(:comment_create, user) }
        .to change { user.reload.token_balance }.by(amount)
    end

    it 'не начисляет для отсутствующего ключа' do
      expect { described_class.award!(:nonexistent_key, user) }
        .not_to change { user.reload.token_balance }
    end

    it 'выдаёт бейдж first_poi (badge_id 2) при первом POI' do
      create(:poi, user: user)

      described_class.award!(:poi_create, user)

      expect(user.reload.earned_badge?(2)).to be(true)
    end
  end
end
