# frozen_string_literal: true

#
# VoteBroadcaster — отправляет live-обновление счётчика голосов через WebSocket.
#
# Ответственность:
# 1. Получает голосуемую сущность (POI/Photo/PoiComment)
# 2. Считает актуальный tally (ups/downs/total)
# 3. Доставляет ТОЛЬКО числа-счётчики через CableReady `text_content` в таргеты
#    [data-vote-counter="up"], [data-vote-counter="down"], [data-vote-counter="hint"]
#    внутри таргет-обёртки [data-vote-zone="<votable_key>-<id>"].
#
# ПОЧЕМУ text_content, а не inner_html всего компонента:
#   - [data-vote-zone] в общем стриме "pois_map" видят ВСЕ подписанные зрители.
#     inner_html заменял бы каркас VoteComponent целиком и стирал персональное
#     состояние каждого зрителя: is-active подсветку, выбранный им голос и
#     data-current-vote → повторные destroy/change были бы невозможны («кнопки
#     не срабатывают»). text_content обновляет только одинаковые для всех числа,
#     не трогая персональные кнопки/диалоги.
#
# Каналы/стримы (модель из README):
#   - POI/Photo → "pois_map" (общая карта)
#   - PoiComment → "user_<id_involved>"
#
class VoteBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет обновление счётчика голосов сущности.
  #
  # @param votable [Poi, Photo, PoiComment] голосуемая сущность
  #
  def self.call(votable:)
    new(votable: votable).broadcast
  end

  attr_reader :votable

  def initialize(votable:)
    @votable = votable
  end

  #
  # Формирует и отправляет обновление счётчиков в таргет-обёртку.
  #
  # Обновляет три селектора через text_content (одинаковы для всех зрителей):
  #   - [data-vote-zone='...'] [data-vote-counter='up']
  #   - [data-vote-zone='...'] [data-vote-counter='down']
  #   - [data-vote-zone='...'] [data-vote-counter='hint']
  #
  def broadcast
    tally = VoteService.tally(votable)
    zone_selector = "[data-vote-zone='#{votable_key}-#{votable.id}']"

    send_counters = proc do |cable|
      cable[stream_name]
        .text_content(selector: "#{zone_selector} [data-vote-counter='up']", text: tally[:ups].to_s)
        .text_content(selector: "#{zone_selector} [data-vote-counter='down']", text: tally[:downs].to_s)
        .text_content(selector: "#{zone_selector} [data-vote-counter='hint']",
                      text: I18n.t("ui.vote_component.hint", total: tally[:total]))
        .broadcast
    end

    send_counters.call(cable_ready)

    Rails.logger.info("VoteBroadcaster: Sent vote counters for #{votable.class}##{votable.id}")
  rescue StandardError => e
    Rails.logger.error("VoteBroadcaster error: #{e.class} #{e.message}")
  end

  private

  #
  # Ключ сущности для таргет-селектора (poi / photo / poi_comment).
  #
  # @return [String]
  #
  def votable_key
    votable.class.name.underscore
  end

  #
  # Имя стрима по типу сущности (модель каналов из README):
  #   - Poi/Photo → "pois_map" (общая карта)
  #   - PoiComment → "user_<author_id>"
  #
  # @return [String]
  #
  def stream_name
    case votable
    when Poi, Photo
      "pois_map"
    when PoiComment
      "user_#{votable.user_id}"
    end
  end
end
