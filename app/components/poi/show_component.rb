# frozen_string_literal: true

#
# Poi::ShowComponent — карточка POI (шапка + табы)
#
# ХОСТ карточки. Шапка — двухколоночная структура по образцу Ui::TooltipComponent
# (фото-cover слева, категория/название/статус/рейтинг/адрес справа) + кнопки Edit/Close.
# Ниже — табы через Ui::TabsComponent:
#   - details  → Poi::DetailsComponent  (полная детальная информация + мини-карта)
#   - comments → Poi::CommentsComponent (заглушка, реализация в ROADMAP)
#   - ratings  → Poi::RatingsComponent  (заглушка, реализация в ROADMAP)
#   - gallery  → Poi::GalleryComponent  (заглушка, реализация в ROADMAP)
#
# Параметры:
#   poi          [Poi] объект POI
#   current_user [User, nil] текущий пользователь (кнопка Edit)
#   comments     [ActiveRecord::Relation<PoiComment>, nil] комментарии (резерв для PoiReflex#create_comment)
#   user_lat     [Float, nil] широта пользователя (резерв для future-проверок)
#   user_lng     [Float, nil] долгота пользователя
#
class Poi::ShowComponent < ApplicationComponent
  attr_reader :poi, :current_user, :comments, :user_lat, :user_lng

  def initialize(poi:, current_user: nil, comments: nil, user_lat: nil, user_lng: nil)
    @poi = poi
    @current_user = current_user
    @comments = comments || []
    @user_lat = user_lat
    @user_lng = user_lng
  end

  private

  #
  # Возвращает CSS класс бейджа статуса
  #
  # @return [String]
  #
  def status_badge_class
    return "bg-gray-100 text-gray-800" unless poi

    case poi.status
    when "approved" then "bg-green-100 text-green-800"
    when "pending" then "bg-yellow-100 text-yellow-800"
    when "rejected" then "bg-red-100 text-red-800"
    when "archived" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  #
  # URL cover-фото POI (MEDIUM вариант) или fallback no-image.png.
  # Единый источник с тултипом карты — PhotoService.
  #
  # @return [String] URL изображения
  #
  def cover_photo_url
    PhotoService.cover_photo_url(poi, variant: PhotoService::MEDIUM) || PhotoService.fallback_url
  end

  #
  # Может ли текущий пользователь редактировать POI?
  #
  # @return [Boolean]
  #
  def can_edit?
    return false if current_user.blank? || poi.blank?

    current_user.has_role?(:admin) || current_user.has_role?(:moderator) || poi.user_id == current_user.id
  end

  #
  # Список табов для Ui::TabsComponent
  #
  # @return [Array<Hash>] массив { id:, name:, icon: }
  #
  def tabs
    [
      { id: "details", name: t(".tab_details"), icon: "mdi-information-outline" },
      { id: "comments", name: t(".tab_comments"), icon: "mdi-comment-text-outline" },
      { id: "ratings", name: t(".tab_ratings"), icon: "mdi-star-outline" },
      { id: "gallery", name: t(".tab_gallery"), icon: "mdi-image-multiple-outline" }
    ]
  end

  #
  # HTML панелей табов. Вложенные компоненты рендерятся через render (view_context) —
  # допустимо при рендере из Reflex и из фонового job (SolidQueue worker).
  #
  # @return [Hash] { tab_id => html }
  #
  def panels
    {
      "details" => render(Poi::DetailsComponent.new(poi: poi)),
      "comments" => render(Poi::CommentsComponent.new(poi: poi, current_user: current_user)),
      "ratings" => render(Poi::RatingsComponent.new(poi: poi)),
      # Контейнер-цель [data-poi-gallery] на обёртке (НЕ на корне компонента —
      # догма inner_html без вложенности). Обновляется Broadcaster/Reflex.
      "gallery" => content_tag(:div, render(Poi::GalleryComponent.new(poi: poi, current_user: current_user)), data: { poi_gallery: true })
    }
  end
end
