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

      # CREATE — статус не переходит (guard по event == "update"), поэтому
      # change_status всегда false даже для pending-точки (иначе pending-маркер
      # ложно попадал бы на карту).
      expect(PoiBroadcaster).to receive(:call).with(poi: poi, change_status: false)
      expect(Admin::DashboardBroadcaster).to receive(:broadcast_stats_update)

      described_class.perform_now(version.id)
    end

    it 'вызывает PoiBroadcaster при обновлении POI' do
      poi = create(:poi)
      poi.update!(city: 'Kyiv')
      version = poi.versions.last

      # UPDATE без смены статуса (city) → change_status: false
      expect(PoiBroadcaster).to receive(:call).with(poi: poi, change_status: false)
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

  describe 'status_change? (#handle_poi_update, переход pending→approved)' do
    it 'передаёт change_status: true, когда статус изменился и object_changes — строка JSON из БД' do
      # Runtime-сценарий: SolidQueue worker перечитывает версию из БД, где
      # object_changes (колонка text + PaperTrail::Serializers::JSON) — это СТРОКА
      # JSON, а не Hash. Раньше status_change? проверял is_a?(Hash) → всегда false →
      # change_status не пробрасывался → feature-нода не добавлялась в
      # #poi-map-features → одобренная точка не появлялась на карте без перезагрузки.
      poi = create(:poi, status: :pending)
      # Генерируем UPDATE-версию именно со сменой статуса (переход pending→approved).
      # CREATE-версия игнорируется (guard по event == "update"), поэтому нужна
      # последняя версия ПОСЛЕ update! — её object_changes содержит ключ "status".
      poi.update!(status: :approved)
      version = poi.versions.last
      expect(version.event).to eq('update')

      # Реальный сериализованный формат колонки (text + JSON-сериализатор)
      version.update_columns(
        object_changes: {
          'status' => [ 0, 1 ],
          'name' => [ { 'en' => 'a' }, { 'en' => 'b' } ]
        }.to_json
      )
      # Перечитываем из БД, как это делает SolidQueue worker
      version.reload
      expect(version.object_changes).to be_a(String)

      expect(PoiBroadcaster).to receive(:call).with(poi: poi, change_status: true)
      expect(Admin::DashboardBroadcaster).to receive(:broadcast_stats_update)

      described_class.perform_now(version.id)
    end

    it 'передаёт change_status: false, когда object_changes — строка JSON без смены статуса' do
      poi = create(:poi, status: :approved)
      poi.update!(city: 'Berlin')
      version = poi.versions.last

      # object_changes без ключа status (строка из БД)
      version.update_columns(object_changes: { 'city' => [ 'Kyiv', 'Berlin' ] }.to_json)
      version.reload

      expect(PoiBroadcaster).to receive(:call).with(poi: poi, change_status: false)
      expect(Admin::DashboardBroadcaster).to receive(:broadcast_stats_update)

      described_class.perform_now(version.id)
    end

    it 'корректно обрабатывает битую JSON-строку object_changes (rescue → false)' do
      poi = create(:poi, status: :approved)
      poi.update!(city: 'Berlin')
      version = poi.versions.last

      version.update_columns(object_changes: 'broken { not json')
      version.reload

      expect(PoiBroadcaster).to receive(:call).with(poi: poi, change_status: false)
      expect(Admin::DashboardBroadcaster).to receive(:broadcast_stats_update)

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

  describe 'TokenTransaction-ветка (#handle_token_transaction_update)' do
    it 'вызывает TokenTransactionBroadcaster при создании транзакции' do
      tx = create(:token_transaction)
      version = tx.versions.last

      expect(TokenTransactionBroadcaster).to receive(:call).with(token_transaction: tx)

      described_class.perform_now(version.id)
    end
  end

  describe 'User-ветка (#handle_user_update)' do
    it 'user-initiated update → UserBroadcaster + Admin::UserBroadcaster + stats' do
      user = create(:user)
      user.update!(name: 'New Name')
      version = user.versions.last

      expect(UserBroadcaster).to receive(:call).with(user: user)
      expect(Admin::UserBroadcaster).to receive(:broadcast_user_update).with(user)
      expect(Admin::DashboardBroadcaster).to receive(:broadcast_stats_update)

      described_class.perform_now(version.id)
    end

    it 'admin-initiated update → БЕЗ UserBroadcaster (только админ-бродкаст)' do
      admin = create(:user, :admin)
      user = create(:user)
      user.update!(name: 'New Name')
      version = user.versions.last
      version.update_column(:whodunnit, admin.id.to_s)

      expect(UserBroadcaster).not_to receive(:call)
      expect(Admin::UserBroadcaster).to receive(:broadcast_user_update).with(user)
      expect(Admin::DashboardBroadcaster).to receive(:broadcast_stats_update)

      described_class.perform_now(version.id)
    end

    it 'destroy → только stats (без UserBroadcaster)' do
      user = create(:user)
      version = PaperTrail::Version.create!(
        item_type: 'User',
        item_id: user.id,
        event: 'destroy',
        whodunnit: user.id.to_s
      )

      expect(UserBroadcaster).not_to receive(:call)
      expect(Admin::DashboardBroadcaster).to receive(:broadcast_stats_update)

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
