# frozen_string_literal: true

#
# Admin::Comments::TableComponent — таблица модерации комментариев в админке.
#
# Колонки: текст, автор, POI, дата, голоса (ups/downs), статус (скрыт/виден),
# действия (Скрыть/Показать/Удалить). Контейнер-цель [data-admin-comments-list]
# задаётся на обёртке в шаблоне страницы, НЕ на корне компонента (догма inner_html).
#
# @param comments [ActiveRecord::Relation<PoiComment>] список комментариев
# @param pagy [Pagy, nil] объект пагинации
#
class Admin::Comments::TableComponent < ApplicationComponent
  attr_reader :comments, :pagy

  #
  # @param comments [ActiveRecord::Relation] комментарии
  # @param pagy [Pagy, nil] объект пагинации
  #
  def initialize(comments:, pagy: nil)
    @comments = comments
    @pagy = pagy
  end

  #
  # Актуальный подсчёт голосов комментария (ups/downs) через VoteService.
  #
  # @param comment [PoiComment]
  # @return [Hash] { ups:, downs: }
  #
  def vote_tally(comment)
    VoteService.tally(comment)
  end
end
