# frozen_string_literal: true

require 'rails_helper'

#
# PoiComment — unit-спек модели комментария к POI.
#
# Покрытие:
# 1. Валидации body (presence, длина 2..1000)
# 2. Ассоциации (poi touch, user, parent)
# 3. Скоупы roots / replies_for (threaded-структура)
# 4. Заглушка (pending): live-рассылка для всех (ROADMAP 2.2)
#
RSpec.describe PoiComment, type: :model do
  let(:poi) { create(:poi) }

  describe 'валидации' do
    it 'валиден с фабрикой' do
      expect(build(:poi_comment, poi: poi)).to be_valid
    end

    it 'требует body' do
      expect(build(:poi_comment, poi: poi, body: nil)).not_to be_valid
    end

    it 'отклоняет слишком короткое body' do
      expect(build(:poi_comment, poi: poi, body: 'A')).not_to be_valid
    end

    it 'отклоняет слишком длинное body' do
      expect(build(:poi_comment, poi: poi, body: 'x' * 1001)).not_to be_valid
    end
  end

  describe 'ассоциации' do
    it 'принадлежит poi, user и опциональному parent' do
      comment = create(:poi_comment, poi: poi, user: create(:user))

      expect(comment.poi).to eq(poi)
      expect(comment.user).to be_present
      expect(comment.parent).to be_nil
    end

    it 'touch обновляет updated_at POI (фиксация в PaperTrail через touch)' do
      expect { create(:poi_comment, poi: poi) }
        .to change { poi.reload.updated_at }
    end
  end

  describe 'threaded-структура' do
    it 'roots возвращает только корневые комментарии' do
      root = create(:poi_comment, poi: poi)
      reply = create(:poi_comment, poi: poi, parent: root)

      expect(poi.poi_comments.roots).to include(root)
      expect(poi.poi_comments.roots).not_to include(reply)
    end

    it 'replies_for возвращает ответы на конкретный комментарий' do
      root = create(:poi_comment, poi: poi)
      reply = create(:poi_comment, poi: poi, parent: root)
      other = create(:poi_comment, poi: poi)

      expect(poi.poi_comments.replies_for(root.id)).to contain_exactly(reply)
      expect(poi.poi_comments.replies_for(root.id)).not_to include(other)
    end
  end

  describe 'live-рассылка для всех (заглушка: ROADMAP 2.2)' do
    it 'комментарий появляется у всех подписанных браузеров без перезагрузки' do
      pending 'заглушка: live только для автора (ROADMAP 2.2, баг)'

      comment = create(:poi_comment, poi: poi)

      expect(PoiBroadcaster).to receive(:call).with(poi: poi)
      PaperTrail::Version.where(item_type: 'PoiComment', item_id: comment.id).last
    end
  end
end
