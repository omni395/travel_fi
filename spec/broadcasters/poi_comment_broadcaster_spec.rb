# frozen_string_literal: true

require 'rails_helper'

#
# PoiCommentBroadcaster — unit-тест live-события о создании комментария.
#
RSpec.describe PoiCommentBroadcaster, type: :service do
  let(:comment) { create(:poi_comment) }
  let(:broadcaster) { described_class.new(comment: comment) }
  let(:cable_mock) { double('cable_ready') }

  before do
    allow(broadcaster).to receive(:cable_ready).and_return(cable_mock)
    allow(cable_mock).to receive(:[]).with("user_#{comment.user_id}").and_return(cable_mock)
    allow(cable_mock).to receive(:dispatch_event)
    allow(cable_mock).to receive(:broadcast)
  end

  it 'шлёт событие poi:comment-created в стрим автора' do
    expect(cable_mock).to receive(:dispatch_event).with(
      name: 'poi:comment-created',
      detail: { poi_id: comment.poi_id, comment_id: comment.id }
    )

    broadcaster.broadcast
  end

  it 'бродкастит в user_<id>' do
    expect(cable_mock).to receive(:broadcast)

    broadcaster.broadcast
  end
end
