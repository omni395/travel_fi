# frozen_string_literal: true

#
# User Service - обработчик бизнес-логики для пользователя
#
# Ответственность:
# 1. Валидирует входные параметры
# 2. Обновляет поля пользователя (name)
# 3. Обрабатывает загрузку аватара через ImageTransformService
# 4. Сохраняет в БД (триггерит after_commit → Broadcaster)
#
# Использование:
#   UserService.call(user: user, params: { name: "John", avatar: file })
#
class UserService
  #
  # Основной входной метод для обновления профиля пользователя
  #
  # @param user [User] пользователь для обновления
  # @param params [Hash] параметры для обновления { name:, avatar: }
  # @return [User] обновленный пользователь
  # @raise [UpdateError] если произойдет ошибка валидации или сохранения
  #
  def self.call(user:, params:)
    service = new(user: user, params: params)
    service.execute
  end

  attr_reader :user, :params

  def initialize(user:, params:)
    @user = user
    @params = params.slice(:name, :avatar) # Допускаем только эти поля
  end

  #
  # Выполняет обновление профиля
  #
  def execute
    validate_params!
    update_user_fields!
    process_avatar! if avatar_present?
    save_user!

    user
  rescue ActiveRecord::RecordInvalid => e
    raise UpdateError, "Failed to save user: #{e.message}"
  rescue StandardError => e
    raise UpdateError, "An error occurred: #{e.message}"
  end

  private

  #
  # Валидирует входные параметры
  #
  def validate_params!
    if params[:name].present? && params[:name].length < 2
      raise UpdateError, "Name must be at least 2 characters long"
    end

    if params[:name].present? && params[:name].length > 100
      raise UpdateError, "Name must be no more than 100 characters"
    end

    if avatar_present? && !valid_avatar_file?
      raise UpdateError, "Invalid avatar file: must be JPG, PNG, or WebP"
    end
  end

  #
  # Обновляет поля пользователя из params
  #
  def update_user_fields!
    user.name = params[:name] if params[:name].present?
  end

  #
  # Проверяет наличие файла аватара в params
  #
  def avatar_present?
    params[:avatar].present?
  end

  #
  # Валидирует формат файла аватара
  # Допускаются: JPEG, PNG, WebP
  #
  def valid_avatar_file?
    avatar = params[:avatar]
    return false unless avatar

    # Проверяем content_type
    allowed_types = ["image/jpeg", "image/png", "image/webp"]

    # Если это uploaded файл (ActionDispatch::Http::UploadedFile)
    if avatar.respond_to?(:content_type)
      return allowed_types.include?(avatar.content_type)
    end

    # Если это обычный File или IO object
    true
  end

  #
  # Обрабатывает загрузку и оптимизацию аватара
  # Использует ImageTransformService для resize, compress, webp conversion
  #
  def process_avatar!
    avatar = params[:avatar]
    return unless avatar

    begin
      # Обрабатываем через ImageTransformService
      processed_image = ImageTransformService.process(
        avatar,
        filename: "avatar_#{user.id}.webp",
        max_dimension: 512,
        format: 'webp'
      )

      # Удаляем старый аватар (если есть)
      user.avatar.detach if user.avatar.attached?

      # Прикрепляем обработанное изображение
      user.avatar.attach(
        io: processed_image,
        filename: "avatar_#{SecureRandom.hex(4)}.webp",
        content_type: 'image/webp'
      )
    rescue StandardError => e
      Rails.logger.error("Failed to process avatar: #{e.class} #{e.message}")
      raise UpdateError, "Failed to process avatar: #{e.message}"
    end
  end

  #
  # Сохраняет пользователя в БД
  # Триггерит валидации и после успешного сохранения вызывает after_commit
  # after_commit вызовет UserBroadcaster для отправки обновлений в браузеры
  #
  def save_user!
    unless user.save
      errors_text = user.errors.full_messages.join(", ")
      raise UpdateError, errors_text
    end
  end

  #
  # Custom exception для ошибок обновления профиля
  #
  class UpdateError < StandardError; end
end
