# frozen_string_literal: true

#
# Ui::AvatarComponent - переиспользуемый аватар
#
# Если у пользователя есть аватар — показывает его.
# Если нет — показывает заглушку app/assets/images/no-image.png.
#
# @example
#   <%= render Ui::AvatarComponent.new(user: @user, size: :xl) %>
#
# @example
#   <%= render Ui::AvatarComponent.new(user: @user, size: :sm) %>
#
class Ui::AvatarComponent < ApplicationComponent
  # @param user [User] пользователь
  # @param size [Symbol] размер (:sm, :md, :lg, :xl)
  def initialize(user:, size: :md)
    @user = user
    @size = size.to_s
  end

  private

  attr_reader :user, :size

  #
  # CSS классы для аватара
  #
  # @return [String] CSS классы
  #
  def css_class
    sizes = {
      "sm" => "w-7 h-7 text-xs",
      "md" => "w-10 h-10 text-sm",
      "lg" => "w-16 h-16 text-xl",
      "xl" => "w-28 h-28 text-3xl"
    }

    size_class = sizes.fetch(size, sizes["md"])
    "inline-block rounded-full object-cover shrink-0 overflow-hidden ring-1 ring-slate-900/10 shadow-sm #{size_class}"
  end

  #
  # URL аватара пользователя (вариант для отображения).
  # Использует ОТНОСИТЕЛЬНЫЙ путь (only_path: true) — аналогично Photo#url и
  # PhotoService. Абсолютные хелперы (rails_representation_url / rails_blob_url)
  # требуют ActiveStorage::Current.url_options (host), который в контексте
  # рендера таблицы из Browser/фонового job не задан — падают на
  # «Cannot generate URL»/«Nil location provided».
  #
  # Порядок приоритета:
  #   1. Прямой URL-строка из мока Lookbook — вернуть как есть.
  #   2. Прикреплённый аватар — variant-путь (fallback на прямой blob-путь).
  #   3. Нет аватара — заглушка app/assets/images/no-image.png.
  #
  # @return [String] относительный URL аватара или заглушки
  #
  def avatar_url
    # Прямой URL-строкой из мока Lookbook — вернуть как есть
    return user.avatar if user.avatar.is_a?(String)

    return asset_path("no-image.png") unless user&.avatar&.attached?

    blob = user.avatar
    begin
      rails_representation_path(blob.variant(resize_to_fill: [ 120, 120 ]), only_path: true)
    rescue StandardError => e
      Rails.logger.warn("AvatarComponent: variant URL failed for user #{user.id}: #{e.class} #{e.message}")
      rails_blob_path(blob, only_path: true)
    end
  rescue StandardError => e
    Rails.logger.warn("AvatarComponent: avatar URL failed for user #{user.id}: #{e.class} #{e.message}")
    asset_path("no-image.png")
  end
end
