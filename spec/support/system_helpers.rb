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
    using_session(:browser_a) do
      prepare_session_window
      yield
    end
  end

  #
  # Выполняет блок в сеансе браузера Б (второй пользователь / окно)
  #
  # @yield блок с действиями в браузере Б
  #
  def browser_b(&block)
    using_session(:browser_b) do
      prepare_session_window
      yield
    end
  end

  #
  # Выполняет блок в сеансе браузера С (третий пользователь / окно).
  # Используется для сценариев «браузер А → браузер Б → браузер С»
  # (например, гео-фильтрация OSM-импорта, баг 4: А импортирует в Берлин,
  # Б смотрит Берлин и видит новые POI, С смотрит Париж и НЕ получает их).
  #
  # @yield блок с действиями в браузере С
  #
  def browser_c(&block)
    using_session(:browser_c) do
      prepare_session_window
      yield
    end
  end

  #
  # Гарантирует, что у текущей сессии есть валидное окно (browser window handle).
  #
  # Причина: headful-Chrome открывает окно асинхронно; при переключении
  # using_session Capybara выполняет window_handles/switch_to_window/close_window.
  # Пока окно не создано — window_handles возвращает nil (симптомы: 'undefined
  # method slice/map for nil') либо Selenium бросает InvalidArgumentError
  # ('handle' must be a string). Данный хелпер ожидает готовности окна до
  # первых window-операций и CDP-вызовов.
  #
  # @param timeout [Integer] максимальное время ожидания (секунды)
  # @return [String] идентификатор (handle) активного окна сессии
  #
  def prepare_session_window(timeout: 90)
    Timeout.timeout(timeout) do
      loop do
        begin
          # Защита: page.driver или browser могут быть nil, если драйвер не инициализирован.
          raise Selenium::WebDriver::Error::WebDriverError, 'driver not available' if page.driver.nil? || page.driver.browser.nil?

          handles = page.driver.browser.window_handles
          return handles.first if handles && handles.any?
        rescue Selenium::WebDriver::Error::NoSuchWindowError, Selenium::WebDriver::Error::WebDriverError
          # окно ещё не готово — повторяем
        end
        sleep 0.2
      end
    end
  rescue Timeout::Error
    raise "Session window did not become available within #{timeout}s -- check Selenium driver initialization and CHROMEDRIVER_PATH"
  end

  #
  # Устойчивый к гонке CDP-вызов переопределения геолокации.
  #
  # execute_cdp требует активного таргета окна сессии. Даже после
  # prepare_session_window таргет может быть ещё не готов, и Selenium бросает
  # InvalidArgumentError ('handle' must be a string) / NoSuchWindowError.
  # Метод повторяет вызов, пока target не станет доступным.
  #
  # @param latitude [Float] широта (WGS84)
  # @param longitude [Float] долгота (WGS84)
  # @param accuracy [Float] точность (метры)
  # @param timeout [Integer] максимальное время ожидания (секунды)
  # @return [void]
  #
  def retry_cdp_geolocation(latitude:, longitude:, accuracy:, timeout: 90)
    Timeout.timeout(timeout) do
      loop do
        begin
          # Защита: убедиться, что драйвер и browser готовы
          raise Selenium::WebDriver::Error::WebDriverError, 'driver not available' if page.driver.nil? || page.driver.browser.nil?

          page.driver.browser.execute_cdp(
            'Emulation.setGeolocationOverride',
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy
          )
          return
        rescue Selenium::WebDriver::Error::NoSuchWindowError, Selenium::WebDriver::Error::InvalidArgumentError, Selenium::WebDriver::Error::WebDriverError
          # CDP-таргет окна ещё не готов — повторяем
        end
        sleep 0.2
      end
    end
  rescue Timeout::Error
    raise "CDP geolocation override did not succeed within #{timeout}s"
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
    # Страховка от гонки: ждём реального появления формы входа, иначе within
    # ищет корневой узел на незагруженной странице → 'undefined method map for nil'.
    wait_for_selector('#devise_session_form', timeout: 90)
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
  # ВАЖНО: visible: false — Capybara по умолчанию (ignore_hidden_elements = true)
  # игнорирует СКРЫТЫЕ элементы. Скрытый контейнер #poi-map-features
  # (class="hidden", map_component.html.erb:44 — данные маркеров карты) обычные
  # селекторы не находят, хотя элемент есть в DOM и маркер на карте отрисован.
  #
  # @param selector [String] CSS-селектор
  # @param timeout [Integer] максимальное время ожидания (секунды)
  # @return [Boolean]
  #
  # ВАЖНО: дефолт 90с — Selenium headful при длинных прогонах грузит страницы
  # медленно; меньшие таймауты дают флаки «элемент не появился». Не снижать.
  # 60с было недостаточно при полном прогоне сьюта (281 пример): селектор
  # присутствует в HTML (проверено диагностикой), но не успевает появиться из-за
  # накопленной нагрузки. Тест идёт дольше, но не флакает.
  #
  def wait_for_selector(selector, timeout: 90)
    Timeout.timeout(timeout) do
      loop do
        return true if page.has_css?(selector, visible: false)
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
