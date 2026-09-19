# frozen_string_literal: true

#
# ModerationService — пороговая авто-модерация контента по голосам сообщества.
#
# Семантика (см. ROADMAP 3.5):
# - Статус POI ставит ТОЛЬКО админ. Голоса НЕ меняют `poi.status` и НЕ влияют
#   на видимость (`pending` не голосуется).
# - Голоса вешают ТОЛЬКО бейджи на уже видимые точки (approved/imported):
#     ups >= threshold  → «Одобрено сообществом»   (moderation_source = :community)
#     downs >= threshold → «Отклонено сообществом» (community_rejected = true, сигнал админу)
# - Фото/комменты: поведение (скрыть/удалить) отложено (TODO) — сейчас только
#   бейджи/репутация.
#
# Алгоритм подсчёта бейджа (badge_state):
#   ups, downs считаем по Vote.
#   approved = ups >= threshold; rejected = downs >= threshold.
#   Оба условия → конфликт: решает net = ups - downs:
#     net > 0 → :approved; net <= 0 (в т.ч. паритет) → :rejected.
#   Только approved → :approved; только rejected → :rejected; иначе :none.
#
class ModerationService
  DEFAULT_THRESHOLD = 10

  #
  # Порог для бейджа «Одобрено/Отклонено сообществом».
  # Берётся из Setting (если задан) или дефолт.
  #
  # @return [Integer]
  #
  def self.threshold
    # TODO (ROADMAP): перенести в Setting/конфиг. Пока дефолт.
    DEFAULT_THRESHOLD
  end

  #
  # Вычисляет состояние бейджа по голосам сущности (см. алгоритм в доклассе).
  #
  # @param votable [Poi, Photo, PoiComment] голосуемая сущность
  # @param threshold [Integer] порог
  # @return [Symbol] :approved / :rejected / :none
  #
  def self.badge_state(votable, threshold: DEFAULT_THRESHOLD)
    tally = VoteService.tally(votable)
    ups = tally[:ups]
    downs = tally[:downs]

    approved = ups >= threshold
    rejected = downs >= threshold

    return :approved if approved && !rejected
    return :rejected if rejected && !approved

    # Конфликт (оба >= порога) → решает net; паритет (net<=0) → :rejected.
    if approved && rejected
      net = ups - downs
      return :approved if net.positive?

      return :rejected
    end

    # Ни один порог не достигнут — бейджа нет.
    :none
  end

  #
  # Оценивает сущность после голосования: выставляет бейджи и пересчитывает
  # репутацию автора. Вызывается из VersionObserverJob#handle_vote_update.
  #
  # @param votable [Poi, Photo, PoiComment] голосуемая сущность
  # @return [Symbol] состояние бейджа (:approved / :rejected / :none)
  #
  def self.evaluate!(votable)
    return :none unless votable

    state = badge_state(votable)

    case votable
    when Poi
      apply_poi_badge(votable, state)
    when PoiComment
      # Авто-модерация комментариев: порог дизлайков скрывает, перевес апвотов — показывает.
      apply_comment_moderation(votable)
      apply_reputation(votable)
    when Photo
      # Фото: пока только репутация автора (сигнал); скрытие не реализовано.
      apply_reputation(votable)
    end

    state
  end

  #
  # Применяет бейдж к POI. Голоса НЕ меняют status/видимость.
  #   :approved → moderation_source = :community (бейдж «Одобрено сообществом»)
  #   :rejected → community_rejected = true (сигнал админу, с карты НЕ снимаем)
  #   :none     → сброс к admin (голосов меньше порога)
  #
  # @param poi [Poi] точка
  # @param state [Symbol] состояние бейджа
  #
  def self.apply_poi_badge(poi, state)
    # Действуем только для уже видимых точек (approved/imported). Pending
    # не голосуется и бейджей не получает (админ решает всё).
    return unless poi.approved? || poi.imported?

    case state
    when :approved
      # Переход → community: только если ещё не community (иначе лишняя версия).
      poi.update!(moderation_source: :community) unless poi.moderation_source_community?
    when :rejected
      poi.update!(community_rejected: true) unless poi.community_rejected?
    when :none
      # Сброс к admin, если голосов стало меньше порога и нет community-флага.
      if poi.moderation_source_community?
        poi.update!(moderation_source: :admin)
      end
    end

    apply_reputation(poi)
  end

  #
  # Авто-модерация комментария по голосам сообщества.
  #   - downs >= threshold → CommentModerationService.hide! (скрыть);
  #   - ups >= threshold и комментарий скрыт → unhide! (перевес апвотов возвращает).
  # Порог — из Setting.global_threshold (глобальная синглтон-запись; дефолт 10).
  # Методы CommentModerationService идемпотентны: лишних версий не создают.
  #
  # @param comment [PoiComment] комментарий
  #
  def self.apply_comment_moderation(comment)
    tally = VoteService.tally(comment)
    threshold = Setting.global_threshold

    # Скрываем при достижении порога дизлайков (в т.ч. если голоса запоздали).
    if tally[:downs] >= threshold
      CommentModerationService.hide!(comment: comment)
    # Авто-показ только при устойчивом перевесе апвотов: апвоты >= порога
    # И дизлайки ниже порога (иначе возвращаем в скрытое сразу).
    elsif comment.hidden? && tally[:ups] >= threshold && tally[:downs] < threshold
      CommentModerationService.unhide!(comment: comment)
    end
  end

  #
  # Пересчитывает репутацию автора сущности.
  #
  # @param votable [Poi, Photo, PoiComment] сущность с автором (user)
  #
  def self.apply_reputation(votable)
    author = votable.respond_to?(:user) ? votable.user : nil
    return unless author

    ReputationService.reckon!(author)
  end
end
