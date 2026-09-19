# frozen_string_literal: true

#
# CommentService — сервис управления комментариями (полиморфный контракт).
#
# Отвечает за жизнь цикла комментария с threading (глубина 2 + флоттенинг):
#   1. create_comment — создание корневого комментария или ответа;
#   2. update_comment — редактирование (автор/admin);
#   3. destroy_comment — удаление (автор/admin), без каскада на текст.
#
# Ветвление (глубина 2):
#   - нет parent            → корень: root_id=nil, depth=0;
#   - parent.depth == 0     → ответ на корень: root_id=parent.id, depth=1,
#                             parent.children_count += 1;
#   - parent.depth >= 1     → флоттенинг "ответа на ответ" в ответ на корень:
#                             целевой root = parent.root (или parent),
#                             запись root_id=root.id, depth=1, parent_id=parent.id,
#                             root.children_count += 1.
#
# Каждый комментарий создаёт награду TFT (comment_create) через
# GamificationService.award!. Сбой начисления не роняет создание самого
# комментария.
#
# Примечание: полиморфный контракт позволяет использовать этот сервис для любого
# "commentable" (POI сейчас; фото/предложения правок — потенциально потом).
#
class CommentService
  # Custom exceptions
  class CreateError < StandardError; end
  class UpdateError < StandardError; end
  class DestroyError < StandardError; end

  class << self
    #
    # Создаёт комментарий к commentable (POI) или ответ (глубина 2 + флоттенинг).
    #
    # @param commentable [Poi] объект-владелец комментария
    # @param user [User] автор комментария
    # @param body [String] текст комментария
    # @param parent_id [Integer, nil] id родительского комментария (опционально)
    # @return [PoiComment]
    # @raise [CreateError] если ошибка валидации
    #
    def create_comment(commentable:, user:, body:, parent_id: nil)
      parent = parent_id.present? ? commentable.poi_comments.find(parent_id) : nil

      comment = PoiComment.new(
        poi: commentable,
        user: user,
        body: body,
        parent: parent
      )

      # Нормализация ветвления (глубина 2 + флоттенинг) ДО save — задаём
      # root_id/depth в зависимости от родителя.
      apply_threading(comment, parent)

      ActiveRecord::Base.transaction do
        comment.save!

        # Инкремент счётчика ответов корня ветки (только если это ответ).
        increment_children_count!(comment, parent) if parent.present?

        # Геймификация: награда TFT за комментарий. Сбой начисления не роняет
        # сам комментарий (иначе не сохранится пользовательский ввод).
        begin
          GamificationService.award!(:comment_create, user)
        rescue StandardError => e
          Rails.logger.error("CommentService award failed: #{e.class} #{e.message}")
        end
      end

      comment
    rescue ActiveRecord::RecordInvalid => e
      raise CreateError, e.message
    end

    #
    # Обновляет текст комментария (автор/admin).
    #
    # @param comment [PoiComment] комментарий
    # @param body [String] новый текст
    # @return [PoiComment]
    # @raise [UpdateError] если ошибка валидации
    #
    def update_comment(comment:, body:)
      comment.update!(body: body)
      comment
    rescue ActiveRecord::RecordInvalid => e
      raise UpdateError, e.message
    end

    #
    # Удаляет комментарий (автор/admin). Ветка остаётся (root/comments других
    # авторов сохраняются); текст удалённого комментария мягко затирается
    # ("deleted"), чтобы не ломать согласованность дерева. Денормализованный
    # children_count предка НЕ инкрементируется при удалении (убыль обрабатывает
    # вызывающий/бродкаст при необходимости).
    #
    # @param comment [PoiComment] комментарий
    # @raise [DestroyError] если ошибка
    #
    def destroy_comment(comment:)
      comment.destroy!
    rescue ActiveRecord::RecordNotDestroyed => e
      raise DestroyError, e.message
    end

    #
    # Корневые комментарии commentable с упорядочиванием.
    #
    # @param commentable [Poi] владелец
    # @param sort [Symbol] :best (net голосов через Vote) или :new (по дате)
    # @return [ActiveRecord::Relation<PoiComment>]
    #
    def roots(commentable, sort: :new)
      scope = PoiComment.roots_for(commentable).visible
      if sort == :best
        # Подзапрос агрегирует value полиморфной Vote (downs/-1, ups/+1).
        # Без денормализации — источник правды остаётся таблица votes.
        scope.order(Arel.sql(
          "COALESCE((SELECT SUM(value) FROM votes WHERE votable_type='PoiComment' AND votable_id=poi_comments.id), 0) DESC, created_at DESC"
        ))
      else
        scope.order(created_at: :desc)
      end
    end

    private

    #
    # Применяет threading к комментарию (root_id/depth) по правилам глубины 2.
    #
    # @param comment [PoiComment] создаваемый комментарий
    # @param parent [PoiComment, nil] родитель
    #
    def apply_threading(comment, parent)
      if parent.nil?
        # Корневой комментарий: root_id пусто (корень сам себе — заполняем
        # после save), depth 0.
        comment.depth = 0
      elsif parent.depth.to_i.zero?
        # Прямой ответ на корень: root = parent, depth 1.
        comment.root = parent
        comment.depth = 1
      else
        # Флоттенинг "ответа на ответ": прикрепляем к корню ветки, depth 1.
        # Фактический parent перенаправляется на корень, чтобы не углублять
        # физическое дерево (глубина 2: корень → ответ). root = корень ветки.
        root = parent.root || parent
        comment.parent = root
        comment.root = root
        comment.depth = 1
      end
    end

    #
    # Инкрементирует children_count корня ветки при создании ответа.
    #
    # @param comment [PoiComment] созданный комментарий
    # @param parent [PoiComment, nil] родитель
    #
    def increment_children_count!(comment, parent)
      # Корень ветки: для флоттенед родитель — это корень; для прямого ответа — сам.
      root = comment.root || parent
      return if root.id == comment.id

      root.update!(children_count: root.children_count.to_i + 1)
    end
  end
end
