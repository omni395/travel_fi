# frozen_string_literal: true

require 'rails_helper'

#
# Ui::SidebarComponent — поведение сайдбара на странице карты POI.
#
# Требования:
#   1. При загрузке страницы сайдбар СВЁРНУТ (узкая полоска с шевроном),
#      карта занимает всю ширину — наложения нет.
#   2. При раскрытии сайдбар НАКРЫВАЕТ карту поверх (оверлей-одеяло),
#      НЕ сдвигая её. Ширина/позиция карты не меняются.
#   3. Повторный клик сворачивает сайдбар обратно в полоску.
#
# Проверка наложения ведётся через фактическую ширину/позицию контейнера
# карты (boundingClientRect) до и после раскрытия — если карта сдвинута
# (flex-поток), её левый край и ширина изменятся; это и есть баг «карта
# сдвинута» (ROADMAP: сайдбар должен работать оверлеем, не выталкивая карту).
#
RSpec.describe 'Sidebar toggle on POI map', type: :system do
  # Сайдбар — чистый фронтенд (ViewComponent + Stimulus), не зависит от карты:
  # обёртка присутствует в HTML при серверном рендере. Карта/маркеры/геолокация
  # для проверки сайдбара не нужны и только добавляют флаки.

  # Координаты boundingClientRect стабильного flex-контейнера карты
  # (.flex-1.min-w-0.relative из index.html.erb). Он рендерится сервером
  # синхронно и не зависит от инициализации OpenLayers — измерение устойчиво.
  # @return [Hash] left, width контейнера карты
  def map_rect(timeout: 10)
    wait_for_selector('.flex-1.min-w-0.relative', timeout: timeout)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector('.flex-1.min-w-0.relative')
        if (!el) return null
        const r = el.getBoundingClientRect()
        return { left: r.left, width: r.width }
      })()
    JS
  end

  # Текущее состояние сайдбара: свёрнут/развёрнут через класс обёртки
  # @return [Symbol] :collapsed | :expanded
  def sidebar_state
    expanded = page.evaluate_script(<<~JS)
      !!document.querySelector('.ui-sidebar--wrapper')?.classList.contains('ui-sidebar--expanded')
    JS
    expanded ? :expanded : :collapsed
  end

  # Ждёт, пока фактическая ширина панели .ui-sidebar достигнет условия.
  # CSS использует transition width 0.3s, поэтому класс переключается мгновенно,
  # а ширина анимируется — проверка getBoundingClientRect сразу после клика
  # ловит промежуточное значение. Ожидаем завершения анимации.
  #
  # @param :expanded [:expanded] ждать ширины > 100
  # @param :collapsed [:collapsed] ждать ширины < 1
  # @param timeout [Integer] максимальное время ожидания (секунды)
  # @return [void]
  def wait_panel_geometry(expectation, timeout: 5)
    Timeout.timeout(timeout) do
      loop do
        width = page.evaluate_script(<<~JS)
          (() => {
            const aside = document.querySelector('.ui-sidebar')
            return aside ? aside.getBoundingClientRect().width : -1
          })()
        JS
        met = expectation == :expanded ? width > 100 : width < 1
        return if met
        sleep 0.1
      end
    end
  rescue Timeout::Error
    raise "Панель сайдбара не достигла состояния #{expectation} за #{timeout}s"
  end

  it 'загружается свёрнутым (полоска), карта на всю ширину без наложения' do
    visit pois_path
    wait_for_selector('.ui-sidebar--wrapper', timeout: 90)

    # Сайдбар свёрнут по умолчанию
    expect(sidebar_state).to eq(:collapsed)

    # Шеврон-кнопка видна (полоска)
    expect(page).to have_css('.ui-sidebar--wrapper button[data-action*="sidebarToggle"]', wait: 10)

    # Панель сайдбара скрыта (width:0 в свёрнутом)
    panel_hidden = page.evaluate_script(<<~JS)
      (() => {
        const aside = document.querySelector('.ui-sidebar')
        if (!aside) return false
        const r = aside.getBoundingClientRect()
        return r.width < 1 || r.right <= r.left
      })()
    JS
    expect(panel_hidden).to eq(true), 'Панель сайдбара должна быть скрыта в свёрнутом состоянии'
  end

  it 'при раскрытии накрывает карту поверх, НЕ сдвигая её' do
    visit pois_path
    wait_for_selector('.ui-sidebar--wrapper', timeout: 90)

    # Ширина и позиция карты ДО раскрытия
    before_rect = map_rect
    expect(before_rect).not_to be_nil

    # Раскрываем сайдбар кликом по шеврону
    find('.ui-sidebar--wrapper button[data-action*="sidebarToggle"]', wait: 10).click
    wait_for_selector('.ui-sidebar--wrapper.ui-sidebar--expanded', timeout: 10)

    # Состояние — expanded
    expect(sidebar_state).to eq(:expanded)

    # Панель стала видимой (ожидаем завершения transition)
    wait_panel_geometry(:expanded)

    # Ключевая проверка: карта НЕ сдвинута (левый край и ширина не изменились).
    # Панель сайдбара — absolute-оверлей ОТНОСИТЕЛЬНО обёртки (left:100%),
    # выезжает поверх карты. Обёртка остаётся в потоке, поэтому карта
    # сохраняет позицию и размер.
    panel_overlay = page.evaluate_script(<<~JS)
      (() => {
        const p = document.querySelector('.ui-sidebar')
        return p && getComputedStyle(p).position === 'absolute'
      })()
    JS
    expect(panel_overlay).to eq(true), 'Панель сайдбара должна быть absolute (оверлей) при раскрытии'

    after_rect = map_rect
    # Selenium evaluate_script возвращает хэш со СТРОКОВЫМИ ключами (JSON),
    # поэтому обращаемся через ['left'] / ['width'].
    expect(after_rect['left']).to be_within(1.0).of(before_rect['left']),
      "Карта сдвинута по горизонтали при раскрытии сайдбара: left #{before_rect['left']} → #{after_rect['left']}"
    expect(after_rect['width']).to be_within(1.0).of(before_rect['width']),
      "Ширина карты изменилась при раскрытии сайдбара: #{before_rect['width']} → #{after_rect['width']}"
  end

  it 'повторный клик сворачивает сайдбар обратно в полоску' do
    visit pois_path
    wait_for_selector('.ui-sidebar--wrapper', timeout: 90)

    # Раскрыли
    find('.ui-sidebar--wrapper button[data-action*="sidebarToggle"]', wait: 10).click
    wait_for_selector('.ui-sidebar--wrapper.ui-sidebar--expanded', timeout: 10)
    expect(sidebar_state).to eq(:expanded)

    # Свернули повторным кликом
    find('.ui-sidebar--wrapper button[data-action*="sidebarToggle"]', wait: 10).click
    wait_for_selector('.ui-sidebar--wrapper.ui-sidebar--collapsed', timeout: 10)
    expect(sidebar_state).to eq(:collapsed)

    # Панель снова скрыта (ожидаем завершения transition)
    wait_panel_geometry(:collapsed)
  end

  it 'клик вне сайдбара закрывает развёрнутый сайдбар' do
    visit pois_path
    wait_for_selector('.ui-sidebar--wrapper', timeout: 90)

    # Раскрыли сайдбар
    find('.ui-sidebar--wrapper button[data-action*="sidebarToggle"]', wait: 10).click
    wait_for_selector('.ui-sidebar--wrapper.ui-sidebar--expanded', timeout: 10)
    expect(sidebar_state).to eq(:expanded)

    # Клик по карте (вне зоны сайдбара) должен закрыть сайдбар
    page.execute_script(<<~JS)
      document.querySelector('.poi-map')?.click()
    JS

    wait_for_selector('.ui-sidebar--wrapper.ui-sidebar--collapsed', timeout: 10)
    expect(sidebar_state).to eq(:collapsed)
  end
end
