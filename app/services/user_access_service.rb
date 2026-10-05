# frozen_string_literal: true

#
# UserAccessService — единый классификатор доступа пользователя по статусу.
#
# Централизует матрицу «кто что может» (без размазанных магических строк
# "active"/"suspended" по всему коду):
#   - can_view_details?  детали точки (модалка) видит active и suspended;
#   - can_interact?      комментировать / голосовать / добавлять фото — только active;
#   - interaction_block  причина, по которой активный юзер НЕ может взаимодействовать
#                        (сейчас только suspended) — для серверной плашки.
#
# Гость / pending / inactive / deleted / banned — деталей не видят и не
# взаимодействуют (guard в PoiReflex#show_detail_modal).
#
class UserAccessService
  # Статусы, имеющие доступ к деталям точки (модалке).
  DETAIL_VIEWER_STATUSES = %w[active suspended].freeze

  # Единственный статус, которому разрешено ВЗАИМОДЕЙСТВОВАТЬ (комм./голос/фото).
  INTERACTIVE_STATUS = "active"

  class << self
    #
    # Может ли пользователь видеть детали точки (модалку show_detail_modal).
    #
    # @param user [User, nil] пользователь
    # @return [Boolean]
    #
    def can_view_details?(user)
      user.present? && DETAIL_VIEWER_STATUSES.include?(user.status)
    end

    #
    # Может ли пользователь взаимодействовать (комментировать/голосовать/фото).
    #
    # @param user [User, nil] пользователь
    # @return [Boolean]
    #
    def can_interact?(user)
      user.present? && user.status == INTERACTIVE_STATUS
    end

    #
    # Причина, блокирующая взаимодействие активного/видимого юзера.
    # Сейчас единственная причина — статус suspended с датой снятия блока.
    #
    # @param user [User, nil] пользователь
    # @return [Hash, nil] { reason: :suspended, unlock_at: Time } или nil, если можно
    #
    def interaction_block(user)
      return nil unless user.present?
      return nil unless user.status == "suspended"

      { reason: :suspended, unlock_at: user.suspended_until }
    end
  end
end
