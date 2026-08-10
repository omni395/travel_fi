# frozen_string_literal: true

require 'rails_helper'

#
# User — редактирование профиля (браузер А → браузер Б).
#
# Путь изменения профиля юзером (как в Admin::UsersReflex#update, который вызывает
# форма Users::FormComponent): Admin::UserService.update → PaperTrail →
# VersionObserverJob → Broadcasters.
#
# Регрессия FIX 4: админ Б видит live-обновление show-страницы
# /admin-panel/users/:id (#user-profile) БЕЗ перезагрузки (AdminChannel).
#
RSpec.describe 'User profile edit (live)', type: :system do
  let!(:admin_b) { create(:user, :admin, :with_setting, email: 'admin_b@example.com') }
  let!(:user_a) { create(:user, :with_setting, name: 'Original Name', email: 'user_a@example.com') }

  it 'А меняет имя → live-обновление show-страницы админки' do
    # Диагностика: ShowComponent рендерится из контекста бродкастера (ApplicationController.render)
    rendered = ApplicationController.render(Admin::Users::User::ShowComponent.new(user: user_a), layout: false)
    expect(rendered).to include('Original Name')

    # Б (админ) открывает show-страницу пользователя в админке
    browser_b do
      sign_in_via_ui(admin_b)
      visit admin_user_path(id: user_a)
      wait_for_selector('#user-profile')
      expect(page).to have_content('Original Name')
    end

    # Юзер меняет имя (как это делает Reflex-путь формы редактирования)
    Admin::UserService.update(user: user_a, params: { name: 'Updated Name' }, current_user: user_a)

    # Проигрываем асинхронный конвейер (PaperTrail → VersionObserverJob → Broadcasters)
    perform_enqueued_jobs_now

    # Б видит новое имя на show-странице админки (inner_html #user-profile, FIX 4)
    browser_b do
      wait_for_selector('#user-profile')
      expect(page).to have_content('Updated Name')
    end

    # Изменение зафиксировано в БД (единый источник правды)
    expect(user_a.reload.name).to eq('Updated Name')
  end
end
