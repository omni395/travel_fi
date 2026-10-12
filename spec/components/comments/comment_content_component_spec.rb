# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comments::CommentContentComponent, type: :helper do
  it 'находит правку тела, когда object_changes загружен из БД как JSON-строка' do
    comment = create(:poi_comment)
    comment.update!(body: 'Edited test comment')
    version = comment.versions.last
    version.update_columns(object_changes: { 'body' => [ 'Test comment', 'Edited test comment' ] }.to_json)
    version.reload

    component = described_class.new(comment: comment)

    expect(component.send(:edited_version)).to eq(version)
  end

  it 'пропускает версию с некорректной JSON-строкой object_changes' do
    comment = create(:poi_comment)
    comment.update!(body: 'Edited test comment')
    version = comment.versions.last
    version.update_columns(object_changes: 'broken { not json')
    version.reload

    component = described_class.new(comment: comment)

    expect(component.send(:edited_version)).to be_nil
  end
end
