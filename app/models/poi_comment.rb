# frozen_string_literal: true

#
# PoiComment — комментарий к точке интереса (POI)
#
# Поддерживает threaded-структуру через parent_id (self-join) с глубиной 2
# (+ флоттенинг "ответа на ответ" в ответ на корень):
#   - parent_id == nil  → корневой комментарий
#   - parent_id != nil  → ответ (depth 1); ответ на ответ флоттенится в корень
#   - root_id           id корня ветки (вся ветка по WHERE root_id = X)
#   - depth             0 — корень, 1 — ответ
#   - children_count    кол-во ответов (для «Показать N» и live-счётчика)
#
# Голоса НЕ денормализуются — используется полиморфная модель Vote
# (has_many :votes, as: :votable), подсчёт через VoteService.tally.
#
# @attr poi_id     [Integer] ссылка на POI
# @attr user_id    [Integer] автор комментария
# @attr parent_id  [Integer, nil] родительский комментарий (опционально)
# @attr root_id    [Integer, nil] id корня ветки
# @attr depth      [Integer] глубина (0 — корень, 1 — ответ)
# @attr body       [Text] текст комментария
#
class PoiComment < ApplicationRecord
  # Аудит всех изменений
  has_paper_trail

  # Ассоциации
  belongs_to :poi, touch: true
  belongs_to :user
  belongs_to :parent, class_name: "PoiComment", optional: true
  # Корень ветки (для корневого комментария root == self)
  belongs_to :root, class_name: "PoiComment", optional: true

  # Прямые ответы (depth 1) на этот комментарий
  has_many :children, class_name: "PoiComment", foreign_key: :parent_id,
                      dependent: :destroy, inverse_of: :parent
  # Все записи ветки (по root_id)
  has_many :branch, class_name: "PoiComment", foreign_key: :root_id,
                    dependent: :destroy, inverse_of: :root

  # Голоса сообщества (Vote, полиморфный votable)
  has_many :votes, as: :votable, dependent: :destroy

  # Валидации
  validates :body, presence: true, length: { minimum: 2, maximum: 1000 }
  validate :parent_belongs_to_same_poi
  validate :depth_not_too_deep

  # Скоупы
  scope :recent, -> { order(created_at: :desc) }
  scope :roots, -> { where(parent_id: nil) }
  scope :replies_for, ->(comment_id) { where(parent_id: comment_id) }
  # Видимые (не скрытые модерацией) комментарии
  scope :visible, -> { where(hidden_at: nil) }
  # Корневые комментарии POI (упорядочивание — best/new задаётся вызовом)
  scope :roots_for, ->(poi) { where(poi_id: poi.id, parent_id: nil) }
  # Вся ветка по корню (сам корень + его ответы; у корня root_id = nil)
  scope :branch_for, ->(root) { where(root_id: root.id).or(where(id: root.id)).order(created_at: :asc) }

  #
  # Скрыт ли комментарий модерацией (пользователем видимый scope фильтрует).
  #
  # @return [Boolean]
  #
  def hidden?
    hidden_at.present?
  end

  #
  # Видим ли комментарий (не скрыт).
  #
  # @return [Boolean]
  #
  def visible?
    !hidden?
  end

  # Голосовал ли пользователь за этот комментарий
  def self.voted_by?(user)
    exists?(user: user)
  end

  # Максимальная физическая глубина прямого вложения. Промпт: «глубина 2 + флоттенинг» —
  # пользователь может ответить на ответ (depth 1), но такой ответ флоттенится
  # на уровне CommentService: фактический parent перенаправляется на корень ветки,
  # поэтому физически вложенность глубже корень→ответ (depth 1) не создаётся.
  # Прямое создание с parent.depth >= 1 считается невалидным (обрабатывает сервис).
  MAX_DEPTH = 1

  private

  #
  # Корректность parent: родитель обязан относиться к тому же POI (и не быть
  # собственным потомком/собой — защита от циклов самоджоина).
  #
  def parent_belongs_to_same_poi
    return if parent.nil?
    return if parent.poi_id == poi_id && parent.id != id

    errors.add(:parent, :incompatible)
  end

  #
  # Ограничение глубины: разрешено отвечать только на корень (depth 0).
  # Ответ на ответ флоттенится на уровне CommentService; физически глубже
  # 1 не создаём. Максимум 1 уровень вложенности от корня.
  #
  def depth_not_too_deep
    return if parent.nil?

    errors.add(:parent, :too_deep) if parent.depth.to_i >= MAX_DEPTH
  end
end
