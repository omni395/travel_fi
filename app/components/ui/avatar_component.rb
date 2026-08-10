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
    "avatar-ui avatar-ui--#{size}"
  end

  #
  # CSS классы для заглушки
  #
  # @return [String] CSS классы
  #
  def fallback_class
    "avatar-ui--fallback avatar-ui--#{size}"
  end

  #
  # Инициалы пользователя (первая буква имени)
  #
  # @return [String] инициалы
  #
  def initials
    user.name.first.upcase
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
    return nil unless user.avatar.attached?

    blob = user.avatar
    begin
      rails_representation_url(blob.variant(resize_to_fill: [120, 120]))
    rescue StandardError => e
      Rails.logger.warn("AvatarComponent: variant URL failed for user #{user.id}: #{e.class} #{e.message}")
      rails_blob_url(blob)
    end
  rescue StandardError => e
    Rails.logger.warn("AvatarComponent: avatar URL failed for user #{user.id}: #{e.class} #{e.message}")
    nil
  end
end
