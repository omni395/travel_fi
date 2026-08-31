# frozen_string_literal: true

#
# VoteReflex — Reflex для голосований сообщества (Community Moderation).
#
# Мост UI → Service: `morph :nothing` + authorize (VotePolicy) + проксимити 100м
# для POI → делегирование в VoteService.cast!. НЕ рендерит DOM после сохранения —
# обновление счётчика/бейджа идёт через Broadcaster (VersionObserverJob →
# VoteBroadcaster), иначе гонки двух морфов.
#
class VoteReflex < ApplicationReflex
  #
  # Ставит/забирает/меняет голос за сущность.
  # Вызывается из Ui::VoteComponent (StimulusReflex#cast).
  #
  # @param votable_type [String] класс сущности ("Poi"/"Photo"/"PoiComment")
  # @param votable_id [Integer] id сущности
  # @param vote_value [Integer] +1 (апрув) / -1 (дизлайк)
  # @param vote_action [String] "create"/"destroy"/"change" (действие)
  #
  def cast(params = {})
    # StimulusReflex 3.x передаёт объект-аргумент как ЕДИНЫЙ ПОЗИЦИОННЫЙ
    # аргумент (не keywords), ключи — строковые (JSON-сериализация).
    # Нормализуем в символьные, затем вычитываем именованные.
    params = deep_symbolize_keys(params) if params.is_a?(Hash)

    votable_type = params[:votable_type].to_s
    votable_id = params[:votable_id]
    vote_value = params[:vote_value]
    vote_action = (params[:vote_action] || :create).to_sym

    votable = find_votable(votable_type, votable_id)
    authorize_with_pundit!(votable, :create?)  # VotePolicy

    # Проксимити 100м для POI (анти-фрод). При нарушении check_proximity!
    # сам рендерит диалог и делает morph :nothing → выходим (НЕ голосуем);
    # повторный morph запрещён (двойной morph → nothing morph type уже задан).
    if votable.is_a?(Poi) && !check_proximity!(votable)
      return
    end

    VoteService.cast!(votable: votable, user: current_user, value: vote_value, action: vote_action)
    morph :nothing

    Rails.logger.info("VoteReflex: Cast vote #{vote_value} on #{votable_type}##{votable_id}")
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn("VoteReflex: votable not found - #{e.message}")
    morph :nothing
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("VoteReflex: not authorized to vote - #{e.message}")
    morph :nothing
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    Rails.logger.warn("VoteReflex: vote rejected - #{e.message}")
    morph :nothing
  end

  private

  #
  # Находит полиморфную голосуемую сущность по типу и id.
  #
  # @param votable_type [String] класс сущности
  # @param votable_id [Integer] id
  # @return [Poi, Photo, PoiComment]
  # @raise [ActiveRecord::RecordNotFound] если не найдена/тип не поддерживается
  #
  def find_votable(votable_type, votable_id)
    klass = votable_type.to_s.constantize
    unless [ Poi, Photo, PoiComment ].include?(klass)
      raise ActiveRecord::RecordNotFound, "Unsupported votable type: #{votable_type}"
    end

    klass.find(votable_id)
  rescue NameError
    raise ActiveRecord::RecordNotFound, "Unknown votable type: #{votable_type}"
  end
end
