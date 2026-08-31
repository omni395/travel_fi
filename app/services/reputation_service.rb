# frozen_string_literal: true

#
# ReputationService — пересчёт репутации автора контента по голосам сообщества.
#
# Репутация копится в users.reputation (integer). Механика:
#   +1 за каждый апрув-голос (+1) за контент автора;
#   -1 за каждый дизлайк-голос (-1) за контент автора.
# Т.е. reputation = сумма value всех Votes за сущности автора.
#
# suspended/banned — НЕ автоматика: репутация лишь сигнал, решение принимает
# админ через существующий Admin::UserService (флоу не меняется).
#
class ReputationService
  #
  # Пересчитывает репутацию автора по всем его контенту (POI, фото, комменты).
  # Идемпотентно: всегда вычисляет актуальную сумму голосов.
  #
  # @param author [User] автор, чью репутацию пересчитываем
  # @return [Integer] новая репутация
  #
  def self.reckon!(author)
    new_reputation = 0

    # Суммируем голоса за POI автора.
    new_reputation += sum_votes(author.pois)
    # Суммируем голоса за фото автора (независимо от POI).
    new_reputation += sum_votes(author.photos)
    # Суммируем голоса за комментарии автора.
    new_reputation += sum_votes(author.poi_comments)

    # update_column (не update!) — служебный счётчик, аудит PaperTrail для него
    # не нужен (иначе каждый голос плодил бы лишнюю версию User).
    author.update_column(:reputation, new_reputation)
    new_reputation
  rescue StandardError => e
    Rails.logger.error("ReputationService reckon! failed for User ##{author&.id}: #{e.class} #{e.message}")
    author&.reputation || 0
  end

  #
  # Суммирует value всех Vote за коллекцию сущностей автора.
  #
  # @param collection [ActiveRecord::Relation, Array] сущности автора
  # @return [Integer] сумма голосов
  #
  def self.sum_votes(collection)
    # Избегаем N+1: один запрос по коллекции id.
    ids = collection.pluck(:id)
    return 0 if ids.empty?

    Vote.where(
      votable_type: collection.klass.name,
      votable_id: ids
    ).sum(:value) || 0
  end
end
