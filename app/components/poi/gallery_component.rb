# frozen_string_literal: true

#
# Poi::GalleryComponent — таб «Галерея» карточки POI
#
# Отображает:
#   - Сетку фотографий галереи. Свои фото автора (current_user) — ПЕРВЫМИ,
#     затем остальные (скоуп Photo.author_first).
#   - Кнопку «Добавить фото» (только для can_manage?): POST /pois/:id/photos
#     (HTTP/multipart, JSON) — бинарники не идут через Reflex.
#   - Кнопку удаления фото: свои фото у юзера; любые — у admin/moderator.
#   - Lightbox/слайдер по клику на миниатюру (JS-контроллер).
#   - Empty-состояние «Нет фото — будьте первым».
#
# Live-обновление после добавления/удаления — через Broadcaster
# (inner_html [data-poi-gallery]), а НЕ через рендер из Reflex.
#
# @param poi [Poi] объект POI
# @param current_user [User, nil] текущий пользователь (для сортировки/удаления)
#
class Poi::GalleryComponent < ApplicationComponent
  def initialize(poi:, current_user: nil)
    @poi = poi
    @current_user = current_user
  end

  private

  attr_reader :poi, :current_user

  #
  # Фотографии галереи: свои (автора current_user) первыми, затем остальные.
  # Если current_user нет — обычная сортировка по позиции.
  #
  # @return [ActiveRecord::Relation<Photo>]
  #
  def photos
    return poi.photos.ordered unless current_user

    poi.photos.author_first(current_user.id)
  end

  #
  # Есть ли фотографии в галерее
  #
  # @return [Boolean]
  #
  def has_photos?
    poi.photos.any?
  end

  #
  # Может ли текущий пользователь управлять галереей (добавлять фото).
  # Админ/модератор — всегда; обычный юзер — при проксимити 100м
  # (проверяется на бэке; здесь — базовое наличие user + гостевой false).
  #
  # @return [Boolean]
  #
  def can_manage?
    current_user.present?
  end

  #
  # Может ли текущий пользователь удалить конкретное фото.
  # Админ/модератор — любые; юзер — только свои.
  #
  # @param photo [Photo] фото
  # @return [Boolean]
  #
  def can_delete?(photo)
    return false unless current_user
    return true if current_user.has_role?(:admin) || current_user.has_role?(:moderator)

    photo.user_id == current_user.id
  end

  #
  # URL миниатюры фото (THUMB) или fallback no-image.png
  #
  # @param photo [Photo] фото
  # @return [String]
  #
  def thumb_url(photo)
    photo.url(variant: PhotoService::THUMB) || PhotoService.fallback_url
  end

  #
  # URL полноразмера фото (MEDIUM) или fallback no-image.png
  #
  # @param photo [Photo] фото
  # @return [String]
  #
  def medium_url(photo)
    photo.url(variant: PhotoService::MEDIUM) || PhotoService.fallback_url
  end

  #
  # Route helper для POST добавления фото (multipart)
  #
  # @return [String]
  #
  def photos_create_path
    Rails.application.routes.url_helpers.poi_photos_path(poi_id: poi.id)
  end
end
