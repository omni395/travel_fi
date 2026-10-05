# frozen_string_literal: true

require 'rails_helper'

#
# CommentService — unit-спек бизнес-логики комментариев (threading + флоттенинг).
#
# Покрытие:
#   1. Создание корневого комментария (root_id=nil, depth=0);
#   2. Ответ на корень (root_id=корень, depth=1, children_count+=1);
#   3. Флоттенинг "ответа на ответ" (root=корень ветки, depth=1);
#   4. Обновление тела;
#   5. roots фильтрует скрытые (.visible);
#   6. Удаление комментария.
#
RSpec.describe CommentService, type: :service do
  let(:poi) { create(:poi) }
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe '.create_comment' do
    it 'создаёт корневой комментарий (depth 0, root пустой)' do
      comment = CommentService.create_comment(commentable: poi, user: user, body: 'Корень')

      expect(comment).to be_persisted
      expect(comment.parent).to be_nil
      expect(comment.depth).to eq(0)
      expect(comment.root_id).to be_nil
    end

    it 'создаёт ответ на корень и инкрементирует children_count' do
      root = CommentService.create_comment(commentable: poi, user: user, body: 'Корень')

      # Ответ оставляет ДРУГОЙ пользователь (на свой отвечать запрещено — анти-флуд).
      reply = CommentService.create_comment(
        commentable: poi, user: other_user, body: 'Ответ', parent_id: root.id
      )

      expect(reply.parent).to eq(root)
      expect(reply.depth).to eq(1)
      expect(reply.root_id).to eq(root.id)
      expect(root.reload.children_count).to eq(1)
    end

    it 'флоттенит "ответ на ответ" — родитель и root становятся корнем ветки, depth=1' do
      root = CommentService.create_comment(commentable: poi, user: user, body: 'Корень')
      reply = CommentService.create_comment(
        commentable: poi, user: other_user, body: 'Ответ', parent_id: root.id
      )

      # Ответ на ответ: сервис перенаправляет parent на корень (флоттенинг),
      # физическая глубина остаётся 1, чтобы не углублять дерево.
      floored = CommentService.create_comment(
        commentable: poi, user: user, body: 'Ответ на ответ', parent_id: reply.id
      )

      expect(floored.parent).to eq(root)
      expect(floored.depth).to eq(1)
      expect(floored.root_id).to eq(root.id)
      expect(root.reload.children_count).to eq(2)
    end

    it 'запрещает отвечать на СВОЙ собственный комментарий (анти-флуд)' do
      root = CommentService.create_comment(commentable: poi, user: user, body: 'Корень')

      expect {
        CommentService.create_comment(commentable: poi, user: user, body: 'Ответ сам себе', parent_id: root.id)
      }.to raise_error(CommentService::CreateError, /your own comment|свой собственный комментарий/)
    end

    it 'запрещает второй ответ на один и тот же чужой комментарий (анти-флуд)' do
      root = CommentService.create_comment(commentable: poi, user: user, body: 'Корень')
      CommentService.create_comment(commentable: poi, user: other_user, body: 'Первый ответ', parent_id: root.id)

      expect {
        CommentService.create_comment(commentable: poi, user: other_user, body: 'Второй ответ', parent_id: root.id)
      }.to raise_error(CommentService::CreateError, /already replied|уже ответили/)
    end
  end

  describe '.update_comment' do
    it 'обновляет body' do
      comment = CommentService.create_comment(commentable: poi, user: user, body: 'Старый')

      CommentService.update_comment(comment: comment, body: 'Новый')

      expect(comment.reload.body).to eq('Новый')
    end
  end

  describe '.roots' do
    it 'возвращает только корневые комментарии' do
      root = CommentService.create_comment(commentable: poi, user: user, body: 'Корень')
      CommentService.create_comment(commentable: poi, user: other_user, body: 'Ответ', parent_id: root.id)

      roots = CommentService.roots(poi, sort: :new)

      expect(roots).to contain_exactly(root)
    end

    it 'фильтрует скрытые комментарии (.visible)' do
      visible = CommentService.create_comment(commentable: poi, user: user, body: 'Видимый')
      hidden = CommentService.create_comment(commentable: poi, user: user, body: 'Скрытый')
      hidden.update!(hidden_at: Time.current)

      roots = CommentService.roots(poi, sort: :new)

      expect(roots).to include(visible)
      expect(roots).not_to include(hidden)
    end
  end

  describe '.destroy_comment' do
    it 'скрывает комментарий модерацией (hidden_at), сохраняя запись и ветку' do
      comment = CommentService.create_comment(commentable: poi, user: user, body: 'Удалить')

      CommentService.destroy_comment(comment: comment)

      expect(comment.reload).to be_persisted
      expect(comment.hidden_at).to be_present
    end
  end
end
