class User < ApplicationRecord
  has_merit

  rolify

  # PaperTrail - аудит всех изменений пользователя
  has_paper_trail
  
  # Enum для статусов пользователя
  enum :status, {
    registered: "registered",
    pending_verification: "pending_verification",
    active: "active",
    suspended: "suspended",
    banned: "banned",
    deleted: "deleted"
  }, validate: true

  # Scopes для фильтрации по статусу
  scope :active, -> { where(status: :active) }
  scope :suspended, -> { where(status: :suspended) }
  scope :banned, -> { where(status: :banned) }
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  # ActiveStorage - аватар пользователя
  has_one_attached :avatar
  
  # Валидации
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :status, presence: true

  # Callbacks - отправка обновлений через WebSocket
  after_commit :broadcast_update, on: [:create, :update], if: :should_broadcast?

  #
  # Проверяет является ли пользователь администратором
  # Использует Rolify для проверки роли admin
  #
  def admin?
    has_role?(:admin)
  end

  #
  # Проверяет является ли пользователь модератором
  # Использует Rolify для проверки роли moderator
  #
  def moderator?
    has_role?(:moderator)
  end

  #
  # Возвращает URL аватара: либо из ActiveStorage, либо no-image.png
  #
  def avatar_url
    if avatar.attached? && avatar.blob.variable?
      avatar
    else
      "no-image.png"
    end
  end

  #
  # Загружает и обрабатывает аватар из URL (OAuth)
  # Используется при регистрации через OAuth провайдер
  # Применяет ImageTransformService для оптимизации (resize, compress, webp)
  #
  # @param image_url [String] URL изображения от провайдера
  #
  def avatar_from_oauth(image_url)
    return unless image_url.present?
    
    begin
      image_data = URI.open(image_url)
      
      # Обрабатываем изображение через ImageTransformService
      # - Resize до 512x512 с сохранением aspect ratio
      # - Конвертируем в webp
      # - Сжимаем до 300KB
      processed_image = ImageTransformService.process(
        image_data,
        filename: "avatar.webp",
        max_dimension: 512,
        format: 'webp'
      )
      
      # Прикрепляем обработанное изображение с уникальным именем
      avatar.attach(
        io: processed_image,
        filename: "avatar_#{SecureRandom.hex(4)}.webp",
        content_type: 'image/webp'
      )
    rescue StandardError => e
      Rails.logger.warn("Failed to attach avatar for user #{id}: #{e.message}")
    end
  end

  #
  # Создает или обновляет пользователя из OmniAuth данных (Google, GitHub и т.д.)
  # Используется в OmniAuth callback контроллере
  #
  # @param auth [Hash] OmniAuth auth hash от провайдера
  # @return [User] найденный или созданный пользователь
  #
  def self.from_google_oauth(auth)
    # Ищем пользователя по provider + uid комбинации
    user = find_or_initialize_by(provider: 'google_oauth2', uid: auth.uid)
    
    # Если это новый пользователь, заполняем данные от OAuth провайдера
    if user.new_record?
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = SecureRandom.hex(32)
      user.status = :active
      # Devise: skip_confirmation! это правильный способ - пропускает требование подтверждения
      user.skip_confirmation!
      # Назначаем роль user через Rolify
      user.add_role(:user)
    end
    
    # Сохраняем флаг ПЕРЕД сохранением (после save! new_record? станет false)
    is_new_user = user.new_record?

    # Attach Google avatar ТОЛЬКО при первом логине
    # При повторном логине аватар не трогаем - юзер может его заменить на свой
    if is_new_user && auth.info.image.present?
      begin
        image_url = auth.info.image
        # Google возвращает URL с параметрами размера, добавляем параметр для большого размера
        image_url = image_url.split('?').first + '?sz=512' if image_url.include?('googleusercontent.com')

        Rails.logger.info("User #{user.id || 'new'}: Attempting to attach Google avatar from URL: #{image_url}")
        io = URI.parse(image_url).open(read_timeout: 5)

        # Process image (compress, convert to webp)
        processed = ImageTransformService.process(
          io,
          filename: "avatar_google_#{user.id}.webp",
          max_size: 300.kilobytes,
          max_dimension: 512,
          format: 'webp'
        )

        if processed.respond_to?(:path) && File.exist?(processed.path)
          file_io = File.open(processed.path, 'rb')
          begin
            # Create blob directly to avoid validation rollback
            blob = ActiveStorage::Blob.create_and_upload!(
              io: file_io,
              filename: "avatar_google_#{user.id}.webp",
              content_type: 'image/webp'
            )

            # Create attachment record directly, bypassing avatar validations
            ActiveStorage::Attachment.create!(
              record_type: 'User',
              record_id: user.id,
              name: 'avatar',
              blob_id: blob.id
            )

            Rails.logger.info("User #{user.id}: Google avatar attached and compressed on first login")
          ensure
            file_io.close if file_io
          end
          processed.unlink if processed.respond_to?(:unlink)
        else
          Rails.logger.warn("User #{user.id}: Google avatar processing failed")
        end
      rescue => e
        Rails.logger.warn("User #{user.id}: Failed to attach Google avatar: #{e.class} #{e.message}")
      end
    end
    
    user.save!(validate: false)

    # Логируем регистрацию через OAuth если это новый пользователь
    if is_new_user
      registration_changes = {
        email: { old: nil, new: user.email },
        name: { old: nil, new: user.name },
        provider: { old: nil, new: 'google_oauth2' },
        uid: { old: nil, new: user.uid }
      }
      registration_changes[:avatar] = { old: nil, new: "Attached" } if user.avatar.attached?
      UserAuditLogger.log_registration(user, registration_changes)
    end

    user
  end

  private

  #
  # Проверяет нужно ли отправлять обновление (не при создании через OAuth обычно)
  #
  def should_broadcast?
    # Отправляем broadcast только если пользователь уже подтвержден
    # и это не начальное создание
    persisted? && will_save_change_to_name?
  end

  #
  # Отправляет обновления профиля через WebSocket (Broadcaster)
  # Вызывается автоматически из after_commit
  #
  def broadcast_update
    # Определяем контекст вызова (админка или пользовательская часть)
    # Если изменение произошло из админки, вызываем Admin::UserBroadcaster
    # Иначе вызываем UserBroadcaster

    # Проверяем наличие параметров контекста
    if Current.try(:admin_context)
      Admin::UserBroadcaster.broadcast_user_update(self)
    else
      UserBroadcaster.call(user: self)
    end
  rescue StandardError => e
    Rails.logger.error("Failed to broadcast user update: #{e.class} #{e.message}")
  end
end

