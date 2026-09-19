# frozen_string_literal: true

require 'rails_helper'

#
# PoiCommentBroadcaster — unit-спек live-событий комментариев (create/update/destroy).
#
# Покрытие:
#   1. create — insert_adjacent_html (beforeend) в [data-comments-list='poi-X'];
#   2. update — insert_adjacent_html (afterbegin) в тот же контейнер;
#   3. destroy — remove ноды [data-comment-id='X'] у публичных зрителей;
#   4. dispatch_event родителю-автору ветки (poi:comment-reply).
#
RSpec.describe PoiCommentBroadcaster, type: :service do
  let(:poi) { create(:poi) }
  let(:parent_author) { create(:user) }
  let(:root) { create(:poi_comment, poi: poi, user: parent_author) }
  let(:comment) { create(:poi_comment, poi: poi, parent: root) }
  let(:cable_mock) { double('cable_ready') }
  let(:pois_map_mock) { double('pois_map') }

  before do
    allow_any_instance_of(described_class).to receive(:cable_ready).and_return(cable_mock)
    allow(cable_mock).to receive(:[]).with('pois_map').and_return(pois_map_mock)
    allow(cable_mock).to receive(:[]).with("user_#{parent_author.id}").and_return(cable_mock)
    allow(cable_mock).to receive(:dispatch_event)
    allow(cable_mock).to receive(:broadcast)
    allow(pois_map_mock).to receive(:insert_adjacent_html)
    allow(pois_map_mock).to receive(:remove)
    allow_any_instance_of(described_class).to receive(:render_comment_component).and_return('<div>comment</div>')
  end

  context 'create' do
    it 'insert_adjacent_html (beforeend) в контейнер списка комментариев' do
      broadcaster = described_class.new(comment: comment, event: :create)

      expect(pois_map_mock).to receive(:insert_adjacent_html).with(
        selector: "[data-comments-list='poi-#{comment.poi_id}']",
        position: 'beforeend',
        html: '<div>comment</div>'
      )

      broadcaster.broadcast
    end

    it 'dispatch_event автору родителя (poi:comment-reply)' do
      broadcaster = described_class.new(comment: comment, event: :create)

      expect(cable_mock).to receive(:dispatch_event).with(
        name: 'poi:comment-reply',
        detail: { poi_id: comment.poi_id, comment_id: comment.id, author: comment.user&.name }
      )

      broadcaster.broadcast
    end
  end

  context 'update' do
    it 'insert_adjacent_html (afterbegin) в контейнер списка' do
      broadcaster = described_class.new(comment: comment, event: :update)

      expect(pois_map_mock).to receive(:insert_adjacent_html).with(
        selector: "[data-comments-list='poi-#{comment.poi_id}']",
        position: 'afterbegin',
        html: '<div>comment</div>'
      )

      broadcaster.broadcast
    end
  end

  context 'destroy' do
    it 'remove ноды [data-comment-id] у публичных зрителей' do
      broadcaster = described_class.new(comment: comment, event: :destroy)

      expect(pois_map_mock).to receive(:remove).with(
        selector: "[data-comment-id='#{comment.id}']"
      )

      broadcaster.broadcast
    end
  end
end
