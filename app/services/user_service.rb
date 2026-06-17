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
  # Возвращает статистику по пользователям для дашборда
  #
  def self.stats
    {
      total: User.count,
      active: User.active.count,
      pending: User.pending_verification.count,
      restricted: User.suspended.count + User.banned.count
    }
  end

  #
  # Обрабатывает вход/регистрацию через Google OAuth
  #
  # @param auth [OmniAuth::AuthHash] данные от провайдера
  # @return [User] найденный или созданный пользователь
  #
  def self.handle_google_oauth(auth)
    new(user: nil, params: {}).handle_google_oauth(auth)
  end

  #
  # Единая точка входа для обновления профиля пользователя
  # Вызывается из Reflex: UserService.call(user: user, params: params)
  #
  # @param user [User] пользователь для обновления
  # @param params [Hash] параметры обновления (:name, :avatar)
  # @return [User] обновленный пользователь
  #
  def self.call(user:, params:)
    service = new(user: user, params: params)
    service.update
  end

  attr_reader :user, :params

  def initialize(user:, params:)
    @user = user
    @params = params.slice(:name, :avatar) # Допускаем только эти поля
  end

  #
  # Основной метод обновления профиля
  # 1. Валидация параметров
  # 2. Обновление полей
  # 3. Обработка аватара
  # 4. Сохранение в БД (триггерит PaperTrail → VersionObserverJob → Broadcaster)
  #
  def update
    validate_params!
    update_user_fields!
    process_avatar!
    save_user!
    user
  end

  #
  # Создает настройки уведомлений по умолчанию для нового пользователя
  #
  # @param user [User] только что созданный пользователь
  #
  def self.create_default_settings(user)
    Setting.create_for_user(user)
  end

  #
  # Обрабатывает логику Google OAuth
  #
  def handle_google_oauth(auth)
    user = User.find_or_initialize_by(provider: 'google_oauth2', uid: auth.uid)
    is_new_user = user.new_record?
    
    if is_new_user
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = SecureRandom.hex(32)
      user.status = :active
      user.skip_confirmation!
    end

    user.save!(validate: false)

    if is_new_user
      self.class.create_default_settings(user)
      attach_oauth_avatar(user, auth.info.image) if auth.info.image.present?
      log_oauth_registration(user, auth)
      GamificationService.award!(:registration, user)
    end

    user
  end

  private

  #
  # Загрузка и оптимизация аватара от OAuth провайдера
  #
  def attach_oauth_avatar(user, image_url)
    image_url = image_url.split("?").first + "?sz=512" if image_url.include?("googleusercontent.com")

    begin
      require "open-uri"
      io = URI.parse(image_url).open(read_timeout: 5)

      processed = ImageTransformService.process(
        io,
        filename: "avatar_oauth_#{user.id}.webp",
        max_size: 300.kilobytes,
        max_dimension: 512,
        format: "webp"
      )

      if processed.respond_to?(:path) && File.exist?(processed.path)
        File.open(processed.path, "rb") do |file_io|
          user.avatar.attach(
            io: file_io,
            filename: "avatar_oauth_#{user.id}.webp",
            content_type: "image/webp"
          )
        end
      end
    rescue StandardError => e
      Rails.logger.warn("User #{user.id}: Failed to attach OAuth avatar: #{e.message}")
    end
  end

  #
  # Логирование события регистрации через OAuth
  #
  def log_oauth_registration(user, auth)
    registration_changes = {
      email: { old: nil, new: user.email },
      name: { old: nil, new: user.name },
      provider: { old: nil, new: auth.provider },
      uid: { old: nil, new: auth.uid }
    }
    registration_changes[:avatar] = { old: nil, new: "Attached" } if user.avatar.attached?
    UserAuditLogger.log_registration(user, registration_changes)
  end

  #
  # Валидирует входные параметры
  #
  def validate_params!
    if params[:name].present? && params[:name].length < 2
      raise UpdateError, I18n.t("user_service.errors.name_too_short")
    end

    if params[:name].present? && params[:name].length > 100
      raise UpdateError, I18n.t("user_service.errors.name_too_long")
    end

    if avatar_present? && !valid_avatar_file?
      raise UpdateError, I18n.t("user_service.errors.invalid_avatar")
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
    allowed_types = [ "image/jpeg", "image/png", "image/webp" ]

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
        format: "webp"
      )

      # Удаляем старый аватар (если есть)
      user.avatar.detach if user.avatar.attached?

      # Прикрепляем обработанное изображение
      user.avatar.attach(
        io: processed_image,
        filename: "avatar_#{SecureRandom.hex(4)}.webp",
        content_type: "image/webp"
      )
    rescue StandardError => e
      Rails.logger.error("Failed to process avatar: #{e.class} #{e.message}")
      raise UpdateError, "Failed to process avatar: #{e.message}"
    end
  end

  #
  # Сохраняет пользователя в БД
  # После успешного сохранения PaperTrail автоматически создаст версию,
  # а VersionObserverJob отправит необходимые обновления через Broadcaster
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
