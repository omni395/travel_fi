# frozen_string_literal: true

#
# AddSourceToUserRewards — добавляет полиморфную связь source на UserReward.
#
# Источник начисления (Poi / Photo / PoiComment / Vote) — реляционная связь для:
#   1) точечного отзыва незабранных начислений (revoke! по source, анти-фарминг);
#   2) UI-резолва «за что начислено» в RewardsComponent.
# Источник правды — PaperTrail-версия начисления (UserReward#source аудируется,
# т.к. модель has_paper_trail).
#
class AddSourceToUserRewards < ActiveRecord::Migration[8.1]
  def change
    add_reference :user_rewards, :source, polymorphic: true, null: true, index: false
    add_index :user_rewards, [ :source_type, :source_id ]
  end
end
