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

    it 'assigns root_id/depth при создании ответа (через CommentService)' do
      user = create(:user)
      root = CommentService.create_comment(commentable: poi, user: user, body: 'Корень')
      reply = CommentService.create_comment(commentable: poi, user: user, body: 'Ответ', parent_id: root.id)

      expect(reply.root_id).to eq(root.id)
      expect(reply.depth).to eq(1)
      expect(reply.root).to eq(root)
    end

    it 'branch_for возвращает всю ветку по корню' do
      user = create(:user)
      root = CommentService.create_comment(commentable: poi, user: user, body: 'Корень')
      reply = CommentService.create_comment(commentable: poi, user: user, body: 'Ответ', parent_id: root.id)

      branch = poi.poi_comments.branch_for(root)

      expect(branch).to include(root, reply)
    end
  end

  describe 'модерация (hidden)' do
    it 'visible возвращает только не скрытые' do
      visible = create(:poi_comment, poi: poi)
      hidden = create(:poi_comment, poi: poi, hidden_at: Time.current)

      expect(poi.poi_comments.visible).to include(visible)
      expect(poi.poi_comments.visible).not_to include(hidden)
    end

    it 'hidden?/visible? корректно отражают состояние' do
      comment = create(:poi_comment, poi: poi)
      expect(comment).not_to be_hidden
      expect(comment).to be_visible

      comment.update!(hidden_at: Time.current)
      expect(comment).to be_hidden
      expect(comment).not_to be_visible
    end
  end

  describe 'валидации threading' do
    it 'запрещает прямой ответ на ответ (родитель depth >= MAX_DEPTH)' do
      user = create(:user)
      root = CommentService.create_comment(commentable: poi, user: user, body: 'Корень')
      reply = CommentService.create_comment(commentable: poi, user: user, body: 'Ответ', parent_id: root.id)

      # Прямое создание с parent=reply (depth 1) через модель — невалидно;
      # флоттенинг корректно делает CommentService (перенаправляет parent на корень).
      deep = build(:poi_comment, poi: poi, parent: reply)
      expect(deep).not_to be_valid
    end

    it 'запрещает parent из другого POI' do
      other_poi = create(:poi)
      foreign_parent = create(:poi_comment, poi: other_poi)

      comment = build(:poi_comment, poi: poi, parent: foreign_parent)
      expect(comment).not_to be_valid
    end
  end

  describe 'live-рассылка (ROADMAP 2.2)' do
    it 'создание комментария фиксирует PaperTrail-версию для VersionObserverJob' do
      comment = create(:poi_comment, poi: poi)

      version = PaperTrail::Version.where(item_type: 'PoiComment', item_id: comment.id).order(:id).last
      expect(version).to be_present
      expect(version.event).to eq('create')
    end
  end
end
