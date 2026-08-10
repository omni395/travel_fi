# frozen_string_literal: true

#
# User Service - обработчик бизнес-логики для пользователя
#
# Ответственность:
# 1. Валидирует входные параметры
# 2. Обновляет поля пользователя (name)
# 3. Обрабатывает загрузку аватара через PhotoService
# 4. Сохраняет в БД (триггерит after_commit → Broadcaster)
#
# Использование:
#   UserService.call(user: user, params: { name: "John", avatar: file })
#
class UserService
  #
  # Обрабатывает вход/регистрацию через Google OAuth
  #
  # @param auth [OmniAuth::AuthHash] данные от провайдера
  # @param referral_code_input [String, nil] реферальный код (опционально)
  # @return [User] найденный или созданный пользователь
  #
  def self.handle_google_oauth(auth, referral_code_input = nil)
    new(user: nil, params: {}).handle_google_oauth(auth, referral_code_input)
  end

  #
  # Единая точка входа для обновления профиля пользователя
  # Вызывается из Reflex: UserService.call(user: user, params: params)
  #
  # @param user [User] пользователь для обновления
  # @param params [Hash] параметры обновления (:name, :avatar)
  # @return [User] обновленный пользователь
  #
  #
  # Забирает разблокированные по лок-периоду начисления пользователя: ставит
  # relay-Джоб (SolidQueue) для каждой available-записи, чтобы токены ушли на
  # custodial-кошелёк. on-chain отправка — асинхронно, через очередь.
  #
  # @param user [User] пользователь, забирающий награды
  # @return [Integer] количество поставленных в очередь начислений
  #
  def self.claim_rewards!(user)
    available = user.token_transactions.unclaimed.available
    available.each do |tx|
      TokenTransactionRelayJob.perform_later(tx.id)
    end
    available.count
  rescue StandardError => e
    Rails.logger.error("UserService.claim_rewards! error: #{e.class} #{e.message}")
    0
  end

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
  # Переводит юзера в статус active после подтверждения email.
  # Вызывается из Users::ConfirmationsController#show.
  # Мутация вынесена из модели (User#confirm_email! удалён) в Service слой.
  #
  # @param user [User] пользователь, подтвердивший email
  # @return [Boolean] true если статус обновлён
  #
  def self.confirm_email(user)
    user.update!(status: :active)
  end

  #
  # Переводит активных пользователей без активности за N месяцев в статус inactive.
  # Активность определяется по последней записи в PaperTrail versions
  # (User#last_activity_at). Пользователи без версий (вне аудита) не трогаются.
  # Вызывается из UserInactivityJob (SolidQueue recurring, config/recurring.yml).
  #
  # @param inactivity_months [Integer] порог неактивности (по умолчанию 6)
  # @return [Integer] количество переведённых в inactive
  #
  def self.mark_inactive_old_users(inactivity_months: 6)
    threshold = inactivity_months.months.ago
    marked = 0

    User.where(status: :active).find_each do |user|
      last_activity = user.last_activity_at
      next if last_activity.nil? || last_activity >= threshold

      user.update!(status: :inactive)
      marked += 1
    end

    marked
  end

  #
  # Фиксирует реферальную связь при регистрации (persisted в БД).
  # Вызывается в момент создания юзера (email или OAuth), чтобы связь
  # пережила подтверждение почты (ссылка из письма — другой запрос,
  # виртуальный атрибут referral_code_input там недоступен).
  #
  # @param user [User] только что созданный пользователь
  # @param referral_code_input [String, nil] реферальный код
  #
  def self.save_referral!(user, referral_code_input)
    return if referral_code_input.blank?
    return if user.referred_by_id.present?

    referrer = User.find_by(referral_code: referral_code_input)
    return unless referrer

    user.update!(referred_by: referrer)
  end

  #
  # Начисляет бонусы за регистрацию: welcome-токены + реферальный бонус.
  # Вызывается ТОЛЬКО когда юзер достиг статуса active (для email — после
  # подтверждения, для OAuth — сразу). Реферальная связь уже в БД (save_referral!).
  #
  # @param user [User] активный пользователь
  #
  def self.award_registration_bonus!(user)
    GamificationService.award!(:registration, user)

    referrer = user.referred_by
    return unless referrer

    GamificationService.award_referral!(referrer, user)
  end

  #
  # Обрабатывает логику Google OAuth.
  # OAuth-юзер сразу активен → custodial-кошелёк + welcome-токены и реферальные
  # бонусы начисляются сразу (накопление = по достижению статуса active).
  #
  # @param auth [OmniAuth::AuthHash] данные от провайдера
  # @param referral_code_input [String, nil] реферальный код (опционально)
  # @return [User]
  #
  def handle_google_oauth(auth, referral_code_input = nil)
    user = User.find_or_initialize_by(provider: 'google_oauth2', uid: auth.uid)
    is_new_user = user.new_record?

    if is_new_user
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = SecureRandom.hex(32)
      user.status = :active
      user.skip_confirmation!
    end

    # Единая транзакция для нового OAuth-юзера: создание + кошелёк + начисления.
    # Атомарность исключает частичное состояние (юзер есть, а бонусов нет —
    # падение на любом этапе откатывает всю ветку начислений).
    ActiveRecord::Base.transaction do
      user.save!(validate: false)

      if is_new_user
        self.class.create_default_settings(user)
        attach_oauth_avatar(user, auth.info.image) if auth.info.image.present?
        log_oauth_registration(user, auth)
        self.class.save_referral!(user, referral_code_input)
        # OAuth: юзер сразу активен → скрытый custodial-кошелёк и начисления сразу.
        WalletService.create_hidden_wallet(user: user)
        self.class.award_registration_bonus!(user)
      end
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

      processed = PhotoService.process(
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
  # Использует PhotoService для resize, compress, webp conversion
  #
  def process_avatar!
    avatar = params[:avatar]
    return unless avatar

    begin
      # Обрабатываем через PhotoService
      processed_image = PhotoService.process(
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
