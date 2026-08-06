# frozen_string_literal: true

require 'timeout'

#
# SystemHelpers — хелперы для system-тестов по принципу «браузер А → браузер Б».
#
# Сценарий эталона:
#   браузер А выполняет действие → изменение попадает в БД → PaperTrail →
#   VersionObserverJob → Broadcaster → CableReady → браузер Б видит live-обновление.
#
module SystemHelpers
  #
  # Выполняет блок в сеансе браузера А (первый пользователь)
  #
  # @yield блок с действиями в браузере А
  #
  def browser_a(&block)
    using_session(:browser_a, &block)
  end

  #
  # Выполняет блок в сеансе браузера Б (второй пользователь / окно)
  #
  # @yield блок с действиями в браузере Б
  #
  def browser_b(&block)
    using_session(:browser_b, &block)
  end

  #
  # Вход пользователя через UI (Devise). Надёжно для реального Capybara-сервера
  # (Warden-логин в памяти не переживает отдельный серверный процесс).
  #
  # @param user [User] пользователь
  #
  def sign_in_via_ui(user)
    # Явный locale: маршруты Devise в scope "(:locale)", без locale возможен редирект.
    visit new_user_session_path(locale: I18n.locale)
    # Вьюха входа оборачивает форму в #devise_session_form (см. devise/sessions/new.html.erb).
    within('#devise_session_form') do
      fill_in 'user[email]', with: user.email
      fill_in 'user[password]', with: user.password
      # Кнопка входа рендерится Ui::BtnComponent → <button type="submit">
      find("button[type='submit']", match: :first).click
    end
  end

  #
  # Ожидание появления CSS-селектора (polling) — для live-обновлений через
  # WebSocket. Бросает ошибку, если элемент не появился за timeout секунд.
  #
  # @param selector [String] CSS-селектор
  # @param timeout [Integer] максимальное время ожидания (секунды)
  # @return [Boolean]
  #
  def wait_for_selector(selector, timeout: 10)
    Timeout.timeout(timeout) do
      loop do
        return true if page.has_selector?(selector)
        sleep 0.2
      end
    end
  rescue Timeout::Error
    raise "Element #{selector.inspect} did not appear within #{timeout}s"
  end

  #
  # Проигрывает все поставленные в очередь джобы (Noticed, VersionObserverJob, ...).
  # Цикл: Noticed 3.x deliver_later enqueue EventJob, который уже внутри enqueue
  # доставки (Email и др.) — одиночный perform_enqueued_jobs их не проигрывает.
  # Вызывается после действия А, чтобы асинхронный конвейер отработал до
  # проверки браузером Б.
  #
  def perform_enqueued_jobs_now(max_iterations: 5)
    iterations = 0
    loop do
      break if enqueued_jobs.empty? || iterations >= max_iterations
      perform_enqueued_jobs
      iterations += 1
    end
  end
end
