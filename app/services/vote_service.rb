# frozen_string_literal: true

#
# VoteService — сервис для голосований сообщества (Community Moderation).
#
# Ответственность:
# 1. cast! — управление голосом (+1 апрув / -1 дизлайк) за сущность в транзакции,
#    с аудитом PaperTrail и наградой TFT (poi_vote) при фактическом создании.
#
# Действия (action):
#   :create  — поставить голос value (если голоса не было). Если голос уже есть —
#              перезаписывает value (упсёрт-поведение, безопасно для повторных
#              вызовов); награда начисляется при создании нового голоса.
#   :destroy — забрать голос юзера за сущность (удалить Vote).
#   :change  — сменить голос: удалить старый (если был) + создать новый value.
#
# Анти-фрод выполняет VotePolicy (не автор, проксимити 100м для POI) ДО вызова.
# Повторное голосование за ту же сущность тем же юзером НЕ зависит от unique
# index [votable_type, votable_id, user_id] — индекс блокирует дубли на уровне
# БД, а логика решения (create/destroy/change) — в этом сервисе.
#
# Голоса НЕ меняют статус POI — только ModerationService вешает бейджи.
#
class VoteService
  ACTIONS = %i[create destroy change].freeze

  #
  # Управляет голосом за сущность.
  #
  # @param votable [Poi, Photo, PoiComment] голосуемая сущность
  # @param user [User] автор голоса
  # @param value [Integer, String] +1/-1 (апрув/дизлайк); требуется для :create/:change
  # @param action [Symbol] :create / :destroy / :change
  # @return [Array<Vote, Symbol>] [голос (nil при destroy), фактическое действие]
  # @raise [ArgumentError] если value невалиден или action неизвестен
  #
  def self.cast!(votable:, user:, value: nil, action: :create)
    unless ACTIONS.include?(action.to_sym)
      raise ArgumentError, "Invalid vote action: #{action.inspect}"
    end

    value_i = normalize_value!(value) unless action == :destroy

    vote = nil
    performed = :none

    ActiveRecord::Base.transaction do
      vote = votable.votes.find_by(user: user)

      case action.to_sym
      when :create
        vote, performed = create_or_toggle(votable, user, vote, value_i)
      when :destroy
        # Удаляем найденный голос (если был) и возвращаем nil вместо удалённого
        # объекта — после destroy объект не нужен вызывающему коду.
        performed = destroy_vote(vote)
        vote = nil
      when :change
        # performed возвращает [vote, :changed] — считываем новый голос.
        vote, performed = change_vote(votable, user, vote, value_i)
      end
    end

    [ vote, performed ]
  end

  #
  # Суммарный счёт голосов сущности: { ups:, downs:, total:, net: }
  #
  # @param votable [Poi, Photo, PoiComment] голосуемая сущность
  # @return [Hash] счёт голосов
  #
  def self.tally(votable)
    ups = votable.votes.ups.count
    downs = votable.votes.downs.count
    {
      ups: ups,
      downs: downs,
      total: ups + downs,
      net: ups - downs
    }
  end

  #
  # Нормализует и валидирует значение голоса.
  #
  # @param value [Integer, String] +1/-1
  # @return [Integer]
  # @raise [ArgumentError] если value не входит в [1, -1]
  #
  def self.normalize_value!(value)
    value_i = value.to_i
    return value_i if [ 1, -1 ].include?(value_i)

    raise ArgumentError, "Invalid vote value: #{value.inspect}"
  end
  private_class_method :normalize_value!

  #
  # Action :create — ставит голос. Если голос уже есть — перезаписывает value.
  # Награда TFT начисляется только когда создаётся новый Vote.
  #
  # @param votable [Poi, Photo, PoiComment]
  # @param user [User]
  # @param vote [Vote, nil] текущий голос юзера
  # @param value_i [Integer] нормализованное значение
  # @return [Array<Vote, Symbol>]
  #
  def self.create_or_toggle(votable, user, vote, value_i)
    if vote
      vote.update!(value: value_i)
      [ vote, :updated ]
    else
      vote = votable.votes.create!(user: user, value: value_i)
      award_poi_vote!(user)
      [ vote, :created ]
    end
  end
  private_class_method :create_or_toggle

  #
  # Action :destroy — забирает голос (удаляет Vote юзера).
  #
  # @param vote [Vote, nil] текущий голос юзера
  # @return [Symbol] :destroyed или :none (голоса не было)
  #
  def self.destroy_vote(vote)
    if vote
      vote.destroy!
      :destroyed
    else
      :none
    end
  end
  private_class_method :destroy_vote

  #
  # Action :change — смена голоса: удаляет старый (если был) + создаёт новый value.
  # Награда TFT начисляется за новое создание.
  #
  # @return [Array<Vote?, Symbol>] [новый голос, :changed]
  #
  def self.change_vote(votable, user, vote, value_i)
    vote.destroy! if vote
    new_vote = votable.votes.create!(user: user, value: value_i)
    award_poi_vote!(user)
    [ new_vote, :changed ]
  end
  private_class_method :change_vote

  #
  # Начисляет TFT-награду за голос (poi_vote). Сбой не роняет сам голос.
  #
  # @param user [User]
  #
  def self.award_poi_vote!(user)
    GamificationService.award!(:poi_vote, user)
  rescue StandardError => e
    Rails.logger.error("VoteService award failed: #{e.class} #{e.message}")
  end
  private_class_method :award_poi_vote!
end
