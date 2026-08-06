# frozen_string_literal: true

require 'rails_helper'

#
# PoiCommentPolicy — unit-спек политики комментариев к POI.
#
# Покрытие:
# 1. index/show — все (включая гостей)
# 2. create — аутентифицированные в радиусе 100м (proximity через Current)
# 3. update — автор или admin (с proximity)
# 4. destroy — автор или admin
#
RSpec.describe PoiCommentPolicy, type: :policy do
  let(:poi) { create(:poi) } # координаты: 50.4501, 30.5234
  let(:author) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:moderator) { create(:user, :moderator) }
  let(:guest) { nil }
  let(:comment) { create(:poi_comment, poi: poi, user: author) }

  # Сбрасываем proximity-координаты (Current) между примерами
  around do |example|
    Current.user_lat = nil
    Current.user_lng = nil
    example.run
    Current.user_lat = nil
    Current.user_lng = nil
  end

  describe 'index/show' do
    it 'доступны всем, включая гостей' do
      expect(described_class.new(guest, comment).index?).to be(true)
      expect(described_class.new(guest, comment).show?).to be(true)
    end
  end

  describe 'create?' do
    it 'запрещён гостю' do
      expect(described_class.new(guest, PoiComment.new(poi: poi, user: nil)).create?).to be(false)
    end

    it 'разрешён админу/модератору без проверки расстояния' do
      expect(described_class.new(admin, PoiComment.new(poi: poi, user: admin)).create?).to be(true)
      expect(described_class.new(moderator, PoiComment.new(poi: poi, user: moderator)).create?).to be(true)
    end

    it 'разрешён аутентифицированному в радиусе 100м' do
      Current.user_lat = 50.4501
      Current.user_lng = 30.5234

      expect(described_class.new(author, PoiComment.new(poi: poi, user: author)).create?).to be(true)
    end

    it 'запрещён аутентифицированному дальше 100м' do
      Current.user_lat = 51.0
      Current.user_lng = 30.0

      expect(described_class.new(author, PoiComment.new(poi: poi, user: author)).create?).to be(false)
    end
  end

  describe 'update?' do
    it 'разрешён автору и админу в радиусе 100м' do
      Current.user_lat = 50.4501
      Current.user_lng = 30.5234

      expect(described_class.new(author, comment).update?).to be(true)
      expect(described_class.new(admin, comment).update?).to be(true)
    end

    it 'запрещён чужому обычному юзеру' do
      Current.user_lat = 50.4501
      Current.user_lng = 30.5234

      expect(described_class.new(other_user, comment).update?).to be(false)
    end
  end

  describe 'destroy?' do
    it 'разрешён автору и админу' do
      expect(described_class.new(author, comment).destroy?).to be(true)
      expect(described_class.new(admin, comment).destroy?).to be(true)
    end

    it 'запрещён чужому и гостю' do
      expect(described_class.new(other_user, comment).destroy?).to be(false)
      expect(described_class.new(guest, comment).destroy?).to be(false)
    end
  end
end
