# frozen_string_literal: true

#
# Selenium Chrome — конфигурация драйвера system-тестов.
#
# Драйвер `selenium_chrome_visible`:
# - Локально (по умолчанию) — ВИДИМОЕ окно Chrome (browser: :chrome без
#   --headless): открывается вкладка, загружается страница, выполняются
#   действия — процесс виден визуально.
# - В CI / полный прогон — headless: ENV['CI'] присутствует, либо
#   ENV['CUPRITE_HEADLESS']=true. Headless в Selenium 4.46 — это флаг
#   Chrome `--headless=new` на обычном :chrome (browser: :headless_chrome
#   упразднён → `unknown driver: :headless_chrome`).
#
# Флаги:
# - --enable-unsafe-swiftshader — программный WebGL против «белого квадрата»
#   на скриншотах (карта OpenLayers/Canvas в headless).
# - --disable-gpu — только в headless (в headful мешает отрисовке окна).
#
require 'selenium-webdriver'
require 'capybara/rails'

headless = ENV['CI'].present? || ENV.fetch('CUPRITE_HEADLESS', 'false') == 'true'

Capybara.register_driver :selenium_chrome_visible do |app|
  options = ::Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--window-size=1440,900')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--enable-unsafe-swiftshader')
  if headless
    options.add_argument('--headless=new')
    options.add_argument('--disable-gpu')
  end

  # If a local chromedriver binary path is provided via ENV, use it and
  # avoid Selenium Manager (which may fail on macOS due to permissions).
  service = if ENV['CHROMEDRIVER_PATH'] && !ENV['CHROMEDRIVER_PATH'].empty?
              Selenium::WebDriver::Service.chrome(path: ENV['CHROMEDRIVER_PATH'])
  else
              nil
  end

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options,
    service: service
  )
end
