# frozen_string_literal: true

#
# AddThreadingToPoiComments — threading-поля комментариев POI (глубина 2 + флоттенинг).
#
# Добавляет поля для ветвления:
#   - root_id         id корня ветки (одна выборка WHERE root_id = X даёт всю ветку)
#   - depth           0 — корень, 1 — ответ (флоттенед ответ на ответ тоже 1)
#   - children_count  кол-во ответов (для «Показать N» и live-счётчика ветки)
#
# Примечание: счётчики голосов НЕ денормализуем — система воутинга отдельная и
# полиморфная (модель Vote + VoteService.tally), прикручивается к любой сущности,
# включая PoiComment (has_many :votes, as: :votable). Дублировать её здесь не нужно.
#
class AddThreadingToPoiComments < ActiveRecord::Migration[8.1]
  def up
    add_reference :poi_comments, :root, foreign_key: { to_table: :poi_comments }, null: true
    add_column :poi_comments, :depth, :integer, default: 0, null: false
    add_column :poi_comments, :children_count, :integer, default: 0, null: false
    # Модерация: null = виден, не-null = скрыт админом/модератором (порог дизлайков)
    add_column :poi_comments, :hidden_at, :datetime, null: true

    add_index :poi_comments, [ :poi_id, :root_id ], name: "idx_poi_comments_on_poi_and_root"
    add_index :poi_comments, [ :root_id ], name: "idx_poi_comments_on_root_id"

    # Backfill существующих: корни (parent_id NULL) → root=id, depth=0;
    # ответы (parent_id есть) → root=parent.root (или parent), depth=1.
    execute <<~SQL
      UPDATE poi_comments
         SET root_id = id, depth = 0
       WHERE parent_id IS NULL;

      UPDATE poi_comments c
         SET root_id = COALESCE(p.root_id, p.id),
             depth = 1
        FROM poi_comments p
       WHERE c.parent_id = p.id
         AND c.parent_id IS NOT NULL;
    SQL
  end

  def down
    remove_index :poi_comments, name: "idx_poi_comments_on_root_id"
    remove_index :poi_comments, name: "idx_poi_comments_on_poi_and_root"
    remove_column :poi_comments, :hidden_at
    remove_column :poi_comments, :children_count
    remove_column :poi_comments, :depth
    remove_reference :poi_comments, :root
  end
end
