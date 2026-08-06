# frozen_string_literal: true

require 'rails_helper'

#
# PoiPolicy — unit-спек политики доступа к POI.
#
# Покрытие:
# 1. Методы: index/show/create/update/destroy/moderate для разных ролей
# 2. Scope: admin всё, обычный юзер — approved + свои, гость — approved
#
RSpec.describe PoiPolicy, type: :policy do
  let(:owner) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:moderator) { create(:user, :moderator) }
  let(:guest) { nil }
  let(:poi) { create(:poi, user: owner) }

  # Хелпер: создаёт политику с конкретным пользователем
  def policy_for(user, record = poi)
    described_class.new(user, record)
  end

  describe 'методы' do
    it 'index и show доступны всем (включая гостей)' do
      expect(policy_for(guest).index?).to be(true)
      expect(policy_for(guest).show?).to be(true)
      expect(policy_for(owner).index?).to be(true)
      expect(policy_for(owner).show?).to be(true)
    end

    it 'create доступен аутентифицированным' do
      expect(policy_for(owner).create?).to be(true)
      expect(policy_for(guest).create?).to be(false)
    end

    it 'update доступен владельцу, админу и модератору' do
      expect(policy_for(owner).update?).to be(true)
      expect(policy_for(admin).update?).to be(true)
      expect(policy_for(moderator).update?).to be(true)
    end

    it 'update запрещён чужому обычному юзеру' do
      expect(policy_for(other_user).update?).to be(false)
    end

    it 'destroy доступен только админу' do
      expect(policy_for(admin).destroy?).to be(true)
      expect(policy_for(moderator).destroy?).to be(false)
      expect(policy_for(owner).destroy?).to be(false)
    end

    it 'moderate доступен админу и модератору' do
      expect(policy_for(admin).moderate?).to be(true)
      expect(policy_for(moderator).moderate?).to be(true)
      expect(policy_for(owner).moderate?).to be(false)
    end
  end

  describe 'Scope' do
    it 'админ и модератор видят все POI' do
      create(:poi, :pending)
      create(:poi)

      expect(described_class::Scope.new(admin, Poi.all).resolve.count).to eq(Poi.count)
      expect(described_class::Scope.new(moderator, Poi.all).resolve.count).to eq(Poi.count)
    end

    it 'обычный юзер видит approved POI и свои' do
      approved = create(:poi, status: :approved)
      own = create(:poi, :pending, user: other_user)
      create(:poi, :pending, user: create(:user))

      resolve = described_class::Scope.new(other_user, Poi.all).resolve

      expect(resolve).to include(approved)
      expect(resolve).to include(own)
    end

    it 'гость видит approved POI (публичная карта)' do
      approved = create(:poi, status: :approved)
      create(:poi, :pending)

      resolve = described_class::Scope.new(guest, Poi.all).resolve

      expect(resolve).to contain_exactly(approved)
    end
  end
end
