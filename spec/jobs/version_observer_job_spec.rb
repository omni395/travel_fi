# frozen_string_literal: true

require 'rails_helper'

#
# VersionObserverJob — unit-спек маршрутизации PaperTrail-версий.
#
# Покрытие ветки handle_poi_update:
# 1. create/update POI → PoiBroadcaster + Admin::DashboardBroadcaster.stats
# 2. destroy POI → только stats (PoiBroadcaster не вызывается)
# 3. audit-only события игнорируются
#
RSpec.describe VersionObserverJob, type: :job do
  describe 'Poi-ветка (#handle_poi_update)' do
    it 'вызывает PoiBroadcaster и stats при создании POI' do
      poi = create(:poi)
      version = poi.versions.last

      expect(PoiBroadcaster).to receive(:call).with(poi: poi)
      expect(Admin::DashboardBroadcaster).to receive(:broadcast_stats_update)

      described_class.perform_now(version.id)
    end

    it 'вызывает PoiBroadcaster при обновлении POI' do
      poi = create(:poi)
      poi.update!(city: 'Kyiv')
      version = poi.versions.last

      expect(PoiBroadcaster).to receive(:call).with(poi: poi)
      expect(Admin::DashboardBroadcaster).to receive(:broadcast_stats_update)

      described_class.perform_now(version.id)
    end

    it 'не вызывает PoiBroadcaster при destroy POI' do
      poi = create(:poi)
      poi.destroy!
      version = PaperTrail::Version.where(item_type: 'Poi', item_id: poi.id).last
      expect(version.event).to eq('destroy')

      expect(PoiBroadcaster).not_to receive(:call)

      described_class.perform_now(version.id)
    end
  end

  describe 'PoiComment-ветка (#handle_poi_comment_update — live-комментарии)' do
    it 'вызывает PoiCommentBroadcaster при создании комментария' do
      # Спецификация: комментарии должны доставляться live всем подписанным.
      # Сейчас ветки handle_poi_comment_update в job НЕТ — тест падает (A-баг,
      # ROADMAP 2.2 «live-комментарии для всех»).
      comment = create(:poi_comment)
      version = comment.versions.last

      expect(PoiCommentBroadcaster).to receive(:call).with(comment: comment)

      described_class.perform_now(version.id)
    end
  end

  describe 'игнорирование audit-only событий' do
    it 'пропускает версии из AUDIT_ONLY_EVENTS' do
      user = create(:user)
      user.versions.create!(event: 'login', whodunnit: user.id.to_s)

      expect(PoiBroadcaster).not_to receive(:call)
      expect(Admin::DashboardBroadcaster).not_to receive(:broadcast_stats_update)

      described_class.perform_now(user.versions.last.id)
    end
  end
end
