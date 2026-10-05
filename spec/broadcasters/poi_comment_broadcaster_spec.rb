# frozen_string_literal: true

require 'rails_helper'

#
# PoiCommentBroadcaster — unit-спек live-событий комментариев (create/update/destroy).
#
# Покрытие:
#   1. create корня — insert_adjacent_html (beforeend) в [data-comments-list='poi-X'];
#   2. create ответа — insert_adjacent_html (beforeend) в [data-comment-children] родителя
#      (вложенность вместо top-level дубля);
#   3. update — inner_html на [data-comment-content] конкретного комментария
#      (БЕЗ самовложения обёртки [data-comment-id]);
#   4. destroy — remove ноды [data-comment-id='X'] у публичных зрителей;
#   5. dispatch_event родителю-автору ветки (poi:comment-reply).
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
    allow(pois_map_mock).to receive(:inner_html)
    allow(pois_map_mock).to receive(:remove)
    allow(pois_map_mock).to receive(:dispatch_event)
    allow_any_instance_of(described_class).to receive(:render_comment_component).and_return('<div>comment</div>')
    allow_any_instance_of(described_class).to receive(:render_comment_content_component).and_return('<p>body</p>')
  end

  context 'create корня (без родителя)' do
    let(:comment) { create(:poi_comment, poi: poi, user: parent_author) }

    it 'insert_adjacent_html (beforeend) в контейнер списка комментариев' do
      broadcaster = described_class.new(comment: comment, event: :create)

      expect(pois_map_mock).to receive(:insert_adjacent_html).with(
        selector: "[data-comments-list='poi-#{comment.poi_id}']",
        position: 'beforeend',
        html: '<div>comment</div>'
      )

      broadcaster.broadcast
    end
  end

  context 'create ответа (с родителем)' do
    it 'insert_adjacent_html в [data-comment-children] родителя ВМЕСТО top-level списка' do
      broadcaster = described_class.new(comment: comment, event: :create)

      expect(pois_map_mock).to receive(:insert_adjacent_html).with(
        selector: "[data-comment-id='#{comment.parent_id}'] [data-comment-children]",
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
    it 'inner_html на [data-comment-content] + dispatch poi:comment-updated (раскрытие кнопок)' do
      broadcaster = described_class.new(comment: comment, event: :update)

      expect(pois_map_mock).to receive(:inner_html).with(
        selector: "[data-comment-id='#{comment.id}'] [data-comment-content]",
        html: '<p>body</p>'
      )
      # После live-правки контент вставлен заново (Stimulus не пересканирует) —
      # бродкастер шлёт событие на обёртку, контроллер повторно раскрывает кнопки.
      expect(pois_map_mock).to receive(:dispatch_event).with(
        name: "poi:comment-updated",
        selector: "[data-comment-id='#{comment.id}']",
        detail: { poi_id: comment.poi_id, comment_id: comment.id }
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
