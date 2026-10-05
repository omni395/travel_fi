# frozen_string_literal: true

#
# Users::RewardsComponent - история начислений токенов TFT в профиле юзера.
#
# Показывает плоскую ленту начислений (по дате, без группировки по типу) с
# пагинацией (pagy, 15/стр) и ссылкой на источник (POI/фото/комментарий)
# через реляционную связь UserReward#source (источник правды — PaperTrail).
# Сверху — сводные мини-карточки с итогами по типам начислений.
#
# @param user [User] пользователь
# @param page [Integer, nil] номер страницы истории (пагинация)
#
class Users::RewardsComponent < ApplicationComponent
  include Pagy::Method

  # Количество записей на страницу истории начислений.
  PER_PAGE = 15

  # Порядок и иконки MDI сводных карточек по action_key.
  # Отсутствующие ключи группируются в конец по алфавиту.
  SUMMARY_ORDER = {
    "registration" => "account-check",
    "referral_bonus_referrer" => "account-multiple-plus",
    "referral_bonus_new_user" => "account-plus",
    "poi_create" => "map-marker-plus",
    "poi_photo_add" => "image-plus",
    "comment_create" => "comment-plus",
    "poi_vote" => "thumb-up"
  }.freeze

  def initialize(user:, page: nil)
    @user = user
    @page = page.presence&.to_i || 1
  end

  private

  attr_reader :user, :page

  #
  # request mock для pagy() в SolidQueue worker (аналог Broadcaster).
  # Компонент рендерится и в браузере (страница профиля), и в SolidQueue worker
  # (TokenTransactionBroadcaster), где нет request → Pagy::Method#pagy упал бы
  # NameError "undefined local variable or method 'request'". Pagy затем заменяет
  # эту заглушку на Pagy::Request.
  #
  # @return [ActionDispatch::Request] заглушка запроса
  #
  def request
    @request ||= ActionDispatch::Request.new({})
  end

  #
  # Записи текущей страницы истории и объект Pagy для пагинации.
  #
  # Пагинация через helper pagy() (Pagy::Method): прямой Pagy.new в Pagy 43.6.1
  # бросает ArgumentError, поэтому используем проверенный проектный helper с
  # mock-request. Внешняя страница (профиль) и worker рендерят одинаково.
  #
  # @return [Array<pagy, records>] [Pagy, Array<TokenTransaction>]
  #
  def paginated
    scope = user.token_transactions.ordered
    pagy(scope, limit: PER_PAGE, page: page)
  end

  #
  # Транзакции текущей страницы (плоская лента, ordered по created_at desc).
  #
  # @return [Array<TokenTransaction>]
  #
  def transactions
    paginated.last
  end

  #
  # Объект Pagy для рендера пагинации (prev/next, page, pages).
  #
  # Имя `pagination` (не `pagy`) — приватный геттер иначе перекрывает helper
  # Pagy::Method#pagy, используемый внутри #paginated.
  #
  # @return [Pagy]
  #
  def pagination
    paginated.first
  end

  #
  # Сводные мини-карточки по типам начислений: сумма TFT и иконка MDI для
  # каждого action_key. Считается по ВСЕМ транзакциям юзера (не только текущей
  # страницы), сортировка — по SUMMARY_ORDER, неизвестные ключи — в конец.
  #
  # @return [Array<Hash>] [{ action_key:, label:, total:, icon: }]
  #
  def summary_by_action
    totals = user.token_transactions.group(:action_key).sum(:amount)
    totals.map do |action_key, total|
      {
        action_key: action_key,
        label: action_key_label_from_key(action_key),
        total: total,
        icon: summary_icon(action_key)
      }
    end.sort_by { |s| SUMMARY_ORDER.key?(s[:action_key]) ? SUMMARY_ORDER.keys.index(s[:action_key]) : SUMMARY_ORDER.size }
  end

  #
  # Иконка MDI для сводной карточки по action_key (fallback — "trophy").
  #
  # @param action_key [String] ключ начисления
  # @return [String] имя MDI-иконки без префикса "mdi-"
  #
  def summary_icon(action_key)
    SUMMARY_ORDER.fetch(action_key, "trophy")
  end

  #
  # Локализованная подпись типа начисления (action_key) по ключу напрямую.
  #
  # @param action_key [String] ключ начисления
  # @return [String]
  #
  def action_key_label_from_key(action_key)
    t(".action_keys.#{action_key}", default: action_key.humanize)
  end

  #
  # Целевые данные открытия источника начисления (POI-модалка) или nil.
  # Читаем реляционную связь UserReward#source напрямую (источник правды —
  # PaperTrail-версия; связь аудируется, т.к. модель has_paper_trail).
  #
  # @param transaction [TokenTransaction] транзакция
  # @return [Hash, nil] { poi_id:, tab:, selector:, link_label: }
  #
  def source_target(transaction)
    source = transaction.user_reward&.source
    return nil unless source

    case source
    when Poi then view_target(source, "details", nil)
    when Photo then view_target_photo(source)
    when PoiComment then view_target(source.poi, "comments", "[data-comment-id='#{source.id}']")
    when Vote then source_target_votable(source.votable)
    end
  end

  #
  # Целевые данные для POI.
  #
  # @param poi [Poi] POI
  # @param tab [String] вкладка
  # @param selector [String, nil] селектор подсветки
  # @return [Hash, nil]
  #
  def view_target(poi, tab, selector)
    return nil unless poi

    { poi_id: poi.id, tab: tab, selector: selector, link_label: poi.localized_name }
  end

  #
  # Целевые данные для фото: POI-владелец, вкладка gallery, подсветка фото.
  #
  # @param photo [Photo] фото
  # @return [Hash, nil]
  #
  def view_target_photo(photo)
    view_target(photo.poi, "gallery", "[data-photo-id='#{photo.id}']")
  end

  #
  # Целевые данные для голоса: рекурсивно по голосуемой сущности.
  #
  # @param votable [ActiveRecord::Base, nil] голосуемая сущность
  # @return [Hash, nil]
  #
  def source_target_votable(votable)
    case votable
    when Poi then view_target(votable, "details", nil)
    when Photo then view_target_photo(votable)
    when PoiComment then view_target(votable.poi, "comments", "[data-comment-id='#{votable.id}']")
    end
  end

  #
  # Локализованная подпись типа начисления (action_key).
  #
  # @param transaction [TokenTransaction] транзакция
  # @return [String]
  #
  def action_key_label(transaction)
    t(".action_keys.#{transaction.action_key}", default: transaction.action_key.humanize)
  end

  #
  # Форматирует сумму токенов без лишних нулей (10.0 → "10").
  #
  # @param amount [Numeric] сумма
  # @return [String]
  #
  def format_amount(amount)
    helpers.number_with_precision(amount, precision: 2, strip_insignificant_zeros: true)
  end
end
