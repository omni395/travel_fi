# frozen_string_literal: true

require 'rails_helper'

#
# VoteBroadcaster — unit-спек доставки live-обновления счётчика голосов.
#
# Покрывает маршрутизацию по стримам (адресная доставка) и то, что обновляются
# ТОЛЬКО числа-счётчики (text_content), а не каркас компонента (inner_html) —
# иначе в общем стриме стиралось бы персональное состояние каждого зрителя
# (is-active, выбранный голос), и повторные destroy/change были бы невозможны.
#
RSpec.describe VoteBroadcaster, type: :service do
  let(:author) { create(:user) }
  let(:voter) { create(:user) }
  let(:poi) { create(:poi, user: author, status: :approved) }
  let(:photo) { create(:photo, poi: poi, user: author) }
  let(:comment) { create(:poi_comment, poi: poi, user: author) }

  let(:cable_mock) { double('cable_ready') }

  # Мок CableReady-билдера: цепочка [] → text_content → broadcast.
  def build_cable_mock
    allow(cable_mock).to receive(:text_content).and_return(cable_mock)
    allow(cable_mock).to receive(:broadcast)
    cable_mock
  end

  def build_broadcaster(votable)
    b = described_class.new(votable: votable)
    allow(b).to receive(:cable_ready).and_return(build_cable_mock)
    b
  end

  # Таргет-селекторы внутри таргет-обёртки [data-vote-zone=...].
  def zone_selectors(votable_key, id)
    zone = "[data-vote-zone='#{votable_key}-#{id}']"
    {
      up: "#{zone} [data-vote-counter='up']",
      down: "#{zone} [data-vote-counter='down']",
      hint: "#{zone} [data-vote-counter='hint']"
    }
  end

  describe 'POI' do
    it 'шлёт text_content счётчиков в стрим pois_map' do
      create(:vote, votable: poi, user: voter, value: 1)

      b = build_broadcaster(poi)
      expect(cable_mock).to receive(:[]).with('pois_map').and_return(cable_mock)
      selectors = zone_selectors('poi', poi.id)
      expect(cable_mock).to receive(:text_content).with(selector: selectors[:up], text: '1')
      expect(cable_mock).to receive(:text_content).with(selector: selectors[:down], text: '0')
      expect(cable_mock).to receive(:text_content).with(selector: selectors[:hint], text: '1 vote(s)')

      b.broadcast
    end
  end

  describe 'Photo (галерея)' do
    it 'шлёт text_content счётчиков в стрим pois_map по таргету photo-<id>' do
      create(:vote, votable: photo, user: voter, value: -1)

      b = build_broadcaster(photo)
      expect(cable_mock).to receive(:[]).with('pois_map').and_return(cable_mock)
      selectors = zone_selectors('photo', photo.id)
      expect(cable_mock).to receive(:text_content).with(selector: selectors[:up], text: '0')
      expect(cable_mock).to receive(:text_content).with(selector: selectors[:down], text: '1')
      expect(cable_mock).to receive(:text_content).with(selector: selectors[:hint], text: '1 vote(s)')

      b.broadcast
    end
  end

  describe 'PoiComment' do
    it 'шлёт text_content счётчиков в личный стрим автора user_<author_id>' do
      b = build_broadcaster(comment)
      expect(cable_mock).to receive(:[]).with("user_#{author.id}").and_return(cable_mock)
      selectors = zone_selectors('poi_comment', comment.id)
      expect(cable_mock).to receive(:text_content).with(selector: selectors[:up], text: '0')
      expect(cable_mock).to receive(:text_content).with(selector: selectors[:down], text: '0')
      expect(cable_mock).to receive(:text_content).with(selector: selectors[:hint], text: '0 vote(s)')

      b.broadcast
    end
  end

  describe 'устойчивость' do
    it 'не роняет broadcast при сбое (счётчик голосов не критичен)' do
      b = build_broadcaster(poi)
      allow(VoteService).to receive(:tally).and_raise(StandardError, 'boom')

      expect { b.broadcast }.not_to raise_error
    end
  end
end
