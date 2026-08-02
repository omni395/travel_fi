# frozen_string_literal: true

#
# Admin::UserService - сервис для управления пользователями в админке
#
# Ответственность:
# 1. Обновление данных пользователя (name, email, status)
# 2. Изменение статуса пользователя
# 3. Управление ролями пользователя (добавление/удаление)
# 4. Удаление пользователя (мягкое удаление)
#
# Использование:
#   Admin::UserService.update(user: user, params: { name: "John" }, current_user: admin)
#   Admin::UserService.change_status(user: user, status: "active", current_user: admin)
#   Admin::UserService.add_role(user: user, role: role, current_user: admin)
#   Admin::UserService.remove_role(user: user, role: role, current_user: admin)
#   Admin::UserService.destroy(user: user, current_user: admin)
#
class Admin::UserService
  #
  # Обновляет данные пользователя
  #
  # @param user [User] пользователь для обновления
  # @param params [Hash] параметры для обновления { name:, email:, status: }
  # @param current_user [User] пользователь, выполняющий обновление
  # @return [User] обновленный пользователь
  # @raise [UpdateError] если произойдет ошибка валидации или сохранения
  #
  def self.update(user:, params:, current_user:)
    service = new(user: user, params: params, current_user: current_user)
    service.execute_update
  end

  #
  # Изменяет статус пользователя
  #
  # @param user [User] пользователь для изменения статуса
  # @param status [String] новый статус
  # @param current_user [User] пользователь, выполняющий изменение
  # @return [User] пользователь с обновленным статусом
  # @raise [StatusError] если произойдет ошибка валидации или изменения
  #
  def self.change_status(user:, status:, current_user:)
    service = new(user: user, current_user: current_user)
    service.execute_status_change(status: status)
  end

  #
  # Добавляет роль пользователю
  #
  # @param user [User] пользователь для добавления роли
  # @param role [Role] роль для добавления
  # @param current_user [User] пользователь, выполняющий действие
  # @return [User] пользователь с добавленной ролью
  # @raise [RoleError] если произойдет ошибка валидации или добавления
  #
  def self.add_role(user:, role:, current_user:)
    service = new(user: user, current_user: current_user)
    service.execute_role_action(role: role, action: :add)
  end

  #
  # Удаляет роль у пользователя
  #
  # @param user [User] пользователь для удаления роли
  # @param role [Role] роль для удаления
  # @param current_user [User] пользователь, выполняющий действие
  # @return [User] пользователь с удаленной ролью
  # @raise [RoleError] если произойдет ошибка валидации или удаления
  #
  def self.remove_role(user:, role:, current_user:)
    service = new(user: user, current_user: current_user)
    service.execute_role_action(role: role, action: :remove)
  end

  #
  # Удаляет пользователя (мягкое удаление)
  #
  # @param user [User] пользователь для удаления
  # @param current_user [User] пользователь, выполняющий удаление
  # @return [User] удаленный пользователь
  # @raise [DestroyError] если произойдет ошибка удаления
  #
  def self.destroy(user:, current_user:)
    service = new(user: user, current_user: current_user)
    service.execute_destroy
  end

  #
  # Ищет пользователей по запросу и статусу через Ransack
  #
  # @param query [String, nil] поисковый запрос (имя или email)
  # @param status [String, nil] статус для фильтрации
  # @param sort_column [String, nil] колонка для сортировки
  # @param sort_direction [String, nil] направление сортировки (asc/desc)
  # @return [ActiveRecord::Relation] отфильтрованные пользователи
  #
  def self.search_users(query: nil, status: nil, sort_column: nil, sort_direction: nil)
    users = User.includes(:roles).where.not(status: "deleted")

    conditions = {}
    conditions[:status_eq] = status if status.present?
    conditions[:name_or_email_cont] = query if query.present?

    result = users.ransack(conditions).result

    # Применяем сортировку
    if sort_column.present? && %w[name email status created_at updated_at].include?(sort_column)
      direction = sort_direction == "asc" ? :asc : :desc
      result = result.order(sort_column => direction)
    else
      result = result.order(created_at: :desc)
    end

    result
  end

  attr_reader :user, :params, :current_user

  def initialize(user:, params: {}, current_user:)
    @user = user
    # role_id включён: update_user_roles! читает params[:role_id]
    @params = params.slice(:name, :email, :status, :role_id)
    @current_user = current_user
  end

  public

  #
  # Выполняет обновление пользователя
  #
  def execute_update
    validate_update_params!
    update_user_fields!
    update_user_roles!

    save_user!

    user
  rescue ActiveRecord::RecordInvalid => e
    raise UpdateError, "Failed to save user: #{e.message}"
  rescue StandardError => e
    raise UpdateError, "An error occurred: #{e.message}"
  end

  #
  # Выполняет изменение статуса
  #
  def execute_status_change(status:)
    @status = status
    validate_status!
    validate_status_transition!

    change_status!

    user
  rescue ActiveRecord::RecordInvalid => e
    raise StatusError, "Failed to change status: #{e.message}"
  rescue StandardError => e
    raise StatusError, "An error occurred: #{e.message}"
  end

  #
  # Выполняет действие с ролью
  #
  def execute_role_action(role:, action:)
    @role = role
    @action = action
    validate_role_action!
    validate_user_for_role!

    execute_role_action!

    user
  rescue StandardError => e
    raise RoleError, "An error occurred: #{e.message}"
  end

  #
  # Выполняет удаление пользователя
  #
  def execute_destroy
    validate_user_for_destroy!
    validate_deletion!

    destroy_user!

    user
  rescue StandardError => e
    raise DestroyError, "An error occurred: #{e.message}"
  end

  #
  # Валидирует параметры обновления
  #
  def validate_update_params!
    if params[:name].present? && params[:name].length < 2
      raise UpdateError, "Name must be at least 2 characters long"
    end

    if params[:name].present? && params[:name].length > 100
      raise UpdateError, "Name must be no more than 100 characters"
    end

    if params[:email].present? && !valid_email_format?(params[:email])
      raise UpdateError, "Invalid email format"
    end

    if params[:status].present? && !valid_status?(params[:status])
      raise UpdateError, "Invalid status: #{params[:status]}"
    end
  end

  #
  # Проверяет формат email
  #
  def valid_email_format?(email)
    email.match?(/\A[^@\s]+@[^@\s]+\z/)
  end

  #
  # Проверяет валидность статуса
  #
  def valid_status?(status)
    User.statuses.values.include?(status)
  end

  #
  # Обновляет поля пользователя из params
  #
  def update_user_fields!
    user.name = params[:name] if params[:name].present?
    user.email = params[:email] if params[:email].present?
    user.status = params[:status] if params[:status].present?
  end

  #
  # Обновляет роль пользователя (один пользователь — одна роль)
  # Заменяет все текущие роли на выбранную
  #
  def update_user_roles!
    return unless params[:role_id].present?

    new_role = Role.find_by(id: params[:role_id])
    return unless new_role

    user.roles = [ new_role ]
  end

  #
  # Сохраняет пользователя в БД
  #
  def save_user!
    unless user.save
      errors_text = user.errors.full_messages.join(", ")
      raise UpdateError, errors_text
    end
  end

  #
  # Валидирует статус
  #
  def validate_status!
    unless valid_status?(@status)
      raise StatusError, "Invalid status: #{@status}"
    end
  end

  #
  # Валидирует переход статуса
  #
  def validate_status_transition!
    # Нельзя менять статус удаленному пользователю
    if user.status == "deleted"
      raise StatusError, "Cannot change status of deleted user"
    end

    # Нельзя менять статус самому себе (кроме активации)
    if user == current_user && @status != "active"
      raise StatusError, "Cannot change your own status"
    end
  end

  #
  # Изменяет статус пользователя
  #
  def change_status!
    user.status = @status

    unless user.save
      errors_text = user.errors.full_messages.join(", ")
      raise StatusError, errors_text
    end
  end

  #
  # Валидирует действие с ролью
  #
  def validate_role_action!
    unless [ :add, :remove ].include?(@action)
      raise RoleError, "Invalid action: #{@action}"
    end
  end

  #
  # Валидирует пользователя для действий с ролями
  #
  def validate_user_for_role!
    # Нельзя менять роли удаленному пользователю
    if user.status == "deleted"
      raise RoleError, "Cannot change roles of deleted user"
    end

    # Нельзя менять роли самому себе
    if user == current_user
      raise RoleError, "Cannot change your own roles"
    end
  end

  #
  # Выполняет действие с ролью
  #
  def execute_role_action!
    case @action
    when :add
      add_role!
    when :remove
      remove_role!
    end
  end

  #
  # Добавляет роль пользователю
  #
  def add_role!
    if user.has_role?(@role.name)
      raise RoleError, "User already has role: #{@role.name}"
    end

    user.add_role(@role.name)
    user.save
  end

  #
  # Удаляет роль у пользователя
  #
  def remove_role!
    unless user.has_role?(@role.name)
      raise RoleError, "User does not have role: #{@role.name}"
    end

    user.remove_role(@role.name)
    user.save
  end

  #
  # Валидирует пользователя для удаления
  #
  def validate_user_for_destroy!
    # Нельзя удалять самого себя
    if user == current_user
      raise DestroyError, "Cannot delete yourself"
    end

    # Нельзя удалять уже удаленного пользователя
    if user.status == "deleted"
      raise DestroyError, "User is already deleted"
    end
  end

  #
  # Проверяет возможность удаления
  #
  def validate_deletion!
    # Проверяем, есть ли у пользователя важные данные
    # Например, контракты, платежи и т.д.
    # В будущем можно добавить дополнительные проверки
  end

  #
  # Выполняет мягкое удаление пользователя
  #
  def destroy_user!
    user.status = "deleted"

    unless user.save
      errors_text = user.errors.full_messages.join(", ")
      raise DestroyError, errors_text
    end
  end

  #
  # Custom exception для ошибок обновления пользователя
  #
  class UpdateError < StandardError; end

  #
  # Custom exception для ошибок изменения статуса
  #
  class StatusError < StandardError; end

  #
  # Custom exception для ошибок управления ролями
  #
  class RoleError < StandardError; end

  #
  # Custom exception для ошибок удаления
  #
  class DestroyError < StandardError; end
end
