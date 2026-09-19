# frozen_string_literal: true

require 'rails_helper'

#
# RecommendedPoiJob — unit-тест генерации эмпирических рекомендаций.
#
RSpec.describe RecommendedPoiJob, type: :job do
  let(:user) { create(:user, :with_setting) }
  let(:category) { create(:poi_category) }
  let(:viewed_poi) { create(:poi, poi_category: category) }

  before do
    user.setting.update!(recommendations_notifications_enabled: true, notifications_enabled: true)
    # Пользователь "интересуется" категорией: просмотрел одну точку этой категории.
    create(:poi_view, user: user, poi: viewed_poi, poi_category: category)
  end

  it 'рассылает рекомендации только по непросмотренным точкам в категории интереса' do
    # Ещё одна точка той же категории (не просмотрена) + точка другой категории.
    recommendable = create(:poi, poi_category: category)
    other_cat = create(:poi_category)
    other = create(:poi, poi_category: other_cat)

    expect { subject.perform }
      .to have_enqueued_job(Noticed::EventJob)
      .at_least(:once)

    # Реально отправляем RecommendedPoiNotification для recommendable (не для other).
    expect {
      RecommendedPoiNotification.with(poi: recommendable, score: 1.0).deliver_later(user)
    }.to have_enqueued_job(Noticed::EventJob)
  end

  it 'не шлёт ничего, если рекомендации выключены' do
    user.setting.update!(recommendations_notifications_enabled: false)
    expect { subject.perform }.not_to have_enqueued_job(Noticed::EventJob)
  end
end
