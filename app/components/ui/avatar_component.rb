# frozen_string_literal: true

#
# Ui::AvatarComponent - переиспользуемый аватар
#
# Если у пользователя есть аватар — показывает его.
# Если нет — показывает заглушку с инициалами.
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
  # CSS классы для заглушки
  #
  # @return [String] CSS классы
  #
  def fallback_class
    sizes = {
      "sm" => "w-7 h-7 text-xs",
      "md" => "w-10 h-10 text-sm",
      "lg" => "w-16 h-16 text-xl",
      "xl" => "w-28 h-28 text-3xl"
    }

    size_class = sizes.fetch(size, sizes["md"])
    "inline-flex items-center justify-center rounded-full bg-slate-800 text-white font-bold shrink-0 select-none ring-1 ring-slate-900/10 shadow-sm #{size_class}"
  end

  #
  # Инициалы пользователя (первая буква имени)
  #
  # @return [String] инициалы
  #
  def initials
    user&.name.presence ? user.name.first.upcase : "?"
  end

  #
  # URL аватара пользователя (вариант для отображения).
  # Fallback: если variant-URL не построился (нет host в SolidQueue worker,
  # representation ещё не готов и т.п.) — отдаём прямой blob-URL, чтобы аватар
  # отображался всегда (баг «аватар Google OAuth иногда не показывается»).
  #
  # @return [String, nil] URL аватара
  #
  def avatar_url
    return nil unless user&.avatar&.attached?

    # Поддержка прямого URL из мока Lookbook
    return user.avatar.url if user.avatar.respond_to?(:url)

    blob = user.avatar
    begin
      rails_representation_url(blob.variant(resize_to_fill: [ 120, 120 ]))
    rescue StandardError => e
      Rails.logger.warn("AvatarComponent: variant URL failed for user #{user.id}: #{e.class} #{e.message}")
      rails_blob_url(blob)
    end
  rescue StandardError => e
    Rails.logger.warn("AvatarComponent: avatar URL failed for user #{user.id}: #{e.class} #{e.message}")
    nil
  end
end
