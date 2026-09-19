# frozen_string_literal: true

require 'rails_helper'

#
# CommentModerationService — unit-спек модерации комментариев (скрытие/показ).
#
# Покрытие:
#   1. hide! устанавливает hidden_at (через update! → PaperTrail-версия);
#   2. unhide! сбрасывает hidden_at в nil;
#   3. Идемпотентность: повторный вызов не создаёт лишней версии.
#
RSpec.describe CommentModerationService, type: :service do
  let(:poi) { create(:poi) }
  let(:comment) { create(:poi_comment, poi: poi) }

  describe '.hide!' do
    it 'скрывает комментарий и фиксирует PaperTrail-версию (event update)' do
      described_class.hide!(comment: comment)

      expect(comment.reload.hidden_at).to be_present
      expect(comment).to be_hidden

      version = PaperTrail::Version.where(item_type: 'PoiComment', item_id: comment.id).order(:id).last
      expect(version.event).to eq('update')
    end

    it 'идемпотентен — повторный вызов не создаёт лишней версии' do
      described_class.hide!(comment: comment)
      count_before = PaperTrail::Version.where(item_type: 'PoiComment', item_id: comment.id).count

      described_class.hide!(comment: comment)

      count_after = PaperTrail::Version.where(item_type: 'PoiComment', item_id: comment.id).count
      expect(count_after).to eq(count_before)
    end
  end

  describe '.unhide!' do
    it 'показывает ранее скрытый комментарий' do
      described_class.hide!(comment: comment)
      described_class.unhide!(comment: comment)

      expect(comment.reload.hidden_at).to be_nil
      expect(comment).to be_visible
    end
  end
end
