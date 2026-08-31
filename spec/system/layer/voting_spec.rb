# frozen_string_literal: true

require 'rails_helper'

#
# Voting / Community Moderation (браузер А, реальные клики по кнопкам).
#
# ПОВЕДЕНЧЕСКИЙ сценарий голосования через UI (не через прямой вызов сервиса):
#   1. create   — первый клик по «Апрув» ставит голос +1 (запись в БД, счётчик 1).
#   2. destroy  — повторный клик по той же кнопке открывает ConfirmDialog «забрать
#                 голос»; подтверждение удаляет голос (Vote удалён, счётчик 0).
#   3. change   — поставить +1, затем клик по «Дизлайк» открывает ConfirmDialog
#                 «изменить голос»; подтверждение удаляет старый и создаёт -1.
#
# Ключевое: НЕ вызываем VoteService напрямую — двигаем реальный StimulusReflex-поток
# (Stimulus → VoteReflex → VoteService → PaperTrail → Broadcast). Именно этот слой
# не был покрыт прежним спеком (тот звал service в лоб).
#
# Геолокация: POI обязан быть в радиусе 100м от юзера (анти-фрод из VoteReflex →
# check_proximity!). Задаём детерминированную геолокацию на Берлин (как центр карты)
# и создаём POI ровно в той же точке → расстояние 0 → проксимити ок.
#
RSpec.describe 'Community Moderation (голосование через реальные клики)', type: :system do
  # Координаты Берлина (fallback-центр карты + геолокация теста, TestGeolocation).
  POI_LAT = TestGeolocation::DEFAULT_TEST_LAT
  POI_LNG = TestGeolocation::DEFAULT_TEST_LNG

  let!(:author) { create(:user, :with_setting, email: 'vote_author@example.com') }
  let!(:voter)  { create(:user, :with_setting, email: 'vote_voter@example.com') }
  let!(:category) { create(:poi_category) }
  let!(:poi) do
    create(:poi,
           user: author,
           poi_category: category,
           status: 'approved',
           name: { 'en' => 'Vote Target', 'ru' => 'Цель голосования', 'es' => 'Objetivo', 'zh' => '投票目标' },
           coordinates: PoiService.parse_coordinates(POI_LAT, POI_LNG))
  end

  # Селекторы голосования внутри таргет-обёртки.
  def vote_zone
    "[data-vote-zone='poi-#{poi.id}']"
  end

  def up_btn
    "#{vote_zone} button[data-action='ui--vote-component#castUp']"
  end

  def down_btn
    "#{vote_zone} button[data-action='ui--vote-component#castDown']"
  end

  def up_counter
    "#{vote_zone} [data-vote-counter='up']"
  end

  def down_counter
    "#{vote_zone} [data-vote-counter='down']"
  end

  #
  # Подготавливает браузер А: логин + открытие карты.
  # Геопозиция (Берлин) мокается ГЛОБАЛЬНО через единый prepare_map_geolocation
  # (spec/support/system_helpers.rb) — CDP-оверрайд + JS-стаб navigator.geolocation
  # + ПРЯМОЙ форс PoiReflex#set_location (детерминированная session). После визита
  # страховочно форсим set_location ещё раз, чтобы session[:user_lat/lng] была
  # гарантированно заполнена, независимо от тайминга браузерной геолокации →
  # check_proximity! при клике пройдёт (POI в радиусе 100м от Берлина).
  #
  def prepare_browser
    sign_in_via_ui(voter)
    prepare_map_geolocation
    visit pois_path
    wait_for_selector('#poi-list [data-poi-id]', timeout: 90)
    force_user_location(latitude: POI_LAT, longitude: POI_LNG)
  end

  #
  # Открывает карточку POI (poi:show-detail → ку maniu внутри оверлея) и
  # переключает таб «Ratings», где живёт голосование (Poi::RatingsComponent).
  #
  def open_ratings_tab
    page.execute_script(
      "document.dispatchEvent(new CustomEvent('poi:show-detail', { detail: { poiId: #{poi.id} } }))"
    )
    wait_for_selector("[data-poi--show-component-target='overlay']:not(.hidden)", timeout: 60)
    wait_for_selector("button[data-tab='ratings']", timeout: 30)
    # Клик по табу через JS (ui--tabs-component#switch) — Selenium-клик по кнопке
    # таба хрупок при многократном прогоне (по образцу open_gallery_tab).
    page.execute_script("document.querySelector(\"button[data-tab='ratings']\").click()")
    wait_for_selector(vote_zone, timeout: 30)
  end

  # Кликает по кнопке голосования через JS (устойчиво к перекрытию обложкой).
  def click_btn(selector)
    page.execute_script("document.querySelector(#{selector.inspect}).click()")
  end

  # Подтверждает открывшийся ConfirmDialog (кнопка «Да/подтвердить»).
  # Ищем кнопку подтверждения только ВНУТРИ конкретного диалога (в DOM их два —
  # removeDialog и changeDialog), чтобы не было неоднозначности.
  def confirm_dialog(dialog_target)
    dialog = "#{vote_zone} [data-ui--vote-component-target='#{dialog_target}']"
    wait_for_selector("#{dialog} [data-controller='ui--confirm-dialog-component']", timeout: 30)
    confirm_btn = "#{dialog} button[data-action='click->ui--confirm-dialog-component#confirm']"
    wait_for_selector(confirm_btn, timeout: 30)
    page.execute_script("document.querySelector(#{confirm_btn.inspect}).click()")
  end

  # Ожидание, пока условие станет истинным (polling с таймаутом).
  def wait_until(timeout: 30, &block)
    Timeout.timeout(timeout) do
      sleep 0.2 until block.call
    end
  rescue Timeout::Error
    raise 'Condition did not become true within timeout'
  end

  it 'полный цикл: create → ConfirmDialog забрать → destroy → ConfirmDialog изменить → change' do
    prepare_browser
    open_ratings_tab

    # --- 1. CREATE: первый клик по «Апрув» ставит голос +1 ---
    click_btn(up_btn)
    wait_until { poi.reload.votes.count == 1 && poi.reload.votes.first.value == 1 }
    expect(page).to have_css(up_counter, text: '1')

    # Повторный клик по ТОЙ ЖЕ кнопке → должен открыться ConfirmDialog «забрать голос».
    click_btn(up_btn)
    wait_for_selector("#{vote_zone} [data-ui--vote-component-target='removeDialog'] [data-controller='ui--confirm-dialog-component']:not(.hidden)", timeout: 30)

    # --- 2. DESTROY: подтверждение удаляет голос ---
    confirm_dialog('removeDialog')
    wait_until { poi.reload.votes.count == 0 }
    expect(page).to have_css(up_counter, text: '0')

    # --- 3. Снова ставим +1 (для смены голоса) ---
    click_btn(up_btn)
    wait_until { poi.reload.votes.count == 1 && poi.reload.votes.first.value == 1 }

    # --- 4. CHANGE: клик по «Дизлайк» (противоположный) → ConfirmDialog «изменить» ---
    click_btn(down_btn)
    wait_for_selector("#{vote_zone} [data-ui--vote-component-target='changeDialog'] [data-controller='ui--confirm-dialog-component']:not(.hidden)", timeout: 30)

    # Подтверждение: старый (+1) удаляется, создаётся -1.
    confirm_dialog('changeDialog')
    wait_until { poi.reload.votes.count == 1 && poi.reload.votes.first.value == -1 }
    expect(page).to have_css(down_counter, text: '1')
    expect(page).to have_css(up_counter, text: '0')
  end
end
