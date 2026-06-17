class User < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

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
  scope :pending_verification, -> { where(status: :pending_verification) }
  scope :deleted, -> { where(status: :deleted) }
  scope :registered, -> { where(status: :registered) }

  #
  # Ransack 4.x — явный allowlist атрибутов для поиска
  #
  # @param auth_object [Object, nil] объект авторизации
  # @return [Array<String>] список разрешённых атрибутов
  #
  def self.ransackable_attributes(auth_object = nil)
    %w[email name status created_at updated_at confirmation_sent_at confirmed_at]
  end

  #
  # Ransack 4.x — явный allowlist ассоциаций для поиска
  #
  # @param auth_object [Object, nil] объект авторизации
  # @return [Array<String>] список разрешённых ассоциаций
  #
  def self.ransackable_associations(auth_object = nil)
    %w[roles]
  end

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  # ActiveStorage - аватар пользователя
  has_one_attached :avatar

  # Настройки уведомлений
  has_one :setting, dependent: :destroy

  # Геймификация: баллы и бейджи
  has_many :gamifications, dependent: :destroy

  # Валидации
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :status, presence: true

  # Назначение роли :user по умолчанию при создании
  after_create :assign_default_role

  # Генерация реферального кода перед созданием
  before_create :generate_referral_code

  # Виртуальный атрибут для ввода реферального кода при регистрации
  attr_accessor :referral_code_input

  # Валидация реферального кода: если передан — должен существовать в БД
  validate :referral_code_must_exist, on: :create

  private

  #
  # Назначает базовую роль :user новому пользователю
  # Вызывается после создания записи в БД
  #
  def assign_default_role
    return if has_role?(:admin) || has_role?(:moderator)
    add_role(:user) unless has_role?(:user)
  end

  #
  # Генерирует уникальный реферальный код перед созданием пользователя
  # Код: 8 символов, буквы верхнего регистра + цифры
  #
  def generate_referral_code
    loop do
      self.referral_code = SecureRandom.alphanumeric(8).upcase
      break unless User.exists?(referral_code: referral_code)
    end
  end

  #
  # Проверяет что переданный referral_code_input существует в БД
  # Если поле пустое — пропускает (необязательное поле)
  #
  def referral_code_must_exist
    return if referral_code_input.blank?
    return if User.exists?(referral_code: referral_code_input)

    errors.add(:referral_code_input, I18n.t("activerecord.errors.models.user.attributes.referral_code_input.not_found"))
  end

  public

  #
  # Возвращает время последней активности пользователя
  # Определяется по последней записи в PaperTrail versions
  #
  # @return [DateTime, nil]
  #
  def last_activity_at
    PaperTrail::Version.where(item_type: "User", item_id: id)
                       .maximum(:created_at)
  end

  #
  # Проверяет, имеет ли пользователь роль администратора
  # Делегирует в Rolify (has_role?(:admin))
  #
  # @return [Boolean] true если пользователь имеет роль admin
  #
  def admin?
    has_role?(:admin)
  end

  #
  # Проверяет, имеет ли пользователь роль модератора
  # Делегирует в Rolify (has_role?(:moderator))
  #
  # @return [Boolean] true если пользователь имеет роль moderator
  #
  def moderator?
    has_role?(:moderator)
  end

  #
  # Создает или обновляет пользователя из OmniAuth данных
  # Делегирует логику в UserService
  #
  # @param auth [Hash] OmniAuth auth hash от провайдера
  # @return [User] найденный или созданный пользователь
  #
  def self.from_google_oauth(auth)
    UserService.handle_google_oauth(auth)
  end

  # --- Геймификация ---

  #
  # Сумма всех начисленных баллов
  #
  # @return [Integer] общее количество баллов
  #
  def total_points
    gamifications.scores.sum(:value)
  end

  #
  # Список ID выданных бейджей
  #
  # @return [Array<Integer>]
  #
  def badge_ids
    gamifications.badges.pluck(:value)
  end

  #
  # Проверяет, есть ли у пользователя бейдж
  #
  # @param badge_id [Integer] ID бейджа
  # @return [Boolean]
  #
  def earned_badge?(badge_id)
    gamifications.badges.exists?(value: badge_id)
  end

  # Примечание: мутационные методы (add_points, grant_badge, remove_badge, update_level!)
  # вынесены в GamificationService для соблюдения архитектурного принципа
  # "Вся бизнес-логика в Service слое, в моделях — только данные"
  # Используйте: GamificationService.add_points!(user, num, action_key:)
  #             GamificationService.grant_badge!(user, badge_id)
  #             GamificationService.remove_badge!(user, badge_id)
  #             GamificationService.update_level!(user)
end
