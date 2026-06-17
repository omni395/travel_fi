# frozen_string_literal: true

#
# User Reflex - обработчик WebSocket событий для обновления профиля пользователя
# Получает RPC вызовы от Stimulus контроллера и обрабатывает их через WebSocket
#
# Поток: Stimulus (браузер) → Reflex (WebSocket RPC) → Service (бизнес-логика) → 
#        Model.save! → after_commit → Broadcaster (CableReady морфинг)
#
class UserReflex < ApplicationReflex
  include CableReady::Broadcaster

  #
  # Обновляет профиль пользователя
  # Получает параметры от Stimulus формы через WebSocket
  # Вызывает Service для валидации и сохранения
  # after_commit в модели автоматически вызовет Broadcaster для обновления UI
  #
  # @param name [String] новое имя пользователя
  #
  def update_profile(name)
    morph :nothing

    # Получаем текущего пользователя из WebSocket соединения
    user = current_user

    # Проверяем авторизацию через Pundit
    authorize user, :update?

    # Подготавливаем параметры для обновления
    update_params = { name: name }

    # Получаем файл аватара из формы (передаётся через signed_id в params)
    if avatar = params[:avatar]
      update_params[:avatar] = avatar
    end

    # Вызываем Service для обновления профиля
    # Service обработает валидации, загрузит аватар и сохранит в БД
    UserService.call(user: user, params: update_params)

    # После успешного сохранения в БД:
    # Model.after_commit вызовет VersionObserverJob → Broadcaster
    # Broadcaster отправит CableReady команды для обновления компонента в браузере
  rescue Pundit::NotAuthorizedError => e
    # Если пользователь не авторизован
    send_error(I18n.t("reflexes.user.not_authorized"))
  rescue UserService::UpdateError => e
    # Если Service вернул ошибку валидации
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("UserReflex#update_profile error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.user.update_error"))
  end

  #
  # Отправляет ошибку в браузер (показывает в форме)
  # Dispatch notice или alert через CableReady
  #
  # @param message [String] сообщение об ошибке
  #
  private def send_error(message)
    cable_ready["user_#{current_user.id}"].dispatch_event(
      name: "usersError",
      detail: { message: message }
    )
    broadcast
  end

  #
  # Отправляет success событие в браузер
  # Вызывается из Broadcaster после успешного обновления
  #
  # @param message [String] опциональное сообщение об успехе
  #
  private def send_success(message = nil)
    cable_ready["user_#{current_user.id}"].dispatch_event(
      name: "usersSuccess",
      detail: { message: message || I18n.t("reflexes.user.profile_updated") }
    )
    broadcast
  end
end
