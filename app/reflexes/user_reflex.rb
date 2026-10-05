# frozen_string_literal: true

#
# User Reflex - обработчик WebSocket событий для обновления профиля пользователя
# Получает RPC вызовы от Stimulus контроллера и обрабатывает их через WebSocket
#
# Поток: Stimulus (браузер) → Reflex (WebSocket RPC) → Service (бизнес-логика) →
#        Model.save! → after_commit → Broadcaster (CableReady морфинг)
#
class UserReflex < ApplicationReflex
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
  # Забирает разблокированные награды пользователя (claim).
  # Ставит relay-Джобы (SolidQueue) для available-начислений; on-chain отправка
  # происходит асинхронно, UI обновляет Broadcaster (через VersionObserverJob).
  #
  def claim_rewards
    morph :nothing

    user = current_user
    authorize user, :update?

    count = UserService.claim_rewards!(user)

    if count.zero?
      send_error(I18n.t("reflexes.user.no_rewards_available"))
    else
      send_success(I18n.t("reflexes.user.rewards_claiming", count: count))
    end
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.user.not_authorized"))
  rescue StandardError => e
    Rails.logger.error("UserReflex#claim_rewards error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.user.claim_error"))
  end

  #
  # Переключает страницу истории начислений (README: read-пагинация — из Reflex
  # допустим рендер зоны, как <entity>_page в админ-таблицах).
  # Рендерит Users::RewardsComponent с указанной страницей и обновляет зону
  # [data-user-rewards] у текущего юзера через CableReady (user_N).
  #
  # @param page [Integer, String] номер страницы
  #
  def rewards_page(page = 1)
    morph :nothing

    user = current_user
    authorize user, :update?

    # Сигнатура принимает и примитив (исторический вызов), и объект { page }
    # (согласовано с эталоном админки). Нормализуем в число.
    page_number = page.is_a?(Hash) ? page[:page].to_i : page.to_i

    html = render_rewards(user, page_number)
    if html.present?
      cable_ready["user_#{user.id}"].inner_html(
        selector: "[data-user-rewards]",
        html: html
      )
      cable_ready.broadcast
    end
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.user.not_authorized"))
  rescue StandardError => e
    Rails.logger.error("UserReflex#rewards_page error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.user.claim_error"))
  end

  #
  # Рендерит компонент истории начислений для страницы.
  #
  # @param user [User] пользователь
  # @param page [Integer] номер страницы
  # @return [String, nil] HTML или nil при сбое
  #
  private def render_rewards(user, page)
    component = Users::RewardsComponent.new(user: user, page: page)
    I18n.with_locale(I18n.default_locale) do
      ApplicationController.render(component, layout: false)
    end
  rescue StandardError => e
    Rails.logger.error("UserReflex render_rewards error: #{e.class} #{e.message}")
    nil
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
    cable_ready.broadcast
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
    cable_ready.broadcast
  end
end
